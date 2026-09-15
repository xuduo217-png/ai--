import { Injectable, Logger } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { randomUUID } from "crypto";
import { LessThanOrEqual, Repository, In } from "typeorm";
import { ChatSession, SessionStatus } from "./entities/chat-session.entity";
import { RedisService } from "../redis/redis.service";

const TEMP_SESSION_TTL_SECONDS = 24 * 60 * 60;
const DEFAULT_MAX_FREE_REPLIES = 3;

export interface RuntimeChatSession {
  id?: number;
  userId: number;
  doctorId: number;
  conversationId: string;
  status: SessionStatus;
  autoReplyCount: number;
  maxFreeReplies: number;
  orderId?: number;
  serviceStartAt?: Date;
  serviceEndAt?: Date;
  lastMessageAt?: Date;
  lastAutoReplyAt?: Date;
  createdAt?: Date;
  updatedAt?: Date;
  order?: ChatSession["order"];
  isTemporary?: boolean;
  paymentRequired?: boolean;
}

@Injectable()
export class ChatSessionService {
  private readonly logger = new Logger(ChatSessionService.name);

  constructor(
    @InjectRepository(ChatSession)
    private chatSessionRepository: Repository<ChatSession>,
    private redisService: RedisService,
  ) {}

  private getTempSessionKey(userId: number, doctorId: number): string {
    return `chat:temp_session:${userId}:${doctorId}`;
  }

  private getTempSessionRefKey(conversationId: string): string {
    return `chat:temp_session_ref:${conversationId}`;
  }

  private serializeTempSession(session: RuntimeChatSession): string {
    return JSON.stringify({
      ...session,
      isTemporary: true,
      createdAt: session.createdAt?.toISOString() || new Date().toISOString(),
      updatedAt: session.updatedAt?.toISOString() || new Date().toISOString(),
      serviceStartAt: session.serviceStartAt?.toISOString(),
      serviceEndAt: session.serviceEndAt?.toISOString(),
      lastMessageAt: session.lastMessageAt?.toISOString(),
      lastAutoReplyAt: session.lastAutoReplyAt?.toISOString(),
    });
  }

  private deserializeTempSession(
    value: string | null,
  ): RuntimeChatSession | null {
    if (!value) {
      return null;
    }

    const rawSession = JSON.parse(value) as Record<string, unknown>;

    return {
      userId: Number(rawSession.userId),
      doctorId: Number(rawSession.doctorId),
      conversationId: String(rawSession.conversationId),
      status: SessionStatus.FREE,
      autoReplyCount: Number(rawSession.autoReplyCount || 0),
      maxFreeReplies: Number(
        rawSession.maxFreeReplies || DEFAULT_MAX_FREE_REPLIES,
      ),
      paymentRequired: Boolean(rawSession.paymentRequired),
      createdAt: rawSession.createdAt
        ? new Date(String(rawSession.createdAt))
        : undefined,
      updatedAt: rawSession.updatedAt
        ? new Date(String(rawSession.updatedAt))
        : undefined,
      lastMessageAt: rawSession.lastMessageAt
        ? new Date(String(rawSession.lastMessageAt))
        : undefined,
      lastAutoReplyAt: rawSession.lastAutoReplyAt
        ? new Date(String(rawSession.lastAutoReplyAt))
        : undefined,
      isTemporary: true,
    };
  }

  private toRuntimePaidSession(session: ChatSession): RuntimeChatSession {
    return {
      id: session.id,
      userId: session.userId,
      doctorId: session.doctorId,
      conversationId: session.conversationId,
      status: session.status,
      autoReplyCount: session.autoReplyCount,
      maxFreeReplies: session.maxFreeReplies,
      orderId: session.orderId,
      serviceStartAt: session.serviceStartAt,
      serviceEndAt: session.serviceEndAt,
      lastMessageAt: session.lastMessageAt,
      lastAutoReplyAt: session.lastAutoReplyAt,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
      order: session.order,
      isTemporary: false,
      paymentRequired: false,
    };
  }

