import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  Inject,
  forwardRef,
} from "@nestjs/common";
import { randomUUID } from "crypto";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { FriendMessage, MessageType } from "../entities/friend-message.entity";
import {
  SendMessageDto,
  QueryMessagesDto,
  AdminQueryMessagesDto,
} from "../dto/message.dto";
import { PaginatedResult } from "../../common/dto/pagination.dto";
import { FriendsService } from "./friends.service";
import { RedisService } from "../../redis/redis.service";
import { UsersService } from "../../users/users.service";
import { User } from "../../users/entities/user.entity";
import { FriendChatBlocksService } from "./friend-chat-blocks.service";
import {
  MESSAGE_RECALL_WINDOW_MS,
  MESSAGE_REVOKED_CONTENT,
} from "../../common/constants/message-recall.constants";

/**
 * 好友消息管理服务
 *
 * 功能：
 * - 发送消息（保存到 MySQL）
 * - 查询历史消息
 * - 标记消息已读
 * - 获取未读消息数
 * - Admin 查询所有消息
 * - 管理离线消息队列（Redis）
 */
@Injectable()
export class FriendMessagesService {
  constructor(
    @InjectRepository(FriendMessage)
    private messageRepository: Repository<FriendMessage>,
    @Inject(forwardRef(() => FriendsService))
    private friendsService: FriendsService,
    private redisService: RedisService,
    private usersService: UsersService,
    private readonly friendChatBlocksService: FriendChatBlocksService,
  ) {}

  /**
   * 规范化媒体消息内容
   * 业务规则：兼容旧版客户端直接发送 URL 字符串，同时统一把图片/语音消息落库为 JSON，避免多端协议分叉。
   */
  private normalizeMediaContent(
    messageType: MessageType,
    content: string,
  ): { normalizedContent: string; cloudFileUrl: string | null } {
    if (messageType === MessageType.TEXT) {
      return {
        normalizedContent: content,
        cloudFileUrl: null,
      };
    }

    const trimmedContent = content.trim();
    if (!trimmedContent) {
      throw new BadRequestException("图片/语音消息内容不能为空");
    }

    const normalizePayload = (payload: Record<string, unknown>) => {
      const mediaUrl =
        typeof payload.url === "string" ? payload.url.trim() : "";
      if (!mediaUrl) {
        throw new BadRequestException("媒体消息内容格式错误");
      }

      const normalizedPayload: Record<string, unknown> = { url: mediaUrl };

      if (messageType === MessageType.IMAGE) {
        const width = Number(payload.width);
        const height = Number(payload.height);

        if (Number.isFinite(width) && width > 0) {
          normalizedPayload.width = width;
        }

        if (Number.isFinite(height) && height > 0) {
          normalizedPayload.height = height;
        }
      }

      if (messageType === MessageType.VOICE) {
        const duration = Number(payload.duration);
        normalizedPayload.duration =
          Number.isFinite(duration) && duration > 0 ? duration : 0;
      }

      if (messageType === MessageType.VIDEO) {
        const thumbnail =
          typeof payload.thumbnail === "string" ? payload.thumbnail.trim() : "";
        const width = Number(payload.width);
        const height = Number(payload.height);
        const duration = Number(payload.duration);
        const size = Number(payload.size);
        const fileName =
          typeof payload.fileName === "string" ? payload.fileName.trim() : "";
        const mimeType =
          typeof payload.mimeType === "string"
            ? payload.mimeType.trim()
            : typeof payload.mime === "string"
              ? payload.mime.trim()
              : "";

        if (thumbnail) {
          normalizedPayload.thumbnail = thumbnail;
        }

        if (Number.isFinite(width) && width > 0) {
          normalizedPayload.width = width;
        }

        if (Number.isFinite(height) && height > 0) {
          normalizedPayload.height = height;
        }

        if (Number.isFinite(duration) && duration > 0) {
          normalizedPayload.duration = Math.round(duration);
        }

        if (Number.isFinite(size) && size > 0) {
          normalizedPayload.size = Math.round(size);
        }

        if (fileName) {
          normalizedPayload.fileName = fileName;
        }

        if (mimeType) {
          normalizedPayload.mimeType = mimeType;
        }
      }

      return {
        normalizedContent: JSON.stringify(normalizedPayload),
        cloudFileUrl: mediaUrl,
      };
    };

    try {
      const parsed = JSON.parse(trimmedContent);
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
        return normalizePayload(parsed as Record<string, unknown>);
      }
    } catch {
      // 兼容旧版客户端直接发送 URL 字符串
    }

