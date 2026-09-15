import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
  Optional,
} from "@nestjs/common";
import { ModuleRef } from "@nestjs/core";
import { ConfigService } from "@nestjs/config";
import { randomUUID } from "crypto";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository, DataSource, EntityManager } from "typeorm";
import {
  Payment,
  PaymentStatus,
  PaymentChannel,
  BusinessType,
  PaymentMethod,
} from "./entities/payment.entity";
import {
  PaymentTransaction,
  TransactionType,
  TransactionStatus,
} from "./entities/payment-transaction.entity";
import { Refund, RefundStatus, RefundType } from "./entities/refund.entity";
import {
  CreatePaymentDto,
  CreatePaymentRequest,
  CreatePaymentResponse,
} from "./dto/create-payment.dto";
import { CreateRefundDto, CreateRefundResponse } from "./dto/create-refund.dto";
import { AlipayService } from "./alipay.service";
import { WechatPayService } from "./wechat-pay.service";
import { createBusinessException } from "../common/constants/error-codes";
import { ErrorCode } from "../common/constants/error-codes";
import { Order, OrderStatus, OrderType } from "../shop/entities/order.entity";
import { User } from "../users/entities/user.entity";
import {
  RelatedType,
  WalletTransaction,
  WalletTransactionStatus,
  WalletTransactionType,
} from "../shop/entities/wallet-transaction.entity";
import { add, equals, subtract, toCents, toNumber, toYuan } from "../common/utils/currency.util";
import {
  AfterSaleStatus,
  OrderAfterSale,
} from "../shop/entities/order-after-sale.entity";
import { PaymentStatusResponseDto } from "./dto/payment-status.dto";
import {
  WalletRecharge,
  WalletRechargeStatus,
} from "../shop/entities/wallet-recharge.entity";
import {
  CharityDonationEntryType,
  CharityDonationSource,
  CharityRecord,
} from "../charity/entities/charity-record.entity";
import { Charity, CharityStatus, ParticipantType } from "../charity/entities/charity.entity";
import {
  CHAT_PAYMENT_FULFILLER,
  ChatPaymentFulfiller,
  PaymentAfterCommit,
} from "./chat-payment-fulfiller";

@Injectable()
export class PaymentService {
  private readonly logger = new Logger(PaymentService.name);

  constructor(
    @InjectRepository(Payment)
    private paymentRepository: Repository<Payment>,
    @InjectRepository(PaymentTransaction)
    private transactionRepository: Repository<PaymentTransaction>,
    @InjectRepository(Refund)
    private refundRepository: Repository<Refund>,
    @InjectRepository(Order)
    private orderRepository: Repository<Order>,
    private alipayService: AlipayService,
    private wechatPayService: WechatPayService,
    private dataSource: DataSource,
    private moduleRef: ModuleRef,
    private configService: ConfigService,
    @Optional()
    @InjectRepository(Charity)
    private charityRepository?: Repository<Charity>,
  ) {}

  /**
   * 按业务实体创建支付（管理员诊断入口）
   * 仅允许通过业务类型和业务 ID 推导支付上下文，避免外部注入归属和金额
   */
  async createPaymentFromBusiness(
    createPaymentDto: CreatePaymentDto,
  ): Promise<CreatePaymentResponse> {
    const paymentRequest =
      await this.buildPaymentContextByBusiness(createPaymentDto);

    return this.createPayment(paymentRequest);
  }

  /**
   * 创建支付（供内部业务服务调用）
   */
  async createPayment(
    createPaymentDto: CreatePaymentRequest,
  ): Promise<CreatePaymentResponse> {
    const {
      channel,
      method,
      amount,
      userId,
      businessType,
      businessId,
      subject,
      body,
      clientIp,
      expireIn = 900, // 默认15分钟
      metadata,
      outTradeNo: customOutTradeNo,
      description,
    } = createPaymentDto;
    const normalizedAmount = toNumber(amount);
    if (!Number.isFinite(normalizedAmount) || normalizedAmount <= 0) {
      throw new BadRequestException("支付金额必须是大于 0 的有效数字");
    }

    // 1. 生成支付单号和商户订单号
    const paymentNo = this.generatePaymentNo();
    const baseOutTradeNo = customOutTradeNo || `${businessType}_${businessId}`;

    // 商城订单允许用户在支付完成前切换渠道。相同渠道复用当前尝试，
    // 不同渠道关闭旧尝试后创建新的商户订单号，保留完整支付审计链路。
    const existingPayment =
      businessType === BusinessType.SHOP_ORDER
        ? await this.paymentRepository.findOne({
            where: { businessType, businessId },
            order: { createdAt: "DESC" },
          })
        : await this.paymentRepository.findOne({
            where: { outTradeNo: baseOutTradeNo },
          });
    let outTradeNo = baseOutTradeNo;

    if (existingPayment) {
      if (!equals(existingPayment.amount, normalizedAmount)) {
        throw new BadRequestException("支付金额与已有支付单不一致");
      }

      if (
        [
          PaymentStatus.SUCCESS,
          PaymentStatus.REFUNDING,
          PaymentStatus.REFUNDED,
        ].includes(existingPayment.status)
      ) {
        throw createBusinessException(ErrorCode.PAYMENT_ALREADY_PAID);
      }

      if (existingPayment.status === PaymentStatus.PROCESSING) {
        throw createBusinessException(
          ErrorCode.PAYMENT_STATUS_INVALID,
          "支付结果处理中，暂时不能切换支付渠道",
        );
      }

      if (
        existingPayment.channel === channel &&
        existingPayment.status === PaymentStatus.PENDING
      ) {
        this.logger.warn(
          `Payment already exists for outTradeNo: ${existingPayment.outTradeNo}`,
        );
        return this.getPaymentResponse(existingPayment);
      }

      if (
        existingPayment.channel === channel &&
        existingPayment.status === PaymentStatus.FAILED
      ) {
        // 失败只代表本地创建支付参数失败；沿用同一个商户订单号重试，
        // 避免网络超时后另起交易造成重复扣款。
        existingPayment.status = PaymentStatus.PENDING;
        existingPayment.failReason = null;
        existingPayment.expiredAt = new Date(Date.now() + expireIn * 1000);
        existingPayment.updatedAt = new Date();
        const retriedPayment =
          await this.paymentRepository.save(existingPayment);
        return this.getPaymentResponse(retriedPayment);
      }

      if (
        existingPayment.channel !== channel &&
        existingPayment.status === PaymentStatus.PENDING
      ) {
        await this.closePaymentAttemptForChannelSwitch(existingPayment);
      }

      outTradeNo = this.generatePaymentAttemptOutTradeNo(baseOutTradeNo);
    }

    // 3. 创建支付记录
    const expiredAt = new Date(Date.now() + expireIn * 1000);
    const payment = this.paymentRepository.create({
      paymentNo,
      outTradeNo,
      channel,
      method,
      status: PaymentStatus.PENDING,
      amount: normalizedAmount,
      userId,
      businessType,
      businessId,
      subject,
      body,
      description: description || subject,
      clientIp,
      metadata,
      expiredAt,
    });

    let savedPayment: Payment;
    try {
      savedPayment = await this.paymentRepository.save(payment);
    } catch (error) {
      // 并发请求可能同时发现没有支付单，唯一索引由数据库仲裁；
      // 竞争失败的一方重新使用已经落库的待支付单。
      const concurrentPayment = await this.paymentRepository.findOne({
        where: { outTradeNo },
      });
      if (
        concurrentPayment?.status === PaymentStatus.PENDING &&
        equals(concurrentPayment.amount, normalizedAmount)
      ) {
        return this.getPaymentResponse(concurrentPayment);
      }
      throw error;
    }
    this.logger.log(
      `Payment created: ${paymentNo}, amount: ${amount}, channel: ${channel}`,
    );

    // 4. 根据支付渠道调用对应服务创建支付
    try {
      const paymentParams = await this.createPaymentParams(savedPayment);
      return this.buildPaymentResponse(savedPayment, paymentParams);
    } catch (error) {
      // 开发环境：如果支付服务未配置，返回模拟支付参数
      const isDev = this.configService.get("NODE_ENV") === "development";
      const isNotConfigured =
        error.message?.includes("not configured") ||
        error.message?.includes("未配置");

      if (isDev && isNotConfigured) {
        this.logger.warn(
          `Payment service not configured, using mock payment for development: ${error.message}`,
        );
        const mockParams = this.generateMockPaymentParams(savedPayment);

        // 模拟支付成功（开发环境自动完成支付）
        // 延迟 1 秒模拟支付完成
        setTimeout(async () => {
          try {
            const afterCommit = await this.dataSource.transaction(
              async (manager) => {
                const lockedPayment = await manager
                  .createQueryBuilder(Payment, "payment")
                  .where("payment.id = :id", { id: savedPayment.id })
                  .setLock("pessimistic_write")
                  .getOne();
                if (!lockedPayment) {
                  throw new NotFoundException("支付记录不存在");
                }
                return this.completeSuccessfulPayment(
                  manager,
                  lockedPayment,
                  `MOCK_${savedPayment.paymentNo}`,
                  { source: "development_mock" },
                );
              },
            );
            await this.runAfterCommit(afterCommit);
            this.logger.log(
              `Mock payment completed: ${savedPayment.paymentNo}`,
            );
          } catch (updateError) {
            this.logger.error(
              `Mock payment completion failed: ${updateError.message}`,
            );
          }
        }, 1000);

        return {
          paymentNo: savedPayment.paymentNo,
          outTradeNo: savedPayment.outTradeNo,
          amount: savedPayment.amount,
          channel: savedPayment.channel,
          method: savedPayment.method,
          paymentParams: mockParams,
          expiredAt: savedPayment.expiredAt,
        };
      }

      // 生产环境或配置了但出错的，正常抛出错误
      this.logger.error(`Create payment failed: ${error.message}`, error.stack);
      // 创建支付失败，更新状态
      await this.paymentRepository.update(savedPayment.id, {
        status: PaymentStatus.FAILED,
        failReason: error.message,
      });
      throw error;
    }
  }