  async updateSession(session: ChatSession): Promise<ChatSession> {
    return this.chatSessionRepository.save(session);
  }

  /**
   * 统一生成会话级唯一 ID。
   * create-path 与 migration backfill 统一使用 UUID v4 语义。
   */
  private createConversationId(): string {
    return randomUUID();
  }

  /**
   * 统一创建新的会话实体，避免不同入口漏写 `conversationId`。
   */
  private createSessionEntity(options: {
    userId: number;
    doctorId: number;
    status: SessionStatus;
    orderId?: number;
    serviceStartAt?: Date;
    serviceEndAt?: Date;
    conversationId?: string;
  }): ChatSession {
    return this.chatSessionRepository.create({
      userId: options.userId,
      doctorId: options.doctorId,
      conversationId: options.conversationId || this.createConversationId(),
      status: options.status,
      orderId: options.orderId,
      autoReplyCount: 0,
      maxFreeReplies: DEFAULT_MAX_FREE_REPLIES,
      serviceStartAt: options.serviceStartAt,
      serviceEndAt: options.serviceEndAt,
    });
  }

  /**
   * 固定按“用户列 + 医生列”读取同一咨询链路的所有会话。
   * 注意：咨询聊天是强角色模型，不再交换 `userId` / `doctorId` 重试。
   */
  private async findSessionsByParticipants(
    userId: number,
    doctorId: number,
  ): Promise<ChatSession[]> {
    return this.chatSessionRepository.find({
      where: { userId, doctorId },
      relations: ["order", "order.serviceItem"],
      order: { createdAt: "DESC" },
    });
  }

  private async getPersistedLatestSessionInternal(
    userId: number,
    doctorId: number,
  ): Promise<ChatSession | null> {
    const sessions = await this.findSessionsByParticipants(userId, doctorId);
    const latestSession = sessions.find((session) => {
      return (
        session.status === SessionStatus.PAID ||
        session.status === SessionStatus.EXPIRED
      );
    });

    if (!latestSession) {
      return null;
    }

    return this.expireSessionIfNeeded(latestSession);
  }

  /**
   * 读取最近一段会话，并在读取路径上顺手归档过期的付费会话。
   */
  private async getLatestSessionInternal(
    userId: number,
    doctorId: number,
  ): Promise<ChatSession | null> {
    return this.getPersistedLatestSessionInternal(userId, doctorId);
  }

  /**
   * 付费会话超时后只做状态归档，不在这里隐式创建下一段会话。
   */
  private async expireSessionIfNeeded(
    session: ChatSession | null,
  ): Promise<ChatSession | null> {
    if (!session) {
      return null;
    }

    if (session.status !== SessionStatus.PAID || !session.serviceEndAt) {
      return session;
    }

    if (new Date() <= new Date(session.serviceEndAt)) {
      return session;
    }

    const result = await this.chatSessionRepository.update(
      {
        id: session.id,
        status: SessionStatus.PAID,
        serviceEndAt: LessThanOrEqual(new Date()),
      },
      { status: SessionStatus.EXPIRED },
    );
    if (!result.affected) {
      return session;
    }
    session.status = SessionStatus.EXPIRED;
    const expiredSession = session;
    this.logger.log(
      `[expireSessionIfNeeded] 会话已归档: id=${expiredSession.id}, conversationId=${expiredSession.conversationId}`,
    );
    return expiredSession;
  }

  async createTempSession(
    userId: number,
    doctorId: number,
  ): Promise<RuntimeChatSession> {
    const session: RuntimeChatSession = {
      userId,
      doctorId,
      conversationId: this.createConversationId(),
      status: SessionStatus.FREE,
      autoReplyCount: 0,
      maxFreeReplies: DEFAULT_MAX_FREE_REPLIES,
      createdAt: new Date(),
      updatedAt: new Date(),
      isTemporary: true,
      paymentRequired: false,
    };

    await this.persistTempSession(session);
    this.logger.log(
      `[createTempSession] 创建新的临时会话: userId=${userId}, doctorId=${doctorId}, conversationId=${session.conversationId}`,
    );
    return session;
  }