    return normalizePayload({
      url: trimmedContent,
      ...(messageType === MessageType.VOICE ? { duration: 0 } : {}),
    });
  }

  /**
   * 生成会话ID
   * 格式：小ID_大ID（如 123_456）
   *
   * @param userId1 用户1 ID
   * @param userId2 用户2 ID
   * @returns 会话ID
   */
  private generateConversationId(userId1: number, userId2: number): string {
    const minId = Math.min(userId1, userId2);
    const maxId = Math.max(userId1, userId2);
    return `${minId}_${maxId}`;
  }

  /**
   * 发送消息（保存到 MySQL）
   *
   * @param senderId 发送人ID
   * @param dto 消息信息
   * @returns 创建的消息
   */
  async sendMessage(
    senderId: number,
    dto: SendMessageDto,
  ): Promise<FriendMessage> {
    const { receiverId, messageType, content } = dto;

    // 验证不能给自己发送消息
    if (senderId === receiverId) {
      throw new BadRequestException("不能给自己发送消息");
    }

    // 验证好友关系
    const isFriend = await this.friendsService.isFriend(senderId, receiverId);
    if (!isFriend) {
      throw new BadRequestException("只能给好友发送消息");
    }

    await this.friendChatBlocksService.assertUsersCanChat(senderId, receiverId);

    // 验证消息内容长度
    if (messageType === MessageType.TEXT && content.length > 500) {
      throw new BadRequestException("文字消息最多500字符");
    }

    // 生成消息ID和会话ID
    const messageId = randomUUID();
    const conversationId = this.generateConversationId(senderId, receiverId);

    const { normalizedContent, cloudFileUrl } = this.normalizeMediaContent(
      messageType,
      content,
    );

    // 创建消息记录
    const message = this.messageRepository.create({
      messageId,
      conversationId,
      senderId,
      receiverId,
      messageType,
      content: normalizedContent,
      cloudFileUrl,
      isRead: 0,
    });

    const savedMessage = await this.messageRepository.save(message);

    // 更新好友关系的最后聊天时间
    await this.friendsService.updateLastChatTime(senderId, receiverId);

    return savedMessage;
  }

  /** 撤回本人在两分钟内发送的普通好友消息。 */
  async revokeMessage(
    messageId: string,
    senderId: number,
  ): Promise<FriendMessage> {
    const message = await this.messageRepository.findOne({
      where: { messageId },
    });
    if (!message) {
      throw new NotFoundException("消息不存在");
    }
    if (message.senderId !== senderId) {
      throw new ForbiddenException("只能撤回自己发送的消息");
    }
    if (message.isRevoked === 1) {
      throw new BadRequestException("消息已撤回");
    }
    const createdAt = new Date(message.createdAt).getTime();
    if (
      !Number.isFinite(createdAt) ||
      Date.now() - createdAt > MESSAGE_RECALL_WINDOW_MS
    ) {
      throw new BadRequestException("消息发送超过2分钟，无法撤回");
    }

    message.isRevoked = 1;
    message.revokedAt = new Date();
    message.isRead = 1;
    return this.toClientMessage(await this.messageRepository.save(message));
  }

  /**
   * 标记消息已读
   *
   * @param messageId 消息ID
   * @param receiverId 接收人ID（验证权限）
   * @returns 已更新的消息实体和是否首次变更
   */
  async markMessageAsRead(
    messageId: string,
    receiverId: number,
  ): Promise<{ message: FriendMessage; changed: boolean }> {
    // 查询消息
    const message = await this.messageRepository.findOne({
      where: { messageId },
    });

    if (!message) {
      throw new NotFoundException("消息不存在");
    }

    // 验证权限（只有接收人可以标记已读）
    if (message.receiverId !== receiverId) {
      throw new BadRequestException("无权操作此消息");
    }

    if (message.isRead === 1) {
      return {
        message,
        changed: false,
      };
    }

    // 更新已读状态
    message.isRead = 1;
    const savedMessage = await this.messageRepository.save(message);

    return {
      message: savedMessage,
      changed: true,
    };
  }

  /**
   * 批量标记会话消息已读
   *
   * @param conversationId 会话ID
   * @param receiverId 接收人ID
   */
  async markConversationAsRead(
    conversationId: string,
    receiverId: number,
  ): Promise<void> {
    await this.messageRepository
      .createQueryBuilder()
      .update(FriendMessage)
      .set({ isRead: 1 })
      .where("conversationId = :conversationId", { conversationId })
      .andWhere("receiverId = :receiverId", { receiverId })
      .andWhere("isRead = :isRead", { isRead: 0 })
      .execute();
  }

  /**
   * 获取历史消息（分页）
   *
   * @param userId 用户ID
   * @param friendId 好友ID
   * @param query 查询参数
   * @returns 分页后的消息列表
   */
  async getHistoryMessages(
    userId: number,
    friendId: number,
    query: QueryMessagesDto,
  ): Promise<PaginatedResult<FriendMessage>> {
    const { page = 1, pageSize = 50 } = query;

    // 生成会话ID
    const conversationId = this.generateConversationId(userId, friendId);

    // 构建查询
    const queryBuilder = this.messageRepository
      .createQueryBuilder("message")
      .where("message.conversationId = :conversationId", { conversationId })
      .orderBy("message.createdAt", "DESC");

    // 分页
    const skip = (page - 1) * pageSize;
    queryBuilder.skip(skip).take(pageSize);

    // 执行查询
    const [messages, total] = await queryBuilder.getManyAndCount();

    return {
      totalPages: Math.ceil(total / pageSize),
      data: messages.map((message) => this.toClientMessage(message)),
      total,
      page,
      pageSize,
    };
  }

  /**
   * 获取未读消息数
   *
   * @param userId 用户ID
   * @param friendId 好友ID（可选，不传则返回所有好友的未读数）
   * @returns 未读消息数
   */
  async getUnreadCount(userId: number, friendId?: number): Promise<number> {
    const queryBuilder = this.messageRepository
      .createQueryBuilder("message")
      .where("message.receiverId = :userId", { userId })
      .andWhere("message.isRead = :isRead", { isRead: 0 });

    if (friendId) {
      queryBuilder.andWhere("message.senderId = :friendId", { friendId });
    }

    return queryBuilder.getCount();
  }

  /**
   * Admin 查询所有消息（分页）
   *
   * @param query 查询参数
   * @returns 分页后的消息列表
   */
  async adminGetMessages(
    query: AdminQueryMessagesDto,
  ): Promise<PaginatedResult<FriendMessage>> {
    const {
      page = 1,
      pageSize = 20,
      conversationId,
      senderId,
      receiverId,
      messageType,
      startTime,
      endTime,
    } = query;

    // 构建查询
    const queryBuilder = this.messageRepository.createQueryBuilder("message");

    // 筛选条件
    if (conversationId) {
      queryBuilder.andWhere("message.conversationId = :conversationId", {
        conversationId,
      });
    }

    if (senderId) {
      queryBuilder.andWhere("message.senderId = :senderId", { senderId });
    }

    if (receiverId) {
      queryBuilder.andWhere("message.receiverId = :receiverId", { receiverId });
    }

    if (messageType) {
      queryBuilder.andWhere("message.messageType = :messageType", {
        messageType,
      });
    }

    if (startTime) {
      queryBuilder.andWhere("message.createdAt >= :startTime", { startTime });
    }

    if (endTime) {
      queryBuilder.andWhere("message.createdAt <= :endTime", { endTime });
    }

    // 排序
    queryBuilder.orderBy("message.createdAt", "DESC");

    // 分页
    const skip = (page - 1) * pageSize;
    queryBuilder.skip(skip).take(pageSize);

    // 关联用户信息（用于后台展示昵称）
    queryBuilder
      .leftJoinAndMapOne(
        "message.sender",
        User,
        "sender",
        "sender.id = message.senderId",
      )
      .leftJoinAndMapOne(
        "message.receiver",
        User,
        "receiver",
        "receiver.id = message.receiverId",
      );

    // 执行查询
    const [messages, total] = await queryBuilder.getManyAndCount();

    const data = messages.map((message: any) => ({
      id: message.id,
      messageId: message.messageId,
      conversationId: message.conversationId,
      senderId: message.senderId,
      receiverId: message.receiverId,
      messageType: message.messageType,
      content: message.content,
      cloudFileUrl: message.cloudFileUrl,
      isRead: message.isRead,
      isRevoked: message.isRevoked,
      revokedAt: message.revokedAt,
      createdAt: message.createdAt,
      updatedAt: message.updatedAt,
      senderName: message.sender?.username,
      receiverName: message.receiver?.username,
    }));

    return {
      totalPages: Math.ceil(total / pageSize),
      data,
      total,
      page,
      pageSize,
    };
  }

  /**
   * 获取会话所有消息（Admin 使用）
   *
   * @param conversationId 会话ID
   * @returns 消息列表
   */
  async getConversationMessages(
    conversationId: string,
  ): Promise<FriendMessage[]> {
    return this.messageRepository.find({
      where: { conversationId },
      order: { createdAt: "ASC" },
    });
  }

  /** 普通客户端不应再拿到已撤回消息的原文或媒体地址。 */
  private toClientMessage(message: FriendMessage): FriendMessage {
    if (message.isRevoked !== 1) {
      return message;
    }
    return {
      ...message,
      messageType: MessageType.TEXT,
      content: MESSAGE_REVOKED_CONTENT,
      cloudFileUrl: null,
    };
  }

  /**
   * 获取消息统计（按类型）
   *
   * @returns 消息统计
   */
  async getMessageStatistics(): Promise<any> {
    const result = await this.messageRepository
      .createQueryBuilder("message")
      .select("message.messageType", "messageType")
      .addSelect("COUNT(*)", "count")
      .groupBy("message.messageType")
      .getRawMany();

    const stats = {
      total: 0,
      text: 0,
      image: 0,
      voice: 0,
    };

    result.forEach((item) => {
      const count = parseInt(item.count, 10);
      stats.total += count;
      stats[item.messageType] = count;
    });

    return stats;
  }

  /**
   * 获取今日消息数
   *
   * @returns 今日消息数
   */
  async getTodayMessagesCount(): Promise<number> {
    return this.messageRepository
      .createQueryBuilder("message")
      .where("DATE(message.createdAt) = CURDATE()")
      .getCount();
  }

  /**
   * 获取7天内活跃用户数
   *
   * @returns 活跃用户数
   */
  async getActiveUsersCount(): Promise<number> {
    const result = await this.messageRepository.query(`
      SELECT COUNT(DISTINCT t.userId) AS count
      FROM (
        SELECT senderId AS userId
        FROM friend_messages
        WHERE createdAt >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        UNION
        SELECT receiverId AS userId
        FROM friend_messages
        WHERE createdAt >= DATE_SUB(NOW(), INTERVAL 7 DAY)
      ) t
    `);

    return parseInt(result?.[0]?.count || "0", 10);
  }

  /**
   * 获取近30天活跃用户增长趋势
   * 返回每天的活跃用户数（发送或接收过消息的用户）
   *
   * @returns 活跃用户增长数据
   */
  async getActiveUserGrowth(): Promise<Array<{ date: string; count: number }>> {
    const results = await this.messageRepository.query(`
      SELECT t.date, COUNT(DISTINCT t.userId) AS count
      FROM (
        SELECT DATE(createdAt) AS date, senderId AS userId
        FROM friend_messages
        WHERE createdAt >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        UNION
        SELECT DATE(createdAt) AS date, receiverId AS userId
        FROM friend_messages
        WHERE createdAt >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
      ) t
      GROUP BY t.date
      ORDER BY t.date ASC
    `);

    return results.map((row) => ({
      date: row.date,
      count: parseInt(row.count || "0", 10),
    }));
  }

  /**
   * 获取离线消息队列状态（从 Redis）
   * 扫描所有用户的离线消息队列，统计消息数量
   *
   * @returns 离线队列状态
   */
  async getOfflineQueueStatus(): Promise<{
    totalUsers: number;
    totalMessages: number;
    queueDetails: Array<{
      userId: number;
      userName?: string;
      messageCount: number;
      oldestMessageTime?: string;
      newestMessageTime?: string;
    }>;
  }> {
    const pattern = "friends:offline:[0-9]*";
    let cursor = "0";
    let totalMessages = 0;
    const queueDetails: Array<{
      userId: number;
      userName?: string;
      messageCount: number;
      oldestMessageTime?: string;
      newestMessageTime?: string;
    }> = [];

    do {
      const [nextCursor, keys] = await this.redisService.scan(
        cursor,
        pattern,
        200,
      );
      cursor = nextCursor;

      for (const hashKey of keys) {
        const userId = parseInt(hashKey.replace("friends:offline:", ""), 10);
        if (!Number.isFinite(userId)) {
          continue;
        }

        const timelineKey = `friends:offline:timeline:${userId}`;
        const messageCount = await this.redisService.zcard(timelineKey);
        if (messageCount <= 0) {
          continue;
        }

        totalMessages += messageCount;

        let userName: string | undefined;
        try {
          const user = await this.usersService.findOne(userId);
          userName = user?.username;
        } catch {
          userName = undefined;
        }

        queueDetails.push({
          userId,
          userName,
          messageCount,
        });
      }
    } while (cursor !== "0");

    queueDetails.sort((a, b) => b.messageCount - a.messageCount);

    return {
      totalUsers: queueDetails.length,
      totalMessages,
      queueDetails,
    };
  }

  /**
   * 清空指定用户的离线消息队列（从 Redis）
   *
   * @param userId 用户ID
   * @returns 清空的消息数量
   */
  async clearUserOfflineQueue(userId: number): Promise<number> {
    const hashKey = `friends:offline:${userId}`;
    const timelineKey = `friends:offline:timeline:${userId}`;

    // 获取消息数量
    const count = await this.redisService.zcard(timelineKey);

    // 删除 Hash 和 Sorted Set
    await this.redisService.del(hashKey);
    await this.redisService.del(timelineKey);

    return count;
  }
}