  async getBusinessPaymentResponse(
    businessType: BusinessType,
    businessId: number,
  ): Promise<CreatePaymentResponse> {
    const payment = await this.paymentRepository.findOne({
      where: { businessType, businessId },
      order: { createdAt: "DESC" },
    });
    if (!payment) {
      throw createBusinessException(ErrorCode.PAYMENT_NOT_FOUND);
    }
    if (payment.status === PaymentStatus.SUCCESS) {
      return this.buildPaymentResponse(payment, {});
    }
    return this.getPaymentResponse(payment);
  }

  /**
   * 余额支付内部业务单。钱包扣款、支付记录和业务履约在同一事务内完成。
   */
  async payBusinessWithBalance(
    request: CreatePaymentRequest,
  ): Promise<CreatePaymentResponse> {
    if (
      request.channel !== PaymentChannel.BALANCE ||
      request.businessType !== BusinessType.CHAT_PACKAGE
    ) {
      throw new BadRequestException("当前业务不支持余额支付");
    }
    const amount = toNumber(request.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException("支付金额必须是大于 0 的有效数字");
    }

    let afterCommit: PaymentAfterCommit | void;
    const payment = await this.dataSource.transaction(async (manager) => {
      const user = await manager
        .createQueryBuilder(User, "user")
        .where("user.id = :id", { id: request.userId })
        .setLock("pessimistic_write")
        .getOne();
      if (!user) throw new NotFoundException("用户不存在");

      const existingPayment = await manager.findOne(Payment, {
        where: {
          businessType: request.businessType,
          businessId: request.businessId,
        },
        order: { createdAt: "DESC" },
      });
      if (existingPayment) {
        if (!equals(existingPayment.amount, request.amount)) {
          throw new BadRequestException("支付金额与已有支付单不一致");
        }
        if (existingPayment.status === PaymentStatus.SUCCESS) {
          afterCommit = await this.fulfillSuccessfulPayment(
            manager,
            existingPayment,
          );
          return existingPayment;
        }
        throw new BadRequestException("当前订单已有未完成的支付尝试");
      }

      const balanceBefore = toNumber(user.balance);
      if (balanceBefore < amount) {
        throw createBusinessException(ErrorCode.INSUFFICIENT_BALANCE);
      }

      const now = new Date();
      const savedPayment = await manager.save(
        Payment,
        manager.create(Payment, {
          paymentNo: this.generatePaymentNo(),
          outTradeNo: `${request.businessType}_${request.businessId}`,
          channel: PaymentChannel.BALANCE,
          method: request.method || PaymentMethod.APP,
          status: PaymentStatus.PENDING,
          amount,
          refundAmount: 0,
          userId: request.userId,
          businessType: request.businessType,
          businessId: request.businessId,
          subject: request.subject,
          body: request.body,
          description: request.description || request.subject,
          clientIp: request.clientIp,
          metadata: { ...request.metadata, balancePayment: true },
          expiredAt: new Date(now.getTime() + (request.expireIn || 900) * 1000),
          updatedAt: now,
        }),
      );

      const balanceAfter = subtract(balanceBefore, amount);
      user.balance = balanceAfter;
      await manager.save(User, user);
      await manager.save(
        WalletTransaction,
        manager.create(WalletTransaction, {
          userId: user.id,
          type: WalletTransactionType.EXPENSE,
          amount,
          balanceBefore,
          balanceAfter,
          relatedType: RelatedType.ADJUSTMENT,
          relatedId: request.businessId,
          status: WalletTransactionStatus.APPROVED,
          remark: `余额支付医生咨询 ${request.businessId}`,
          reviewedAt: now,
          reviewedBy: user.id,
          frozenAmount: 0,
          autoProcessed: true,
        }),
      );

      afterCommit = await this.completeSuccessfulPayment(
        manager,
        savedPayment,
        savedPayment.paymentNo,
        { source: "balance" },
      );
      return savedPayment;
    });

    await this.runAfterCommit(afterCommit);
    return this.buildPaymentResponse(payment, {});
  }

  /**
   * 按业务实体构建支付上下文
   * 业务规则：管理员诊断入口只允许提交业务定位参数，金额和归属必须由服务端推导
   */
  private async buildPaymentContextByBusiness(
    createPaymentDto: CreatePaymentDto,
  ): Promise<CreatePaymentRequest> {
    switch (createPaymentDto.businessType) {
      case BusinessType.SHOP_ORDER:
        return this.buildShopOrderPaymentContext(createPaymentDto);
      default:
        throw new BadRequestException(
          `业务类型 ${createPaymentDto.businessType} 暂不支持通过诊断入口创建支付`,
        );
    }
  }

  /**
   * 构建商城订单支付上下文
   * 业务规则：订单金额、归属和描述全部以订单快照为准，避免外部参数污染支付记录
   */
  private async buildShopOrderPaymentContext(
    createPaymentDto: CreatePaymentDto,
  ): Promise<CreatePaymentRequest> {
    const order = await this.orderRepository.findOne({
      where: { id: createPaymentDto.businessId },
    });

    if (!order) {
      throw createBusinessException(
        ErrorCode.BUSINESS_INVALID_PARAM,
        `商城订单 ${createPaymentDto.businessId} 不存在`,
      );
    }

    if (order.status !== OrderStatus.PENDING) {
      throw createBusinessException(
        ErrorCode.BUSINESS_INVALID_PARAM,
        "当前订单状态不允许创建支付",
      );
    }

    const items = Array.isArray(order.items) ? order.items : [];
    const firstItemName = items[0]?.productName || `订单 ${order.orderNo}`;
    const body = items
      .map((item) => `${item.productName} x${item.quantity}`)
      .join(", ");
    const subject =
      items.length > 1
        ? `商城订单支付 - ${firstItemName} 等${items.length}件商品`
        : `商城订单支付 - ${firstItemName}`;

    return {
      channel: createPaymentDto.channel,
      method: createPaymentDto.method,
      amount: toNumber(order.totalAmount),
      userId: order.userId,
      businessType: BusinessType.SHOP_ORDER,
      businessId: order.id,
      subject,
      body,
      description: body || subject,
      clientIp: createPaymentDto.clientIp,
      expireIn: createPaymentDto.expireIn,
      metadata: {
        ...createPaymentDto.metadata,
        orderNo: order.orderNo,
        clientIp:
          createPaymentDto.clientIp ?? createPaymentDto.metadata?.clientIp,
      },
    };
  }

