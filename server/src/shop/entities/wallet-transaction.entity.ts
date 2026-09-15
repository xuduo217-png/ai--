import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  Index,
  ManyToOne,
  JoinColumn,
  VersionColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

/**
 * 钱包交易类型枚举
 */
export enum WalletTransactionType {
  INCOME = 'income', // 收入
  EXPENSE = 'expense', // 支出
  FREEZE = 'freeze', // 冻结
  UNFREEZE = 'unfreeze', // 解冻
}

/**
 * 钱包交易状态枚举
 */
export enum WalletTransactionStatus {
  PENDING = 'pending', // 待审核
  APPROVED = 'approved', // 已审核
  REJECTED = 'rejected', // 已拒绝
}

/**
 * 关联类型枚举
 */
export enum RelatedType {
  ORDER = 'order', // 订单
  REFUND = 'refund', // 退款
  RECHARGE = 'recharge', // 充值
  WITHDRAW = 'withdraw', // 提现
  CHARITY = 'charity', // 公益捐款
  ADJUSTMENT = 'adjustment', // 平台余额调整
}

/**
 * 钱包明细表
 * 记录用户钱包的所有变动
 */
@Entity('wallet_transactions', { comment: '钱包明细表' })
@Index(['userId'])
@Index(['relatedType'])
@Index(['relatedId'])
@Index(['status'])
@Index(['createdAt'])
export class WalletTransaction {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '用户ID' })
  userId: number;

  @Column({
    type: 'enum',
    enum: WalletTransactionType,
    comment: '交易类型',
  })
  type: WalletTransactionType;

  @Column({ type: 'decimal', precision: 10, scale: 2, comment: '金额' })
  amount: number;

  @Column({ type: 'decimal', precision: 10, scale: 2, comment: '变动前余额' })
  balanceBefore: number;

  @Column({ type: 'decimal', precision: 10, scale: 2, comment: '变动后余额' })
  balanceAfter: number;

  @Column({
    type: 'enum',
    enum: RelatedType,
    comment: '关联类型',
  })
  relatedType: RelatedType;

  @Column({ comment: '关联ID（如订单ID）' })
  relatedId: number;

  @Column({
    type: 'enum',
    enum: WalletTransactionStatus,
    default: WalletTransactionStatus.PENDING,
    comment: '状态',
  })
  status: WalletTransactionStatus;

  @Column({ type: 'text', nullable: true, comment: '备注' })
  remark: string;

  @Column({ type: 'decimal', precision: 10, scale: 2, default: 0, comment: '冻结金额（审核拒绝时）' })
  frozenAmount: number;

  @Column({ type: 'text', nullable: true, comment: '拒绝原因' })
  rejectReason: string;

  @Column({ type: 'datetime', nullable: true, comment: '审核时间' })
  reviewedAt: Date;

  @Column({ type: 'int', nullable: true, comment: '审核人ID（管理员ID）' })
  reviewedBy: number;

  @Column({ type: 'tinyint', default: 0, comment: '是否自动处理（0=手动，1=自动）' })
  autoProcessed: boolean;

  // ========== 乐观锁 ==========

  @VersionColumn({ comment: '版本号（乐观锁，防止并发修改）' })
  version: number;

  // ========== 关联关系 ==========

  @ManyToOne(() => User)
  @JoinColumn({ name: 'userId' })
  user: User;

  // ========== 时间戳 ==========

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;
}
