import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from "typeorm";

/** 医生主动延长咨询服务的审计记录。 */
@Index(["conversationId", "createdAt"])
@Index(["idempotencyKey"], { unique: true })
@Entity("chat_session_extensions", { comment: "聊天会话延长记录" })
export class ChatSessionExtension {
  @PrimaryGeneratedColumn({ comment: "主键ID" })
  id: number;

  @Column({ comment: "会话ID" })
  sessionId: number;

  @Column({ type: "varchar", length: 36, comment: "会话级唯一标识" })
  conversationId: string;

  @Column({ comment: "关联订单ID" })
  orderId: number;

  @Column({ comment: "医生ID" })
  doctorId: number;

  @Column({ comment: "用户ID" })
  userId: number;

  @Column({ type: "int", comment: "延长时长（分钟）" })
  extensionMinutes: number;

  @Column({ type: "timestamp", comment: "延长前服务结束时间" })
  beforeServiceEndAt: Date;

  @Column({ type: "timestamp", comment: "延长后服务结束时间" })
  afterServiceEndAt: Date;

  @Column({ type: "varchar", length: 500, nullable: true, comment: "延长原因" })
  reason?: string;

  @Column({ type: "varchar", length: 128, comment: "客户端幂等键" })
  idempotencyKey: string;

  @CreateDateColumn({ comment: "延长时间" })
  createdAt: Date;
}