  /**
   * 获取开发环境 mock 支付页基础地址
   * 优先使用显式公共地址，避免 admin/rnapp 收到只对本机有效的 localhost 链接。
   */
  private getMockPaymentBaseUrl(): string {
    const configuredBaseUrl =
      this.configService.get<string>("SERVER_PUBLIC_BASE_URL")?.trim() ||
      this.configService.get<string>("SERVER_LAN_HOST")?.trim();

    if (configuredBaseUrl) {
      const normalizedBaseUrl = configuredBaseUrl.replace(/\/+$/, "");
      if (
        normalizedBaseUrl.startsWith("http://") ||
        normalizedBaseUrl.startsWith("https://")
      ) {
        return normalizedBaseUrl;
      }

      const port = this.configService.get<string>("PORT") || "3000";
      return `http://${normalizedBaseUrl}:${port}`;
    }

    const port = this.configService.get<string>("PORT") || "3000";
    return `http://127.0.0.1:${port}`;
  }

  /**
   * 处理支付回调（支付宝/微信）
   * 安全修复：使用事务和悲观锁确保幂等性和原子性
   */
  async handlePaymentCallback(
    channel: PaymentChannel,
    callbackData: any,
    headers?: any,
    rawBody?: string,
  ): Promise<void> {
    // 安全修复：不记录完整回调数据，仅记录必要信息
    this.logger.log(`Payment callback received: channel=${channel}`);

    try {
      // 1. 验证签名
      let isValid = false;
      let outTradeNo: string | null = null;
      let transactionId: string | null = null;
      let callbackAmount: string | null = null;

      if (channel.startsWith("alipay")) {
        const result = await this.alipayService.verifyCallback(callbackData);
        isValid = result.valid;
        outTradeNo = result.outTradeNo;
        transactionId = result.tradeNo;
        callbackAmount = result.totalAmount;
      } else if (channel.startsWith("wechat")) {
        const result = await this.wechatPayService.verifyCallback(
          callbackData,
          headers,
          rawBody,
        );
        isValid = result.valid;
        outTradeNo = result.outTradeNo;
        transactionId = result.transactionId;
      } else {
        throw new BadRequestException("不支持的支付渠道");
      }

      if (!isValid || !outTradeNo || !transactionId) {
        this.logger.warn(
          `Payment callback signature verification failed: ${channel}`,
        );
        throw new BadRequestException("签名验证失败");
      }

      // 2. 使用事务和悲观锁处理支付状态更新（防止并发重复处理）
      const afterCommit = await this.dataSource.transaction(async (manager) => {
        // 使用悲观锁获取支付记录，确保原子性
        const payment = await manager
          .createQueryBuilder(Payment, "payment")
          .where("payment.outTradeNo = :outTradeNo", { outTradeNo })
          .setLock("pessimistic_write")
          .getOne();

        if (!payment) {
          this.logger.warn(`Payment not found: ${outTradeNo}`);
          throw new NotFoundException("支付记录不存在");
        }

        if (
          ![
            PaymentStatus.PENDING,
            PaymentStatus.PROCESSING,
            PaymentStatus.SUCCESS,
          ].includes(payment.status)
        ) {
          throw new BadRequestException("支付单已关闭或状态不允许支付");
        }

        // 回调渠道必须与支付单一致，防止不同渠道的交易推进同一支付单。
        if (
          (channel.startsWith("alipay") &&
            !payment.channel.startsWith("alipay")) ||
          (channel.startsWith("wechat") &&
            !payment.channel.startsWith("wechat"))
        ) {
          throw new BadRequestException("支付渠道与支付单不一致");
        }

        // 支付宝回调金额必须与本地支付单金额一致，不能只凭签名推进订单。
        if (
          channel.startsWith("alipay") &&
          !equals(callbackAmount, payment.amount)
        ) {
          throw new BadRequestException("支付宝回调金额与支付单不一致");
        }

        return this.completeSuccessfulPayment(
          manager,
          payment,
          transactionId,
          callbackData,
        );
      });
      await this.runAfterCommit(afterCommit);
    } catch (error) {
      this.logger.error(
        `Handle payment callback failed: ${error.message}`,
        error.stack,
      );
      throw error;
    }
  }

  /**
   * 在支付事务内把已确认的支付落到业务实体。
   * 回调和主动查单都应复用这段逻辑，避免支付单成功而订单仍待支付。
   */
  private async fulfillSuccessfulPayment(
    manager: EntityManager,
    payment: Payment,
  ): Promise<PaymentAfterCommit | void> {
    switch (payment.businessType) {
      case BusinessType.SHOP_ORDER:
        await this.fulfillShopOrderPayment(manager, payment);
        return;
      case BusinessType.WALLET_RECHARGE:
        await this.fulfillWalletRechargePayment(manager, payment);
        return;
      case BusinessType.CHARITY_DONATION:
        await this.fulfillCharityDonationPayment(manager, payment);
        return;
      case BusinessType.CHAT_PACKAGE: {
        const fulfiller = this.moduleRef.get<ChatPaymentFulfiller>(
          CHAT_PAYMENT_FULFILLER,
          { strict: false },
        );
        if (!fulfiller) {
          throw new BadRequestException("咨询支付履约服务不可用");
        }
        return fulfiller.fulfillSuccessfulPayment(manager, payment);
      }
      default:
        return;
    }
  }

  private async fulfillShopOrderPayment(
    manager: EntityManager,
    payment: Payment,
  ): Promise<void> {
    const order = await manager
      .createQueryBuilder(Order, "order")
      .where("order.id = :id", { id: payment.businessId })
      .setLock("pessimistic_write")
      .getOne();

    if (!order) {
      throw new NotFoundException(`商城订单不存在: ${payment.businessId}`);
    }

    if (payment.userId !== order.userId) {
      throw new BadRequestException("支付用户与订单归属不一致");
    }

    if (!equals(payment.amount, order.totalAmount)) {
      throw new BadRequestException("支付金额与订单金额不一致");
    }

    if (order.paymentNo && order.paymentNo !== payment.paymentNo) {
      throw new BadRequestException("订单已绑定其他支付单");
    }

    // 重复通知或历史补偿时，已付款订单是幂等成功状态。
    if (order.status === OrderStatus.PAID) {
      await this.fulfillShopOrderDonation(manager, order, payment);
      return;
    }

    if (order.status !== OrderStatus.PENDING) {
      throw new BadRequestException("订单状态不允许更新为已支付");
    }

    await manager.update(Order, order.id, {
      status: OrderStatus.PAID,
      paidAt: payment.paidAt || new Date(),
      paymentMethod: payment.channel,
      paymentNo: payment.paymentNo,
      transactionId: payment.transactionId,
    });

    await this.fulfillShopOrderDonation(manager, order, payment);

    setImmediate(() => {
      this.triggerWebhook(payment, "ORDER_PAID_NOTIFICATION").catch((error) =>
        this.logger.error(`Order paid notification failed: ${error.message}`),
      );
    });

    this.logger.log(`Order ${order.orderNo} paid successfully`);
  }

