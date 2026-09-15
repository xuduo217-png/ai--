import {
  Entity,
  Column,
  DeleteDateColumn,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Activity } from './activity.entity';
import { User } from '../../users/entities/user.entity';

/**
 * 线上投票活动选手/候选项
 */
@Entity('activity_vote_options', { comment: '活动投票选手表' })
@Index(['activityId'])
@Index(['activityId', 'sortOrder'])
@Index(['ownerUserId'])
export class ActivityVoteOption {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ type: 'int', comment: '活动ID' })
  activityId: number;

  @Column({ type: 'varchar', length: 500, default: '', comment: '选手图片URL' })
  image: string;

  @Column({ type: 'varchar', length: 500, default: '', comment: '选手视频URL' })
  video: string;

  @Column({ type: 'varchar', length: 500, default: '', comment: '选手视频缩略图URL' })
  videoCover: string;

  @Column({ type: 'varchar', length: 100, comment: '选手标题' })
  title: string;

  @Column({ type: 'text', nullable: true, comment: '选手描述' })
  description?: string;

  @Column({ type: 'int', default: 0, comment: '票数' })
  voteCount: number;

  @Column({ type: 'int', default: 0, comment: '排序值' })
  sortOrder: number;

  @Column({ type: 'int', nullable: true, comment: '所属用户ID（用户端报名添加时记录）' })
  ownerUserId?: number | null;

  @Column({ type: 'bigint', comment: '创建时间（时间戳，毫秒）' })
  createdAt: number;

  @Column({ type: 'bigint', comment: '更新时间（时间戳，毫秒）' })
  updatedAt: number;

  @DeleteDateColumn({
    type: 'timestamp',
    nullable: true,
    comment: '软删除时间',
  })
  deletedAt?: Date;

  @ManyToOne(() => Activity, (activity) => activity.voteOptions, {
    eager: false,
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'activityId' })
  activity: Activity;

  @ManyToOne(() => User, { eager: false, nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'ownerUserId' })
  ownerUser?: User | null;
}
