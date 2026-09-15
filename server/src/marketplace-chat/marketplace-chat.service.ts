import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { randomUUID } from "crypto";
import { InjectRepository } from "@nestjs/typeorm";
import { Brackets, Repository } from "typeorm";

import { MessageType } from "../friends/entities/friend-message.entity";
import { ModerationService } from "../moderation/moderation.service";
import { Product, PublishSource } from "../shop/entities/product.entity";
import { User } from "../users/entities/user.entity";
import {
  OpenMarketplaceConversationDto,
  QueryMarketplaceConversationsDto,
  QueryMarketplaceMessagesDto,
  SendMarketplaceMessageDto,
} from "./dto/marketplace-chat.dto";
import { MarketplaceConversation } from "./entities/marketplace-conversation.entity";
import { MarketplaceMessage } from "./entities/marketplace-message.entity";
import {
  MESSAGE_RECALL_WINDOW_MS,
  MESSAGE_REVOKED_CONTENT,
} from "../common/constants/message-recall.constants";

@Injectable()
export class MarketplaceChatService {
  constructor(
    @InjectRepository(MarketplaceConversation)
    private readonly conversationRepository: Repository<MarketplaceConversation>,
    @InjectRepository(MarketplaceMessage)
    private readonly messageRepository: Repository<MarketplaceMessage>,
    @InjectRepository(Product)
    private readonly productRepository: Repository<Product>,
    private readonly moderationService: ModerationService,
  ) {}

  async openConversation(userId: number, dto: OpenMarketplaceConversationDto) {
    const product = await this.productRepository.findOne({
      where: { id: dto.productId },
      relations: ["publisher"],
    });

    if (
      !product ||
      product.publishSource !== PublishSource.USER ||
      !product.publishedBy
    ) {
      throw new NotFoundException("二手商品不存在");
    }

    if (product.publishedBy === userId) {
      throw new BadRequestException("不能联系自己发布商品的卖家");
    }

    await this.moderationService.assertUsersCanInteract(
      userId,
      product.publishedBy,
    );

    const existing = await this.conversationRepository.findOne({
      where: {
        productId: product.id,
        buyerId: userId,
        sellerId: product.publishedBy,
      },
      relations: ["product", "buyer", "seller"],
    });
    if (existing) {
      return this.getConversation(userId, existing.conversationId);
    }

    if (!product.isActive || Number(product.stock) <= 0 || product.soldAt) {
      throw new BadRequestException("商品已下架或售出，暂时无法联系卖家");
    }

    const conversation = this.conversationRepository.create({
      conversationId: randomUUID(),
      productId: product.id,
      buyerId: userId,
      sellerId: product.publishedBy,
      product,
      seller: product.publisher,
      lastMessageId: null,
      lastMessageType: null,
      lastMessageContent: null,
      lastMessageSenderId: null,
      lastMessageAt: null,
    });

    try {
      const saved = await this.conversationRepository.save(conversation);
      return this.getConversation(userId, saved.conversationId);
    } catch (error) {
      const duplicate = await this.conversationRepository.findOne({
        where: {
          productId: product.id,
          buyerId: userId,
          sellerId: product.publishedBy,
        },
        relations: ["product", "buyer", "seller"],
      });
      if (duplicate) {
        return this.toConversationResponse(duplicate, userId, 0);
      }
      throw error;
    }
  }