  private async fulfillWalletRechargePayment(
    manager: EntityManager,
    payment: Payment,
  ): Promise<void> {
    const recharge = await manager
      .createQueryBuilder(WalletRecharge, "recharge")
      .where("recharge.id = :id", { id: payment.businessId })
      .setLock("pessimistic_write")
      .getOne();
    if (!recharge) {
      throw new NotFoundException(`钱包充值单不存在: ${payment.businessId}`);
    }
    if (recharge.userId !== payment.userId) {
      throw new BadRequestException("支付用户与充值单归属不一致");
    }
    if (!equals(recharge.amount, payment.amount)) {
      throw new BadRequestException("支付金额与充值金额不一致");
    }
    if (recharge.paymentNo && recharge.paymentNo !== payment.paymentNo) {
      throw new BadRequestException("充值单已绑定其他支付单");
    }
    if (recharge.status === WalletRechargeStatus.SUCCEEDED) return;
    if (recharge.status !== WalletRechargeStatus.PENDING) {
      throw new BadRequestException("充值单状态不允许入账");
    }

    const user = await manager
      .createQueryBuilder(User, "user")
      .where("user.id = :id", { id: payment.userId })
      .setLock("pessimistic_write")
      .getOne();
    if (!user) throw new NotFoundException("用户不存在");

    const balanceBefore = toNumber(user.balance);
    const balanceAfter = add(balanceBefore, payment.amount);
    user.balance = balanceAfter;
    await manager.save(user);

    const walletTransaction = await manager.save(
      manager.create(WalletTransaction, {
        userId: user.id,
        type: WalletTransactionType.INCOME,
        amount: toNumber(payment.amount),
        balanceBefore,
        balanceAfter,
        relatedType: RelatedType.RECHARGE,
        relatedId: recharge.id,
        status: WalletTransactionStatus.APPROVED,
        remark: "支付宝充值",
        frozenAmount: 0,
        autoProcessed: true,
      }),
    );

    recharge.status = WalletRechargeStatus.SUCCEEDED;
    recharge.paymentNo = payment.paymentNo;
    recharge.walletTransactionId = walletTransaction.id;
    recharge.paidAt = payment.paidAt || new Date();
    recharge.failureMessage = null;
    await manager.save(recharge);
    this.logger.log(`Wallet recharge ${recharge.rechargeNo} credited`);
  }

  private async fulfillCharityDonationPayment(
    manager: EntityManager,
    payment: Payment,
  ): Promise<void> {
    const taskEvidence = `payment:${payment.paymentNo}`;
    const existingRecord = await manager.findOne(CharityRecord, {
      where: {
        charityId: payment.businessId,
        userId: payment.userId,
        taskType: "donation",
        taskEvidence,
      },
    });
    if (existingRecord) return;

    await manager.save(
      manager.create(CharityRecord, {
        charityId: payment.businessId,
        userId: payment.userId,
        checkInDate: null,
        checkInTime: payment.paidAt || new Date(),
        taskType: "donation",
        taskEvidence,
        donationAmount: toNumber(payment.amount),
      }),
    );
    this.logger.log(`Charity donation ${payment.paymentNo} fulfilled`);
  }

  /**
   * 普通商城订单自动公益入账。该方法由线上支付和余额支付共同调用，
   * 并且与订单支付履约处于同一个事务中。
   */
  async fulfillShopOrderDonation(
    manager: EntityManager,
    order: Order,
    payment: Payment,
  ): Promise<void> {
    if (
      !this.charityRepository ||
      order.orderType !== OrderType.NORMAL ||
      payment.businessType !== BusinessType.SHOP_ORDER
    ) {
      return;
    }

    const charity = await manager
      .createQueryBuilder(Charity, "charity")
      .where("charity.isMallAutoDonation = :enabled", { enabled: true })
      .andWhere("charity.participantType = :participantType", {
        participantType: ParticipantType.DONATION,
      })
      .andWhere("charity.status = :status", { status: CharityStatus.ACTIVE })
      .andWhere("charity.deletedAt IS NULL")
      .orderBy("charity.isPinned", "DESC")
      .addOrderBy("charity.createdAt", "DESC")
      .setLock("pessimistic_write")
      .getOne();
    if (!charity) return;

    const sourceReference = `shop_payment:${payment.paymentNo}`;
    const existingRecord = await manager.findOne(CharityRecord, {
      where: { sourceReference },
    });
    if (existingRecord) return;

    const baseCents = toCents(payment.amount);
    const rate = toNumber(charity.donationRate);
    const donationCents = Math.round((baseCents * rate) / 100);
    const paidAt = payment.paidAt || new Date();
    await manager.save(
      manager.create(CharityRecord, {
        charityId: charity.id,
        userId: order.userId,
        checkInDate: null,
        checkInTime: paidAt,
        taskType: "mall_order",
        taskEvidence: `order:${order.orderNo}`,
        donationAmount: toYuan(donationCents),
        donationSource: CharityDonationSource.MALL_ORDER,
        donationEntryType: CharityDonationEntryType.CREDIT,
        orderId: order.id,
        orderNo: order.orderNo,
        donationBaseAmount: toYuan(baseCents),
        donationRate: rate,
        sourceReference,
      }),
    );
    this.logger.log(
      `Mall order ${order.orderNo} charity donation fulfilled: ${toYuan(donationCents)}`,
    );
  }

  /** 退款成功后按原公益比例生成负数冲销流水。 */
  private async fulfillShopOrderRefund(
    manager: EntityManager,
    payment: Payment,
    refund: Refund,
  ): Promise<void> {
    if (!this.charityRepository || payment.businessType !== BusinessType.SHOP_ORDER) {
      return;
    }

    const sourceCredit = await manager.findOne(CharityRecord, {
      where: {
        orderId: payment.businessId,
        donationSource: CharityDonationSource.MALL_ORDER,
        donationEntryType: CharityDonationEntryType.CREDIT,
      },
      order: { id: "ASC" },
    });
    if (!sourceCredit) return;

    const sourceDonationCents = Math.max(toCents(sourceCredit.donationAmount || 0), 0);
    const sourceBaseCents = toCents(sourceCredit.donationBaseAmount || payment.amount);
    if (sourceBaseCents <= 0) return;

    const reversalRecords = await manager.find(CharityRecord, {
      where: {
        orderId: payment.businessId,
        donationSource: CharityDonationSource.MALL_ORDER,
        donationEntryType: CharityDonationEntryType.REVERSAL,
      },
    });
    const reversedCents = reversalRecords.reduce(
      (sum, record) => sum + Math.abs(toCents(record.donationAmount || 0)),
      0,
    );
    const remainingCents = Math.max(sourceDonationCents - reversedCents, 0);
    const refundDonationCents = Math.min(
      remainingCents,
      Math.round((toCents(refund.refundAmount) * sourceDonationCents) / sourceBaseCents),
    );

    const sourceReference = `refund:${refund.refundNo}`;
    const existingRecord = await manager.findOne(CharityRecord, {
      where: { sourceReference },
    });
    if (existingRecord) return;

    const order = await manager.findOne(Order, { where: { id: payment.businessId } });
    await manager.save(
      manager.create(CharityRecord, {
        charityId: sourceCredit.charityId,
        userId: payment.userId,
        checkInDate: null,
        checkInTime: refund.refundedAt || new Date(),
        taskType: "mall_refund",
        taskEvidence: `refund:${refund.refundNo}`,
        donationAmount: -toYuan(refundDonationCents),
        donationSource: CharityDonationSource.MALL_ORDER,
        donationEntryType: CharityDonationEntryType.REVERSAL,
        orderId: payment.businessId,
        orderNo: order?.orderNo || sourceCredit.orderNo,
        donationBaseAmount: toNumber(refund.refundAmount),
        donationRate: sourceCredit.donationRate,
        sourceReference,
      }),
    );
    this.logger.log(
      `Mall order refund ${refund.refundNo} charity reversal fulfilled: ${toYuan(refundDonationCents)}`,
    );
  }

