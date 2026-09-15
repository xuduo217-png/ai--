import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  Index,
} from 'typeorm';

export enum CharityDonationSource {
  MANUAL = 'manual',
  MALL_ORDER = 'mall_order',
}

export enum CharityDonationEntryType {
  CREDIT = 'credit',
  REVERSAL = 'reversal',
}

/**
 * 公益打卡记录(CharityRecord)实体
 *
 * 记录用户参与公益的打卡/任务完成/捐款记录
 * 通过唯一索引防止同一用户在同一公益同一天重复打卡
 */
@Entity('charity_records', { comment: '公益参与记录表' })
@Index(['charityId', 'userId', 'checkInDate'], { unique: true }) // 防止重复打卡
@Index('IDX_charity_records_source_reference', ['sourceReference'], { unique: true })
export class CharityRecord {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ type: 'int', comment: '公益ID' })
  charityId: number;

  @Column({ type: 'int', comment: '用户ID' })
  userId: number;

  @Column({ type: 'date', nullable: true, comment: '打卡日期(YYYY-MM-DD)，捐款记录可为空' })
  checkInDate: string | null;

  @Column({ type: 'datetime', comment: '打卡时间' })
  checkInTime: Date;

  @Column({ length: 50, nullable: true, comment: '任务类型: checkin=签到, share=分享, view=浏览等' })
  taskType: string;

  @Column({ type: 'text', nullable: true, comment: '任务证据(如分享链接、浏览记录)' })
  taskEvidence: string;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    nullable: true,
    default: 0,
    comment: '捐款金额（元，捐款类型公益专用）',
  })
  donationAmount?: number;

  @Column({
    type: 'enum',
    enum: CharityDonationSource,
    default: CharityDonationSource.MANUAL,
    comment: '公益来源: manual=主动捐款, mall_order=商城订单自动公益',
  })
  donationSource: CharityDonationSource;

  @Column({
    type: 'enum',
    enum: CharityDonationEntryType,
    default: CharityDonationEntryType.CREDIT,
    comment: '公益流水类型: credit=入账, reversal=退款冲销',
  })
  donationEntryType: CharityDonationEntryType;

  @Column({ type: 'int', nullable: true, comment: '关联商城订单ID' })
  orderId: number | null;

  @Column({ type: 'varchar', length: 64, nullable: true, comment: '关联商城订单号' })
  orderNo: string | null;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    nullable: true,
    comment: '公益计算基数（元，支付或退款实付金额）',
  })
  donationBaseAmount: number | null;

  @Column({
    type: 'decimal',
    precision: 5,
    scale: 2,
    nullable: true,
    comment: '公益比例快照（百分比）',
  })
  donationRate: number | null;

  @Column({ type: 'varchar', length: 128, nullable: true, comment: '幂等来源标识' })
  sourceReference: string | null;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;
}
