import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
  Index,
  DeleteDateColumn,
} from 'typeorm';
import { Hospital } from '../../hospitals/entities/hospital.entity';
import { ActivityVoteOption } from './activity-vote-option.entity';

/**
 * 活动状态枚举
 */
export enum ActivityStatus {
  UPCOMING = 'UPCOMING',   // 未开始
  ONGOING = 'ONGOING',     // 进行中
  EXPIRED = 'EXPIRED',     // 已结束
}

/**
 * 活动类型枚举
 */
export enum ActivityType {
  OFFLINE = 'OFFLINE', // 线下活动
  ONLINE = 'ONLINE', // 线上投票
}

/**
 * 活动(Activity)实体
 *
 * 用于管理宠物医院活动，支持活动创建、编辑、报名等功能
 */
@Entity('activities', { comment: '活动表' })
@Index(['hospitalId'])
@Index(['startTime'])
@Index(['endTime'])
@Index(['showOnHome'])
@Index(['deletedAt'])
export class Activity {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ length: 200, comment: '活动名称' })
  title: string;

  @Column({ type: 'bigint', comment: '活动开始时间（时间戳，秒）' })
  startTime: number;

  @Column({ type: 'bigint', comment: '活动结束时间（时间戳，秒）' })
  endTime: number;

  @Column({ type: 'enum', enum: ActivityType, default: ActivityType.OFFLINE, comment: '活动类型（OFFLINE=线下活动，ONLINE=线上投票）' })
  activityType: ActivityType;

  @Column({ type: 'varchar', length: 500, default: '', comment: '活动地点（线下活动必填，线上活动可为空）' })
  location: string;

  @Column({ type: 'text', comment: '活动简介（短文本）' })
  summary: string;

  @Column({ type: 'text', comment: '活动详情（富文本 HTML）' })
  description: string;

  @Column({ type: 'varchar', length: 500, default: '', comment: '活动封面图片URL' })
  coverImage: string;

  @Column({ type: 'varchar', length: 500, default: '', comment: '活动分享海报图片URL' })
  sharePosterImage: string;

  @Column({ type: 'varchar', length: 10, default: '', comment: '活动分享海报提示标题' })
  sharePosterTitle: string;

  @Column({ type: 'varchar', length: 30, default: '', comment: '活动分享海报提示信息' })
  sharePosterDescription: string;

  @Column({ type: 'boolean', default: false, comment: '是否展示到首页' })
  showOnHome: boolean;

  @Column({ type: 'int', comment: '关联医院ID' })
  hospitalId: number;

  @Column({ type: 'int', default: 0, comment: '报名人数（冗余字段）' })
  registrationCount: number;

  @Column({ type: 'bigint', comment: '创建时间（时间戳，毫秒）' })
  createdAt: number;

  @Column({ type: 'bigint', comment: '更新时间（时间戳，毫秒）' })
  updatedAt: number;

  @DeleteDateColumn({
    type: 'timestamp',
    nullable: true,
    comment: '删除时间（软删除）',
  })
  deletedAt?: Date;

  // ==================== 关联关系 ====================

  /**
   * 关联医院
   */
  @ManyToOne(() => Hospital, { eager: false })
  @JoinColumn({ name: 'hospitalId' })
  hospital: Hospital;

  /**
   * 线上投票选手列表
   */
  @OneToMany(() => ActivityVoteOption, (option) => option.activity)
  voteOptions?: ActivityVoteOption[];

  // ==================== 用户端额外字段（不保存到数据库） ====================

  /**
   * 活动状态（根据时间实时计算）
   * 用户端和管理端专用字段，不在数据库中存储
   */
  status?: ActivityStatus;

  /**
   * 医院名称（用于查询时返回）
   */
  hospitalName?: string;

  /**
   * 医院完整信息（用于编辑时回显）
   * 不在数据库中存储
   */
  hospitalData?: {
    id: number;
    name: string;
    logo: string;
    city: string;
    address: string;
    phone: string;
  };

  /**
   * 当前用户是否已报名
   * 用户端专用字段，不在数据库中存储
   */
  isRegistered?: boolean;

  /**
   * 是否可以报名
   * 用户端专用字段，不在数据库中存储
   */
  canRegister?: boolean;

  /**
   * 评论数
   * 线上投票活动管理端列表专用字段，不在数据库中存储
   */
  commentCount?: number;
}