  private async completeSuccessfulPayment(
    manager: EntityManager,
    payment: Payment,
    transactionId: string,
    responseData: unknown,
  ): Promise<PaymentAfterCommit | void> {
    const isFirstSuccess = payment.status !== PaymentStatus.SUCCESS;
    if (isFirstSuccess) {
      const now = new Date();
      payment.status = PaymentStatus.SUCCESS;
      payment.transactionId = transactionId;
      payment.thirdPartyTradeNo = transactionId;
      payment.paidAt = now;
      payment.updatedAt = now;
      await manager.save(payment);

      const transaction = await manager.findOne(PaymentTransaction, {
        where: {
          paymentId: payment.id,
          type: TransactionType.PAY,
          status: TransactionStatus.SUCCESS,
        },
      });
      if (!transaction) {
        await manager.save(
          manager.create(PaymentTransaction, {
            paymentId: payment.id,
            transactionNo: this.generateTransactionNo(),
            type: TransactionType.PAY,
            status: TransactionStatus.SUCCESS,
            channel: payment.channel,
            amount: toNumber(payment.amount),
            responseData,
          }),
        );
      }
    }

    const afterCommit = await this.fulfillSuccessfulPayment(manager, payment);
    this.logger.log(
      `Payment success: ${payment.paymentNo}, transactionId: ${transactionId}`,
    );
    return afterCommit;
  }

  private async runAfterCommit(
    afterCommit: PaymentAfterCommit | void,
  ): Promise<void> {
    if (!afterCommit) return;
    try {
      await afterCommit();
    } catch (error) {
      this.logger.error(`Payment after-commit hook failed: ${error.message}`);
    }
  }

  /**
   * 查询支付状态
   */
  async queryPaymentStatus(
    paymentNo: string,
    requesterId: number,
    requesterRole: string,
  ): Promise<PaymentStatusResponseDto> {
    const payment = await this.paymentRepository.findOne({
      where: { paymentNo },
    });

    if (!payment) {
      throw createBusinessException(ErrorCode.PAYMENT_NOT_FOUND);
    }

    const isAdmin =
      requesterRole === "SUPER_ADMIN" || requesterRole === "STAFF";
    if (!isAdmin && payment.userId !== requesterId) {
      throw createBusinessException(ErrorCode.PERMISSION_DENIED);
    }

    // 如果支付状态是待支付，向第三方查询最新状态
    if (payment.status === PaymentStatus.PENDING) {
      try {
        let thirdPartyStatus: string;

        if (payment.channel.startsWith("alipay")) {
          thirdPartyStatus = await this.alipayService.queryPayment(payment);
        } else if (payment.channel.startsWith("wechat")) {
          thirdPartyStatus = await this.wechatPayService.queryPayment(payment);
        }

        // 如果第三方已支付，更新本地状态
        if (
          thirdPartyStatus === "TRADE_SUCCESS" ||
          thirdPartyStatus === "SUCCESS"
        ) {
          const afterCommit = await this.dataSource.transaction(
            async (manager) => {
              const lockedPayment = await manager
                .createQueryBuilder(Payment, "payment")
                .where("payment.id = :id", { id: payment.id })
                .setLock("pessimistic_write")
                .getOne();

              if (!lockedPayment) {
                throw createBusinessException(ErrorCode.PAYMENT_NOT_FOUND);
              }

              const hook = await this.completeSuccessfulPayment(
                manager,
                lockedPayment,
                lockedPayment.transactionId ||
                  `QUERY_${lockedPayment.paymentNo}`,
                { source: "active_query" },
              );
              Object.assign(payment, lockedPayment);
              return hook;
            },
          );
          await this.runAfterCommit(afterCommit);
        } else if (
          thirdPartyStatus === "TRADE_CLOSED" ||
          thirdPartyStatus === "CLOSED"
        ) {
          await this.dataSource.transaction(async (manager) => {
            const lockedPayment = await manager
              .createQueryBuilder(Payment, "payment")
              .where("payment.id = :id", { id: payment.id })
              .setLock("pessimistic_write")
              .getOne();
            if (!lockedPayment) {
              throw createBusinessException(ErrorCode.PAYMENT_NOT_FOUND);
            }
            if (lockedPayment.status === PaymentStatus.PENDING) {
              const now = new Date();
              lockedPayment.status = PaymentStatus.CLOSED;
              lockedPayment.closedAt = now;
              lockedPayment.updatedAt = now;
              await manager.save(lockedPayment);
            }
            Object.assign(payment, lockedPayment);
          });
        }
      } catch (error) {
        this.logger.error(`Query payment status failed: ${error.message}`);
      }
    } else if (
      payment.status === PaymentStatus.SUCCESS &&
      (
        [
          BusinessType.WALLET_RECHARGE,
          BusinessType.CHARITY_DONATION,
          BusinessType.CHAT_PACKAGE,
        ] as BusinessType[]
      ).includes(payment.businessType)
    ) {
      const afterCommit = await this.dataSource.transaction(async (manager) => {
        const lockedPayment = await manager
          .createQueryBuilder(Payment, "payment")
          .where("payment.id = :id", { id: payment.id })
          .setLock("pessimistic_write")
          .getOne();
        if (!lockedPayment) {
          throw createBusinessException(ErrorCode.PAYMENT_NOT_FOUND);
        }
        const hook = await this.completeSuccessfulPayment(
          manager,
          lockedPayment,
          lockedPayment.transactionId || `QUERY_${lockedPayment.paymentNo}`,
          { source: "success_reconciliation" },
        );
        Object.assign(payment, lockedPayment);
        return hook;
      });
      await this.runAfterCommit(afterCommit);
    }

    return this.toPaymentStatusResponse(payment);
  }

  /**
   * 关闭支付
   */
  async closePayment(paymentNo: string): Promise<void> {
    const payment = await this.paymentRepository.findOne({
      where: { paymentNo },
    });

    if (!payment) {
      throw createBusinessException(ErrorCode.PAYMENT_NOT_FOUND);
    }

    if (payment.status !== PaymentStatus.PENDING) {
      throw createBusinessException(ErrorCode.PAYMENT_STATUS_INVALID);
    }

    // 调用第三方关闭支付
    try {
      if (payment.channel.startsWith("alipay")) {
        await this.alipayService.closePayment(payment);
      } else if (payment.channel.startsWith("wechat")) {
        await this.wechatPayService.closePayment(payment);
      }

      // 更新本地状态
      await this.paymentRepository.update(payment.id, {
        status: PaymentStatus.CLOSED,
        closedAt: new Date(),
        updatedAt: new Date(),
      });

      this.logger.log(`Payment closed: ${paymentNo}`);
      await this.triggerWebhook(
        {
          ...payment,
          status: PaymentStatus.CLOSED,
          closedAt: new Date(),
        },
        "PAYMENT_CLOSED",
      );
    } catch (error) {
      this.logger.error(`Close payment failed: ${error.message}`);
      throw error;
    }
  }

  /**
   * 切换商城支付渠道前关闭旧的待支付尝试，不触发订单取消回调。
   */
  async closePendingShopPaymentsForChannelSwitch(
    orderId: number,
    targetChannel: PaymentChannel,
  ): Promise<void> {
    const payments = await this.paymentRepository.find({
      where: {
        businessType: BusinessType.SHOP_ORDER,
        businessId: orderId,
      },
      order: { createdAt: "DESC" },
    });

    for (const payment of payments) {
      if (payment.channel === targetChannel) continue;
      if (payment.status === PaymentStatus.PROCESSING) {
        throw createBusinessException(
          ErrorCode.PAYMENT_STATUS_INVALID,
          "支付结果处理中，暂时不能切换支付渠道",
        );
      }
      if (payment.status === PaymentStatus.PENDING) {
        await this.closePaymentAttemptForChannelSwitch(payment);
      }
    }
  }

