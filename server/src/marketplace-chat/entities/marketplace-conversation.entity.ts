import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";

import { MessageType } from "../../friends/entities/friend-message.entity";
import { Product } from "../../shop/entities/product.entity";
import { User } from "../../users/entities/user.entity";

@Entity("marketplace_conversations", { comment: "二手商城买卖双方会话表" })
@Index(
  "UQ_marketplace_conversation_participants",
  ["productId", "buyerId", "sellerId"],
  { unique: true },
)
@Index("IDX_marketplace_conversation_buyer", ["buyerId", "lastMessageAt"])
@Index("IDX_marketplace_conversation_seller", ["sellerId", "lastMessageAt"])
export class MarketplaceConversation {
  @PrimaryGeneratedColumn({ type: "bigint", comment: "主键ID" })
  id: number;

  @Column({ type: "varchar", length: 36, unique: true, comment: "会话UUID" })
  conversationId: string;

  @Column({ type: "int", comment: "商品ID" })
  productId: number;

  @Column({ type: "int", comment: "买家ID" })
  buyerId: number;

  @Column({ type: "int", comment: "卖家ID" })
  sellerId: number;

  @Column({
    type: "varchar",
    length: 36,
    nullable: true,
    comment: "最后一条消息UUID",
  })
  lastMessageId: string | null;

  @Column({
    type: "enum",
    enum: MessageType,
    nullable: true,
    comment: "最后一条消息类型",
  })
  lastMessageType: MessageType | null;

  @Column({ type: "text", nullable: true, comment: "最后一条消息内容" })
  lastMessageContent: string | null;

  @Column({ type: "int", nullable: true, comment: "最后一条消息发送人ID" })
  lastMessageSenderId: number | null;

  @Column({ type: "timestamp", nullable: true, comment: "最后消息时间" })
  lastMessageAt: Date | null;

  @ManyToOne(() => Product, { createForeignKeyConstraints: false })
  @JoinColumn({ name: "productId" })
  product?: Product;

  @ManyToOne(() => User, { createForeignKeyConstraints: false })
  @JoinColumn({ name: "buyerId" })
  buyer?: User;

  @ManyToOne(() => User, { createForeignKeyConstraints: false })
  @JoinColumn({ name: "sellerId" })
  seller?: User;

  @CreateDateColumn({ comment: "创建时间" })
  createdAt: Date;

  @UpdateDateColumn({ comment: "更新时间" })
  updatedAt: Date;
}
