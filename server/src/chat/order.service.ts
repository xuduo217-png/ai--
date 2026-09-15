import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import {
  DataSource,
  EntityManager,
  Repository,
  IsNull,
  LessThan,
  MoreThan,
} from 'typeorm';
import { randomUUID } from 'crypto';
import { ChatOrder, OrderStatus } from './entities/chat-order.entity';
import { ChatSessionService } from './chat-session.service';
import { ChatSession, SessionStatus } from './entities/chat-session.entity';
import { Message, MessageStatus, MessageType } from './entities/message.entity';
import { DoctorsService } from '../doctors/doctors.service';
import { RedisService } from '../redis/redis.service';
import { ChatGateway } from './chat.gateway';
import { PaymentService } from '../payment/payment.service';
import {
  BusinessType,
  Payment,
  PaymentChannel,
  PaymentMethod,
} from '../payment/entities/payment.entity';
import { CreatePaymentResponse } from '../payment/dto/create-payment.dto';
import {
  ChatPaymentFulfiller,
  PaymentAfterCommit,
} from '../payment/chat-payment-fulfiller';
import { equals, toNumber } from '../common/utils/currency.util';
import { User } from '../users/entities/user.entity';

export interface CreateChatOrderResult {
  order: ChatOrder;
  paymentParams: CreatePaymentResponse;
}

interface PreparedTempMessages {
  entities: Message[];
  cleanup: () => Promise<void>;
}

@Injectable()
export class OrderService implements ChatPaymentFulfiller {
  private readonly logger = new Logger(OrderService.name);

  constructor(
    @InjectRepository(ChatOrder)
    private orderRepository: Repository<ChatOrder>,
    @InjectRepository(Message)
    private messageRepository: Repository<Message>,
    private chatSessionService: ChatSessionService,
    private doctorsService: DoctorsService,
    private redisService: RedisService,
    private chatGateway: ChatGateway,
    private paymentService: PaymentService,
    private dataSource: DataSource,
  ) {}

