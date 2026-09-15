import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from "typeorm";
import { User } from "../../users/entities/user.entity";
import { Doctor } from "../../doctors/entities/doctor.entity";
import { ChatOrder } from "./chat-order.entity";

/**
 * 会话状态枚举
 */
export enum SessionStatus {
  FREE = "FREE", // 免费会话
  PAID = "PAID", // 付费会话
  EXPIRED = "EXPIRED", // 已过期
}

/**
 * 聊天会话表
 * 记录用户与医生的聊天会话状态
 *
 * 注意：同一时刻同一个用户和医生只能有一个未结束的会话（FREE 或 PAID 未过期）
 * 服务结束后会创建新会话，因此移除了 userId + doctorId 的唯一约束
 */
@Index(["userId", "doctorId"]) // 移除 unique 约束，允许多个会话（历史记录）
@Index(["userId"])
@Index(["doctorId"])
@Index(["orderId"])
@Index("uk_chat_sessions_conversation_id", ["conversationId"], { unique: true })
@Index(["userId", "doctorId", "status", "serviceEndAt"]) // 用于查询活跃会话
@Entity("chat_sessions", { comment: "聊天会话表" })
export class ChatSession {
  @PrimaryGeneratedColumn({ comment: "主键ID" })
  id: number;

  @Column({ comment: "用户ID" })
  userId: number;

  @Column({ comment: "医生ID" })
  doctorId: number;

  @Column({
    type: "varchar",
    length: 36,
    comment: "会话级唯一标识",
  })
  conversationId: string;

  @Column({
    type: "enum",
    enum: SessionStatus,
    default: SessionStatus.FREE,
    comment: "会话状态",
  })
  status: SessionStatus;

  @Column({ type: "int", default: 0, comment: "已使用自动回复次数" })
  autoReplyCount: number;

  @Column({ type: "int", default: 3, comment: "最大免费自动回复次数" })
  maxFreeReplies: number;

  @Column({ type: "int", nullable: true, comment: "关联订单ID" })
  orderId?: number;

  @Column({ type: "timestamp", nullable: true, comment: "服务开始时间" })
  serviceStartAt?: Date;

  @Column({ type: "timestamp", nullable: true, comment: "服务结束时间" })
  serviceEndAt?: Date;

  @Column({ type: "timestamp", nullable: true, comment: "最后消息时间" })
  lastMessageAt?: Date;

  @Column({ type: "timestamp", nullable: true, comment: "最后自动回复时间" })
  lastAutoReplyAt?: Date;

  @CreateDateColumn({ comment: "创建时间" })
  createdAt: Date;

  @UpdateDateColumn({ comment: "更新时间" })
  updatedAt: Date;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn()
  user?: User;

  @ManyToOne(() => Doctor, { nullable: true })
  @JoinColumn()
  doctor?: Doctor;

  @ManyToOne(() => ChatOrder, { nullable: true })
  @JoinColumn()
  order?: ChatOrder;
}
