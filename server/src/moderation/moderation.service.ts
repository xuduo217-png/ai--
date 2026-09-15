import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { In, Repository } from "typeorm";

import { Comment } from "../community/entities/comment.entity";
import { Post } from "../community/entities/post.entity";
import { ActivityComment } from "../activities/entities/activity-comment.entity";
import { ActivityVoteOption } from "../activities/entities/activity-vote-option.entity";
import { FriendMessage } from "../friends/entities/friend-message.entity";
import { MarketplaceConversation } from "../marketplace-chat/entities/marketplace-conversation.entity";
import { MarketplaceMessage } from "../marketplace-chat/entities/marketplace-message.entity";
import { LostFound } from "../lost-found/entities/lost-found.entity";
import { LostFoundComment } from "../lost-found/entities/lost-found-comment.entity";
import { Product } from "../shop/entities/product.entity";
import { PendingProductStatus } from "../shop/entities/product-pending.entity";
import { User } from "../users/entities/user.entity";
import { BlockUserDto } from "./dto/block-user.dto";
import { CreateReportDto } from "./dto/create-report.dto";
import {
  HandleReportActionDto,
  UpdateReportStatusDto,
} from "./dto/handle-report.dto";
import { QueryReportsDto } from "./dto/query-reports.dto";
import {
  ReportAction,
  ReportStatus,
  ReportTargetSnapshot,
  ReportTargetType,
  UGCReport,
} from "./entities/ugc-report.entity";
import { UserBlock } from "./entities/user-block.entity";

interface ResolvedReportTarget {
  targetUserId?: number | null;
  snapshot: ReportTargetSnapshot;
}

export interface CommunityBlockListItem {
  id: number;
  blockerId: number;
  blockedUserId: number;
  reason?: string | null;
  blockedAt: Date;
  createdAt: Date;
  blockedUser: {
    id: number;
    username?: string | null;
    nickname: string;
    avatar?: string | null;
  };
}

@Injectable()
export class ModerationService {
  private readonly OPEN_REPORT_STATUSES = [
    ReportStatus.PENDING,
    ReportStatus.PROCESSING,
  ];

