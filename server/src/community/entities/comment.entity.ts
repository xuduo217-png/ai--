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
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Post } from './post.entity';

/**
 * 评论实体
 * 存储帖子的评论和回复
 */
@Entity('community_comments')
@Index('IDX_community_comments_post_id', ['postId'])
@Index('IDX_community_comments_user_id', ['userId'])
@Index('IDX_community_comments_parent_id', ['parentId']) // 支持嵌套回复
export class Comment {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  /**
   * 帖子ID
   */
  @Column({ type: 'int', comment: '帖子ID' })
  postId: number;

  /**
   * 评论用户ID
   */
  @Column({ type: 'int', comment: '评论用户ID' })
  userId: number;

  /**
   * 关联的用户实体
   */
  @ManyToOne(() => User, { nullable: false })
  @JoinColumn({ name: 'userId' })
  user: User;

  /**
   * 关联的帖子实体
   */
  @ManyToOne(() => Post, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'postId' })
  post: Post;

  /**
   * 父评论ID（用于嵌套回复）
   * 如果为 null，表示是顶层评论
   */
  @Column({ type: 'int', nullable: true, comment: '父评论ID（用于嵌套回复）' })
  parentId?: number;

  /**
   * 关联的父评论实体
   */
  @ManyToOne(() => Comment, { nullable: true, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'parentId' })
  parent?: Comment;

  /**
   * 评论内容
   */
  @Column({ type: 'text', comment: '评论内容' })
  content: string;

  /**
   * 点赞数
   */
  @Column({ type: 'int', default: 0, comment: '点赞数' })
  likeCount: number;

  /**
   * 创建时间
   */
  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  /**
   * 更新时间
   */
  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;

  /**
   * 删除时间（软删除）
   */
  @DeleteDateColumn({
    type: 'timestamp',
    nullable: true,
    comment: '删除时间（软删除）',
  })
  deletedAt?: Date;
}