  /**
   * 创建退款
   * 安全修复：使用事务和悲观锁防止并发退款导致超额退款
   * 权限验证：外部接口仅管理员可用，商城订单只能由有效售后单触发内部退款
   */
  async createRefund(
    createRefundDto: CreateRefundDto,
    userId: number,
    userRole: string,
  ): Promise<CreateRefundResponse> {
    return this.createRefundInternal(createRefundDto, userId, userRole, {
      allowShopAfterSale: false,
      triggerWebhook: true,
    });
  }

  /**
   * 商城售后专用退款入口。退款金额只读取已审批售后单，调用方不能传入金额。
   */
  async createShopAfterSaleRefund(
    afterSaleId: number,
    operatorId: number,
    reason: string,
  ): Promise<CreateRefundResponse> {
    const afterSale = await this.dataSource
      .getRepository(OrderAfterSale)
      .findOne({
        where: { id: afterSaleId },
      });
    if (
      !afterSale ||
      afterSale.status !== AfterSaleStatus.REFUNDING ||
      !afterSale.approvedAmount ||
      toNumber(afterSale.approvedAmount) <= 0
    ) {
      throw new BadRequestException("售后单未进入有效退款状态");
    }

    const orderId = afterSale.orderId;
    const order = await this.orderRepository.findOne({
      where: { id: orderId },
    });

    if (!order || order.orderType !== afterSale.orderType) {
      throw new BadRequestException("售后单与订单类型不一致");
    }

    const payments = await this.paymentRepository.find({
      where: { businessType: BusinessType.SHOP_ORDER, businessId: orderId },
      order: { createdAt: "DESC" },
    });
    let payment =
      payments.find(
        (item) =>
          item.paymentNo === order.paymentNo &&
          [PaymentStatus.SUCCESS, PaymentStatus.REFUNDED].includes(item.status),
      ) ||
      payments.find((item) => item.status === PaymentStatus.SUCCESS) ||
      payments.find((item) => item.status === PaymentStatus.REFUNDED);

    // 历史渠道切换可能只留下旧渠道待支付单。仅在订单快照和钱包扣款流水
    // 同时证明余额支付成功时补建支付快照，不能根据 paymentMethod 单独猜测。
    if (!payment && order.paymentMethod === PaymentChannel.BALANCE) {
      const walletPayment = await this.dataSource
        .getRepository(WalletTransaction)
        .findOne({
          where: {
            userId: order.userId,
            type: WalletTransactionType.EXPENSE,
            relatedType: RelatedType.ORDER,
            relatedId: order.id,
            status: WalletTransactionStatus.APPROVED,
          },
          order: { createdAt: "DESC" },
        });
      if (!walletPayment || !equals(walletPayment.amount, order.totalAmount)) {
        throw new BadRequestException("余额支付扣款流水与订单金额不一致");
      }

      const baseOutTradeNo = `${BusinessType.SHOP_ORDER}_${order.id}`;
      const occupiedBaseOutTradeNo = payments.some(
        (item) => item.outTradeNo === baseOutTradeNo,
      );
      payment = await this.paymentRepository.save(
        this.paymentRepository.create({
          paymentNo: order.paymentNo || `BALANCE_${order.orderNo}`,
          outTradeNo: occupiedBaseOutTradeNo
            ? `${baseOutTradeNo}_BALANCE`
            : baseOutTradeNo,
          channel: PaymentChannel.BALANCE,
          method: PaymentMethod.APP,
          status: PaymentStatus.SUCCESS,
          amount: toNumber(order.totalAmount),
          refundAmount: 0,
          transactionId: order.transactionId || order.paymentNo,
          userId: order.userId,
          businessType: BusinessType.SHOP_ORDER,
          businessId: order.id,
          subject: `商城订单支付 - ${order.items?.[0]?.productName || order.orderNo}`,
          body: `历史余额订单支付快照`,
          metadata: {
            restoredFromOrder: true,
            walletTransactionId: walletPayment.id,
          },
          paidAt: order.paidAt || new Date(),
          updatedAt: new Date(),
        }),
      );
    }

    if (!payment) {
      throw new NotFoundException("订单支付记录不存在");
    }

    const afterSaleRefunds = await this.refundRepository.find({
      where: { paymentId: payment.id },
      order: { createdAt: "DESC" },
    });
    const existing = afterSaleRefunds.find(
      (refund) => Number(refund.metadata?.afterSaleId) === afterSaleId,
    );
    if (existing?.status === RefundStatus.SUCCESS) {
      return {
        refundId: existing.id,
        refundNo: existing.refundNo,
        paymentId: existing.paymentId,
        refundAmount: existing.refundAmount,
        status: existing.status,
        channel: existing.channel,
        thirdPartyRefundNo: existing.thirdPartyRefundNo,
        createdAt: existing.createdAt,
      };
    }
    if (existing && existing.status !== RefundStatus.FAILED) {
      throw new BadRequestException("退款正在处理中，请勿重复提交");
    }

    return this.createRefundInternal(
      {
        paymentId: payment.id,
        refundAmount: toNumber(afterSale.approvedAmount),
        type: equals(afterSale.approvedAmount, order.totalAmount)
          ? RefundType.FULL
          : RefundType.PARTIAL,
        reason,
        metadata: {
          orderId,
          afterSaleId,
          orderType: afterSale.orderType,
          handlerType: afterSale.handlerType,
        },
      },
      operatorId,
      "SYSTEM",
      {
        allowShopAfterSale: true,
        triggerWebhook: false,
        retryRefundId: existing?.id,
        afterSaleId,
      },
    );
  }

  /** 兼容旧的二手售后服务调用，金额仍由售后单决定。 */
  async createSecondHandAfterSaleRefund(
    _orderId: number,
    afterSaleId: number,
    operatorId: number,
    reason: string,
  ): Promise<CreateRefundResponse> {
    return this.createShopAfterSaleRefund(afterSaleId, operatorId, reason);
  }

