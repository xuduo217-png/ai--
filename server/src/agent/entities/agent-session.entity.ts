import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";

@Entity("agent_sessions", { comment: "用户 Agent 会话" })
@Index(["userId", "updatedAt"])
@Index(["sessionId"], { unique: true })
export class AgentSession {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: "varchar", length: 36 })
  sessionId: string;

  @Column()
  userId: number;

  @Column({ type: "int", nullable: true })
  petId?: number;

  @Column({ type: "varchar", length: 80, default: "新对话" })
  title: string;

  @Column({ type: "varchar", length: 20, default: "ACTIVE" })
  status: "ACTIVE" | "ARCHIVED";

  @Column({ type: "timestamp", nullable: true })
  lastMessageAt?: Date;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
