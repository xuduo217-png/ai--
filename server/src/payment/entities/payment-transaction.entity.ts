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

/**
 * 交易类型
 */
export enum TransactionType {
  PAY = 'pay', // 支付
  REFUND = 'refund', // 退款
  QUERY = 'query', // 查询
  CLOSE = 'close', // 关闭
  CANCEL = 'cancel', // 撤销
}

/**
 * 交易状态
 */
export enum TransactionStatus {
  PENDING = 'pending', // 处理中
  SUCCESS = 'success', // 成功
  FAILED = 'failed', // 失败
  TIMEOUT = 'timeout', // 超时
}

/**
 * 支付流水表
 * 记录每次与第三方支付平台的交互，便于对账和问题排查
 */
@Entity('payment_transactions', { comment: '支付流水表' })
@Index('IDX_payment_transactions_paymentId', ['paymentId'])
@Index('IDX_payment_transactions_type', ['type'])
@Index('IDX_payment_transactions_status', ['status'])
@Index('IDX_payment_transactions_createdAt', ['createdAt'])
export class PaymentTransaction {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '关联的支付记录ID' })
  paymentId: number;

  @ManyToOne(() => Payment)
  @JoinColumn({ name: 'paymentId' })
  payment: Payment;

  @Column({ unique: true, comment: '交易流水号（系统生成）' })
  transactionNo: string;

  @Column({
    type: 'enum',
    enum: TransactionType,
    comment: '交易类型',
  })
  type: TransactionType;

  @Column({
    type: 'enum',
    enum: TransactionStatus,
    default: TransactionStatus.PENDING,
    comment: '交易状态',
  })
  status: TransactionStatus;

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
    nullable: true,
    comment: '交易金额',
  })
  amount: number;

  @Column({
    type: 'varchar',
    length: 512,
    nullable: true,
    comment: '第三方接口URL',
  })
  apiUrl: string;

  @Column({ type: 'json', nullable: true, comment: '请求参数（JSON格式）' })
  requestParams: Record<string, any>;

  @Column({ type: 'json', nullable: true, comment: '响应数据（JSON格式）' })
  responseData: Record<string, any>;

  @Column({ type: 'text', nullable: true, comment: '错误信息' })
  errorMessage: string;

  @Column({ type: 'varchar', length: 64, nullable: true, comment: '错误码' })
  errorCode: string;

  @Column({ type: 'int', nullable: true, comment: '执行时长（毫秒）' })
  duration: number;

  @Column({ default: 0, comment: '重试次数' })
  retryCount: number;

  @Column({ type: 'varchar', length: 64, nullable: true, comment: '客户端IP' })
  clientIp: string;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;
}
