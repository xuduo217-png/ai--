import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from "typeorm";
import {
  WalletWithdrawal,
  WalletWithdrawalStatus,
} from "./wallet-withdrawal.entity";

export enum WalletWithdrawalActorType {
  USER = "user",
  ADMIN = "admin",
  SYSTEM = "system",
}

@Entity("wallet_withdrawal_logs", { comment: "钱包提现状态日志" })
@Index(["withdrawalId", "createdAt"])
export class WalletWithdrawalLog {
  @PrimaryGeneratedColumn({ comment: "主键ID" })
  id: number;

  @Column({ comment: "提现单ID" })
  withdrawalId: number;

  @Column({ type: "varchar", length: 30, nullable: true, comment: "原状态" })
  fromStatus: WalletWithdrawalStatus | null;

  @Column({ type: "varchar", length: 30, comment: "新状态" })
  toStatus: WalletWithdrawalStatus;

  @Column({ length: 50, comment: "动作" })
  action: string;

  @Column({ type: "enum", enum: WalletWithdrawalActorType, comment: "操作者类型" })
  actorType: WalletWithdrawalActorType;

  @Column({ nullable: true, comment: "操作者ID" })
  actorId: number | null;

  @Column({ length: 80, nullable: true, comment: "外部状态码" })
  externalCode: string | null;

  @Column({ length: 500, nullable: true, comment: "脱敏说明" })
  description: string | null;

  @ManyToOne(() => WalletWithdrawal, (withdrawal) => withdrawal.logs)
  @JoinColumn({ name: "withdrawalId" })
  withdrawal: WalletWithdrawal;

  @CreateDateColumn({ comment: "创建时间" })
  createdAt: Date;
}