  async persistTempSession(
    session: RuntimeChatSession,
  ): Promise<RuntimeChatSession> {
    const normalizedSession: RuntimeChatSession = {
      ...session,
      status: SessionStatus.FREE,
      autoReplyCount: session.autoReplyCount ?? 0,
      maxFreeReplies: session.maxFreeReplies ?? DEFAULT_MAX_FREE_REPLIES,
      updatedAt: new Date(),
      isTemporary: true,
      paymentRequired: session.paymentRequired ?? false,
    };
    const tempSessionKey = this.getTempSessionKey(
      normalizedSession.userId,
      normalizedSession.doctorId,
    );
    const tempSessionRefKey = this.getTempSessionRefKey(
      normalizedSession.conversationId,
    );

    await Promise.all([
      this.redisService.set(
        tempSessionKey,
        this.serializeTempSession(normalizedSession),
        TEMP_SESSION_TTL_SECONDS,
      ),
      this.redisService.set(
        tempSessionRefKey,
        `${normalizedSession.userId}:${normalizedSession.doctorId}`,
        TEMP_SESSION_TTL_SECONDS,
      ),
    ]);

    return normalizedSession;
  }

  async getTempSession(
    userId: number,
    doctorId: number,
  ): Promise<RuntimeChatSession | null> {
    const tempSessionKey = this.getTempSessionKey(userId, doctorId);
    const sessionValue = await this.redisService.get(tempSessionKey);
    return this.deserializeTempSession(sessionValue);
  }

  async getTempSessionByConversationId(
    conversationId: string,
  ): Promise<RuntimeChatSession | null> {
    const refKey = this.getTempSessionRefKey(conversationId);
    const participantPair = await this.redisService.get(refKey);

    if (!participantPair) {
      return null;
    }

    const [userId, doctorId] = participantPair
      .split(":")
      .map((value) => Number(value));

    if (!userId || !doctorId) {
      await this.redisService.del(refKey);
      return null;
    }

    return this.getTempSession(userId, doctorId);
  }

  async deleteTempSession(userId: number, doctorId: number): Promise<void> {
    const existingSession = await this.getTempSession(userId, doctorId);

    if (!existingSession) {
      return;
    }

    await this.redisService.del(
      this.getTempSessionKey(userId, doctorId),
      this.getTempSessionRefKey(existingSession.conversationId),
      `chat:temp:${existingSession.conversationId}`,
      `chat:init:${existingSession.conversationId}`,
    );
    this.logger.log(
      `[deleteTempSession] 已清理临时会话: userId=${userId}, doctorId=${doctorId}, conversationId=${existingSession.conversationId}`,
    );
  }

  async markTempSessionPaymentRequired(
    conversationId: string,
  ): Promise<RuntimeChatSession | null> {
    const tempSession =
      await this.getTempSessionByConversationId(conversationId);

    if (!tempSession) {
      return null;
    }

    return this.persistTempSession({
      ...tempSession,
      paymentRequired: true,
    });
  }

  async getOrCreateSession(
    userId: number,
    doctorId: number,
  ): Promise<RuntimeChatSession> {
    const activePaidSession = await this.getActiveSession(userId, doctorId);
    if (activePaidSession) {
      return this.toRuntimePaidSession(activePaidSession);
    }

    const tempSession = await this.getTempSession(userId, doctorId);
    if (tempSession) {
      if (tempSession.paymentRequired) {
        // 业务规则：用户在弹出付费提示后退出页面，再次进入时应开启全新的临时会话。
        await this.deleteTempSession(userId, doctorId);
      } else {
        return tempSession;
      }
    }

    return this.createTempSession(userId, doctorId);
  }

  async getPersistedSessionByConversationId(
    conversationId: string,
  ): Promise<ChatSession | null> {
    if (!conversationId) {
      return null;
    }

    const session = await this.chatSessionRepository.findOne({
      where: { conversationId },
      relations: ["order", "order.serviceItem"],
    });

    return this.expireSessionIfNeeded(session);
  }

