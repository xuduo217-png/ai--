import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";

import { MessageType } from "../../friends/entities/friend-message.entity";

@Entity("marketplace_messages", { comment: "二手商城聊天消息表" })
@Index("IDX_marketplace_message_conversation", ["conversationId", "createdAt"])
@Index("IDX_marketplace_message_sender", ["senderId", "createdAt"])
@Index("IDX_marketplace_message_unread", ["receiverId", "isRead", "createdAt"])
export class MarketplaceMessage {
  @PrimaryGeneratedColumn({ type: "bigint", comment: "主键ID" })
  id: number;

  @Column({ type: "varchar", length: 36, unique: true, comment: "消息UUID" })
  messageId: string;

  @Column({ type: "varchar", length: 36, comment: "会话UUID" })
  conversationId: string;

  @Column({ type: "int", comment: "发送人ID" })
  senderId: number;

  @Column({ type: "int", comment: "接收人ID" })
  receiverId: number;

  @Column({ type: "enum", enum: MessageType, comment: "消息类型" })
  messageType: MessageType;

  @Column({ type: "text", comment: "消息内容（文本或媒体JSON）" })
  content: string;

  @Column({
    type: "varchar",
    length: 500,
    nullable: true,
    comment: "媒体文件URL",
  })
  cloudFileUrl: string | null;

  @Column({ type: "tinyint", default: 0, comment: "是否已读" })
  isRead: number;

  @Column({ type: "tinyint", default: 0, comment: "是否已撤回" })
  isRevoked: number;

  @Column({ type: "datetime", nullable: true, comment: "撤回时间" })
  revokedAt: Date | null;

  @CreateDateColumn({ comment: "创建时间" })
  createdAt: Date;

  @UpdateDateColumn({ comment: "更新时间" })
  updatedAt: Date;
}
