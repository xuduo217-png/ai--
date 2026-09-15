import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Activity } from './activity.entity';
import { User } from '../../users/entities/user.entity';

/**
 * 活动报名记录(ActivityRegistration)实体
 *
 * 用于记录用户报名活动的信息
 */
@Entity('activity_registrations', { comment: '活动报名记录表' })
@Index(['activityId'])
@Index(['userId'])
@Index(['activityId', 'userId'])
@Index(['activityId', 'userId', 'participationKey'], { unique: true }) // 线下防重复报名，线上防当天重复投票
export class ActivityRegistration {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ type: 'int', comment: '活动ID' })
  activityId: number;

  @Column({ type: 'int', comment: '用户ID' })
  userId: number;

  @Column({ type: 'varchar', length: 20, comment: '联系电话' })
  phone: string;

  @Column({ type: 'int', nullable: true, comment: '投票选手ID（线上投票专用）' })
  voteOptionId?: number;

  @Column({
    type: 'varchar',
    length: 20,
    default: 'offline',
    comment: '参与唯一键：线下固定 offline，线上为投票日期 YYYY-MM-DD',
  })
  participationKey: string;

  @Column({ type: 'bigint', comment: '报名时间（时间戳，毫秒）' })
  registeredAt: number;

  // ==================== 关联关系 ====================

  /**
   * 关联活动
   */
  @ManyToOne(() => Activity, { eager: false })
  @JoinColumn({ name: 'activityId' })
  activity: Activity;

  /**
   * 关联用户
   */
  @ManyToOne(() => User, { eager: false })
  @JoinColumn({ name: 'userId' })
  user: User;

  // ==================== 查询额外字段（不保存到数据库） ====================

  /**
   * 用户昵称
   */
  userName?: string;

  /**
   * 用户头像
   */
  userAvatar?: string;
}
