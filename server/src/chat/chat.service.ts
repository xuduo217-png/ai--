import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { In, Repository, MoreThanOrEqual } from "typeorm";
import { Message, MessageType, MessageStatus } from "./entities/message.entity";
import { ChatOrder, OrderStatus } from "./entities/chat-order.entity";
import { PaginatedResult } from "../common/dto/pagination.dto";
import { ChatSessionService, RuntimeChatSession } from "./chat-session.service";
import { AutoReplyService } from "./auto-reply.service";
import { DoctorsService } from "../doctors/doctors.service";
import { RedisService } from "../redis/redis.service";
import { SensitiveWordService } from "../community/sensitive-word.service";
import {
  MESSAGE_RECALL_WINDOW_MS,
  MESSAGE_REVOKED_CONTENT,
} from "../common/constants/message-recall.constants";

interface SaveMessageOptions {
  conversationId: string;
  senderId: number;
  senderType?: "user" | "doctor"; // 发送者类型
  receiverId: number;
  receiverType?: "user" | "doctor"; // 接收者类型
  content: string;
  type?: MessageType;
  isAutoReply?: boolean;
  aiConsultationId?: number;
  orderId?: number; // 关联的医疗服务订单ID
}

type ChatPrincipalType = "user" | "doctor";

interface TemporaryMessage {
  id: number;
  conversationId: string;
  receiverId?: number | null;
  receiverType?: string;
  isRead?: boolean;
  isRevoked?: boolean;
  revokedAt?: Date | string | null;
  createdAt: Date | string;
  [key: string]: unknown;
}

export interface ConsultationConversationLastMessage {
  id: number;
  conversationId: string;
  senderId?: number | null;
  receiverId?: number | null;
  content: string;
  type: MessageType;
  isAutoReply: boolean;
  createdAt: Date | string;
}

export interface ConsultationConversationSummary {
  conversationId: string;
  userId: number;
  doctorId: number;
  doctorName: string;
  doctorAvatar: string;
  status: string;
  paymentRequired: boolean;
  isTemporary: boolean;
  orderId?: number;
  serviceStartAt?: Date;
  serviceEndAt?: Date;
  lastMessage: ConsultationConversationLastMessage | null;
  unreadCount: number;
  createdAt: Date;
  updatedAt: Date;
}

/**
 * 判断消息是否为结构化媒体消息
 * 业务规则：图片/语音消息的 content 是 JSON 或资源地址，不能走文本类 HTML 转义，否则会把协议本身破坏掉。
 */
function shouldBypassTextSanitization(type: MessageType): boolean {
  return (
    type === MessageType.IMAGE ||
    type === MessageType.VIDEO ||
    type === MessageType.VOICE
  );
}

/**
 * 安全过滤内容
 * 防止 XSS 攻击，转义 HTML 特殊字符
 */
