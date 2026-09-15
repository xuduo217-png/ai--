import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Optional,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository, In, IsNull, Not } from "typeorm";
import { Comment } from "./entities/comment.entity";
import { Post } from "./entities/post.entity";
import { CreateCommentDto } from "./dto";
import { SensitiveWordService } from "./sensitive-word.service";
import { instanceToPlain } from "class-transformer";
import { User } from "../users/entities/user.entity";
import { NotificationSenderService } from "../notifications/notification-sender.service";
import { ModerationService } from "../moderation/moderation.service";

/**
 * 评论服务
 * 提供评论的增删改查功能
 */
@Injectable()
export class CommentService {
  // 常量定义
  private readonly DEFAULT_REPLY_LIMIT = 10;
  private readonly MAX_REPLY_LIMIT = 50;

  constructor(
    @InjectRepository(Comment)
    private readonly commentRepository: Repository<Comment>,
    @InjectRepository(Post)
    private readonly postRepository: Repository<Post>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly sensitiveWordService: SensitiveWordService,
    private readonly notificationSender: NotificationSenderService,
    @Optional()
    private readonly moderationService?: ModerationService,
  ) {}

  /**
   * 将 Comment 实体转换为响应格式
   * 转换 user 对象为前端期望的格式（username -> nickname）
   * 并使用 instanceToPlain 自动排除 @Exclude() 标记的字段（如 password）
   */
  private toCommentResponse(comment: Comment): any {
    const plainComment = instanceToPlain(comment);

    // 转换 user 对象格式
    if (plainComment.user) {
      plainComment.user = {
        id: plainComment.user.id,
        // 使用 username 作为 nickname 显示
        nickname:
          plainComment.user.username || plainComment.user.phone || "匿名用户",
        avatar: plainComment.user.avatar,
      };
    }

    // 递归转换 replies
    if (plainComment.replies && Array.isArray(plainComment.replies)) {
      plainComment.replies = plainComment.replies.map((reply: Comment) => {
        const plainReply = instanceToPlain(reply);
        if (plainReply.user) {
          plainReply.user = {
            id: plainReply.user.id,
            nickname:
              plainReply.user.username || plainReply.user.phone || "匿名用户",
            avatar: plainReply.user.avatar,
          };
        }
        return plainReply;
      });
    }

    return plainComment;
  }

  /**
   * 批量转换 Comment 实体为响应格式
   */
  private toCommentResponseList(comments: Comment[]): any[] {
    return comments.map((comment) => this.toCommentResponse(comment));
  }

  /**
   * 创建评论
   */
  async create(
    userId: number,
    postId: number,
    dto: CreateCommentDto,
  ): Promise<Comment> {
    // 检查帖子是否存在
    const post = await this.postRepository.findOne({ where: { id: postId } });
    if (!post) {
      throw new NotFoundException("帖子不存在");
    }

    // 只能对已通过的帖子评论
    if (post.status !== "APPROVED") {
      throw new NotFoundException("帖子不存在");
    }

    await this.moderationService?.assertUsersCanInteract(userId, post.userId);

    // 如果是回复评论，检查父评论是否存在
    let parentComment: Comment | null = null;

    if (dto.parentId) {
      parentComment = await this.commentRepository.findOne({
        where: { id: dto.parentId },
      });
      if (!parentComment) {
        throw new NotFoundException("父评论不存在");
      }
      await this.moderationService?.assertUsersCanInteract(
        userId,
        parentComment.userId,
      );
    }

    // 敏感词检测
    const processResult = await this.sensitiveWordService.process(dto.content);
    if (processResult.action === "REJECT") {
      throw new ForbiddenException("评论包含违规内容，请修改后重新提交");
    }

    // 使用处理后的内容（如果有替换）
    const content = processResult.text || dto.content;

    const comment = this.commentRepository.create({
      userId,
      postId,
      content,
      parentId: dto.parentId,
    });

    const saved = await this.commentRepository.save(comment);

    // 增加帖子的评论数（使用直接实体操作确保持久化）
    post.commentCount = (post.commentCount || 0) + 1;
    await this.postRepository.save(post);

    // 社区互动通知只发给内容拥有者，且不向自己发通知。
    const currentUser = await this.userRepository.findOne({
      where: { id: userId },
      select: ["id", "username", "phone"],
    });
    const commenterName =
      currentUser?.username || currentUser?.phone || `用户${userId}`;

    if (post.userId !== userId) {
      await this.notificationSender.commentReceived(post.userId, {
        commenterName,
        comment: content,
        contentType: "帖子",
        path: "PostDetail",
        params: { postId },
      });
    }

    if (
      parentComment &&
      parentComment.userId !== userId &&
      parentComment.userId !== post.userId
    ) {
      await this.notificationSender.commentReceived(parentComment.userId, {
        commenterName,
        comment: content,
        contentType: "评论",
        path: "PostDetail",
        params: { postId },
      });
    }

    // 转换为响应格式
    return this.toCommentResponse(saved);
  }