  private async createRefundInternal(
    createRefundDto: CreateRefundDto,
    userId: number,
    userRole: string,
    options: {
      allowShopAfterSale: boolean;
      triggerWebhook: boolean;
      retryRefundId?: number;
      afterSaleId?: number;
    },
  ): Promise<CreateRefundResponse> {
    const {
      paymentId,
      refundAmount,
      type = RefundType.PARTIAL,
      reason,
      metadata,
    } = createRefundDto;

    let refundError: Error | null = null;
    let webhookPayment: Payment | null = null;

    const result = await this.dataSource.transaction(async (manager) => {
      // 1. 使用悲观锁获取支付记录
      const payment = await manager
        .createQueryBuilder(Payment, "payment")
        .where("payment.id = :paymentId", { paymentId })
        .setLock("pessimistic_write")
        .getOne();

      if (!payment) {
        throw createBusinessException(ErrorCode.PAYMENT_NOT_FOUND);
      }

      const paymentRefunds = await manager.find(Refund, {
        where: { paymentId },
        order: { createdAt: "DESC" },
      });
      let retryRefundId = options.retryRefundId;
      if (options.afterSaleId) {
        const sameAfterSaleRefund = paymentRefunds.find(
          (refund) =>
            Number(refund.metadata?.afterSaleId) ===
            Number(options.afterSaleId),
        );
        if (sameAfterSaleRefund) {
          if (!equals(sameAfterSaleRefund.refundAmount, refundAmount)) {
            throw new BadRequestException("同一售后单的退款金额不一致");
          }
          if (sameAfterSaleRefund.status === RefundStatus.SUCCESS) {
            return this.toRefundResponse(sameAfterSaleRefund);
          }
          if (
            [RefundStatus.PENDING, RefundStatus.PROCESSING].includes(
              sameAfterSaleRefund.status,
            )
          ) {
            throw new BadRequestException("退款正在处理中，请勿重复提交");
          }
          if (sameAfterSaleRefund.status === RefundStatus.FAILED) {
            retryRefundId = sameAfterSaleRefund.id;
          }
        }
      }

      // 2. 权限验证：只有管理员或支付所有者可以退款
      const isAdmin = userRole === "SUPER_ADMIN" || userRole === "STAFF";
      const isInternal = userRole === "SYSTEM";
      if (!isAdmin && !isInternal && payment.userId !== userId) {
        throw createBusinessException(ErrorCode.PERMISSION_DENIED);
      }

      if (payment.businessType === BusinessType.SHOP_ORDER) {
        if (!options.allowShopAfterSale || !options.afterSaleId) {
          throw new BadRequestException("商城订单请通过订单售后流程退款");
        }
        const afterSale = await manager.findOne(OrderAfterSale, {
          where: { id: options.afterSaleId, orderId: payment.businessId },
          lock: { mode: "pessimistic_write" },
        });
        if (
          !afterSale ||
          afterSale.status !== AfterSaleStatus.REFUNDING ||
          !equals(afterSale.approvedAmount || 0, refundAmount)
        ) {
          throw new BadRequestException("售后状态或审批退款金额无效");
        }
      }

      if (payment.status !== PaymentStatus.SUCCESS) {
        throw createBusinessException(ErrorCode.PAYMENT_STATUS_INVALID);
      }

      // 2. 检查退款金额
      if (refundAmount > payment.amount) {
        throw createBusinessException(ErrorCode.REFUND_AMOUNT_EXCEEDS);
      }

      // 3. 在锁定的同一事务中查询已退款金额
      const existingRefunds = paymentRefunds.filter(
        (refund) => refund.status === RefundStatus.SUCCESS,
      );

      const totalRefunded = existingRefunds.reduce(
        (sum, refund) => sum + Number(refund.refundAmount),
        0,
      );

      if (totalRefunded + refundAmount > payment.amount) {
        throw createBusinessException(ErrorCode.REFUND_AMOUNT_EXCEEDS);
      }

      // 4. 创建退款记录
      let savedRefund: Refund;
      if (retryRefundId) {
        const retryRefund = await manager.findOne(Refund, {
          where: { id: retryRefundId, paymentId },
          lock: { mode: "pessimistic_write" },
        });
        if (
          !retryRefund ||
          retryRefund.status !== RefundStatus.FAILED ||
          Number(retryRefund.metadata?.afterSaleId) !==
            Number(metadata?.afterSaleId)
        ) {
          throw new BadRequestException("原退款记录不可重试");
        }
        retryRefund.status = RefundStatus.PENDING;
        retryRefund.reason = reason;
        retryRefund.userId = userId;
        retryRefund.remark = null;
        retryRefund.updatedAt = new Date();
        savedRefund = await manager.save(retryRefund);
      } else {
        savedRefund = await manager.save(
          manager.create(Refund, {
            refundNo: options.afterSaleId
              ? this.generateAfterSaleRefundNo(options.afterSaleId)
              : this.generateRefundNo(),
            paymentId,
            outTradeNo: payment.outTradeNo,
            status: RefundStatus.PENDING,
            type,
            channel: payment.channel,
            refundAmount,
            reason,
            userId,
            metadata,
          }),
        );
      }
      const refundNo = savedRefund.refundNo;
      this.logger.log(`Refund created: ${refundNo}, amount: ${refundAmount}`);

      // 5. 调用第三方退款接口
      try {
        let thirdPartyRefundNo: string;

        if (payment.channel.startsWith("alipay")) {
          thirdPartyRefundNo = await this.alipayService.createRefund(
            payment,
            refundAmount,
            refundNo,
            reason,
          );
        } else if (payment.channel.startsWith("wechat")) {
          thirdPartyRefundNo = await this.wechatPayService.createRefund(
            payment,
            refundAmount,
            refundNo,
            reason,
          );
        } else if (payment.channel === PaymentChannel.BALANCE) {
          const buyer = await manager
            .createQueryBuilder(User, "user")
            .where("user.id = :id", { id: payment.userId })
            .setLock("pessimistic_write")
            .getOne();
          if (!buyer) {
            throw new NotFoundException("退款用户不存在");
          }

          const balanceBefore = toNumber(buyer.balance);
          const balanceAfter = add(balanceBefore, refundAmount);
          buyer.balance = balanceAfter;
          await manager.save(buyer);
          await manager.save(
            manager.create(WalletTransaction, {
              userId: buyer.id,
              type: WalletTransactionType.INCOME,
              amount: refundAmount,
              balanceBefore,
              balanceAfter,
              relatedType: RelatedType.REFUND,
              relatedId: savedRefund.id,
              status: WalletTransactionStatus.APPROVED,
              remark: `余额退款 ${savedRefund.refundNo}`,
              reviewedAt: new Date(),
              reviewedBy: userId,
              autoProcessed: userRole === "SYSTEM",
            }),
          );
          thirdPartyRefundNo = `BALANCE_REFUND_${savedRefund.refundNo}`;
        } else {
          throw new BadRequestException("当前支付渠道不支持退款");
        }

        // 6. 更新退款状态
        const now = new Date();
        savedRefund.status = RefundStatus.SUCCESS;
        savedRefund.thirdPartyRefundNo = thirdPartyRefundNo;
        savedRefund.refundedAt = now;
        savedRefund.updatedAt = now;
        await manager.save(savedRefund);

        // 7. 更新支付记录的退款金额
        payment.refundAmount = totalRefunded + refundAmount;
        if (totalRefunded + refundAmount >= payment.amount) {
          payment.status = PaymentStatus.REFUNDED;
          payment.refundedAt = now;
        }
        payment.updatedAt = now;
        await manager.save(payment);

        await this.fulfillShopOrderRefund(manager, payment, savedRefund);

        this.logger.log(
          `Refund success: ${refundNo}, thirdPartyRefundNo: ${thirdPartyRefundNo}`,
        );

        webhookPayment = payment;

        return {
          refundId: savedRefund.id,
          refundNo: savedRefund.refundNo,
          paymentId: savedRefund.paymentId,
          refundAmount: savedRefund.refundAmount,
          status: RefundStatus.SUCCESS,
          channel: savedRefund.channel,
          thirdPartyRefundNo,
          createdAt: savedRefund.createdAt,
        };
      } catch (error) {
        this.logger.error(
          `Create refund failed: ${error.message}`,
          error.stack,
        );
        savedRefund.status = RefundStatus.FAILED;
        savedRefund.remark = error.message;
        savedRefund.updatedAt = new Date();
        await manager.save(savedRefund);
        refundError = error;
        return null;
      }
    });

    if (refundError) {
      throw refundError;
    }

    if (options.triggerWebhook && webhookPayment && result) {
      await this.triggerWebhook(webhookPayment, "REFUND_SUCCESS", {
        refundNo: result.refundNo,
        refundAmount: result.refundAmount,
      });
    }

    return result;
  }

  private toPaymentStatusResponse(payment: Payment): PaymentStatusResponseDto {
    return {
      paymentNo: payment.paymentNo,
      status: payment.status,
      channel: payment.channel,
      method: payment.method,
      amount: toNumber(payment.amount),
      refundAmount: toNumber(payment.refundAmount),
      businessType: payment.businessType,
      paidAt: payment.paidAt || null,
      closedAt: payment.closedAt || null,
      expiredAt: payment.expiredAt || null,
    };
  }

  private toRefundResponse(refund: Refund): CreateRefundResponse {
    return {
      refundId: refund.id,
      refundNo: refund.refundNo,
      paymentId: refund.paymentId,
      refundAmount: refund.refundAmount,
      status: refund.status,
      channel: refund.channel,
      thirdPartyRefundNo: refund.thirdPartyRefundNo,
      createdAt: refund.createdAt,
    };
  }

