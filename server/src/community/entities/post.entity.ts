import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from "typeorm";
import { User } from "../../users/entities/user.entity";

/**
 * 帖子审核状态枚举
 */
export enum PostStatus {
  PENDING_REVIEW = "PENDING_REVIEW", // 待审核
  APPROVED = "APPROVED", // 已通过
  REJECTED = "REJECTED", // 已拒绝
}

/**
 * 社区帖子实体
 * 存储用户发布的社区内容
 */
@Entity("community_posts")
@Index("IDX_community_posts_user_id", ["userId"])
@Index("IDX_community_posts_status", ["status"])
@Index("IDX_community_posts_created_at", ["createdAt"])
@Index("IDX_community_posts_is_pinned", ["isPinned"])
@Index("IDX_community_posts_heat_score", ["heatScore"]) // 热度排序索引
export class Post {
  @PrimaryGeneratedColumn({ comment: "主键ID" })
  id: number;

  /**
   * 发布用户ID
   */
  @Column({ type: "int", comment: "发布用户ID" })
  userId: number;

  /**
   * 关联的用户实体
   */
  @ManyToOne(() => User, { nullable: false })
  @JoinColumn({ name: "userId" })
  user: User;

  /**
   * 帖子内容（文字）
   */
  @Column({ type: "text", comment: "帖子内容" })
  content: string;

  /**
   * 图片列表（JSON 数组，存储图片 URL）
   */
  @Column({ type: "json", nullable: true, comment: "图片列表 [URL]" })
  images?: string[];

  /**
   * 视频 URL
   */
  @Column({ type: "varchar", length: 500, nullable: true, comment: "视频URL" })
  video?: string;

  /**
   * 视频封面图 URL
   * 社区信息流和详情页优先消费封面图，避免列表环境里实时解码视频首帧带来额外性能压力。
   */
  @Column({
    type: "varchar",
    length: 500,
    nullable: true,
    comment: "视频封面图URL",
  })
  videoCover?: string;

  /**
   * 审核状态
   */
  @Column({
    type: "enum",
    enum: PostStatus,
    default: PostStatus.PENDING_REVIEW,
    comment: "审核状态",
  })
  status: PostStatus;

  /**
   * 点赞数
   */
  @Column({ type: "int", default: 0, comment: "点赞数" })
  likeCount: number;

  /**
   * 评论数
   */
  @Column({ type: "int", default: 0, comment: "评论数" })
  commentCount: number;

  /**
   * 浏览数
   */
  @Column({ type: "int", default: 0, comment: "浏览数" })
  viewCount: number;

  /**
   * 热度分数（用于推荐排序）
   * 计算公式：点赞数 + 评论数 * 2 + 浏览数 * 0.1
   */
  @Column({ type: "int", default: 0, comment: "热度分数（用于推荐排序）" })
  heatScore: number;

  /**
   * 是否置顶
   */
  @Column({ type: "bool", default: false, comment: "是否置顶" })
  isPinned: boolean;

  /**
   * 是否精华
   */
  @Column({ type: "bool", default: false, comment: "是否精华" })
  isFeatured: boolean;

  /**
   * 审核拒绝原因
   */
  @Column({ type: "text", nullable: true, comment: "审核拒绝原因" })
  rejectReason?: string;

  /**
   * 触发的敏感词列表（JSON 数组）
   */
  @Column({ type: "json", nullable: true, comment: "触发的敏感词列表" })
  detectedSensitiveWords?: string[];

  /**
   * 创建时间
   */
  @CreateDateColumn({ comment: "创建时间" })
  createdAt: Date;

  /**
   * 更新时间
   */
  @UpdateDateColumn({ comment: "更新时间" })
  updatedAt: Date;

  /**
   * 删除时间（软删除）
   */
  @DeleteDateColumn({
    type: "timestamp",
    nullable: true,
    comment: "删除时间（软删除）",
  })
  deletedAt?: Date;
}