  async getSession(
    userId: number,
    doctorId: number,
  ): Promise<RuntimeChatSession | null> {
    const activePaidSession = await this.getActiveSession(userId, doctorId);
    if (activePaidSession) {
      return this.toRuntimePaidSession(activePaidSession);
    }

    return this.getTempSession(userId, doctorId);
  }

  async getSessionByConversationId(
    conversationId: string,
  ): Promise<RuntimeChatSession | null> {
    const persistedSession =
      await this.getPersistedSessionByConversationId(conversationId);

    if (persistedSession) {
      return this.toRuntimePaidSession(persistedSession);
    }

    return this.getTempSessionByConversationId(conversationId);
  }

  async getLatestPersistedSession(
    userId: number,
    doctorId: number,
  ): Promise<ChatSession | null> {
    return this.getPersistedLatestSessionInternal(userId, doctorId);
  }

  async getOrCreatePersistedSessionForOrder(options: {
    userId: number;
    doctorId: number;
    status: SessionStatus;
    orderId: number;
    serviceStartAt: Date;
    serviceEndAt: Date;
    conversationId?: string;
  }): Promise<ChatSession> {
    const existingPaidSession = await this.getActiveSession(
      options.userId,
      options.doctorId,
    );

    if (existingPaidSession) {
      existingPaidSession.status = options.status;
      existingPaidSession.orderId = options.orderId;
      existingPaidSession.serviceStartAt = options.serviceStartAt;
      existingPaidSession.serviceEndAt = options.serviceEndAt;
      return this.chatSessionRepository.save(existingPaidSession);
    }

    return this.chatSessionRepository.save(
      this.createSessionEntity({
        userId: options.userId,
        doctorId: options.doctorId,
        status: options.status,
        orderId: options.orderId,
        serviceStartAt: options.serviceStartAt,
        serviceEndAt: options.serviceEndAt,
        conversationId: options.conversationId,
      }),
    );
  }

  async getOrCreateLegacyPaidSession(
    userId: number,
    doctorId: number,
  ): Promise<ChatSession> {
    const latestSession = await this.getPersistedLatestSessionInternal(
      userId,
      doctorId,
    );
    if (!latestSession || latestSession.status === SessionStatus.EXPIRED) {
      this.logger.log(
        `[getOrCreateLegacyPaidSession] 创建新的持久化会话: userId=${userId}, doctorId=${doctorId}`,
      );
      return this.chatSessionRepository.save(
        this.createSessionEntity({
          userId,
          doctorId,
          status: SessionStatus.FREE,
        }),
      );
    }

    return latestSession;
  }

  async getPreviousSession(
    userId: number,
    doctorId: number,
    beforeConversationId: string,
  ): Promise<ChatSession | null> {
    const currentSession =
      await this.getPersistedSessionByConversationId(beforeConversationId);
    if (
      !currentSession ||
      currentSession.userId !== userId ||
      currentSession.doctorId !== doctorId
    ) {
      return null;
    }

    const sessions = (
      await this.findSessionsByParticipants(userId, doctorId)
    ).filter(
      (session) =>
        session.status === SessionStatus.PAID ||
        session.status === SessionStatus.EXPIRED,
    );
    const currentIndex = sessions.findIndex(
      (session) => session.id === currentSession.id,
    );

    if (currentIndex < 0 || currentIndex === sessions.length - 1) {
      return null;
    }

    return this.expireSessionIfNeeded(sessions[currentIndex + 1]);
  }

  async getUserSessions(userId: number): Promise<ChatSession[]> {
    return this.chatSessionRepository.find({
      where: { userId },
      relations: ["order", "order.serviceItem"],
      order: { updatedAt: "DESC" },
    });
  }