  async create(
    userId: number,
    doctorId: number,
    serviceItemId: number,
    paymentChannel: PaymentChannel,
    idempotencyKey: string,
    conversationId?: string,
  ): Promise<CreateChatOrderResult> {
    this.logger.log(
      `[create] 开始创建订单: userId=${userId}, doctorId=${doctorId}, serviceItemId=${serviceItemId}`,
    );

    // 获取收费项信息
    const serviceItem =
      await this.doctorsService.findServiceItemById(serviceItemId);
    if (!serviceItem) {
      this.logger.warn(`[create] 收费项不存在: serviceItemId=${serviceItemId}`);
      throw new NotFoundException('收费项不存在');
    }

    this.logger.log(
      `[create] 收费项信息: id=${serviceItem.id}, name=${serviceItem.name}, doctorId=${serviceItem.doctorId}, isActive=${serviceItem.isActive}`,
    );

    if (!serviceItem.isActive) {
      throw new BadRequestException('收费项已下架');
    }

    // 验证收费项是否属于指定医生
    if (serviceItem.doctorId !== doctorId) {
      this.logger.warn(
        `[create] 收费项与医生不匹配: serviceItem.doctorId=${serviceItem.doctorId}, request.doctorId=${doctorId}`,
      );
      throw new BadRequestException('收费项与医生不匹配');
    }

    // 检查是否存在未结束的付费会话（PAID 且未过期）
    const existingSession = await this.chatSessionService.getActiveSession(
      userId,
      doctorId,
    );
    if (existingSession) {
      // 只检查是否已有活跃的付费服务
      const isActivePaidSession =
        existingSession.status === SessionStatus.PAID &&
        existingSession.serviceEndAt &&
        new Date() < existingSession.serviceEndAt;

      if (isActivePaidSession) {
        throw new BadRequestException('您已有有效的付费服务，无需重复购买');
      }

      // 如果是 FREE 会话，允许购买，服务将在下次会话时生效
      // 或者立即结束免费会话并开始付费服务（根据业务需求选择）
      // 这里我们选择：购买后立即升级为付费会话
    }

    const tempSession = await this.chatSessionService.getTempSession(
      userId,
      doctorId,
    );
    const preservedConversationId =
      Boolean(conversationId) && tempSession?.conversationId === conversationId;
    const idempotencyRemark = `payment-idempotency:${idempotencyKey}`;
    const savedOrder = await this.dataSource.transaction(async (manager) => {
      const user = await manager
        .createQueryBuilder(User, 'user')
        .where('user.id = :id', { id: userId })
        .setLock('pessimistic_write')
        .getOne();
      if (!user) throw new NotFoundException('用户不存在');

      const existingOrder = await manager.findOne(ChatOrder, {
        where: { userId, remark: idempotencyRemark },
      });
      if (
        existingOrder &&
        (existingOrder.doctorId !== doctorId ||
          existingOrder.serviceItemId !== serviceItemId)
      ) {
        throw new BadRequestException('支付幂等键与订单信息不匹配');
      }
      if (existingOrder) return existingOrder;

      const order = manager.create(ChatOrder, {
        orderNo: this.generateOrderNo(),
        userId,
        doctorId,
        serviceItemId,
        durationMinutes: serviceItem.duration,
        amount: serviceItem.price,
        status: OrderStatus.PENDING,
        paidAt: undefined,
        serviceStartAt: undefined,
        serviceEndAt: undefined,
        expiredAt: new Date(Date.now() + 15 * 60 * 1000),
        remark: idempotencyRemark,
      });
      const createdOrder = await manager.save(ChatOrder, order);
      this.logger.log(
        `[create] 待支付订单保存成功: orderId=${createdOrder.id}`,
      );
      return createdOrder;
    });

    if (![OrderStatus.PENDING, OrderStatus.PAID].includes(savedOrder.status)) {
      throw new BadRequestException('当前订单状态不允许继续支付');
    }

    const paymentRequest = {
      channel: paymentChannel,
      method: PaymentMethod.APP,
      amount: toNumber(savedOrder.amount),
      userId,
      businessType: BusinessType.CHAT_PACKAGE,
      businessId: savedOrder.id,
      subject: `医生咨询 - ${serviceItem.name}`,
      body: `医生咨询服务，时长 ${serviceItem.duration} 分钟`,
      expireIn: 900,
      metadata: {
        idempotencyKey,
        conversationId: preservedConversationId
          ? tempSession?.conversationId
          : undefined,
      },
    };
    const paymentParams =
      paymentChannel === PaymentChannel.BALANCE
        ? await this.paymentService.payBusinessWithBalance(paymentRequest)
        : savedOrder.status === OrderStatus.PAID
          ? await this.paymentService.getBusinessPaymentResponse(
              BusinessType.CHAT_PACKAGE,
              savedOrder.id,
            )
          : await this.paymentService.createPayment(paymentRequest);

    const latestOrder =
      (await this.orderRepository.findOne({ where: { id: savedOrder.id } })) ||
      savedOrder;
    return { order: latestOrder, paymentParams };
  }

