import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  Index,
} from 'typeorm';

/**
 * 公益状态枚举
 */
export enum CharityStatus {
  DRAFT = 'DRAFT',       // 草稿
  ACTIVE = 'ACTIVE',     // 进行中
  EXPIRED = 'EXPIRED',   // 已结束
}

/**
 * 参与方式枚举
 */
export enum ParticipantType {
  CHECKIN = 'checkin',   // 签到打卡
  TASK = 'task',         // 任务完成
  DONATION = 'donation', // 爱心捐款
}

/**
 * 公益(Charity)实体
 *
 * 用于管理用户公益活动，包括签到打卡、任务完成、爱心捐款等类型
 * 支持永久活动和限时活动
 */
@Entity('charities', { comment: '公益活动表' })
@Index(['deletedAt'])
export class Charity {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ length: 100, comment: '公益名称' })
  title: string;

  @Column({ type: 'text', comment: '公益描述' })
  description: string;

  @Column({ type: 'text', nullable: true, comment: '公益详情（富文本内容）' })
  details: string;

  @Column({ nullable: true, comment: '封面图片URL' })
  coverImage: string;

  @Column({ type: 'datetime', nullable: true, comment: '开始时间(留空表示立即开始)' })
  startTime: Date;

  @Column({ type: 'datetime', nullable: true, comment: '结束时间(留空表示永久活动)' })
  endTime: Date;

  @Column({ type: 'int', default: 0, comment: '目标打卡次数(打卡类型达标后可发布文章)' })
  targetCheckIns: number;

  @Column({ type: 'int', default: 0, comment: '已完成打卡次数(所有参与者的打卡次数总和)' })
  completedCheckIns: number;

  @Column({
    type: 'enum',
    enum: ParticipantType,
    default: ParticipantType.CHECKIN,
    comment: '参与方式: checkin=签到打卡, task=任务完成, donation=爱心捐款',
  })
  participantType: ParticipantType;

  @Column({
    type: 'boolean',
    default: false,
    comment: '是否为商城订单自动公益活动（商城普通商品支付后自动入账）',
  })
  isMallAutoDonation: boolean;

  @Column({
    type: 'decimal',
    precision: 5,
    scale: 2,
    default: 0,
    comment: '商城自动公益比例（百分比，例如 1.50 表示 1.5%）',
  })
  donationRate: number;

  @Column({
    type: 'boolean',
    default: false,
    comment: '是否置顶展示',
  })
  isPinned: boolean;

  /**
   * 任务配置(JSON格式)
   * 示例: { "taskType": "share", "targetUrl": "https://..." }
   */
  @Column({ type: 'json', nullable: true, comment: '任务配置(JSON)' })
  taskConfig: Record<string, any>;

  @Column({
    type: 'enum',
    enum: CharityStatus,
    default: CharityStatus.ACTIVE,
    comment: '公益状态: DRAFT=草稿, ACTIVE=进行中, EXPIRED=已结束',
  })
  status: CharityStatus;

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

  // ==================== 用户端额外字段（不保存到数据库） ====================

  /**
   * 当前用户打卡次数
   * 用户端专用字段，不在数据库中存储
   */
  userCheckInCount?: number;

  /**
   * 今日是否已打卡
   * 用户端专用字段，不在数据库中存储
   */
  hasCheckedToday?: boolean;

  /**
   * 参与人数（去重）
   * 管理员列表专用字段，不在数据库中存储
   */
  participantCount?: number;

  /**
   * 总签到次数（所有参与者的签到次数总和）
   * 管理员列表专用字段，不在数据库中存储
   */
  totalCheckIns?: number;

  /**
   * 已捐金额
   * 捐款型公益专用字段，不在数据库中存储
   */
  donatedAmount?: number;
}