  /**
   * 获取用户消息中心需要的全部咨询会话。
   * 付费/历史会话来自 MySQL，尚未付费的会话来自 Redis。
   */
  async getUserRuntimeSessions(userId: number): Promise<RuntimeChatSession[]> {
    const persistedSessions = await this.getUserSessions(userId);
    const runtimeSessions = await Promise.all(
      persistedSessions.map(async (session) => {
        const normalized = await this.expireSessionIfNeeded(session);
        return normalized ? this.toRuntimePaidSession(normalized) : null;
      }),
    );

    const sessionsByConversationId = new Map<string, RuntimeChatSession>();
    for (const session of runtimeSessions) {
      if (session)
        sessionsByConversationId.set(session.conversationId, session);
    }

    let cursor = "0";
    do {
      const [nextCursor, keys] = await this.redisService.scan(
        cursor,
        `chat:temp_session:${userId}:*`,
      );
      cursor = nextCursor;

      for (const key of keys) {
        try {
          const session = this.deserializeTempSession(
            await this.redisService.get(key),
          );
          if (
            session?.userId === userId &&
            !sessionsByConversationId.has(session.conversationId)
          ) {
            sessionsByConversationId.set(session.conversationId, session);
          }
        } catch (error) {
          this.logger.warn(
            `[getUserRuntimeSessions] 跳过无效临时会话 ${key}: ${error.message}`,
          );
        }
      }
    } while (cursor !== "0");

    return Array.from(sessionsByConversationId.values());
  }

  async getDoctorSessions(doctorId: number): Promise<ChatSession[]> {
    return this.chatSessionRepository.find({
      where: { doctorId },
      relations: ["order", "order.serviceItem"],
      order: { updatedAt: "DESC" },
    });
  }

  async resetAutoReplyCount(userId: number, doctorId: number): Promise<void> {
    const tempSession = await this.getTempSession(userId, doctorId);

    if (tempSession) {
      await this.persistTempSession({
        ...tempSession,
        autoReplyCount: 0,
        lastAutoReplyAt: undefined,
        paymentRequired: false,
      });
      return;
    }

    const session = await this.getPersistedLatestSessionInternal(
      userId,
      doctorId,
    );
    if (session) {
      session.autoReplyCount = 0;
      session.lastAutoReplyAt = null;
      await this.chatSessionRepository.save(session);
    }
  }