  /**
   * 删除评论
   */
  async delete(id: number, userId: number): Promise<void> {
    const comment = await this.commentRepository.findOne({
      where: { id },
      relations: ["post"],
    });

    if (!comment) {
      throw new NotFoundException("评论不存在");
    }

    // 权限检查：只能删除自己的评论
    if (comment.userId !== userId) {
      throw new NotFoundException("评论不存在");
    }

    await this.commentRepository.softRemove(comment);

    // 减少帖子的评论数
    if (comment.post) {
      comment.post.commentCount--;
      await this.postRepository.save(comment.post);
    }
  }

  /**
   * 获取帖子的评论列表（优化版：避免 N+1 查询）
   */
  async findByPost(
    postId: number,
    page: number = 1,
    limit: number = 10,
    currentUserId?: number,
  ): Promise<{
    data: Comment[];
    total: number;
  }> {
    const blockedUserIds =
      await this.moderationService?.getBlockedUserIds(currentUserId);
    const visibleAuthorFilter = blockedUserIds?.length
      ? { userId: Not(In(blockedUserIds)) }
      : {};

    // 1. 获取顶层评论
    const [comments, total] = await this.commentRepository.findAndCount({
      where: { postId, parentId: IsNull(), ...visibleAuthorFilter },
      relations: ["user", "parent"],
      order: { createdAt: "DESC" },
      take: limit,
      skip: (page - 1) * limit,
    });

    // 2. 如果有顶层评论，一次性获取所有回复
    if (comments.length > 0) {
      const commentIds = comments.map((c) => c.id);
      const allReplies = await this.commentRepository.find({
        where: { parentId: In(commentIds), ...visibleAuthorFilter },
        relations: ["user"],
        order: { createdAt: "ASC" },
        take: this.DEFAULT_REPLY_LIMIT,
      });

      // 3. 手动关联回复到评论
      const repliesMap = new Map<number, Comment[]>();
      allReplies.forEach((reply) => {
        if (!repliesMap.has(reply.parentId)) {
          repliesMap.set(reply.parentId, []);
        }
        repliesMap.get(reply.parentId).push(reply);
      });

      comments.forEach((comment) => {
        (comment as any).replies = repliesMap.get(comment.id) || [];
      });
    }

    // 转换为响应格式
    return { data: this.toCommentResponseList(comments), total };
  }

  /**
   * 增加评论点赞数（使用直接实体操作确保持久化）
   */
  async incrementLikeCount(commentId: number): Promise<void> {
    const comment = await this.commentRepository.findOne({
      where: { id: commentId },
    });

    if (!comment) {
      throw new NotFoundException("评论不存在");
    }

    comment.likeCount = (comment.likeCount || 0) + 1;
    await this.commentRepository.save(comment);
  }

  /**
   * 减少评论点赞数（使用直接实体操作确保持久化）
   */
  async decrementLikeCount(commentId: number): Promise<void> {
    const comment = await this.commentRepository.findOne({
      where: { id: commentId },
    });

    if (!comment) {
      throw new NotFoundException("评论不存在");
    }

    // 防止点赞数变成负数
    comment.likeCount = Math.max(0, (comment.likeCount || 0) - 1);
    await this.commentRepository.save(comment);
  }
}
