import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  Index,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Payment, PaymentChannel } from './payment.entity';
import { User } from '../../users/entities/user.entity';

/**
 * 退款状态
 */
export enum RefundStatus {
  PENDING = 'pending', // 退款中
  SUCCESS = 'success', // 退款成功
  FAILED = 'failed', // 退款失败
  PROCESSING = 'processing', // 处理中
  CLOSED = 'closed', // 退款关闭
}

/**
 * 退款类型
 */
export enum RefundType {
  FULL = 'full', // 全额退款
  PARTIAL = 'partial', // 部分退款
}

/**
 * 退款记录表
 * 存储所有退款记录和状态
 */
@Entity('refunds', { comment: '退款记录表' })
@Index('IDX_refunds_paymentId', ['paymentId'])
@Index('IDX_refunds_userId', ['userId'])
@Index('IDX_refunds_status', ['status'])
@Index('IDX_refunds_createdAt', ['createdAt'])
export class Refund {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ unique: true, comment: '退款单号（系统生成，UUID）' })
  refundNo: string;

  @Column({ comment: '关联的支付记录ID' })
  paymentId: number;

  @ManyToOne(() => Payment)
  @JoinColumn({ name: 'paymentId' })
  payment: Payment;

  @Column({ comment: '关联的业务单号（订单号等）' })
  outTradeNo: string;

  @Column({
    type: 'enum',
    enum: RefundStatus,
    default: RefundStatus.PENDING,
    comment: '退款状态',
  })
  status: RefundStatus;

  @Column({
    type: 'enum',
    enum: RefundType,
    comment: '退款类型',
  })
  type: RefundType;

  @Column({
    type: 'enum',
    enum: PaymentChannel,
    comment: '支付渠道',
  })
  channel: PaymentChannel;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    comment: '退款金额（元）',
  })
  refundAmount: number;

  @Column({ type: 'varchar', length: 512, nullable: true, comment: '退款原因' })
  reason: string;

  @Column({ comment: '申请人ID' })
  userId: number;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column({ nullable: true, comment: '处理人ID（管理员）' })
  processedBy: number;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'processedBy' })
  processor: User;

  @Column({ nullable: true, comment: '第三方退款单号' })
  thirdPartyRefundNo: string;

  @Column({ type: 'text', nullable: true, comment: '退款说明（管理员备注）' })
  remark: string;

  @Column({ type: 'json', nullable: true, comment: '扩展信息（JSON格式）' })
  metadata: Record<string, any>;

  @Column({ type: 'timestamp', nullable: true, comment: '退款成功时间' })
  refundedAt: Date;

  @Column({ type: 'timestamp', nullable: true, comment: '处理时间' })
  processedAt: Date;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @Column({ type: 'timestamp', nullable: true, comment: '更新时间' })
  updatedAt: Date;
}
