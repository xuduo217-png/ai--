import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

/**
 * 点赞目标类型枚举
 */
export enum LikeTargetType {
  POST = 'POST', // 帖子
  COMMENT = 'COMMENT', // 评论
}

/**
 * 点赞实体
 * 统一存储帖子和评论的点赞记录
 */
@Entity('community_likes')
@Index('IDX_community_likes_user_target', ['userId', 'targetType', 'targetId'], { unique: true }) // 防止重复点赞
@Index('IDX_community_likes_target', ['targetType', 'targetId']) // 用于查询某个帖子的所有点赞
export class Like {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  /**
   * 用户ID
   */
  @Column({ type: 'int', comment: '用户ID' })
  userId: number;

  /**
   * 关联的用户实体
   */
  @ManyToOne(() => User, { nullable: false })
  @JoinColumn({ name: 'userId' })
  user: User;

  /**
   * 点赞目标类型
   */
  @Column({
    type: 'enum',
    enum: LikeTargetType,
    comment: '点赞目标类型'
  })
  targetType: LikeTargetType;

  /**
   * 目标ID（帖子ID或评论ID）
   */
  @Column({ type: 'int', comment: '目标ID（帖子ID或评论ID）' })
  targetId: number;

  /**
   * 创建时间
   */
  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;
}