  /**
   * 触发业务回调（Webhook）
   * 通知相关模块支付/退款成功
   */
  private async triggerWebhook(
    payment: Payment,
    event: string,
    data?: any,
  ): Promise<void> {
    try {
      this.logger.log(
        `Triggering webhook: ${event}, payment: ${payment.paymentNo}`,
      );

      // 支付成功必须由支付模块直接在事务内落单，不能依赖跨模块的字符串 token
      // 或事务提交后的 setImmediate，否则支付单成功与订单状态会永久分裂。
      if (
        payment.businessType === BusinessType.SHOP_ORDER &&
        event === "PAYMENT_SUCCESS"
      ) {
        await this.dataSource.transaction((manager) =>
          this.fulfillSuccessfulPayment(manager, payment),
        );
        return;
      }

      // 临时实现：通过 ModuleRef 动态获取 ShopService
      // 注意：这需要在 PaymentModule 中导入 ShopModule
      let shopService;
      try {
        // 尝试从模块上下文中获取 ShopService
        const shopModuleProvider = this.moduleRef.get<any>("ShopService", {
          strict: false,
        });
        if (shopModuleProvider) {
          shopService = shopModuleProvider;
        }
      } catch (error) {
        this.logger.warn(`Could not get ShopService: ${error.message}`);
      }

      switch (payment.businessType) {
        case "shop_order":
          if (shopService) {
            try {
              await shopService.handlePaymentWebhook(payment, event, data);
            } catch (error) {
              this.logger.error(
                `Shop webhook failed: ${error.message}`,
                error.stack,
              );
            }
          } else {
            this.logger.warn(
              `ShopService not available for webhook: ${payment.businessId}`,
            );
          }
          break;

        case "chat_package":
          // TODO: 调用 Chat 模块更新套餐订单状态
          this.logger.log(`Chat package webhook: ${payment.businessId}`);
          break;

        default:
          this.logger.warn(`Unknown business type: ${payment.businessType}`);
      }
    } catch (error) {
      this.logger.error(
        `Webhook trigger failed: ${error.message}`,
        error.stack,
      );
      // Webhook 失败不影响主流程
    }
  }

  /**
   * 生成支付单号
   */
  private generatePaymentNo(): string {
    const timestamp = Date.now().toString();
    const random = randomUUID().substring(0, 8).toUpperCase();
    return `PAY${timestamp}${random}`;
  }

  private generatePaymentAttemptOutTradeNo(baseOutTradeNo: string): string {
    const suffix = `${Date.now().toString(36)}_${randomUUID()
      .replace(/-/g, "")
      .substring(0, 6)}`;
    const prefix = baseOutTradeNo.substring(0, 64 - suffix.length - 1);
    return `${prefix}_${suffix}`;
  }

  private async closePaymentAttemptForChannelSwitch(
    payment: Payment,
  ): Promise<void> {
    if (payment.channel.startsWith("alipay")) {
      await this.alipayService.closePayment(payment);
    } else if (payment.channel.startsWith("wechat")) {
      await this.wechatPayService.closePayment(payment);
    } else {
      throw new BadRequestException("当前支付渠道不支持切换");
    }

    const now = new Date();
    await this.paymentRepository.update(payment.id, {
      status: PaymentStatus.CLOSED,
      closedAt: now,
      updatedAt: now,
    });
    payment.status = PaymentStatus.CLOSED;
    payment.closedAt = now;
    payment.updatedAt = now;
  }

  /**
   * 生成交易流水号
   */
  private generateTransactionNo(): string {
    const timestamp = Date.now().toString();
    const random = randomUUID().substring(0, 8).toUpperCase();
    return `TXN${timestamp}${random}`;
  }

  /**
   * 生成退款单号
   */
  private generateRefundNo(): string {
    const timestamp = Date.now().toString();
    const random = randomUUID().substring(0, 8).toUpperCase();
    return `REF${timestamp}${random}`;
  }

  private generateAfterSaleRefundNo(afterSaleId: number): string {
    return `ASREF${afterSaleId}`;
  }

  /**
   * 获取支付响应
   */
  private async getPaymentResponse(
    payment: Payment,
  ): Promise<CreatePaymentResponse> {
    try {
      const paymentParams = await this.createPaymentParams(payment);
      return this.buildPaymentResponse(payment, paymentParams);
    } catch (error) {
      const isDev = this.configService.get("NODE_ENV") === "development";
      const isNotConfigured =
        error.message?.includes("not configured") ||
        error.message?.includes("未配置");
      if (isDev && isNotConfigured) {
        return this.buildPaymentResponse(
          payment,
          this.generateMockPaymentParams(payment),
        );
      }
      throw error;
    }
  }

  private async createPaymentParams(payment: Payment): Promise<any> {
    if (
      payment.channel === PaymentChannel.ALIPAY ||
      payment.channel === PaymentChannel.ALIPAY_WAP ||
      payment.channel === PaymentChannel.ALIPAY_WEB
    ) {
      return this.alipayService.createPayment(payment);
    }

    if (
      payment.channel === PaymentChannel.WECHAT ||
      payment.channel === PaymentChannel.WECHAT_JSAPI ||
      payment.channel === PaymentChannel.WECHAT_H5 ||
      payment.channel === PaymentChannel.WECHAT_NATIVE
    ) {
      return this.wechatPayService.createPayment(payment);
    }

    throw new BadRequestException("不支持的支付渠道");
  }

  private buildPaymentResponse(
    payment: Payment,
    paymentParams: any,
  ): CreatePaymentResponse {
    return {
      paymentNo: payment.paymentNo,
      outTradeNo: payment.outTradeNo,
      amount: toNumber(payment.amount),
      channel: payment.channel,
      method: payment.method,
      paymentParams,
      expiredAt: payment.expiredAt,
    };
  }

  /**
   * 生成模拟支付参数（开发环境）
   */
  private generateMockPaymentParams(payment: Payment): any {
    const { channel, method, paymentNo, outTradeNo, amount, subject } = payment;
    const mockPaymentBaseUrl = this.getMockPaymentBaseUrl();

    // 支付宝模拟参数
    if (channel.startsWith("alipay")) {
      if (method === "app") {
        return {
          alipayOrderString: `MOCK_ALIPAY_ORDER_STRING_${paymentNo}`,
          mockMode: true,
        };
      } else if (method === "web" || method === "h5") {
        return {
          paymentUrl: `${mockPaymentBaseUrl}/mock-payment/alipay?outTradeNo=${outTradeNo}`,
          paymentHtml: `<form>Mock payment form for ${subject}</form>`,
          mockMode: true,
        };
      } else if (method === "native") {
        return {
          qrCodeUrl: `MOCK_QR_CODE_${paymentNo}`,
          mockMode: true,
        };
      }
    }

    // 微信支付模拟参数
    if (channel.startsWith("wechat")) {
      if (method === "app") {
        return {
          wechatAppid: "MOCK_APPID",
          wechatPartnerId: "MOCK_MCH_ID",
          wechatPrepayId: `MOCK_PREPAY_ID_${paymentNo}`,
          wechatNonceStr: "MOCK_NONCE_STR",
          wechatTimeStamp: Math.floor(Date.now() / 1000).toString(),
          wechatSign: "MOCK_SIGN",
          mockMode: true,
        };
      } else if (method === "jsapi") {
        return {
          wechatAppid: "MOCK_APPID",
          wechatTimeStamp: Math.floor(Date.now() / 1000).toString(),
          wechatNonceStr: "MOCK_NONCE_STR",
          wechatPackage: `prepay_id=MOCK_PREPAY_ID_${paymentNo}`,
          wechatSignType: "RSA",
          wechatPaySign: "MOCK_SIGN",
          mockMode: true,
        };
      } else if (method === "h5") {
        return {
          paymentUrl: `${mockPaymentBaseUrl}/mock-payment/wechat?outTradeNo=${outTradeNo}`,
          mockMode: true,
        };
      } else if (method === "native") {
        return {
          qrCodeUrl: `MOCK_WECHAT_QR_CODE_${paymentNo}`,
          mockMode: true,
        };
      }
    }

    // 默认模拟参数
    return {
      mockMode: true,
      message: "开发环境模拟支付",
      paymentNo,
      amount,
    };
  }
}