function sanitizeContent(content: string): string {
  if (!content || typeof content !== "string") {
    return content;
  }

  // HTML 实体编码，防止 XSS 攻击
  return content
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#x27;")
    .replace(/\//g, "&#x2F;");
}

@Injectable()
export class ChatService {
  private readonly logger = new Logger(ChatService.name);

  constructor(
    @InjectRepository(Message)
    private messageRepository: Repository<Message>,
    @InjectRepository(ChatOrder)
    private orderRepository: Repository<ChatOrder>,
    private chatSessionService: ChatSessionService,
    private autoReplyService: AutoReplyService,
    private doctorsService: DoctorsService,
    private redisService: RedisService,
    private sensitiveWordService: SensitiveWordService,
  ) {}

  /**
   * 根据发送者/接收者角色解析固定的医患参与者。
   * 咨询聊天是强角色模型，后续所有会话读取都必须基于这个映射。
   */
  private resolveParticipantPair(
    senderId: number,
    senderType: "user" | "doctor",
    receiverId: number,
    receiverType: "user" | "doctor",
  ): { userId: number; doctorId: number } {
    if (senderType === receiverType) {
      throw new BadRequestException("会话参与者类型不合法");
    }

    return senderType === "user"
      ? { userId: senderId, doctorId: receiverId }
      : { userId: receiverId, doctorId: senderId };
  }

  private createRedisTempKey(conversationId: string): string {
    return `chat:temp:${conversationId}`;
  }

  private createRedisUnreadKey(
    principalType: ChatPrincipalType,
    principalId: number,
  ): string {
    return `chat:unread:${principalType}:${principalId}`;
  }

  private createRedisUnreadBackfillKey(
    principalType: ChatPrincipalType,
    principalId: number,
  ): string {
    return `chat:unread:backfilled:${principalType}:${principalId}`;
  }

  private createRedisConversationReadKey(
    principalType: ChatPrincipalType,
    principalId: number,
    conversationId: string,
  ): string {
    return `chat:read:${principalType}:${principalId}:${conversationId}`;
  }

  private createRedisUnreadField(
    conversationId: string,
    messageId: number,
  ): string {
    return `${conversationId}:${messageId}`;
  }

  private async saveTemporaryMessage(message: TemporaryMessage): Promise<void> {
    await this.redisService.lpush(
      this.createRedisTempKey(message.conversationId),
      JSON.stringify(message),
    );

    if (
      message.isRead === true ||
      (message.receiverType !== "user" && message.receiverType !== "doctor") ||
      !message.receiverId
    ) {
      return;
    }

    await this.redisService.hset(
      this.createRedisUnreadKey(message.receiverType, message.receiverId),
      this.createRedisUnreadField(message.conversationId, message.id),
      message.conversationId,
    );
  }

  private async ensureTemporaryUnreadIndex(
    principalId: number,
    principalType: ChatPrincipalType,
  ): Promise<void> {
    const backfillKey = this.createRedisUnreadBackfillKey(
      principalType,
      principalId,
    );
    if (await this.redisService.get(backfillKey)) return;

    let cursor = "0";
    do {
      const [nextCursor, keys] = await this.redisService.scan(
        cursor,
        "chat:temp:*",
      );
      cursor = nextCursor;

      for (const key of keys) {
        const conversationId = key.substring("chat:temp:".length);
        const messages = await this.redisService.lrange(key, 0, -1);
        let session: RuntimeChatSession | null | undefined;

        for (const rawMessage of messages) {
          let message: TemporaryMessage;
          try {
            message = JSON.parse(rawMessage) as TemporaryMessage;
          } catch {
            continue;
          }

          if (message.isRead === true || message.receiverId !== principalId) {
            continue;
          }

          let belongsToPrincipal = message.receiverType === principalType;
          if (!message.receiverType) {
            session ??=
              await this.chatSessionService.getSessionByConversationId(
                conversationId,
              );
            belongsToPrincipal =
              principalType === "user"
                ? session?.userId === principalId
                : session?.doctorId === principalId;
          }
          if (!belongsToPrincipal) continue;

          await this.redisService.hset(
            this.createRedisUnreadKey(principalType, principalId),
            this.createRedisUnreadField(conversationId, message.id),
            conversationId,
          );
        }
      }
    } while (cursor !== "0");

    await this.redisService.set(backfillKey, "1");
  }

  private async clearTemporaryConversationUnread(
    conversationId: string,
    principalId: number,
    principalType: ChatPrincipalType,
  ): Promise<void> {
    await this.ensureTemporaryUnreadIndex(principalId, principalType);
    const unreadKey = this.createRedisUnreadKey(principalType, principalId);
    const unreadMessages = await this.redisService.hgetall(unreadKey);
    const fields = Object.entries(unreadMessages)
      .filter(
        ([, indexedConversationId]) => indexedConversationId === conversationId,
      )
      .map(([field]) => field);

    if (fields.length > 0) {
      await this.redisService.hdel(unreadKey, ...fields);
    }
    await this.redisService.set(
      this.createRedisConversationReadKey(
        principalType,
        principalId,
        conversationId,
      ),
      new Date().toISOString(),
    );
  }

  private createRuntimeMessageId(): number {
    return Date.now() * 1000 + Math.floor(Math.random() * 1000);
  }

  /**
   * 创建持久化消息查询。
   * 高频同步路径只读取消息表本身字段，避免联表 users/order 放大 SQL 体积。
   */
  private createPersistedMessageQuery(options: {
    conversationId: string;
    orderId?: number;
    since?: Date;
    until?: Date;
    limit?: number;
  }) {
    const queryBuilder = this.messageRepository
      .createQueryBuilder("message")
      .where("message.conversationId = :conversationId", {
        conversationId: options.conversationId,
      })
      .andWhere("message.isDeleted = :isDeleted", { isDeleted: false });

    if (options.orderId) {
      queryBuilder.andWhere("message.orderId = :orderId", {
        orderId: options.orderId,
      });
    }

    if (options.since) {
      queryBuilder.andWhere("message.createdAt > :since", {
        since: options.since,
      });
    }

    if (options.until) {
      queryBuilder.andWhere("message.createdAt <= :until", {
        until: options.until,
      });
    }

    queryBuilder
      .orderBy("message.createdAt", "ASC")
      .addOrderBy("message.id", "ASC");

    if (options.limit) {
      queryBuilder.take(options.limit);
    }

    return queryBuilder;
  }

  private isPaidRuntimeSession(
    session?: RuntimeChatSession | null,
  ): session is RuntimeChatSession {
    return Boolean(
      session &&
      !session.isTemporary &&
      (session.status === "PAID" || session.status === "EXPIRED"),
    );
  }

  async saveMessage(options: SaveMessageOptions): Promise<Message> {
    const {
      conversationId,
      senderId,
      senderType = "user",
      receiverId,
      receiverType = "doctor",
      content,
      type = MessageType.TEXT,
      isAutoReply = false,
      aiConsultationId,
      orderId,
    } = options;

    const session =
      await this.chatSessionService.getPersistedSessionByConversationId(
        conversationId,
      );
    if (!session) {
      throw new BadRequestException("无效的 conversationId");
    }

    const participants = [senderId, receiverId].sort((a, b) => a - b);
    const sessionParticipants = [session.userId, session.doctorId].sort(
      (a, b) => a - b,
    );

    // 验证 conversationId 对应的 session 是否属于当前参与者。
    if (
      sessionParticipants[0] !== participants[0] ||
      sessionParticipants[1] !== participants[1]
    ) {
      this.logger.error(
        `[saveMessage] conversationId 与参与者不匹配! conversationId=${conversationId}, senderId=${senderId}, receiverId=${receiverId}`,
      );
      throw new BadRequestException(
        "conversationId 与参与者不匹配，请检查聊天对象",
      );
    }

    let sanitizedContent = content;

    if (!shouldBypassTextSanitization(type)) {
      // 安全过滤：仅文本类消息执行 XSS 防护和敏感词过滤。
      // 图片/语音消息是结构化协议，如果在这里转义会把 JSON 变成无效字符串。
      sanitizedContent = sanitizeContent(content);
      const processResult =
        await this.sensitiveWordService.process(sanitizedContent);

      // 高危敏感词直接拒绝
      if (processResult.action === "REJECT") {
        this.logger.warn(
          `消息包含高危敏感词，已拒绝: senderId=${senderId}, words=${processResult.words.map((w) => w.word).join(",")}`,
        );
        throw new BadRequestException("消息内容包含敏感信息，无法发送");
      }

      // 中危敏感词自动替换
      if (processResult.action === "REPLACE" && processResult.text) {
        sanitizedContent = processResult.text;
        this.logger.log(
          `消息包含中危敏感词，已替换: senderId=${senderId}, words=${processResult.words.map((w) => w.word).join(",")}`,
        );
      }
    }

    const message = this.messageRepository.create({
      conversationId,
      senderId,
      senderType,
      receiverId,
      receiverType,
      content: sanitizedContent,
      type,
      status: MessageStatus.SENT,
      isAutoReply,
      aiConsultationId,
      orderId, // 保存 orderId（如果有）
    });

    const savedMessage = await this.messageRepository.save(message);
    session.lastMessageAt = savedMessage.createdAt || new Date();
    await this.chatSessionService.updateSession(session);
    return savedMessage;
  }

  /**
   * 发送消息
   * - 会话状态为 FREE 时，消息存 Redis（临时存储）
   * - 会话状态为 PAID 时，消息存 MySQL（持久存储）
   */
  async sendMessage(
    conversationId: string,
    senderId: number,
    senderType: "user" | "doctor",
    receiverId: number,
    receiverType: "user" | "doctor",
    content: string,
    type: MessageType = MessageType.TEXT,
  ): Promise<Message> {
    const check = await this.canSendMessage(
      senderId,
      receiverId,
      senderType,
      receiverType,
      conversationId,
    );
    if (!check.canSend) {
      throw new ForbiddenException(check.reason);
    }

    // 构建消息对象
    const message = {
      conversationId,
      senderId,
      senderType,
      receiverId,
      receiverType,
      content,
      type,
      isAutoReply: false,
      isRead: false,
      createdAt: new Date(),
      // 生成唯一 ID（时间戳 + 随机数，避免同一毫秒内重复）
      id: this.createRuntimeMessageId(),
    };

    // 根据会话状态选择存储方式
    if (!this.isPaidRuntimeSession(check.session)) {
      // 免费阶段：存 Redis
      await this.saveTemporaryMessage(message);
      this.logger.log(
        `[sendMessage] 免费会话，消息已存入 Redis [${conversationId}]: ${content}`,
      );

      return message as Message;
    } else {
      // 付费阶段：存 MySQL，并关联到当前订单
      const savedMessage = await this.saveMessage({
        conversationId,
        senderId,
        senderType,
        receiverId,
        receiverType,
        content,
        type,
        orderId: check.session?.orderId, // 关联到当前订单（如果有）
      });
      this.logger.log(
        `[sendMessage] 付费会话，消息已存入 MySQL [${conversationId}]: ${content}, orderId: ${check.session?.orderId}`,
      );
      return savedMessage;
    }
  }

  async sendAiConsultation(
    conversationId: string,
    senderId: number,
    receiverId: number,
    aiConsultationId: number,
  ): Promise<Message> {
    const check = await this.canSendMessage(
      senderId,
      receiverId,
      "user",
      "doctor",
      conversationId,
    );
    if (!check.canSend) {
      throw new ForbiddenException(check.reason);
    }

    // 🔑 关键修复：根据会话状态选择存储方式
    const isFreeSession = !this.isPaidRuntimeSession(check.session);

    if (isFreeSession) {
      // 免费会话：存 Redis
      const message = {
        id: Date.now(),
        conversationId,
        senderId,
        senderType: "user" as const,
        receiverId,
        receiverType: "doctor" as const,
        content: "[AI问诊] 请点击查看详情",
        type: MessageType.AI_CONSULTATION,
        aiConsultationId,
        isAutoReply: false,
        isRead: false,
        createdAt: new Date(),
      };
      await this.saveTemporaryMessage(message);
      this.logger.log(
        `[sendAiConsultation] 免费会话，AI问诊消息已存入 Redis [${conversationId}]`,
      );
      return message as Message;
    } else {
      // 付费会话：存 MySQL，并关联到当前订单
      const message = await this.saveMessage({
        conversationId,
        senderId,
        receiverId,
        content: "[AI问诊] 请点击查看详情",
        type: MessageType.AI_CONSULTATION,
        aiConsultationId,
        orderId: check.session?.orderId, // 关联到当前订单（如果有）
      });
      this.logger.log(
        `[sendAiConsultation] 付费会话，AI问诊消息已存入 MySQL [${conversationId}], orderId: ${check.session?.orderId}`,
      );
      return message;
    }
  }

  async getMessagesByConversation(
    conversationId: string,
    page = 1,
    pageSize = 50,
    orderId?: number, // 🔑 新增：按订单筛选消息
    redactRevoked = true,
  ): Promise<PaginatedResult<Message>> {
    const session =
      await this.chatSessionService.getSessionByConversationId(conversationId);
    if (!session) {
      throw new BadRequestException("无效的 conversationId");
    }
    const isPaidSession = this.isPaidRuntimeSession(session);

    // 3. 根据会话状态选择数据源
    if (isPaidSession) {
      // PAID/EXPIRED/COMPLETED 会话：从 MySQL 获取持久化消息
      this.logger.log(
        `[getMessagesByConversation] 付费会话，从 MySQL 获取消息 [${conversationId}], 状态: ${session.status}, orderId: ${orderId}`,
      );

      const data = await this.createPersistedMessageQuery({
        conversationId,
        orderId,
      }).getMany();
      const total = data.length;

      this.logger.log(
        `[getMessagesByConversation] 从 MySQL 获取到 ${total} 条持久化消息 [${conversationId}]`,
      );

      return {
        data: redactRevoked
          ? data.map((message) => this.toClientMessage(message))
          : data,
        total,
        page: 1,
        pageSize: total,
        totalPages: 1,
      };
    } else {
      // FREE 会话完全驻留在 Redis 临时存储中。
      this.logger.log(
        `[getMessagesByConversation] 免费会话，从 Redis 获取临时消息 [${conversationId}]`,
      );

      const messages = await this.getFreeSessionMessages(
        conversationId,
        undefined,
        undefined,
        redactRevoked,
      );

      this.logger.log(
        `[getMessagesByConversation] 免费会话共 ${messages.length} 条临时消息 [${conversationId}]`,
      );

      return {
        data: redactRevoked
          ? messages.map((message) => this.toClientMessage(message))
          : messages,
        total: messages.length,
        page,
        pageSize,
        totalPages: 1,
      };
    }
  }

  /**
   * 增量同步消息
   * @param conversationId 会话ID
   * @param since 起始时间（可选）
   * @param limit 最大返回数量（默认50）
   */
  async syncMessages(
    conversationId: string,
    since?: Date,
    limit = 50,
  ): Promise<{
    data: Message[];
    total: number;
    hasMore: boolean;
    lastTimestamp: string | null;
  }> {
    const session =
      await this.chatSessionService.getSessionByConversationId(conversationId);
    if (!session) {
      throw new NotFoundException("无效的 conversationId");
    }

    return this.syncMessagesBySession(session, since, limit);
  }

  /**
   * 使用已校验的会话执行增量同步。
   * Controller 先完成参与者校验后可以直接复用该会话，避免每次同步重复读取 chat_sessions。
   */
  async syncMessagesBySession(
    session: RuntimeChatSession,
    since?: Date,
    limit = 50,
  ): Promise<{
    data: Message[];
    total: number;
    hasMore: boolean;
    lastTimestamp: string | null;
  }> {
    const conversationId = session.conversationId;

    // 验证 limit 参数
    if (limit < 1 || limit > 1000) {
      throw new BadRequestException("limit 必须在 1-1000 之间");
    }

    this.logger.log(
      `[syncMessages] 开始增量同步 [${conversationId}], since=${since?.toISOString()}, limit=${limit}`,
    );

    // 2. 以持久化 session 状态作为真源，避免 Redis 临时态滞后。
    const isPaidSession =
      session.status === "PAID" || session.status === "EXPIRED";
    const syncUpperBound = new Date();

    if (isPaidSession) {
      // ========== 付费会话：从 MySQL 增量查询 ==========
      this.logger.log(
        `[syncMessages] 付费会话，从 MySQL 增量查询 [${conversationId}]`,
      );

      const messages = await this.createPersistedMessageQuery({
        conversationId,
        since,
        until: syncUpperBound,
        limit: limit + 1,
      }).getMany();
      const hasMore = messages.length > limit;
      const pageMessages = hasMore ? messages.slice(0, limit) : messages;
      const data = pageMessages.map((message) =>
        this.toClientMessage(message),
      );
      const total = data.length;
      const lastTimestamp =
        data.length > 0
          ? data[data.length - 1].createdAt.toISOString()
          : syncUpperBound.toISOString();

      this.logger.log(
        `[syncMessages] 从 MySQL 获取到 ${total} 条消息 [${conversationId}], hasMore=${hasMore}`,
      );

      return {
        data,
        total,
        hasMore,
        lastTimestamp,
      };
    } else {
      // ========== 免费会话：仅从 Redis 同步临时消息 ==========
      this.logger.log(
        `[syncMessages] 免费会话，从 Redis 同步临时消息 [${conversationId}]`,
      );

      const filteredMessages = await this.getFreeSessionMessages(
        conversationId,
        since,
        syncUpperBound,
      );

      const hasMore = filteredMessages.length > limit;
      const data = hasMore
        ? filteredMessages.slice(0, limit)
        : filteredMessages;
      const total = data.length;
      // 统一返回 ISO 字符串格式（与付费会话保持一致）。
      // 免费会话消息来自 Redis/MySQL 混合源，createdAt 可能是字符串也可能是 Date。
      const lastMessageCreatedAt =
        data.length > 0
          ? (data[data.length - 1].createdAt as string | Date)
          : null;
      const lastTimestamp =
        lastMessageCreatedAt !== null
          ? typeof lastMessageCreatedAt === "string"
            ? lastMessageCreatedAt
            : new Date(lastMessageCreatedAt).toISOString()
          : syncUpperBound.toISOString();

      this.logger.log(
        `[syncMessages] 从 Redis 获取到 ${total} 条消息 [${conversationId}], hasMore=${hasMore}`,
      );

      return {
        data,
        total,
        hasMore,
        lastTimestamp,
      };
    }
  }

  /**
   * 读取免费会话消息。
   * 业务规则：免费会话完全是 Redis 临时态，只有用户在当前会话直接付费后才会迁移到数据库。
   */
  private async getFreeSessionMessages(
    conversationId: string,
    since?: Date,
    until?: Date,
    redactRevoked = true,
  ): Promise<Message[]> {
    const tempKey = this.createRedisTempKey(conversationId);
    const tempMessagesJson = await this.redisService.lrange(tempKey, 0, -1);

    const tempMessages = tempMessagesJson
      .map((msg) => this.parseRedisMessage(msg))
      .filter((message) => {
        const createdAt = new Date(message.createdAt);

        if (since && createdAt <= since) {
          return false;
        }

        if (until && createdAt > until) {
          return false;
        }

        return true;
      });

    return redactRevoked
      ? tempMessages.map((message) => this.toClientMessage(message))
      : tempMessages;
  }

  /**
   * 解析 Redis 临时消息并兼容历史旧数据缺失 id 的情况。
   */
  private parseRedisMessage(message: string): Message {
    const parsedMessage = JSON.parse(message);

    if (!parsedMessage.id) {
      parsedMessage.id = new Date(parsedMessage.createdAt).getTime();
    }

    return parsedMessage;
  }

  async getMessageById(messageId: number): Promise<Message> {
    const message = await this.messageRepository.findOne({
      where: { id: messageId },
      relations: ["sender", "receiver"],
    });

    if (!message) {
      throw new NotFoundException("消息不存在");
    }

    return this.toClientMessage(message);
  }

  /** 撤回本人两分钟内发送的普通医患消息，兼容 Redis 免费会话和 MySQL 付费会话。 */
  async revokeMessage(
    conversationId: string,
    messageId: number,
    senderId: number,
    senderType: ChatPrincipalType,
  ): Promise<Message> {
    const session = await this.assertConversationParticipant(
      conversationId,
      senderId,
      senderType,
    );

    if (this.isPaidRuntimeSession(session)) {
      const message = await this.messageRepository.findOne({
        where: { id: messageId, conversationId },
      });
      if (!message) {
        throw new NotFoundException("消息不存在");
      }
      this.assertMessageCanBeRevoked(message, senderId, senderType);
      message.isRevoked = true;
      message.revokedAt = new Date();
      message.isRead = true;
      message.status = MessageStatus.READ;
      return this.toClientMessage(await this.messageRepository.save(message));
    }

    const key = this.createRedisTempKey(conversationId);
    const rawMessages = await this.redisService.lrange(key, 0, -1);
    const index = rawMessages.findIndex((raw) => {
      try {
        return Number((JSON.parse(raw) as TemporaryMessage).id) === messageId;
      } catch {
        return false;
      }
    });
    if (index < 0) {
      throw new NotFoundException("消息不存在");
    }

    const message = JSON.parse(rawMessages[index]) as unknown as Message;
    this.assertMessageCanBeRevoked(message, senderId, senderType);
    message.isRevoked = true;
    message.revokedAt = new Date();
    message.isRead = true;
    await this.redisService.lset(key, index, JSON.stringify(message));

    if (
      message.receiverId &&
      (message.receiverType === "user" || message.receiverType === "doctor")
    ) {
      await this.redisService.hdel(
        this.createRedisUnreadKey(message.receiverType, message.receiverId),
        this.createRedisUnreadField(conversationId, messageId),
      );
    }
    return this.toClientMessage(message);
  }

  private assertMessageCanBeRevoked(
    message: Message,
    senderId: number,
    senderType: ChatPrincipalType,
  ): void {
    if (message.senderId !== senderId || message.senderType !== senderType) {
      throw new ForbiddenException("只能撤回自己发送的消息");
    }
    if (message.isRevoked) {
      throw new BadRequestException("消息已撤回");
    }
    const createdAt = new Date(message.createdAt).getTime();
    if (
      !Number.isFinite(createdAt) ||
      Date.now() - createdAt > MESSAGE_RECALL_WINDOW_MS
    ) {
      throw new BadRequestException("消息发送超过2分钟，无法撤回");
    }
    if (
      message.isAutoReply ||
      ![
        MessageType.TEXT,
        MessageType.IMAGE,
        MessageType.VIDEO,
        MessageType.VOICE,
      ].includes(message.type)
    ) {
      throw new BadRequestException("该消息不支持撤回");
    }
  }

  private toClientMessage(message: Message): Message {
    if (!message.isRevoked) {
      return message;
    }
    return {
      ...message,
      type: MessageType.TEXT,
      content: MESSAGE_REVOKED_CONTENT,
      packages: [],
    } as Message;
  }

  async canSendMessage(
    senderId: number,
    receiverId: number,
    senderType: "user" | "doctor" = "user",
    receiverType: "user" | "doctor" = "doctor",
    conversationId?: string,
  ): Promise<{ canSend: boolean; reason?: string; session?: any }> {
    const participantPair = this.resolveParticipantPair(
      senderId,
      senderType,
      receiverId,
      receiverType,
    );
    const session = conversationId
      ? await this.chatSessionService.getSessionByConversationId(conversationId)
      : await this.chatSessionService.getSession(
          participantPair.userId,
          participantPair.doctorId,
        );

    if (conversationId && !session) {
      throw new BadRequestException("无效的 conversationId");
    }

    const { doctorId } = participantPair;

    if (!session) {
      return { canSend: true };
    }

    if (session.status === "FREE") {
      const autoReplyLimit = (await this.autoReplyService.getActiveReplies())
        .length;
      const freeSession = {
        ...session,
        maxFreeReplies: autoReplyLimit,
        paymentRequired: Boolean(session.paymentRequired),
      };

      if (freeSession.paymentRequired) {
        const packages = await this.getAvailablePackages(doctorId);
        return {
          canSend: false,
          reason: "FREE_LIMIT_EXCEEDED",
          session: { ...freeSession, availablePackages: packages },
        };
      }
      return { canSend: true, session: freeSession };
    }

    if (session.status === "PAID") {
      if (session.serviceEndAt && new Date() > new Date(session.serviceEndAt)) {
        const persistedSession =
          await this.chatSessionService.getPersistedSessionByConversationId(
            session.conversationId,
          );
        if (persistedSession) {
          persistedSession.status = "EXPIRED" as any;
          await this.chatSessionService.updateSession(persistedSession);
        }

        const packages = await this.getAvailablePackages(doctorId);
        return {
          canSend: false,
          reason: "SERVICE_EXPIRED",
          session: {
            ...session,
            status: "EXPIRED",
            availablePackages: packages,
          },
        };
      }
      return { canSend: true, session };
    }

    if (session.status === "EXPIRED") {
      const packages = await this.getAvailablePackages(doctorId);
      return {
        canSend: false,
        reason: "SERVICE_EXPIRED",
        session: { ...session, availablePackages: packages },
      };
    }

    return { canSend: false, reason: "UNKNOWN" };
  }

  async shouldSendPaymentPromptAfterMessage(
    conversationId: string,
  ): Promise<boolean> {
    const session =
      await this.chatSessionService.getSessionByConversationId(conversationId);

    if (
      !session ||
      session.status !== "FREE" ||
      Boolean(session.paymentRequired)
    ) {
      return false;
    }

    const autoReplyLimit = (await this.autoReplyService.getActiveReplies())
      .length;
    return session.autoReplyCount >= autoReplyLimit;
  }

  async triggerAutoReply(
    conversationId: string,
    userId: number,
    doctorId: number,
  ): Promise<Message | null> {
    const session =
      await this.chatSessionService.getSessionByConversationId(conversationId);

    // 检查会话状态
    if (!session || session.status !== "FREE") {
      this.logger.debug(
        `[triggerAutoReply] 会话状态不满足条件: session=${!!session}, status=${session?.status}`,
      );
      return null;
    }

    // 获取所有启用的自动回复（按 sortOrder 排序）
    const autoReplies = await this.autoReplyService.getActiveReplies();
    this.logger.debug(
      `[triggerAutoReply] 当前状态: autoReplyCount=${session.autoReplyCount}, autoReplies.length=${autoReplies.length}`,
    );

    // 检查是否已发完所有自动回复
    if (session.autoReplyCount >= autoReplies.length) {
      this.logger.warn(
        `[triggerAutoReply] 自动回复已全部发送完毕: ${session.autoReplyCount}/${autoReplies.length}`,
      );
      // 注意：不在这里推送付费提示，由 Gateway 在接收到 null 后处理
      return null;
    }

    // 防抖：1秒内不重复发送（防止用户快速连续发送消息）
    if (session.lastAutoReplyAt) {
      const timeDiff = Date.now() - new Date(session.lastAutoReplyAt).getTime();
      if (timeDiff < 1000) {
        this.logger.debug(
          `[triggerAutoReply] 距离上次自动回复仅 ${timeDiff}ms，跳过本次触发`,
        );
        return null;
      }
    }

    // 获取下一条自动回复（autoReplyCount=1时取第2条，因为第1条已在进入房间时发送）
    const nextReply = autoReplies[session.autoReplyCount];

    if (!nextReply) {
      this.logger.warn(
        `[triggerAutoReply] 无法获取第 ${session.autoReplyCount + 1} 条自动回复 (autoReplies[${session.autoReplyCount}] is null)`,
      );
      return null;
    }

    // 构建自动回复消息
    // 注意：自动回复永远是医生发送给用户的，所以类型固定
    const autoReplyMessage = {
      conversationId,
      senderId: doctorId,
      senderType: "doctor", // 自动回复发送者固定为医生
      receiverId: userId,
      receiverType: "user", // 自动回复接收者固定为用户
      content: nextReply.content,
      type: MessageType.TEXT,
      isAutoReply: true,
      isRead: false,
      createdAt: new Date(),
      id: Date.now() + 1,
    };

    // 存入 Redis（临时存储）
    await this.saveTemporaryMessage(autoReplyMessage);
    this.logger.log(
      `[triggerAutoReply] 自动回复 [${session.autoReplyCount + 1}/${autoReplies.length}] 已发送: ${nextReply.content}`,
    );

    // 更新自动回复计数
    await this.chatSessionService.persistTempSession({
      ...session,
      autoReplyCount: session.autoReplyCount + 1,
      lastAutoReplyAt: new Date(),
    });
    this.logger.debug(
      `[triggerAutoReply] 计数器已更新: ${session.autoReplyCount} -> ${session.autoReplyCount + 1}`,
    );

    // 最后一条自动回复发出后，等待用户再发送一条消息才提示付费。
    if (session.autoReplyCount + 1 >= autoReplies.length) {
      this.logger.log(
        `[triggerAutoReply] 已发送最后一条自动回复，等待用户下一条消息后提示付费`,
      );
    }

    return autoReplyMessage as Message;
  }

  async getPetAiConsultations(
    petId: number,
    userId: number,
    page = 1,
    pageSize = 10,
  ): Promise<PaginatedResult<any>> {
    // TODO: 实现 AI 问诊记录查询（需要注入 AiConsultationService）
    return {
      data: [],
      total: 0,
      page: 1,
      pageSize: 10,
      totalPages: 0,
    };
  }

  async getAiConsultationDetail(messageId: number): Promise<any> {
    const message = await this.getMessageById(messageId);

    if (!message || message.type !== MessageType.AI_CONSULTATION) {
      throw new NotFoundException("不是 AI 问诊记录");
    }

    // TODO: 注入 AiConsultationService 并获取完整数据
    return {
      messageId: message.id,
      aiConsultationId: message.aiConsultationId,
      question: "TODO: 从 AiConsultationService 获取完整数据",
      pet: null,
      createdAt: new Date(),
      responseTime: null,
    };
  }

  async getOrCreateSession(userId: number, doctorId: number): Promise<any> {
    const session = await this.chatSessionService.getOrCreateSession(
      userId,
      doctorId,
    );

    // 使用 Redis 标记防止重复触发初始自动回复（防止并发调用导致多次发送）
    const initKey = `chat:init:${session.conversationId}`;
    const isInitialized = await this.redisService.get(initKey);

    // 首次创建会话且未初始化时，立即发送第一条自动回复
    const isNewSession = session.autoReplyCount === 0 && !isInitialized;
    if (isNewSession) {
      // 标记已初始化（有效期1小时，防止重复触发）
      await this.redisService.set(initKey, "1");
      await this.redisService.expire(initKey, 3600);
      this.logger.log(
        `[getOrCreateSession] 首次创建会话，发送初始自动回复 [${userId}-${doctorId}]`,
      );

      await this.sendInitialAutoReply(session.conversationId, userId, doctorId);
    }

    const [packages, autoReplies] = await Promise.all([
      this.getAvailablePackages(doctorId),
      this.autoReplyService.getActiveReplies(),
    ]);

    const remainingDays = session.serviceEndAt
      ? Math.max(
          0,
          Math.ceil(
            (new Date(session.serviceEndAt).getTime() - new Date().getTime()) /
              (1000 * 60 * 60 * 24),
          ),
        )
      : null;

    return {
      sessionId: session.id,
      userId: session.userId,
      doctorId: session.doctorId,
      conversationId: session.conversationId,
      status: session.status,
      autoReplyCount: session.autoReplyCount,
      maxFreeReplies: autoReplies.length,
      paymentRequired: Boolean(session.paymentRequired),
      serviceStartAt: session.serviceStartAt,
      serviceEndAt: session.serviceEndAt,
      currentOrder: session.order,
      availablePackages: packages,
      remainingDays,
    };
  }

  async markAsRead(
    messageId: number,
    principalId: number,
    principalType: ChatPrincipalType,
  ): Promise<void> {
    const message = await this.messageRepository.findOne({
      where: { id: messageId, isDeleted: false },
    });
    if (!message) {
      throw new NotFoundException("消息不存在");
    }
    if (
      message.receiverId !== principalId ||
      message.receiverType !== principalType
    ) {
      throw new ForbiddenException("您无权标记该消息为已读");
    }

    await this.messageRepository.update(messageId, {
      isRead: true,
      status: MessageStatus.READ,
    });
  }

  async markConversationAsRead(
    conversationId: string,
    principalId: number,
    principalType: ChatPrincipalType,
  ): Promise<void> {
    const session = await this.assertConversationParticipant(
      conversationId,
      principalId,
      principalType,
    );
    const expectedParticipantId =
      principalType === "user" ? session.userId : session.doctorId;
    if (expectedParticipantId !== principalId) {
      throw new ForbiddenException("当前账号类型与会话参与者不匹配");
    }

    await this.messageRepository.update(
      {
        conversationId,
        receiverId: principalId,
        receiverType: principalType,
        isRead: false,
        isDeleted: false,
      },
      { isRead: true, status: MessageStatus.READ },
    );
    await this.clearTemporaryConversationUnread(
      conversationId,
      principalId,
      principalType,
    );
  }

  async getUnreadCount(
    principalId: number,
    principalType: ChatPrincipalType,
  ): Promise<number> {
    if (principalType === "user") {
      const sessions =
        await this.chatSessionService.getUserRuntimeSessions(principalId);
      const temporaryConversationIds = new Set(
        sessions
          .filter((session) => session.isTemporary)
          .map((session) => session.conversationId),
      );
      const persistedConversationIds = sessions
        .filter((session) => !session.isTemporary)
        .map((session) => session.conversationId);
      const persistedCount = persistedConversationIds.length
        ? await this.messageRepository.count({
            where: {
              conversationId: In(persistedConversationIds),
              receiverId: principalId,
              receiverType: principalType,
              isRead: false,
              isDeleted: false,
            },
          })
        : 0;
      await this.ensureTemporaryUnreadIndex(principalId, principalType);
      const temporaryUnread = await this.redisService.hgetall(
        this.createRedisUnreadKey(principalType, principalId),
      );
      const visibleTemporaryUnread = Object.values(temporaryUnread).filter(
        (conversationId) => temporaryConversationIds.has(conversationId),
      ).length;
      return persistedCount + visibleTemporaryUnread;
    }

    const persistedCount = await this.messageRepository.count({
      where: {
        receiverId: principalId,
        receiverType: principalType,
        isRead: false,
        isDeleted: false,
      },
    });
    await this.ensureTemporaryUnreadIndex(principalId, principalType);
    const temporaryUnread = await this.redisService.hgetall(
      this.createRedisUnreadKey(principalType, principalId),
    );
    return persistedCount + Object.keys(temporaryUnread).length;
  }

  async getConversationList(
    userId: number,
    page = 1,
    limit = 20,
  ): Promise<{
    data: ConsultationConversationSummary[];
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  }> {
    const sessions =
      await this.chatSessionService.getUserRuntimeSessions(userId);
    if (sessions.length === 0) {
      return { data: [], total: 0, page, limit, totalPages: 0 };
    }

    const persistedConversationIds = sessions
      .filter((session) => !session.isTemporary)
      .map((session) => session.conversationId);
    const [persistedMessages, persistedUnreadCounts] =
      await this.loadPersistedConversationMetadata(
        persistedConversationIds,
        userId,
        "user",
      );

    await this.ensureTemporaryUnreadIndex(userId, "user");
    const temporaryUnreadIndex = await this.redisService.hgetall(
      this.createRedisUnreadKey("user", userId),
    );
    const temporaryUnreadCounts = new Map<string, number>();
    for (const conversationId of Object.values(temporaryUnreadIndex)) {
      temporaryUnreadCounts.set(
        conversationId,
        (temporaryUnreadCounts.get(conversationId) || 0) + 1,
      );
    }

    const sortable = await Promise.all(
      sessions.map(async (session) => {
        let lastMessage = persistedMessages.get(session.conversationId) || null;
        if (session.isTemporary) {
          const messages = await this.redisService.lrange(
            this.createRedisTempKey(session.conversationId),
            0,
            0,
          );
          lastMessage = messages.length
            ? this.parseRedisMessage(messages[0])
            : null;
        }

        const createdAt = session.createdAt || new Date(0);
        const updatedAt = session.updatedAt || createdAt;
        const sortAt = lastMessage?.createdAt
          ? new Date(lastMessage.createdAt)
          : session.lastMessageAt || updatedAt;

        return {
          session,
          lastMessage,
          createdAt,
          updatedAt,
          sortAt,
          unreadCount: session.isTemporary
            ? temporaryUnreadCounts.get(session.conversationId) || 0
            : persistedUnreadCounts.get(session.conversationId) || 0,
        };
      }),
    );
    sortable.sort((left, right) => {
      const timeDifference = right.sortAt.getTime() - left.sortAt.getTime();
      return timeDifference !== 0
        ? timeDifference
        : right.session.conversationId.localeCompare(
            left.session.conversationId,
          );
    });

    const total = sortable.length;
    const pageItems = sortable.slice((page - 1) * limit, page * limit);
    const doctorIds = Array.from(
      new Set(pageItems.map((item) => item.session.doctorId)),
    );
    const doctors = new Map<number, { name?: string; avatar?: string }>();
    await Promise.all(
      doctorIds.map(async (doctorId) => {
        try {
          doctors.set(doctorId, await this.doctorsService.findOne(doctorId));
        } catch {
          doctors.set(doctorId, {});
        }
      }),
    );

    const data = pageItems.map(
      ({ session, lastMessage, unreadCount, createdAt, updatedAt }) => {
        const doctor = doctors.get(session.doctorId);
        const visibleLastMessage = lastMessage
          ? this.toClientMessage(lastMessage)
          : null;
        return {
          conversationId: session.conversationId,
          userId: session.userId,
          doctorId: session.doctorId,
          doctorName: doctor?.name || `医生${session.doctorId}`,
          doctorAvatar: doctor?.avatar || "",
          status: session.status,
          paymentRequired: session.paymentRequired === true,
          isTemporary: session.isTemporary === true,
          orderId: session.orderId,
          serviceStartAt: session.serviceStartAt,
          serviceEndAt: session.serviceEndAt,
          lastMessage: visibleLastMessage
            ? {
                id: visibleLastMessage.id,
                conversationId: session.conversationId,
                senderId: visibleLastMessage.senderId,
                receiverId: visibleLastMessage.receiverId,
                content: visibleLastMessage.content,
                type: visibleLastMessage.type,
                isAutoReply: visibleLastMessage.isAutoReply === true,
                createdAt: visibleLastMessage.createdAt,
              }
            : null,
          unreadCount,
          createdAt,
          updatedAt,
        } satisfies ConsultationConversationSummary;
      },
    );

    return {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  private async loadPersistedConversationMetadata(
    conversationIds: string[],
    principalId: number,
    principalType: "user" | "doctor",
  ): Promise<[Map<string, Message>, Map<string, number>]> {
    if (conversationIds.length === 0) {
      return [new Map(), new Map()];
    }

    const latestMessageIdQuery = this.messageRepository
      .createQueryBuilder("latest")
      .select("latest.conversationId", "conversationId")
      .addSelect("MAX(latest.id)", "messageId")
      .where("latest.conversationId IN (:...conversationIds)", {
        conversationIds,
      })
      .andWhere("latest.isDeleted = :isDeleted", { isDeleted: false })
      .groupBy("latest.conversationId");
    const latestMessages = await this.messageRepository
      .createQueryBuilder("message")
      .innerJoin(
        `(${latestMessageIdQuery.getQuery()})`,
        "latest_message",
        "latest_message.messageId = message.id",
      )
      .setParameters(latestMessageIdQuery.getParameters())
      .getMany();

    const unreadRows = await this.messageRepository
      .createQueryBuilder("message")
      .select("message.conversationId", "conversationId")
      .addSelect("COUNT(message.id)", "unreadCount")
      .where("message.conversationId IN (:...conversationIds)", {
        conversationIds,
      })
      .andWhere("message.receiverId = :principalId", { principalId })
      .andWhere("message.receiverType = :receiverType", {
        receiverType: principalType,
      })
      .andWhere("message.isRead = :isRead", { isRead: false })
      .andWhere("message.isDeleted = :isDeleted", { isDeleted: false })
      .groupBy("message.conversationId")
      .getRawMany<{ conversationId: string; unreadCount: string }>();

    return [
      new Map(
        latestMessages.map((message) => [message.conversationId, message]),
      ),
      new Map(
        unreadRows.map((row) => [
          row.conversationId,
          Number(row.unreadCount) || 0,
        ]),
      ),
    ];
  }

  generateConversationId(userId: number, doctorId: number): string {
    const ids = [userId, doctorId].sort((a, b) => a - b);
    return ids.join("_");
  }

  /**
   * 兼容接口：返回服务端解析出的真实 session `conversationId`。
   */
  async resolveConversationId(
    userId: number,
    doctorId: number,
  ): Promise<{ conversationId: string }> {
    const session = await this.chatSessionService.getOrCreateSession(
      userId,
      doctorId,
    );
    return { conversationId: session.conversationId };
  }

  /**
   * 校验当前用户是否属于指定会话，供 HTTP / WebSocket 入口统一复用。
   */
  async assertConversationParticipant(
    conversationId: string,
    currentUserId: number,
    currentUserType: ChatPrincipalType,
  ) {
    const session =
      await this.chatSessionService.getSessionByConversationId(conversationId);

    if (!session) {
      throw new BadRequestException("无效的 conversationId");
    }

    const participantId =
      currentUserType === "user" ? session.userId : session.doctorId;
    const isParticipant = participantId === currentUserId;
    if (!isParticipant) {
      throw new ForbiddenException("您无权访问该会话的消息");
    }

    return session;
  }

  /**
   * 获取当前会话之前的最近一段历史会话元数据。
   */
  async getPreviousSession(
    currentUserId: number,
    currentUserType: ChatPrincipalType,
    doctorId: number,
    beforeConversationId: string,
  ) {
    const currentSession =
      await this.chatSessionService.getPersistedSessionByConversationId(
        beforeConversationId,
      );

    if (!currentSession) {
      throw new BadRequestException("无效的 beforeConversationId");
    }

    const participantId =
      currentUserType === "user"
        ? currentSession.userId
        : currentSession.doctorId;
    const isParticipant = participantId === currentUserId;
    if (!isParticipant) {
      throw new ForbiddenException("您无权访问该会话");
    }

    if (currentSession.doctorId !== doctorId) {
      throw new BadRequestException("beforeConversationId 与 doctorId 不匹配");
    }

    const previousSession = await this.chatSessionService.getPreviousSession(
      currentSession.userId,
      currentSession.doctorId,
      beforeConversationId,
    );

    if (!previousSession) {
      return null;
    }

    return {
      sessionId: previousSession.id,
      conversationId: previousSession.conversationId,
      status: previousSession.status,
      orderId: previousSession.orderId,
      serviceStartAt: previousSession.serviceStartAt,
      serviceEndAt: previousSession.serviceEndAt,
      createdAt: previousSession.createdAt,
      updatedAt: previousSession.updatedAt,
    };
  }

  /**
   * 发送初始自动回复（创建会话时立即发送）
   * 用户点击医生聊天后，系统立即发送第一条欢迎消息
   *
   * @param conversationId 会话ID
   * @param userId 用户ID
   * @param doctorId 医生ID
   */
  async sendInitialAutoReply(
    conversationId: string,
    userId: number,
    doctorId: number,
  ): Promise<void> {
    // 1. 检查 Redis 中是否已有消息（防止重复发送）
    const tempKey = this.createRedisTempKey(conversationId);
    const existingMessages = await this.redisService.llen(tempKey);

    if (existingMessages > 0) {
      this.logger.warn(
        `[sendInitialAutoReply] 已有 ${existingMessages} 条消息，跳过初始自动回复 [${conversationId}]`,
      );
      return;
    }

    // 2. 获取第一条自动回复（sortOrder = 1）
    const firstReply = await this.autoReplyService.getReplyByIndex(1);

    if (!firstReply) {
      this.logger.warn("[sendInitialAutoReply] 没有配置自动回复");
      return;
    }

    // 3. 构建自动回复消息
    const autoReplyMessage = {
      conversationId,
      senderId: doctorId, // 医生 ID
      senderType: "doctor",
      receiverId: userId, // 用户 ID
      receiverType: "user",
      content: firstReply.content,
      type: MessageType.TEXT,
      isAutoReply: true,
      isRead: false,
      createdAt: new Date(),
      id: Date.now(),
    };

    // 4. 存入 Redis（临时存储）
    await this.saveTemporaryMessage(autoReplyMessage);
    this.logger.log(
      `[sendInitialAutoReply] 初始自动回复已发送 [${conversationId}]: ${firstReply.content}`,
    );

    // 5. 重置计数器为 1（Redis 和数据库同步）
    const session =
      await this.chatSessionService.getSessionByConversationId(conversationId);
    if (session?.isTemporary) {
      await this.chatSessionService.persistTempSession({
        ...session,
        autoReplyCount: 1,
        lastAutoReplyAt: new Date(),
      });
      this.logger.log(
        `[sendInitialAutoReply] 计数器已重置为 1 [${userId}-${doctorId}]`,
      );
    }
  }

  /**
   * 检查并发送自动回复（基于顺序轮播）
   * 用于 FREE 会话阶段，自动回复也存 Redis
   *
   * 完整业务流程：
   * 1. 用户点击医生聊天 → 系统发送第 1 条（创建会话时）
   * 2. 用户发送消息 → 系统发送第 2 条
   * 3. 用户再发消息 → 系统发送第 3 条
   * 4. ...直到 N 条发完 → 用户再发送一条消息后提示付费
   *
   * 注意：第1条自动回复在创建会话时已发送，此方法处理后续回复
   *
   * @param conversationId 会话ID
   * @param userId 用户ID
   * @param doctorId 医生ID
   */
  private async checkAndSendAutoReply(
    conversationId: string,
    userId: number,
    doctorId: number,
  ): Promise<void> {
    // 1. 获取所有启用的自动回复（按 sortOrder 排序）
    const autoReplies = await this.autoReplyService.getActiveReplies();

    if (autoReplies.length === 0) {
      return;
    }

    // 2. 获取已发送的自动回复数量（从 Redis）
    const session =
      await this.chatSessionService.getSessionByConversationId(conversationId);

    if (!session?.isTemporary) {
      return;
    }

    const currentCount = session.autoReplyCount;

    // 3. 检查是否还有剩余的自动回复
    if (currentCount >= autoReplies.length) {
      this.logger.debug(
        `自动回复已全部发送完毕: ${currentCount}/${autoReplies.length}`,
      );
      // 推送付费提示
      await this.pushPaymentPrompt(userId, doctorId);
      return;
    }

    // 4. 获取下一条自动回复（currentCount=1 时获取第2条，因为第1条已在创建会话时发送）
    const nextReply = autoReplies[currentCount];

    // 5. 构建自动回复消息
    const autoReplyMessage = {
      conversationId,
      senderId: doctorId, // 医生 ID
      senderType: "doctor" as const,
      receiverId: userId, // 用户 ID
      receiverType: "user" as const,
      content: nextReply.content,
      type: "TEXT",
      isAutoReply: true,
      isRead: false,
      createdAt: new Date(),
      id: this.createRuntimeMessageId(),
    };

    // 6. 存入 Redis（临时存储）
    await this.saveTemporaryMessage(autoReplyMessage);
    this.logger.debug(
      `自动回复 [${currentCount + 1}/${autoReplies.length}] 已存入 Redis: ${nextReply.content}`,
    );

    // 7. 更新已发送数量（存 Redis）
    await this.chatSessionService.persistTempSession({
      ...session,
      autoReplyCount: currentCount + 1,
      lastAutoReplyAt: new Date(),
    });

    // 8. 最后一条自动回复发出后，等待用户下一条消息再提示付费
    if (currentCount + 1 >= autoReplies.length) {
      this.logger.debug("最后一条自动回复已发送，等待用户下一条消息");
    }
  }

  /**
   * 推送付费提示
   * 当免费自动回复用完时，提示用户购买套餐
   */
  private async pushPaymentPrompt(
    userId: number,
    doctorId: number,
  ): Promise<void> {
    // 获取该医生的套餐列表
    const packages = await this.getAvailablePackages(doctorId);

    // TODO: 通过 WebSocket 推送付费提示
    // 需要注入 ChatGateway
    this.logger.log(
      `用户 ${userId} 与医生 ${doctorId} 的免费自动回复已用完，推送付费提示`,
    );

    // 记录付费提示信息
    this.logger.log(
      `[PaymentRequired] userId: ${userId}, doctorId: ${doctorId}, packages: ${JSON.stringify(packages)}`,
    );
  }

  /**
   * 获取医生的可用收费项列表
   * @param doctorId 医生 ID
   * @returns 收费项列表
   */
  async getAvailablePackages(doctorId: number): Promise<any[]> {
    const serviceItems = await this.doctorsService.getServiceItems(doctorId);

    // 转换为前端需要的格式（保持兼容性）
    return serviceItems.map((item) => ({
      id: item.id,
      name: item.name,
      duration: item.duration, // 分钟
      durationDays: Math.floor(item.duration / 1440), // 转换为天（用于显示）
      price: item.price,
      description: item.description,
    }));
  }

  /**
   * 发送付费提示消息
   * 当用户免费额度用完时，向聊天记录中插入一条付费提示消息
   *
   * @param userId 用户 ID
   * @param doctorId 医生 ID
   * @param packages 可用套餐列表
   * @returns 创建的消息
   */
  async sendPaymentPromptMessage(
    userId: number,
    doctorId: number,
    packages: any[],
  ): Promise<Message> {
    const session = await this.chatSessionService.getSession(userId, doctorId);
    if (!session) {
      throw new NotFoundException("会话不存在");
    }

    const conversationId = session.conversationId;
    const message = {
      id: this.createRuntimeMessageId(),
      conversationId,
      senderId: null, // 系统消息，发送者为 NULL（表示无发送者）
      senderType: "doctor", // 系统消息使用 doctor 类型
      receiverId: userId,
      receiverType: "user",
      content: "免费咨询次数已用完，请选择套餐继续咨询",
      type: MessageType.PAYMENT_PROMPT,
      status: MessageStatus.SENT,
      isAutoReply: false,
      isRead: false,
      packages, // 存储套餐列表
      createdAt: new Date(),
    };

    await this.chatSessionService.markTempSessionPaymentRequired(
      conversationId,
    );
    await this.saveTemporaryMessage(message);
    this.logger.log(
      `[sendPaymentPromptMessage] 付费提示消息已发送 [conversationId: ${conversationId}, packages: ${packages.length}]`,
    );

    return message as Message;
  }

  /**
   * 发送购买成功消息
   * 用户购买套餐成功后，向聊天记录中插入一条确认消息
   *
   * @param userId 用户 ID
   * @param doctorId 医生 ID
   * @param packageName 套餐名称
   * @param serviceEndAt 服务到期时间
   * @param orderId 订单 ID
   * @returns 创建的消息
   */
  async sendPaymentSuccessMessage(
    userId: number,
    doctorId: number,
    packageName: string,
    serviceEndAt: Date,
    orderId: number,
  ): Promise<Message> {
    const session = await this.chatSessionService.getSession(userId, doctorId);
    if (!session) {
      throw new NotFoundException("会话不存在");
    }

    const conversationId = session.conversationId;
    const endTimeStr = new Date(serviceEndAt).toLocaleString("zh-CN", {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    });

    const message = this.messageRepository.create({
      conversationId,
      senderId: null, // 系统消息，发送者为 NULL（表示无发送者）
      senderType: "doctor", // 系统消息使用 doctor 类型
      receiverId: userId,
      receiverType: "user",
      content: `您已购买「${packageName}」，服务至 ${endTimeStr}`,
      type: MessageType.PAYMENT_SUCCESS,
      status: MessageStatus.SENT,
      isAutoReply: false,
      isRead: false,
      orderId, // 关联订单 ID
    });

    const savedMessage = await this.messageRepository.save(message);
    this.logger.log(
      `[sendPaymentSuccessMessage] 购买成功消息已发送 [conversationId: ${conversationId}, order: ${orderId}]`,
    );

    return savedMessage;
  }

  async getStatistics(userId?: number): Promise<any> {
    const whereCondition: any = {
      isDeleted: false,
    };

    if (userId) {
      whereCondition.senderId = userId;
    }

    const totalMessages = await this.messageRepository.count({
      where: whereCondition,
    });

    const byType = await this.messageRepository
      .createQueryBuilder("message")
      .select("message.type", "type")
      .addSelect("COUNT(*)", "count")
      .where("message.isDeleted = :isDeleted", { isDeleted: false })
      .groupBy("message.type")
      .getRawMany();

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const todayCondition: any = {
      isDeleted: false,
      createdAt: MoreThanOrEqual(today),
    };

    if (userId) {
      todayCondition.senderId = userId;
    }

    const todayCount = await this.messageRepository.count({
      where: todayCondition,
    });

    return {
      totalMessages,
      byType: byType.reduce(
        (acc, item) => ({ ...acc, [item.type]: parseInt(item.count) }),
        {},
      ),
      todayCount,
    };
  }

  /**
   * 获取会话列表（管理后台专用）
   * 委托给 ChatSessionService 处理
   */
  async getSessions(options: {
    page?: number;
    limit?: number;
    doctorId?: number;
    userId?: number;
    status?: any;
  }) {
    return this.chatSessionService.getSessions(options);
  }

  async getDoctorSessions(options: {
    page?: number;
    limit?: number;
    doctorId: number;
    status?: any;
  }) {
    const result = await this.chatSessionService.getSessions(options);
    const conversationIds = result.data.map(
      (session) => session.conversationId as string,
    );
    const [latestMessages, unreadCounts] =
      await this.loadPersistedConversationMetadata(
        conversationIds,
        options.doctorId,
        "doctor",
      );
    const data = result.data.map((session) => {
      const lastMessage = latestMessages.get(session.conversationId);
      const visibleLastMessage = lastMessage
        ? this.toClientMessage(lastMessage)
        : null;
      return {
        ...session,
        lastMessage: visibleLastMessage
          ? {
              id: visibleLastMessage.id,
              conversationId: visibleLastMessage.conversationId,
              senderId: visibleLastMessage.senderId,
              receiverId: visibleLastMessage.receiverId,
              content: visibleLastMessage.content,
              type: visibleLastMessage.type,
              isAutoReply: visibleLastMessage.isAutoReply === true,
              isRead: visibleLastMessage.isRead === true,
              createdAt: visibleLastMessage.createdAt,
            }
          : null,
        unreadCount: unreadCounts.get(session.conversationId) || 0,
      };
    });
    data.sort((left, right) => {
      const leftAt =
        left.lastMessage?.createdAt || left.lastMessageAt || left.updatedAt;
      const rightAt =
        right.lastMessage?.createdAt || right.lastMessageAt || right.updatedAt;
      const byTime =
        new Date(rightAt || 0).getTime() - new Date(leftAt || 0).getTime();
      return byTime !== 0
        ? byTime
        : right.conversationId.localeCompare(left.conversationId);
    });
    return { ...result, data };
  }

  /**
   * 获取用户的历史咨询列表（已支付的订单）
   *
   * @param userId 用户ID
   * @param page 页码
   * @param limit 每页数量
   * @param doctorId 可选的医生ID筛选
   * @returns 历史咨询列表
   */
  async getHistoryConsultations(
    userId: number,
    page = 1,
    limit = 10,
    doctorId?: number,
  ): Promise<{
    data: any[];
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  }> {
    // 查询已支付的订单
    const [orders, total] = await this.orderRepository.findAndCount({
      where: {
        userId,
        status: OrderStatus.PAID,
        ...(doctorId === undefined ? {} : { doctorId }),
      },
      relations: ["doctor", "serviceItem"],
      order: { paidAt: "DESC" },
      skip: (page - 1) * limit,
      take: limit,
    });

    // 为每个订单查询最后一条消息
    const data = await Promise.all(
      orders.map(async (order) => {
        // 查询最后一条消息
        const lastMessage = await this.messageRepository.findOne({
          where: { orderId: order.id },
          order: { createdAt: "DESC" },
        });
        const visibleLastMessage = lastMessage
          ? this.toClientMessage(lastMessage)
          : null;

        // 判断服务状态
        const now = new Date();
        const isActive = order.serviceEndAt && now < order.serviceEndAt;

        return {
          id: order.id,
          orderNo: order.orderNo,
          doctorId: order.doctorId,
          doctorName: order.doctor?.name || `医生${order.doctorId}`,
          doctorAvatar: order.doctor?.avatar || "",
          lastMessage: visibleLastMessage
            ? {
                id: visibleLastMessage.id,
                content: visibleLastMessage.content,
                type: visibleLastMessage.type,
                createdAt: visibleLastMessage.createdAt,
              }
            : null,
          amount: order.amount,
          status: isActive ? "ACTIVE" : "EXPIRED",
          serviceStartAt: order.serviceStartAt,
          serviceEndAt: order.serviceEndAt,
          paidAt: order.paidAt,
          durationDays: Math.floor(order.durationMinutes / 1440),
        };
      }),
    );

    return {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * 获取指定订单的聊天记录
   *
   * @param orderId 订单ID
   * @param userId 用户ID（用于权限验证）
   * @param page 页码
   * @param limit 每页数量
   * @returns 消息列表
   */
  async getMessagesByOrder(
    orderId: number,
    userId: number,
    page = 1,
    limit = 50,
  ): Promise<PaginatedResult<Message>> {
    this.logger.log(
      `[getMessagesByOrder] 开始查询订单消息, orderId=${orderId}, userId=${userId}, page=${page}, limit=${limit}`,
    );

    // 验证订单是否属于该用户
    const order = await this.orderRepository.findOne({
      where: { id: orderId, userId },
      relations: ["doctor"],
    });

    if (!order) {
      this.logger.warn(
        `[getMessagesByOrder] 订单不存在或无权访问, orderId=${orderId}, userId=${userId}`,
      );
      throw new NotFoundException("订单不存在或无权访问");
    }

    this.logger.log(
      `[getMessagesByOrder] 订单验证通过, orderNo=${order.orderNo}, doctorId=${order.doctorId}`,
    );

    // 🔑 关键修改：查询关联到该订单的所有消息（包括购买时关联的历史消息）
    const [data, total] = await this.messageRepository.findAndCount({
      where: {
        orderId, // 直接使用 orderId 过滤（购买时已关联历史消息）
        isDeleted: false,
      },
      relations: ["sender", "receiver", "order"], // 加载发送者、接收者和订单关系
      order: { createdAt: "ASC" }, // ⚠️ 改为正序（最旧的在前），符合聊天界面习惯
      skip: (page - 1) * limit,
      take: limit,
    });

    this.logger.log(
      `[getMessagesByOrder] 查询完成, 找到 ${total} 条消息, 返回第 ${page} 页，共 ${data.length} 条`,
    );

    return {
      data: data.map((message) => this.toClientMessage(message)),
      total,
      page,
      pageSize: limit,
      totalPages: Math.ceil(total / limit),
    };
  }
}
