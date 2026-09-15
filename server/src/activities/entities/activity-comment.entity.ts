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
import { Activity } from './activity.entity';
import { ActivityVoteOption } from './activity-vote-option.entity';
import { User } from '../../users/entities/user.entity';

/**
 * 活动评论实体
 * 独立存储线上投票活动的评论和回复，不复用社区评论表。
 */
@Entity('activity_comments', { comment: '活动评论表' })
@Index('IDX_activity_comments_activity_id', ['activityId'])
@Index('idx_activity_comments_vote_option_id', ['voteOptionId'])
@Index('IDX_activity_comments_user_id', ['userId'])
@Index('IDX_activity_comments_parent_id', ['parentId'])
export class ActivityComment {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ type: 'int', comment: '活动ID' })
  activityId: number;

  @ManyToOne(() => Activity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'activityId' })
  activity: Activity;

  @Column({ type: 'int', nullable: true, comment: '选手ID（为空表示活动级评论）' })
  voteOptionId?: number | null;

  @ManyToOne(() => ActivityVoteOption, { nullable: true, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'voteOptionId' })
  voteOption?: ActivityVoteOption | null;

  @Column({ type: 'int', comment: '评论用户ID' })
  userId: number;

  @ManyToOne(() => User, { nullable: false })
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column({ type: 'int', nullable: true, comment: '父评论ID（用于回复）' })
  parentId?: number;

  @ManyToOne(() => ActivityComment, { nullable: true, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'parentId' })
  parent?: ActivityComment;

  @Column({ type: 'text', comment: '评论内容' })
  content: string;

  @Column({ type: 'int', default: 0, comment: '点赞数（预留）' })
  likeCount: number;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;

  @DeleteDateColumn({
    type: 'timestamp',
    nullable: true,
    comment: '删除时间（软删除）',
  })
  deletedAt?: Date;
}