  constructor(
    @InjectRepository(UGCReport)
    private readonly reportRepository: Repository<UGCReport>,
    @InjectRepository(UserBlock)
    private readonly blockRepository: Repository<UserBlock>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Post)
    private readonly postRepository: Repository<Post>,
    @InjectRepository(Comment)
    private readonly commentRepository: Repository<Comment>,
    @InjectRepository(LostFound)
    private readonly lostFoundRepository: Repository<LostFound>,
    @InjectRepository(LostFoundComment)
    private readonly lostFoundCommentRepository: Repository<LostFoundComment>,
    @InjectRepository(ActivityComment)
    private readonly activityCommentRepository: Repository<ActivityComment>,
    @InjectRepository(ActivityVoteOption)
    private readonly activityVoteOptionRepository: Repository<ActivityVoteOption>,
    @InjectRepository(Product)
    private readonly productRepository: Repository<Product>,
    @InjectRepository(FriendMessage)
    private readonly friendMessageRepository: Repository<FriendMessage>,
    @InjectRepository(MarketplaceMessage)
    private readonly marketplaceMessageRepository: Repository<MarketplaceMessage>,
    @InjectRepository(MarketplaceConversation)
    private readonly marketplaceConversationRepository: Repository<MarketplaceConversation>,
  ) {}

  async createReport(
    reporterId: number,
    dto: CreateReportDto,
  ): Promise<UGCReport> {
    const targetId = String(dto.targetId);
    const target = await this.resolveReportTarget(dto.targetType, targetId);

    if (target.targetUserId === reporterId) {
      throw new BadRequestException("不能举报自己的内容");
    }

    const existingReport = await this.reportRepository.findOne({
      where: {
        reporterId,
        targetType: dto.targetType,
        targetId,
        status: In(this.OPEN_REPORT_STATUSES),
      },
    });

    if (existingReport) {
      return existingReport;
    }

    const report = this.reportRepository.create({
      reporterId,
      targetType: dto.targetType,
      targetId,
      targetUserId: target.targetUserId ?? null,
      reason: dto.reason,
      description: dto.description?.trim() || null,
      targetSnapshot: target.snapshot,
      status: ReportStatus.PENDING,
      action: ReportAction.NONE,
    });

    return this.reportRepository.save(report);
  }

  async blockUser(blockerId: number, dto: BlockUserDto): Promise<UserBlock> {
    if (blockerId === dto.blockedUserId) {
      throw new BadRequestException("不能屏蔽自己");
    }

    const blockedUser = await this.userRepository.findOne({
      where: { id: dto.blockedUserId },
      select: ["id"],
    });

    if (!blockedUser) {
      throw new NotFoundException("用户不存在");
    }

    const existingBlock = await this.blockRepository.findOne({
      where: {
        blockerId,
        blockedUserId: dto.blockedUserId,
      },
    });

    if (existingBlock) {
      return existingBlock;
    }

    const block = this.blockRepository.create({
      blockerId,
      blockedUserId: dto.blockedUserId,
      reason: dto.reason?.trim() || null,
    });

    return this.blockRepository.save(block);
  }

  async unblockUser(blockerId: number, blockedUserId: number): Promise<void> {
    await this.blockRepository.delete({ blockerId, blockedUserId });
  }

  async getBlocks(blockerId: number): Promise<CommunityBlockListItem[]> {
    const blocks = await this.blockRepository.find({
      where: { blockerId },
      relations: ["blockedUser"],
      order: { createdAt: "DESC" },
    });

    return blocks.map((block) => {
      const blockedUser = block.blockedUser;
      return {
        id: block.id,
        blockerId: block.blockerId,
        blockedUserId: block.blockedUserId,
        reason: block.reason,
        blockedAt: block.createdAt,
        createdAt: block.createdAt,
        blockedUser: {
          id: blockedUser?.id ?? block.blockedUserId,
          username: blockedUser?.username ?? null,
          nickname: blockedUser
            ? this.resolveUserNickname(blockedUser)
            : `用户${block.blockedUserId}`,
          avatar: blockedUser?.avatar ?? null,
        },
      };
    });
  }

  async getBlockedUserIds(blockerId?: number): Promise<number[]> {
    if (!blockerId) {
      return [];
    }

    const blocks = await this.blockRepository.find({
      where: { blockerId },
      select: ["blockedUserId"],
    });

    return blocks.map((block) => block.blockedUserId);
  }

  async assertUsersCanInteract(userId: number, targetUserId: number) {
    const blockCount = await this.blockRepository.count({
      where: [
        { blockerId: userId, blockedUserId: targetUserId },
        { blockerId: targetUserId, blockedUserId: userId },
      ],
    });

    if (blockCount > 0) {
      throw new ForbiddenException("你们已存在屏蔽关系，无法继续互动");
    }
  }

  async findReports(query: QueryReportsDto) {
    const page = Math.max(Number(query.page || 1), 1);
    const pageSize = Math.min(Math.max(Number(query.pageSize || 20), 1), 100);

    const queryBuilder = this.reportRepository
      .createQueryBuilder("report")
      .leftJoinAndSelect("report.reporter", "reporter")
      .leftJoinAndSelect("report.targetUser", "targetUser")
      .leftJoinAndSelect("report.handler", "handler");

    if (query.status) {
      queryBuilder.andWhere("report.status = :status", {
        status: query.status,
      });
    }

    if (query.targetType) {
      queryBuilder.andWhere("report.targetType = :targetType", {
        targetType: query.targetType,
      });
    }

    if (query.reason) {
      queryBuilder.andWhere("report.reason = :reason", {
        reason: query.reason,
      });
    }

    if (query.startTime) {
      queryBuilder.andWhere("report.createdAt >= :startTime", {
        startTime: query.startTime,
      });
    }

    if (query.endTime) {
      queryBuilder.andWhere("report.createdAt <= :endTime", {
        endTime: query.endTime,
      });
    }

    queryBuilder
      .orderBy("report.createdAt", "DESC")
      .skip((page - 1) * pageSize)
      .take(pageSize);

    const [data, total] = await queryBuilder.getManyAndCount();

    return {
      data: data.map((report) => this.toAdminReportResponse(report)),
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  async findReportDetail(id: number) {
    const report = await this.reportRepository.findOne({
      where: { id },
      relations: ["reporter", "targetUser", "handler"],
    });

    if (!report) {
      throw new NotFoundException("举报记录不存在");
    }

    return this.toAdminReportResponse(report);
  }

  async updateReportStatus(
    id: number,
    adminId: number,
    dto: UpdateReportStatusDto,
  ) {
    const report = await this.findReportEntity(id);
    report.status = dto.status;
    report.handledBy = adminId;
    report.handledAt = new Date();
    report.handlingRemark = dto.remark?.trim() || report.handlingRemark || null;

    return this.reportRepository.save(report);
  }

  async handleReportAction(
    id: number,
    adminId: number,
    dto: HandleReportActionDto,
  ) {
    const report = await this.findReportEntity(id);

    await this.executeReportAction(report, dto.action);

    report.action = dto.action;
    report.status =
      dto.action === ReportAction.NONE
        ? ReportStatus.REJECTED
        : ReportStatus.RESOLVED;
    report.handledBy = adminId;
    report.handledAt = new Date();
    report.handlingRemark = dto.remark?.trim() || null;

    return this.reportRepository.save(report);
  }

  private async findReportEntity(id: number): Promise<UGCReport> {
    const report = await this.reportRepository.findOne({ where: { id } });
    if (!report) {
      throw new NotFoundException("举报记录不存在");
    }

    return report;
  }

  private async executeReportAction(
    report: UGCReport,
    action: ReportAction,
  ): Promise<void> {
    if (action === ReportAction.CONTENT_REMOVED) {
      await this.removeTargetContent(report);
      return;
    }

    if (action === ReportAction.USER_BLOCKED) {
      if (!report.targetUserId) {
        throw new BadRequestException("该举报没有可屏蔽的目标用户");
      }
      await this.blockUser(report.reporterId, {
        blockedUserId: report.targetUserId,
        reason: "举报处理",
      });
      return;
    }

    if (action === ReportAction.ACCOUNT_DISABLED) {
      if (!report.targetUserId) {
        throw new BadRequestException("该举报没有可禁用的目标用户");
      }
      await this.userRepository.update(report.targetUserId, {
        isActive: false,
      });
    }
  }

  private async removeTargetContent(report: UGCReport): Promise<void> {
    const numericId = () =>
      this.parsePositiveNumber(report.targetId, "举报目标ID");

    switch (report.targetType) {
      case ReportTargetType.COMMUNITY_POST:
        await this.postRepository.softDelete(numericId());
        return;
      case ReportTargetType.COMMUNITY_COMMENT:
        await this.commentRepository.softDelete(numericId());
        return;
      case ReportTargetType.LOST_FOUND_RECORD:
        await this.lostFoundRepository.softDelete(numericId());
        return;
      case ReportTargetType.LOST_FOUND_COMMENT:
        await this.lostFoundCommentRepository.softDelete(numericId());
        return;
      case ReportTargetType.ACTIVITY_COMMENT:
        await this.activityCommentRepository.softDelete(numericId());
        return;
      case ReportTargetType.ACTIVITY_VOTE_OPTION:
        await this.activityVoteOptionRepository.softDelete(numericId());
        return;
      case ReportTargetType.SECOND_HAND_PRODUCT:
        await this.productRepository.update(numericId(), { isActive: false });
        await this.productRepository.query(
          "UPDATE products_pending SET status = ? WHERE productId = ?",
          [PendingProductStatus.OFF_SHELF, numericId()],
        );
        return;
      case ReportTargetType.CHAT_MESSAGE:
        await this.hideFriendMessage(report.targetId);
        return;
      case ReportTargetType.MARKETPLACE_MESSAGE:
        await this.hideMarketplaceMessage(report.targetId);
        return;
      default:
        throw new BadRequestException("该目标类型不支持移除内容");
    }
  }

  private async hideFriendMessage(targetId: string): Promise<void> {
    const numericId = Number(targetId);

    if (Number.isInteger(numericId) && numericId > 0) {
      await this.friendMessageRepository.update(numericId, {
        content: "该消息因违规已被隐藏",
        cloudFileUrl: null,
      });
      return;
    }

    await this.friendMessageRepository.update(
      { messageId: targetId },
      {
        content: "该消息因违规已被隐藏",
        cloudFileUrl: null,
      },
    );
  }

  private async hideMarketplaceMessage(targetId: string): Promise<void> {
    const message = await this.findMarketplaceMessageByTargetId(targetId);
    if (!message) {
      throw new NotFoundException("商城消息不存在");
    }
    const hiddenContent = "该消息因违规已被隐藏";
    await Promise.all([
      this.marketplaceMessageRepository.update(message.id, {
        content: hiddenContent,
        cloudFileUrl: null,
      }),
      this.marketplaceConversationRepository.update(
        { lastMessageId: message.messageId },
        { lastMessageContent: hiddenContent },
      ),
    ]);
  }

  private async resolveReportTarget(
    targetType: ReportTargetType,
    targetId: string,
  ): Promise<ResolvedReportTarget> {
    switch (targetType) {
      case ReportTargetType.COMMUNITY_POST:
        return this.resolveCommunityPost(targetId);
      case ReportTargetType.COMMUNITY_COMMENT:
        return this.resolveCommunityComment(targetId);
      case ReportTargetType.LOST_FOUND_RECORD:
        return this.resolveLostFoundRecord(targetId);
      case ReportTargetType.LOST_FOUND_COMMENT:
        return this.resolveLostFoundComment(targetId);
      case ReportTargetType.ACTIVITY_COMMENT:
        return this.resolveActivityComment(targetId);
      case ReportTargetType.ACTIVITY_VOTE_OPTION:
        return this.resolveActivityVoteOption(targetId);
      case ReportTargetType.SECOND_HAND_PRODUCT:
        return this.resolveSecondHandProduct(targetId);
      case ReportTargetType.CHAT_MESSAGE:
        return this.resolveFriendMessage(targetId);
      case ReportTargetType.MARKETPLACE_MESSAGE:
        return this.resolveMarketplaceMessage(targetId);
      case ReportTargetType.USER:
        return this.resolveUserTarget(targetId);
      default:
        throw new BadRequestException("举报目标类型无效");
    }
  }

  private async resolveCommunityPost(
    targetId: string,
  ): Promise<ResolvedReportTarget> {
    const id = this.parsePositiveNumber(targetId, "帖子ID");
    const post = await this.postRepository.findOne({
      where: { id },
      relations: ["user"],
      withDeleted: true,
    });

    if (!post) {
      throw new NotFoundException("帖子不存在");
    }

    return {
      targetUserId: post.userId,
      snapshot: {
        summary: this.truncate(post.content),
        images: post.images || [],
        author: this.toSnapshotAuthor(post.user, post.userId),
      },
    };
  }

  private async resolveCommunityComment(
    targetId: string,
  ): Promise<ResolvedReportTarget> {
    const id = this.parsePositiveNumber(targetId, "评论ID");
    const comment = await this.commentRepository.findOne({
      where: { id },
      relations: ["user"],
      withDeleted: true,
    });

    if (!comment) {
      throw new NotFoundException("评论不存在");
    }

    return {
      targetUserId: comment.userId,
      snapshot: {
        summary: this.truncate(comment.content),
        author: this.toSnapshotAuthor(comment.user, comment.userId),
        metadata: { postId: comment.postId, parentId: comment.parentId },
      },
    };
  }

  private async resolveLostFoundRecord(
    targetId: string,
  ): Promise<ResolvedReportTarget> {
    const id = this.parsePositiveNumber(targetId, "走失招领ID");
    const record = await this.lostFoundRepository.findOne({
      where: { id },
      relations: ["publisher"],
      withDeleted: true,
    });

    if (!record) {
      throw new NotFoundException("走失招领信息不存在");
    }

    return {
      targetUserId: record.publisherId,
      snapshot: {
        title: record.contactName,
        summary: this.truncate(record.description),
        images: record.images || [],
        author: this.toSnapshotAuthor(record.publisher, record.publisherId),
        metadata: { recordType: record.recordType },
      },
    };
  }

  private async resolveLostFoundComment(
    targetId: string,
  ): Promise<ResolvedReportTarget> {
    const id = this.parsePositiveNumber(targetId, "走失招领评论ID");
    const comment = await this.lostFoundCommentRepository.findOne({
      where: { id },
      relations: ["user"],
      withDeleted: true,
    });

    if (!comment) {
      throw new NotFoundException("评论不存在");
    }

    return {
      targetUserId: comment.userId,
      snapshot: {
        summary: this.truncate(comment.content),
        author: this.toSnapshotAuthor(comment.user, comment.userId),
        metadata: {
          lostFoundId: comment.lostFoundId,
          parentId: comment.parentId,
        },
      },
    };
  }

  private async resolveActivityComment(
    targetId: string,
  ): Promise<ResolvedReportTarget> {
    const id = this.parsePositiveNumber(targetId, "活动评论ID");
    const comment = await this.activityCommentRepository.findOne({
      where: { id },
      relations: ["user"],
      withDeleted: true,
    });

    if (!comment) {
      throw new NotFoundException("评论不存在");
    }

    return {
      targetUserId: comment.userId,
      snapshot: {
        summary: this.truncate(comment.content),
        author: this.toSnapshotAuthor(comment.user, comment.userId),
        metadata: {
          activityId: comment.activityId,
          voteOptionId: comment.voteOptionId,
          parentId: comment.parentId,
        },
      },
    };
  }

  private async resolveActivityVoteOption(
    targetId: string,
  ): Promise<ResolvedReportTarget> {
    const id = this.parsePositiveNumber(targetId, "活动选手ID");
    const option = await this.activityVoteOptionRepository.findOne({
      where: { id },
      relations: ["ownerUser"],
      withDeleted: true,
    });

    if (!option) {
      throw new NotFoundException("活动选手不存在");
    }

    return {
      targetUserId: option.ownerUserId ?? null,
      snapshot: {
        title: option.title,
        summary: this.truncate(option.description || ""),
        images: option.image ? [option.image] : [],
        author: this.toSnapshotAuthor(option.ownerUser, option.ownerUserId),
        metadata: { activityId: option.activityId },
      },
    };
  }

  private async resolveSecondHandProduct(
    targetId: string,
  ): Promise<ResolvedReportTarget> {
    const id = this.parsePositiveNumber(targetId, "商品ID");
    const product = await this.productRepository.findOne({
      where: { id },
      relations: ["publisher"],
    });

    if (!product) {
      throw new NotFoundException("商品不存在");
    }

    return {
      targetUserId: product.publishedBy ?? null,
      snapshot: {
        title: product.name,
        summary: this.truncate(product.description || ""),
        images: product.images || (product.image ? [product.image] : []),
        author: this.toSnapshotAuthor(product.publisher, product.publishedBy),
        metadata: {
          price: product.price,
          publishSource: product.publishSource,
        },
      },
    };
  }

  private async resolveFriendMessage(
    targetId: string,
  ): Promise<ResolvedReportTarget> {
    const message = await this.findFriendMessageByTargetId(targetId);
    if (!message) {
      throw new NotFoundException("消息不存在");
    }

    return {
      targetUserId: message.senderId,
      snapshot: {
        summary: this.truncate(message.content),
        metadata: {
          messageId: message.messageId,
          conversationId: message.conversationId,
          messageType: message.messageType,
          receiverId: message.receiverId,
        },
      },
    };
  }

  private async resolveMarketplaceMessage(
    targetId: string,
  ): Promise<ResolvedReportTarget> {
    const message = await this.findMarketplaceMessageByTargetId(targetId);
    if (!message) {
      throw new NotFoundException("商城消息不存在");
    }

    return {
      targetUserId: message.senderId,
      snapshot: {
        summary: this.truncate(message.content),
        metadata: {
          messageId: message.messageId,
          conversationId: message.conversationId,
          messageType: message.messageType,
          receiverId: message.receiverId,
        },
      },
    };
  }

  private async resolveUserTarget(
    targetId: string,
  ): Promise<ResolvedReportTarget> {
    const id = this.parsePositiveNumber(targetId, "用户ID");
    const user = await this.userRepository.findOne({ where: { id } });

    if (!user) {
      throw new NotFoundException("用户不存在");
    }

    return {
      targetUserId: user.id,
      snapshot: {
        author: this.toSnapshotAuthor(user, user.id),
      },
    };
  }

  private async findFriendMessageByTargetId(targetId: string) {
    const numericId = Number(targetId);
    if (Number.isInteger(numericId) && numericId > 0) {
      const message = await this.friendMessageRepository.findOne({
        where: { id: numericId },
      });
      if (message) {
        return message;
      }
    }

    return this.friendMessageRepository.findOne({
      where: { messageId: targetId },
    });
  }

  private async findMarketplaceMessageByTargetId(targetId: string) {
    const numericId = Number(targetId);
    if (Number.isInteger(numericId) && numericId > 0) {
      const message = await this.marketplaceMessageRepository.findOne({
        where: { id: numericId },
      });
      if (message) {
        return message;
      }
    }

    return this.marketplaceMessageRepository.findOne({
      where: { messageId: targetId },
    });
  }

  private parsePositiveNumber(value: string, fieldName: string): number {
    const parsed = Number(value);
    if (!Number.isInteger(parsed) || parsed <= 0) {
      throw new BadRequestException(`${fieldName}必须为正整数`);
    }

    return parsed;
  }

  private truncate(value: string, maxLength = 200): string {
    const text = String(value || "")
      .replace(/\s+/g, " ")
      .trim();
    return text.length > maxLength ? `${text.slice(0, maxLength)}...` : text;
  }

  private resolveUserNickname(user?: Partial<User> | null): string {
    if (!user) {
      return "匿名用户";
    }

    return user.username || user.phone || `用户${user.id}`;
  }

  private toSnapshotAuthor(
    user?: Partial<User> | null,
    fallbackId?: number | null,
  ) {
    const id = user?.id ?? fallbackId;
    if (!id) {
      return undefined;
    }

    return {
      id,
      nickname: this.resolveUserNickname(user || { id }),
      avatar: user?.avatar ?? null,
    };
  }

  private toAdminReportResponse(report: UGCReport) {
    const createdAt = report.createdAt
      ? new Date(report.createdAt).getTime()
      : 0;
    const isOverdue =
      report.status === ReportStatus.PENDING &&
      createdAt > 0 &&
      Date.now() - createdAt > 24 * 60 * 60 * 1000;

    return {
      ...report,
      isOverdue,
      reporter: report.reporter
        ? {
            id: report.reporter.id,
            nickname: this.resolveUserNickname(report.reporter),
            avatar: report.reporter.avatar,
          }
        : undefined,
      targetUser: report.targetUser
        ? {
            id: report.targetUser.id,
            nickname: this.resolveUserNickname(report.targetUser),
            avatar: report.targetUser.avatar,
          }
        : undefined,
      handler: report.handler
        ? {
            id: report.handler.id,
            nickname: this.resolveUserNickname(report.handler),
          }
        : undefined,
    };
  }
}
