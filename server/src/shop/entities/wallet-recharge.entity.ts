import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
  VersionColumn,
} from "typeorm";
import { User } from "../../users/entities/user.entity";
import { WalletTransaction } from "./wallet-transaction.entity";

export enum WalletRechargeStatus {
  PENDING = "pending",
  SUCCEEDED = "succeeded",
  FAILED = "failed",
  CLOSED = "closed",
}

@Entity("wallet_recharges", { comment: "钱包充值单" })
@Index(["rechargeNo"], { unique: true })
@Index(["userId", "idempotencyKey"], { unique: true })
@Index(["paymentNo"], { unique: true })
@Index(["walletTransactionId"], { unique: true })
@Index(["userId", "createdAt"])
@Index(["status", "updatedAt"])
export class WalletRecharge {
  @PrimaryGeneratedColumn({ comment: "主键ID" })
  id: number;

  @Column({ length: 40, comment: "充值单号" })
  rechargeNo: string;

  @Column({ length: 36, comment: "客户端幂等键" })
  idempotencyKey: string;

  @Column({ comment: "充值用户ID" })
  userId: number;

  @Column({ length: 80, nullable: true, comment: "关联支付单号" })
  paymentNo: string | null;

  @Column({ nullable: true, comment: "关联钱包流水ID" })
  walletTransactionId: number | null;

  @Column({ type: "decimal", precision: 10, scale: 2, comment: "充值金额" })
  amount: number;

  @Column({
    type: "enum",
    enum: WalletRechargeStatus,
    default: WalletRechargeStatus.PENDING,
    comment: "充值状态",
  })
  status: WalletRechargeStatus;

  @Column({ type: "datetime", nullable: true, comment: "支付过期时间" })
  expiredAt: Date | null;

  @Column({ type: "datetime", nullable: true, comment: "到账时间" })
  paidAt: Date | null;

  @Column({ type: "datetime", nullable: true, comment: "失败时间" })
  failedAt: Date | null;

  @Column({ type: "varchar", length: 500, nullable: true, comment: "失败原因" })
  failureMessage: string | null;

  @VersionColumn({ comment: "乐观锁版本" })
  version: number;

  @ManyToOne(() => User)
  @JoinColumn({ name: "userId" })
  user: User;

  @ManyToOne(() => WalletTransaction, { nullable: true })
  @JoinColumn({ name: "walletTransactionId" })
  walletTransaction: WalletTransaction | null;

  @CreateDateColumn({ comment: "创建时间" })
  createdAt: Date;

  @UpdateDateColumn({ comment: "更新时间" })
  updatedAt: Date;
}