  /**
   * 获取会话列表（管理后台专用）
   * 支持分页和多维度筛选
   */
  async getSessions(options: {
    page?: number;
    limit?: number;
    doctorId?: number;
    userId?: number;
    status?: SessionStatus;
  }): Promise<{
    data: any[];
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  }> {
    const { page = 1, limit = 20, doctorId, userId, status } = options;
    const now = new Date();

    // 构建查询条件
    const whereCondition: any = {};
    if (doctorId) whereCondition.doctorId = doctorId;
    if (userId) whereCondition.userId = userId;

    // 🔑 关键：默认过滤掉免费会话，只显示付费会话（PAID、EXPIRED）
    // 如果明确指定了 status 参数，则按指定的状态查询
    if (status) {
      whereCondition.status = status;
    } else {
      // 未指定 status 时，只返回付费会话（排除 FREE）
      whereCondition.status = In(["PAID", "EXPIRED"]);
    }

    // 查询数据（关联订单、收费项、用户、医生、医院、科室）
    const sessions = await this.chatSessionRepository.find({
      where: whereCondition,
      relations: [
        "order",
        "order.serviceItem",
        "user",
        "doctor",
        "doctor.hospital",
        "doctor.department",
      ],
      order: { updatedAt: "DESC" },
      skip: (page - 1) * limit,
      take: limit,
    });

    // 🔑 关键修复：检查并更新过期的 PAID 会话
    // 这样可以确保查询 status=PAID 时，不会返回已过期的会话
    const filteredSessions: ChatSession[] = [];

    for (const session of sessions) {
      // 如果是 PAID 状态且已过期，更新为 EXPIRED
      if (session.status === SessionStatus.PAID && session.serviceEndAt) {
        if (now > new Date(session.serviceEndAt)) {
          this.logger.log(
            `[getSessions] ⏰ 会话已过期，更新状态: id=${session.id}, conversationId=${session.conversationId}`,
          );
          const result = await this.chatSessionRepository.update(
            {
              id: session.id,
              status: SessionStatus.PAID,
              serviceEndAt: LessThanOrEqual(now),
            },
            { status: SessionStatus.EXPIRED },
          );
          if (result.affected) {
            session.status = SessionStatus.EXPIRED;
          } else {
            filteredSessions.push(session);
          }
        } else {
          // 未过期，保留
          filteredSessions.push(session);
        }
      } else {
        // 非 PAID 状态或没有过期时间，保留
        filteredSessions.push(session);
      }
    }

    // 🔑 关键：使用过滤后的数据重新计算总数（如果查询的是 PAID 状态）
    let total = await this.chatSessionRepository.count({
      where: whereCondition,
    });

    // 如果明确查询 PAID 状态，需要重新计算总数（排除已过期的）
    if (status === SessionStatus.PAID) {
      // 查询所有 PAID 状态的会话（不分页）
      const allPaidSessions = await this.chatSessionRepository.find({
        where: {
          ...whereCondition,
          status: SessionStatus.PAID,
        },
      });

      // 过滤掉已过期的
      const activePaidSessions = allPaidSessions.filter(
        (session) =>
          !session.serviceEndAt || now <= new Date(session.serviceEndAt),
      );

      total = activePaidSessions.length;
    }

    // 为每个会话添加 conversationId 并格式化数据
    const data = filteredSessions.map((session) => {
      // 扁平化数据结构，只返回前端需要的字段
      return {
        id: session.id,
        conversationId: session.conversationId,
        userId: session.userId,
        userName:
          session.user?.username ||
          session.user?.phone ||
          `用户${session.userId}`,
        userAvatar: session.user?.avatar || "",
        doctorId: session.doctorId,
        doctorName: session.doctor?.name || `医生${session.doctorId}`,
        // 医院信息
        hospitalId: session.doctor?.hospitalId,
        hospitalName: session.doctor?.hospital?.name || "",
        // 科室信息
        departmentId: session.doctor?.departmentId,
        departmentName: session.doctor?.department?.name || "",
        // 会话状态
        status: session.status,
        autoReplyCount: session.autoReplyCount,
        maxFreeReplies: session.maxFreeReplies,
        // 套餐信息
        orderId: session.orderId,
        serviceItemId: session.order?.serviceItemId,
        serviceItemName: session.order?.serviceItem?.name || "",
        // 时间信息
        serviceStartAt: session.serviceStartAt,
        serviceEndAt: session.serviceEndAt,
        lastMessageAt: session.lastMessageAt,
        lastAutoReplyAt: session.lastAutoReplyAt,
        createdAt: session.createdAt,
        updatedAt: session.updatedAt,
        // 消息数量（可选，暂时返回0，后续可以统计）
        messageCount: 0,
      };
    });

    return {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * 获取活跃会话（未结束的会话）
   * 查询条件：FREE 或 PAID 且未过期
   *
   * @param userId 用户ID
   * @param doctorId 医生ID
   * @returns 活跃会话，如果不存在则返回 null
   */
  async getActiveSession(
    userId: number,
    doctorId: number,
  ): Promise<ChatSession | null> {
    const now = new Date();
    const session = await this.getPersistedLatestSessionInternal(
      userId,
      doctorId,
    );

    if (!session) {
      return null;
    }

    if (
      session.status === SessionStatus.PAID &&
      (!session.serviceEndAt || now <= new Date(session.serviceEndAt))
    ) {
      return session;
    }

    return null;
  }

  /**
   * 为订单创建或获取会话
   *
   * @param userId 用户ID
   * @param doctorId 医生ID
   * @param status 会话状态
   * @param orderId 订单ID
   * @param serviceStartAt 服务开始时间
   * @param serviceEndAt 服务结束时间
   * @returns 会话对象（包含 conversationId）
   */
  async getLatestSession(
    userId: number,
    doctorId: number,
  ): Promise<ChatSession | null> {
    return this.getPersistedLatestSessionInternal(userId, doctorId);
  }
}
