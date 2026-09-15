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

@Entity("user_blocks", { comment: "用户屏蔽关系表" })
@Index("UQ_user_blocks_pair", ["blockerId", "blockedUserId"], {
  unique: true,
})
@Index("IDX_user_blocks_blocked_user", ["blockedUserId"])
export class UserBlock {
  @PrimaryGeneratedColumn({ comment: "主键ID" })
  id: number;

  @Column({ type: "int", comment: "屏蔽人ID" })
  blockerId: number;

  @ManyToOne(() => User, { createForeignKeyConstraints: false })
  @JoinColumn({ name: "blockerId" })
  blocker?: User;

  @Column({ type: "int", comment: "被屏蔽用户ID" })
  blockedUserId: number;

  @ManyToOne(() => User, { createForeignKeyConstraints: false })
  @JoinColumn({ name: "blockedUserId" })
  blockedUser?: User;

  @Column({ type: "varchar", length: 200, nullable: true, comment: "屏蔽原因" })
  reason?: string | null;

  @CreateDateColumn({ comment: "创建时间" })
  createdAt: Date;
}
