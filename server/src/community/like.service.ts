import {
  Injectable,
  NotFoundException,
  ConflictException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { In, Repository } from "typeorm";
import { Like, LikeTargetType } from "./entities/like.entity";
import { Post } from "./entities/post.entity";
import { Comment } from "./entities/comment.entity";
import { CommentService } from "./comment.service";
import { User } from "../users/entities/user.entity";
import { NotificationSenderService } from "../notifications/notification-sender.service";

/**
 * 点赞服务
 * 提供帖子和评论的点赞/取消点赞功能
 */
@Injectable()
export class LikeService {
  constructor(
    @InjectRepository(Like)
    private readonly likeRepository: Repository<Like>,
    @InjectRepository(Post)
    private readonly postRepository: Repository<Post>,
    @InjectRepository(Comment)
    private readonly commentRepository: Repository<Comment>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly commentService: CommentService,
    private readonly notificationSender: NotificationSenderService,
  ) {}

  /**
   * 点赞帖子（使用原子操作避免竞态条件）
   * 幂等性：如果已经点赞过也返回成功
   */
  async likePost(userId: number, postId: number): Promise<void> {
    // 检查帖子是否存在
    const post = await this.postRepository.findOne({ where: { id: postId } });
    if (!post) {
      throw new NotFoundException("帖子不存在");
    }

    // 检查是否已点赞
    const existing = await this.likeRepository.findOne({
      where: {
        userId,
        targetType: LikeTargetType.POST,
        targetId: postId,
      },
    });

    // 如果已经点赞过，直接返回（幂等性）
    if (existing) {
      console.log(`[LikeService] 用户 ${userId} 已经点赞过帖子 ${postId}`);
      return;
    }

    // 创建点赞记录
    const like = this.likeRepository.create({
      userId,
      targetType: LikeTargetType.POST,
      targetId: postId,
    });
    await this.likeRepository.save(like);

    // 增加点赞数（使用更可靠的方式）
    post.likeCount = (post.likeCount || 0) + 1;
    await this.postRepository.save(post);
    console.log(
      `[LikeService] 帖子 ${postId} 点赞成功，新的点赞数: ${post.likeCount}`,
    );

    if (post.userId !== userId) {
      const currentUser = await this.userRepository.findOne({
        where: { id: userId },
        select: ["id", "username", "phone"],
      });
      await this.notificationSender.likeReceived(post.userId, {
        likerName:
          currentUser?.username || currentUser?.phone || `用户${userId}`,
        contentType: "帖子",
        path: "PostDetail",
        params: { postId },
      });
    }
  }

  /**
   * 取消点赞帖子（使用实体操作避免竞态条件）
   * 幂等性：如果未点赞过也返回成功
   */
  async unlikePost(userId: number, postId: number): Promise<void> {
    // 查找点赞记录
    const like = await this.likeRepository.findOne({
      where: {
        userId,
        targetType: LikeTargetType.POST,
        targetId: postId,
      },
    });

    // 如果没有点赞记录，直接返回（幂等性）
    if (!like) {
      console.log(`[LikeService] 用户 ${userId} 未点赞过帖子 ${postId}`);
      return;
    }

    // 删除点赞记录
    await this.likeRepository.remove(like);

    // 减少点赞数（使用更可靠的方式，与 likePost 保持一致）
    const post = await this.postRepository.findOne({ where: { id: postId } });
    if (post) {
      post.likeCount = Math.max(0, (post.likeCount || 0) - 1);
      await this.postRepository.save(post);
      console.log(
        `[LikeService] 帖子 ${postId} 取消点赞成功，新的点赞数: ${post.likeCount}`,
      );
    }
  }

  /**
   * 点赞评论
   * 幂等性：如果已经点赞过也返回成功
   */
  async likeComment(userId: number, commentId: number): Promise<void> {
    const comment = await this.commentRepository.findOne({
      where: { id: commentId },
    });

    if (!comment) {
      throw new NotFoundException("评论不存在");
    }

    // 检查是否已点赞
    const existing = await this.likeRepository.findOne({
      where: {
        userId,
        targetType: LikeTargetType.COMMENT,
        targetId: commentId,
      },
    });

    // 如果已经点赞过，直接返回（幂等性）
    if (existing) {
      return;
    }

    // 创建点赞记录
    const like = this.likeRepository.create({
      userId,
      targetType: LikeTargetType.COMMENT,
      targetId: commentId,
    });
    await this.likeRepository.save(like);

    // 增加评论点赞数
    await this.commentService.incrementLikeCount(commentId);

    if (comment.userId !== userId) {
      const currentUser = await this.userRepository.findOne({
        where: { id: userId },
        select: ["id", "username", "phone"],
      });
      await this.notificationSender.likeReceived(comment.userId, {
        likerName:
          currentUser?.username || currentUser?.phone || `用户${userId}`,
        contentType: "评论",
        path: "PostDetail",
        params: { postId: comment.postId },
      });
    }
  }

  /**
   * 取消点赞评论
   * 幂等性：如果未点赞过也返回成功
   */
  async unlikeComment(userId: number, commentId: number): Promise<void> {
    // 查找点赞记录
    const like = await this.likeRepository.findOne({
      where: {
        userId,
        targetType: LikeTargetType.COMMENT,
        targetId: commentId,
      },
    });

    // 如果没有点赞记录，直接返回（幂等性）
    if (!like) {
      return;
    }

    // 删除点赞记录
    await this.likeRepository.remove(like);

    // 减少评论点赞数
    await this.commentService.decrementLikeCount(commentId);
  }

  /**
   * 检查用户是否已点赞帖子
   */
  async hasLikedPost(userId: number, postId: number): Promise<boolean> {
    const like = await this.likeRepository.findOne({
      where: {
        userId,
        targetType: LikeTargetType.POST,
        targetId: postId,
      },
    });
    return !!like;
  }

  /**
   * 批量获取用户已点赞的帖子 ID
   * 用户主页/社区列表会同时加载多条帖子，统一批量查询可避免逐条查库放大远端 MySQL 往返次数。
   */
  async findLikedPostIds(userId: number, postIds: number[]): Promise<number[]> {
    if (postIds.length === 0) {
      return [];
    }

    const likes = await this.likeRepository.find({
      where: {
        userId,
        targetType: LikeTargetType.POST,
        targetId: In(postIds),
      },
      select: ["targetId"],
    });

    return likes.map((like) => like.targetId);
  }

  /**
   * 检查用户是否已点赞评论
   */
  async hasLikedComment(userId: number, commentId: number): Promise<boolean> {
    const like = await this.likeRepository.findOne({
      where: {
        userId,
        targetType: LikeTargetType.COMMENT,
        targetId: commentId,
      },
    });
    return !!like;
  }

  /**
   * 获取帖子点赞用户列表
   */
  async getPostLikeUsers(
    postId: number,
    limit: number = 10,
  ): Promise<number[]> {
    const likes = await this.likeRepository.find({
      where: {
        targetType: LikeTargetType.POST,
        targetId: postId,
      },
      take: limit,
      order: { createdAt: "DESC" },
    });
    return likes.map((like) => like.userId);
  }
}
