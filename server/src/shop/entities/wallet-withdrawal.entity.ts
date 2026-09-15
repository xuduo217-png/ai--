import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
  VersionColumn,
} from "typeorm";
import { User } from "../../users/entities/user.entity";
import { WalletTransaction } from "./wallet-transaction.entity";
import { WalletWithdrawalLog } from "./wallet-withdrawal-log.entity";

export enum WalletWithdrawalStatus {
  PENDING_REVIEW = "pending_review",
  PROCESSING = "processing",
  SUCCEEDED = "succeeded",
  REJECTED = "rejected",
  FAILED = "failed",
}

export enum WalletWithdrawalPayeeIdentityType {
  ALIPAY_LOGON_ID = "ALIPAY_LOGON_ID",
}

@Entity("wallet_withdrawals", { comment: "钱包提现单" })
@Index(["withdrawalNo"], { unique: true })
@Index(["userId", "idempotencyKey"], { unique: true })
@Index(["walletTransactionId"], { unique: true })
@Index(["outBizNo"], { unique: true })
@Index(["userId", "createdAt"])
@Index(["status", "updatedAt"])
export class WalletWithdrawal {
  @PrimaryGeneratedColumn({ comment: "主键ID" })
  id: number;

  @Column({ length: 40, comment: "提现单号" })
  withdrawalNo: string;

  @Column({ length: 36, comment: "客户端幂等键" })
  idempotencyKey: string;

  @Column({ comment: "提现用户ID" })
  userId: number;

  @Column({ nullable: true, comment: "关联钱包流水ID" })
  walletTransactionId: number | null;

  @Column({ type: "decimal", precision: 10, scale: 2, comment: "提现金额" })
  amount: number;

  @Column({
    type: "enum",
    enum: WalletWithdrawalStatus,
    default: WalletWithdrawalStatus.PENDING_REVIEW,
    comment: "提现状态",
  })
  status: WalletWithdrawalStatus;

  @Column({
    type: "enum",
    enum: WalletWithdrawalPayeeIdentityType,
    default: WalletWithdrawalPayeeIdentityType.ALIPAY_LOGON_ID,
    comment: "收款身份类型",
  })
  payeeIdentityType: WalletWithdrawalPayeeIdentityType;

  @Column({ type: "text", comment: "加密支付宝账号" })
  payeeAccountEncrypted: string;

  @Column({ length: 160, comment: "脱敏支付宝账号" })
  payeeAccountMasked: string;

  @Column({ type: "text", comment: "加密支付宝实名姓名" })
  payeeNameEncrypted: string;

  @Column({ length: 80, comment: "脱敏支付宝实名姓名" })
  payeeNameMasked: string;

  @Column({ length: 20, default: "v1", comment: "加密密钥版本" })
  encryptionKeyVersion: string;

  @Column({ length: 64, nullable: true, comment: "支付宝业务单号" })
  outBizNo: string | null;

  @Column({ length: 80, nullable: true, comment: "支付宝业务标识" })
  alipayOrderId: string | null;

  @Column({ length: 80, nullable: true, comment: "支付宝资金单号" })
  payFundOrderId: string | null;

  @Column({ length: 40, nullable: true, comment: "最近支付宝状态" })
  alipayStatus: string | null;

  @Column({ length: 80, nullable: true, comment: "失败码" })
  failureCode: string | null;

  @Column({ length: 500, nullable: true, comment: "脱敏失败原因" })
  failureMessage: string | null;

  @Column({ nullable: true, comment: "审核管理员ID" })
  reviewedBy: number | null;

  @Column({ type: "datetime", nullable: true, comment: "审核时间" })
  reviewedAt: Date | null;

  @Column({ type: "text", nullable: true, comment: "拒绝原因" })
  rejectReason: string | null;

  @Column({ type: "datetime", nullable: true, comment: "开始转账时间" })
  processingAt: Date | null;

  @Column({ type: "datetime", nullable: true, comment: "完成时间" })
  completedAt: Date | null;

  @Column({ type: "datetime", nullable: true, comment: "失败时间" })
  failedAt: Date | null;

  @VersionColumn({ comment: "乐观锁版本" })
  version: number;

  @ManyToOne(() => User)
  @JoinColumn({ name: "userId" })
  user: User;

  @ManyToOne(() => WalletTransaction, { nullable: true })
  @JoinColumn({ name: "walletTransactionId" })
  walletTransaction: WalletTransaction | null;

  @OneToMany(() => WalletWithdrawalLog, (log) => log.withdrawal)
  logs: WalletWithdrawalLog[];

  @CreateDateColumn({ comment: "创建时间" })
  createdAt: Date;

  @UpdateDateColumn({ comment: "更新时间" })
  updatedAt: Date;
}