  async listConversations(
    userId: number,
    query: QueryMarketplaceConversationsDto,
  ) {
    const page = Math.max(Number(query.page || 1), 1);
    const pageSize = Math.min(Math.max(Number(query.pageSize || 20), 1), 100);

    const queryBuilder = this.conversationRepository
      .createQueryBuilder("conversation")
      .leftJoinAndSelect("conversation.product", "product")
      .leftJoinAndSelect("conversation.buyer", "buyer")
      .leftJoinAndSelect("conversation.seller", "seller")
      .where(
        new Brackets((builder) => {
          builder
            .where("conversation.buyerId = :userId", { userId })
            .orWhere("conversation.sellerId = :userId", { userId });
        }),
      )
      .addSelect(
        "COALESCE(conversation.lastMessageAt, conversation.createdAt)",
        "conversation_sort_at",
      )
      .orderBy("conversation_sort_at", "DESC")
      .skip((page - 1) * pageSize)
      .take(pageSize);

    const [conversations, total] = await queryBuilder.getManyAndCount();
    const unreadCounts = await this.getUnreadCountsByConversation(
      userId,
      conversations,
    );

    return {
      data: conversations.map((conversation) =>
        this.toConversationResponse(
          conversation,
          userId,
          unreadCounts.get(conversation.conversationId) || 0,
        ),
      ),
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  async getConversation(userId: number, conversationId: string) {
    const conversation = await this.findParticipantConversation(
      userId,
      conversationId,
      true,
    );
    const unreadCount = await this.messageRepository.count({
      where: { conversationId, receiverId: userId, isRead: 0 },
    });
    return this.toConversationResponse(conversation, userId, unreadCount);
  }

  async getHistory(
    userId: number,
    conversationId: string,
    query: QueryMarketplaceMessagesDto,
  ) {
    await this.findParticipantConversation(userId, conversationId);
    const page = Math.max(Number(query.page || 1), 1);
    const pageSize = Math.min(Math.max(Number(query.pageSize || 50), 1), 100);
    const [data, total] = await this.messageRepository.findAndCount({
      where: { conversationId },
      order: { createdAt: "DESC" },
      skip: (page - 1) * pageSize,
      take: pageSize,
    });

    return {
      data: data.map((message) => this.toClientMessage(message)),
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  async sendMessage(senderId: number, dto: SendMarketplaceMessageDto) {
    const conversation = await this.findParticipantConversation(
      senderId,
      dto.conversationId,
    );
    const receiverId =
      conversation.buyerId === senderId
        ? conversation.sellerId
        : conversation.buyerId;

    await this.moderationService.assertUsersCanInteract(senderId, receiverId);

    const { normalizedContent, cloudFileUrl } = this.normalizeContent(
      dto.messageType,
      dto.content,
    );
    const message = this.messageRepository.create({
      messageId: randomUUID(),
      conversationId: conversation.conversationId,
      senderId,
      receiverId,
      messageType: dto.messageType,
      content: normalizedContent,
      cloudFileUrl,
      isRead: 0,
    });
    const saved = await this.messageRepository.save(message);

    await this.conversationRepository.update(conversation.id, {
      lastMessageId: saved.messageId,
      lastMessageType: saved.messageType,
      lastMessageContent: saved.content,
      lastMessageSenderId: senderId,
      lastMessageAt: saved.createdAt,
    });

    return saved;
  }

  /** 撤回本人在两分钟内发送的商城聊天消息。 */
  async revokeMessage(messageId: string, senderId: number) {
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
    const saved = await this.messageRepository.save(message);

    const conversation = await this.conversationRepository.findOne({
      where: { conversationId: message.conversationId },
    });
    if (conversation?.lastMessageId === message.messageId) {
      await this.conversationRepository.update(conversation.id, {
        lastMessageType: MessageType.TEXT,
        lastMessageContent: MESSAGE_REVOKED_CONTENT,
      });
    }

    return this.toClientMessage(saved);
  }

  async markMessageAsRead(
    messageId: string,
    conversationId: string,
    receiverId: number,
  ) {
    const message = await this.messageRepository.findOne({
      where: { messageId, conversationId },
    });
    if (!message) {
      throw new NotFoundException("消息不存在");
    }
    if (message.receiverId !== receiverId) {
      throw new ForbiddenException("无权操作此消息");
    }
    if (message.isRead === 1) {
      return { message, changed: false };
    }
    message.isRead = 1;
    return {
      message: await this.messageRepository.save(message),
      changed: true,
    };
  }

  async markConversationAsRead(userId: number, conversationId: string) {
    await this.findParticipantConversation(userId, conversationId);
    const result = await this.messageRepository
      .createQueryBuilder()
      .update(MarketplaceMessage)
      .set({ isRead: 1 })
      .where("conversationId = :conversationId", { conversationId })
      .andWhere("receiverId = :userId", { userId })
      .andWhere("isRead = 0")
      .execute();
    return result.affected || 0;
  }

  async getUnreadCount(userId: number) {
    return this.messageRepository.count({
      where: { receiverId: userId, isRead: 0 },
    });
  }

  async resolveCounterpart(userId: number, conversationId: string) {
    const conversation = await this.findParticipantConversation(
      userId,
      conversationId,
    );
    return conversation.buyerId === userId
      ? conversation.sellerId
      : conversation.buyerId;
  }

  private async findParticipantConversation(
    userId: number,
    conversationId: string,
    withRelations = false,
  ) {
    const conversation = await this.conversationRepository.findOne({
      where: { conversationId },
      relations: withRelations ? ["product", "buyer", "seller"] : undefined,
    });
    if (!conversation) {
      throw new NotFoundException("商城会话不存在");
    }
    if (conversation.buyerId !== userId && conversation.sellerId !== userId) {
      throw new ForbiddenException("无权访问此商城会话");
    }
    return conversation;
  }

  private normalizeContent(messageType: MessageType, content: string) {
    if (messageType === MessageType.TEXT) {
      const text = content.trim();
      if (!text) {
        throw new BadRequestException("消息内容不能为空");
      }
      if (text.length > 500) {
        throw new BadRequestException("文字消息最多500字符");
      }
      return { normalizedContent: text, cloudFileUrl: null };
    }

    let payload: Record<string, unknown>;
    try {
      const parsed = JSON.parse(content) as unknown;
      payload =
        parsed && typeof parsed === "object" && !Array.isArray(parsed)
          ? (parsed as Record<string, unknown>)
          : { url: content.trim() };
    } catch {
      payload = { url: content.trim() };
    }

    const url = typeof payload.url === "string" ? payload.url.trim() : "";
    if (!url) {
      throw new BadRequestException("媒体消息内容格式错误");
    }

    const normalized: Record<string, unknown> = { url };
    for (const key of ["width", "height", "duration", "size"]) {
      const value = Number(payload[key]);
      if (Number.isFinite(value) && value >= 0) {
        normalized[key] = value;
      }
    }
    for (const key of ["thumbnail", "fileName", "mimeType", "mime"]) {
      if (typeof payload[key] === "string" && String(payload[key]).trim()) {
        normalized[key === "mime" ? "mimeType" : key] = String(
          payload[key],
        ).trim();
      }
    }
    return { normalizedContent: JSON.stringify(normalized), cloudFileUrl: url };
  }

  private async getUnreadCountsByConversation(
    userId: number,
    conversations: MarketplaceConversation[],
  ) {
    const ids = conversations.map((item) => item.conversationId);
    const result = new Map<string, number>();
    if (ids.length === 0) {
      return result;
    }
    const rows = await this.messageRepository
      .createQueryBuilder("message")
      .select("message.conversationId", "conversationId")
      .addSelect("COUNT(*)", "count")
      .where("message.receiverId = :userId", { userId })
      .andWhere("message.isRead = 0")
      .andWhere("message.conversationId IN (:...ids)", { ids })
      .groupBy("message.conversationId")
      .getRawMany<{ conversationId: string; count: string }>();
    rows.forEach((row) => result.set(row.conversationId, Number(row.count)));
    return result;
  }

  private toConversationResponse(
    conversation: MarketplaceConversation,
    currentUserId: number,
    unreadCount: number,
  ) {
    const peer =
      conversation.buyerId === currentUserId
        ? conversation.seller
        : conversation.buyer;
    return {
      id: conversation.id,
      conversationId: conversation.conversationId,
      productId: conversation.productId,
      buyerId: conversation.buyerId,
      sellerId: conversation.sellerId,
      role: conversation.buyerId === currentUserId ? "buyer" : "seller",
      peer: this.toUserResponse(
        peer,
        conversation.buyerId === currentUserId
          ? conversation.sellerId
          : conversation.buyerId,
      ),
      product: this.toProductResponse(
        conversation.product,
        conversation.productId,
      ),
      lastMessage: conversation.lastMessageId
        ? {
            messageId: conversation.lastMessageId,
            messageType: conversation.lastMessageType,
            content: conversation.lastMessageContent,
            senderId: conversation.lastMessageSenderId,
            createdAt: conversation.lastMessageAt,
          }
        : null,
      unreadCount,
      createdAt: conversation.createdAt,
      updatedAt: conversation.updatedAt,
    };
  }

  private toClientMessage(message: MarketplaceMessage): MarketplaceMessage {
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

  private toUserResponse(user: User | undefined, fallbackId: number) {
    return {
      id: user?.id ?? fallbackId,
      nickname: user?.username || user?.phone || `用户${fallbackId}`,
      username: user?.username ?? null,
      avatar: user?.avatar ?? null,
    };
  }

  private toProductResponse(product: Product | undefined, fallbackId: number) {
    return {
      id: product?.id ?? fallbackId,
      name: product?.name || "商品已不可见",
      image: product?.image || product?.images?.[0] || null,
      price: product ? Number(product.price) : null,
      isActive: Boolean(product?.isActive),
      isSold: Boolean(
        product?.soldAt || (product && Number(product.stock) <= 0),
      ),
    };
  }
}