  async fulfillSuccessfulPayment(
    manager: EntityManager,
    payment: Payment,
  ): Promise<PaymentAfterCommit | void> {
    if (payment.businessType !== BusinessType.CHAT_PACKAGE) {
      throw new BadRequestException('支付单不是医生咨询套餐');
    }

    const user = await manager
      .createQueryBuilder(User, 'user')
      .where('user.id = :id', { id: payment.userId })
      .setLock('pessimistic_write')
      .getOne();
    if (!user) {
      throw new NotFoundException('支付用户不存在');
    }

    const order = await manager
      .createQueryBuilder(ChatOrder, 'chatOrder')
      .leftJoinAndSelect('chatOrder.serviceItem', 'serviceItem')
      .where('chatOrder.id = :id', { id: payment.businessId })
      .setLock('pessimistic_write')
      .getOne();
    if (!order) {
      throw new NotFoundException(`咨询订单不存在: ${payment.businessId}`);
    }
    if (order.userId !== payment.userId) {
      throw new BadRequestException('支付用户与咨询订单归属不一致');
    }
    if (!equals(order.amount, payment.amount)) {
      throw new BadRequestException('支付金额与咨询订单金额不一致');
    }

    const existingOrderSession = await manager.findOne(ChatSession, {
      where: { orderId: order.id },
    });
    if (order.status === OrderStatus.PAID) {
      await this.doctorsService.incrementConsultation(order.doctorId, manager);
      if (!existingOrderSession) return;
      const existingPaymentMessage = await manager.findOne(Message, {
        where: {
          orderId: order.id,
          type: MessageType.PAYMENT_SUCCESS,
        },
      });
      return this.buildAfterCommit(
        order,
        existingOrderSession.conversationId,
        existingPaymentMessage,
        undefined,
      );
    }
    if (order.status !== OrderStatus.PENDING) {
      throw new BadRequestException('咨询订单状态不允许更新为已支付');
    }

    const activeSession = await manager.findOne(ChatSession, {
      where: {
        userId: order.userId,
        doctorId: order.doctorId,
        status: SessionStatus.PAID,
        serviceEndAt: MoreThan(new Date()),
      },
    });
    if (activeSession && activeSession.orderId !== order.id) {
      throw new BadRequestException('已有有效的付费咨询服务');
    }

    const paidAt = payment.paidAt || new Date();
    const serviceEndAt = new Date(
      paidAt.getTime() + order.durationMinutes * 60 * 1000,
    );
    const requestedConversationId = `${payment.metadata?.conversationId || ''}`;
    const conversationId =
      requestedConversationId.trim() ||
      existingOrderSession?.conversationId ||
      randomUUID();
    const preparedTempMessages = requestedConversationId
      ? await this.prepareTempMessages(conversationId, order.id)
      : undefined;

    const session =
      existingOrderSession ||
      manager.create(ChatSession, {
        userId: order.userId,
        doctorId: order.doctorId,
        conversationId,
        status: SessionStatus.PAID,
        orderId: order.id,
        autoReplyCount: 0,
        maxFreeReplies: 3,
        serviceStartAt: paidAt,
        serviceEndAt,
      });
    session.status = SessionStatus.PAID;
    session.orderId = order.id;
    session.serviceStartAt = paidAt;
    session.serviceEndAt = serviceEndAt;
    await manager.save(ChatSession, session);

    if (preparedTempMessages?.entities.length) {
      await manager.save(Message, preparedTempMessages.entities);
    }

    order.status = OrderStatus.PAID;
    order.paidAt = paidAt;
    order.serviceStartAt = paidAt;
    order.serviceEndAt = serviceEndAt;
    await manager.save(ChatOrder, order);
    await this.doctorsService.incrementConsultation(order.doctorId, manager);

    const endTimeText = serviceEndAt.toLocaleString('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
    const paymentMessage = await manager.save(
      Message,
      manager.create(Message, {
        conversationId,
        senderId: null,
        senderType: 'doctor',
        receiverId: order.userId,
        receiverType: 'user',
        content: `您已购买「${order.serviceItem?.name || '医生咨询'}」，服务至 ${endTimeText}`,
        type: MessageType.PAYMENT_SUCCESS,
        status: MessageStatus.SENT,
        isAutoReply: false,
        orderId: order.id,
      }),
    );

    await manager.update(
      Message,
      {
        conversationId,
        orderId: IsNull(),
        createdAt: LessThan(paidAt),
      },
      { orderId: order.id },
    );
    this.logger.log(`咨询订单 ${order.orderNo} 已支付并激活会话`);

    return this.buildAfterCommit(
      order,
      conversationId,
      paymentMessage,
      preparedTempMessages?.cleanup,
    );
  }

  private buildAfterCommit(
    order: ChatOrder,
    conversationId: string,
    paymentMessage?: Message | null,
    cleanupTempMessages?: () => Promise<void>,
  ): PaymentAfterCommit {
    return async () => {
      await cleanupTempMessages?.();
      await this.chatSessionService.deleteTempSession(
        order.userId,
        order.doctorId,
      );
      if (!paymentMessage) return;
      this.chatGateway.notifyPaymentSuccess(order.userId, order.doctorId, {
        id: paymentMessage.id,
        conversationId,
        senderId: paymentMessage.senderId,
        senderType: paymentMessage.senderType,
        receiverId: paymentMessage.receiverId,
        receiverType: paymentMessage.receiverType,
        content: paymentMessage.content,
        type: paymentMessage.type,
        status: paymentMessage.status,
        isAutoReply: paymentMessage.isAutoReply,
        orderId: paymentMessage.orderId,
        createdAt: paymentMessage.createdAt,
      });
    };
  }

  private async prepareTempMessages(
    conversationId: string,
    orderId: number,
  ): Promise<PreparedTempMessages> {
    const tempKey = `chat:temp:${conversationId}`;
    const rawMessages = await this.redisService.lrange(tempKey, 0, -1);
    if (rawMessages.length === 0) {
      return { entities: [], cleanup: async () => undefined };
    }

    const messages = rawMessages.map((value) => JSON.parse(value));
    const readAtByPrincipal = new Map<string, Date | null>();
    for (const message of messages) {
      if (!message.receiverType || !message.receiverId) continue;
      const principalKey = `${message.receiverType}:${message.receiverId}`;
      if (readAtByPrincipal.has(principalKey)) continue;
      const readAt = await this.redisService.get(
        `chat:read:${principalKey}:${conversationId}`,
      );
      readAtByPrincipal.set(principalKey, readAt ? new Date(readAt) : null);
    }

    const entities = messages.map((message) => {
      const principalKey = `${message.receiverType}:${message.receiverId}`;
      const readAt = readAtByPrincipal.get(principalKey);
      const createdAt = new Date(message.createdAt);
      const wasRead =
        message.isRead === true ||
        (readAt instanceof Date &&
          !Number.isNaN(readAt.getTime()) &&
          createdAt.getTime() <= readAt.getTime());
      return this.messageRepository.create({
        conversationId,
        senderId: message.senderId,
        senderType: message.senderType,
        receiverId: message.receiverId,
        receiverType: message.receiverType,
        content: message.content,
        type: message.type,
        status: wasRead ? MessageStatus.READ : MessageStatus.SENT,
        isRead: wasRead,
        isAutoReply: message.isAutoReply || false,
        isRevoked: message.isRevoked === true,
        revokedAt: message.revokedAt ? new Date(message.revokedAt) : null,
        packages: message.packages,
        orderId,
        createdAt,
      });
    });

    return {
      entities,
      cleanup: async () => {
        const unreadFieldsByPrincipal = new Map<string, string[]>();
        for (const message of messages) {
          if (!message.receiverType || !message.receiverId || !message.id) {
            continue;
          }
          const principalKey = `${message.receiverType}:${message.receiverId}`;
          const fields = unreadFieldsByPrincipal.get(principalKey) || [];
          fields.push(`${conversationId}:${message.id}`);
          unreadFieldsByPrincipal.set(principalKey, fields);
        }
        for (const [principalKey, fields] of unreadFieldsByPrincipal) {
          await this.redisService.hdel(
            `chat:unread:${principalKey}`,
            ...fields,
          );
          await this.redisService.del(
            `chat:read:${principalKey}:${conversationId}`,
          );
        }
        await this.redisService.del(tempKey);
      },
    };
  }

  async getUserOrders(userId: number, page = 1, pageSize = 10): Promise<any> {
    const [data, total] = await this.orderRepository.findAndCount({
      where: { userId },
      relations: ['serviceItem', 'doctor'],
      order: { createdAt: 'DESC' },
      skip: (page - 1) * pageSize,
      take: pageSize,
    });

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 获取医生订单列表
   * 供医生端按分页查看自己的咨询订单
   */
  async getDoctorOrders(
    doctorId: number,
    page = 1,
    pageSize = 10,
  ): Promise<any> {
    const [data, total] = await this.orderRepository.findAndCount({
      where: { doctorId },
      relations: ['serviceItem', 'doctor'],
      order: { createdAt: 'DESC' },
      skip: (page - 1) * pageSize,
      take: pageSize,
    });

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  async findByOrderNo(orderNo: string): Promise<ChatOrder> {
    const order = await this.orderRepository.findOne({
      where: { orderNo },
      relations: ['serviceItem', 'doctor'],
    });

    if (!order) {
      throw new NotFoundException('订单不存在');
    }

    return order;
  }

  async findById(id: number): Promise<ChatOrder> {
    const order = await this.orderRepository.findOne({
      where: { id },
      relations: ['serviceItem', 'doctor', 'session'],
    });

    if (!order) {
      throw new NotFoundException('订单不存在');
    }

    return order;
  }

  async cancelOrder(orderNo: string, userId: number): Promise<ChatOrder> {
    const order = await this.findByOrderNo(orderNo);

    if (order.userId !== userId) {
      throw new BadRequestException('无权操作此订单');
    }

    if (order.status !== OrderStatus.PENDING) {
      throw new BadRequestException('只能取消待支付订单');
    }

    order.status = OrderStatus.CANCELLED;
    return this.orderRepository.save(order);
  }

  private generateOrderNo(): string {
    const now = new Date();
    const timestamp = now.getTime().toString();
    const random = Math.floor(Math.random() * 10000)
      .toString()
      .padStart(4, '0');
    return `CO${timestamp}${random}`;
  }

  /**
   * 迁移临时消息到数据库
   * 付费成功后调用，将 Redis 中的临时消息批量迁移到 MySQL
   * @param conversationId 会话 ID
   */
  async migrateTempMessages(conversationId: string): Promise<void> {
    // 1. 从 Redis 获取临时消息
    const tempKey = `chat:temp:${conversationId}`;
    const tempMessages = await this.redisService.lrange(tempKey, 0, -1);

    if (tempMessages.length === 0) {
      this.logger.log(`会话 ${conversationId} 没有临时消息需要迁移`);
      return;
    }

    this.logger.log(
      `开始迁移会话 ${conversationId} 的 ${tempMessages.length} 条消息`,
    );

    // 2. 解析并批量插入到 MySQL
    const parsedMessages = tempMessages.map((msg) => JSON.parse(msg));
    const readAtByPrincipal = new Map<string, Date | null>();
    for (const message of parsedMessages) {
      if (!message.receiverType || !message.receiverId) continue;
      const principalKey = `${message.receiverType}:${message.receiverId}`;
      if (readAtByPrincipal.has(principalKey)) continue;
      const readAt = await this.redisService.get(
        `chat:read:${principalKey}:${conversationId}`,
      );
      readAtByPrincipal.set(principalKey, readAt ? new Date(readAt) : null);
    }

    const messageEntities = parsedMessages.map((msg) => {
      // 调试：打印每条要迁移的消息
      this.logger.log(
        `[迁移消息] senderId=${msg.senderId}, receiverId=${msg.receiverId}, senderType=${msg.senderType}, receiverType=${msg.receiverType}, isAutoReply=${msg.isAutoReply}, content=${msg.content?.substring(0, 20)}`,
      );

      const principalKey = `${msg.receiverType}:${msg.receiverId}`;
      const readAt = readAtByPrincipal.get(principalKey);
      const wasReadBeforeMigration =
        msg.isRead === true ||
        (readAt instanceof Date &&
          !Number.isNaN(readAt.getTime()) &&
          new Date(msg.createdAt).getTime() <= readAt.getTime());

      return this.messageRepository.create({
        conversationId: msg.conversationId,
        senderId: msg.senderId,
        senderType: msg.senderType,
        receiverId: msg.receiverId,
        receiverType: msg.receiverType,
        content: msg.content,
        type: msg.type,
        status: wasReadBeforeMigration
          ? MessageStatus.READ
          : MessageStatus.SENT,
        isRead: wasReadBeforeMigration,
        isAutoReply: msg.isAutoReply || false,
        isRevoked: msg.isRevoked === true,
        revokedAt: msg.revokedAt ? new Date(msg.revokedAt) : null,
        packages: msg.packages,
        createdAt: new Date(msg.createdAt),
      });
    });

    await this.messageRepository.save(messageEntities);

    this.logger.log(`成功迁移 ${messageEntities.length} 条消息到数据库`);

    // 3. 清理已迁移消息对应的临时未读索引和会话已读水位
    const unreadFieldsByPrincipal = new Map<string, string[]>();
    for (const message of parsedMessages) {
      if (!message.receiverType || !message.receiverId || !message.id) continue;
      const principalKey = `${message.receiverType}:${message.receiverId}`;
      const fields = unreadFieldsByPrincipal.get(principalKey) ?? [];
      fields.push(`${conversationId}:${message.id}`);
      unreadFieldsByPrincipal.set(principalKey, fields);
    }
    for (const [principalKey, fields] of unreadFieldsByPrincipal) {
      await this.redisService.hdel(`chat:unread:${principalKey}`, ...fields);
      await this.redisService.del(
        `chat:read:${principalKey}:${conversationId}`,
      );
    }

    // 4. 删除 Redis 中的临时消息
    await this.redisService.del(tempKey);

    this.logger.log(`已删除 Redis 中的临时消息: ${tempKey}`);
  }

  /**
   * 获取医生收入统计
   * @param doctorId 医生ID
   * @returns 收入统计数据
   */
  async getDoctorIncomeStats(doctorId: number): Promise<{
    today: number;
    thisWeek: number;
    thisMonth: number;
    total: number;
    consultationCount: number;
  }> {
    const now = new Date();
    const todayStart = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate(),
    );
    const weekStart = new Date(todayStart);
    weekStart.setDate(weekStart.getDate() - now.getDay()); // 本周一
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1); // 本月1号

    // 查询已支付订单
    const orders = await this.orderRepository.find({
      where: {
        doctorId,
        status: OrderStatus.PAID,
      },
      select: ['amount', 'paidAt', 'id'],
    });

    // 初始化统计数据
    let today = 0;
    let thisWeek = 0;
    let thisMonth = 0;
    let total = 0;
    const consultationCount = orders.length;

    // 遍历订单计算各时段收入
    orders.forEach((order) => {
      const paidAt = new Date(order.paidAt);
      const amount = parseFloat(order.amount.toString());

      total += amount;

      // 今日收入
      if (paidAt >= todayStart) {
        today += amount;
      }

      // 本周收入
      if (paidAt >= weekStart) {
        thisWeek += amount;
      }

      // 本月收入
      if (paidAt >= monthStart) {
        thisMonth += amount;
      }
    });

    return {
      today: Math.round(today * 100) / 100, // 保留两位小数
      thisWeek: Math.round(thisWeek * 100) / 100,
      thisMonth: Math.round(thisMonth * 100) / 100,
      total: Math.round(total * 100) / 100,
      consultationCount,
    };
  }

  /**
   * 获取医生收入明细列表
   * @param doctorId 医生ID
   * @param page 页码
   * @param pageSize 每页数量
   * @returns 收入明细列表
   */
  async getDoctorIncomeList(
    doctorId: number,
    page = 1,
    pageSize = 10,
  ): Promise<{
    data: Array<{
      id: string;
      consultationId: string;
      amount: number;
      status: string;
      createdAt: string;
      userName?: string;
      serviceName?: string;
    }>;
    total: number;
    page: number;
    pageSize: number;
    totalPages: number;
  }> {
    const [orders, total] = await this.orderRepository.findAndCount({
      where: {
        doctorId,
        status: OrderStatus.PAID,
      },
      relations: ['user', 'serviceItem'],
      order: { createdAt: 'DESC' },
      skip: (page - 1) * pageSize,
      take: pageSize,
    });

    const data = orders.map((order) => ({
      id: order.id.toString(),
      consultationId: order.orderNo,
      amount: parseFloat(order.amount.toString()),
      status: order.status.toLowerCase(),
      createdAt: order.paidAt?.toISOString() || order.createdAt.toISOString(),
      userName: order.user?.username || '未知用户',
      serviceName: order.serviceItem?.name || '咨询服务',
    }));

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }
}
