import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from "typeorm";
import { User } from "../../users/entities/user.entity";

/**
 * 好友聊天拉黑关系。
 * 该状态只影响好友私聊和好友关系互动，不参与社区等公开内容过滤。
 */
@Entity("friend_chat_blocks", { comment: "好友聊天拉黑关系表" })
@Index("UQ_friend_chat_blocks_pair", ["blockerUserId", "blockedUserId"], {
  unique: true,
})
@Index("IDX_friend_chat_blocks_blocked_user", ["blockedUserId"])
export class FriendChatBlock {
  @PrimaryGeneratedColumn({ type: "bigint", comment: "主键ID" })
  id: number;

  @Column({ type: "int", comment: "拉黑人ID" })
  blockerUserId: number;

  @ManyToOne(() => User, { createForeignKeyConstraints: false })
  @JoinColumn({ name: "blockerUserId" })
  blockerUser?: User;

  @Column({ type: "int", comment: "被拉黑用户ID" })
  blockedUserId: number;

  @ManyToOne(() => User, { createForeignKeyConstraints: false })
  @JoinColumn({ name: "blockedUserId" })
  blockedUser?: User;

  @CreateDateColumn({ comment: "拉黑时间" })
  createdAt: Date;
}
