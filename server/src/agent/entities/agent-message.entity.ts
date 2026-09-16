import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from "typeorm";
import type { AgentIntent } from "../agent.service";

@Entity("agent_messages", { comment: "Agent 会话消息与路由结果" })
@Index(["sessionId", "createdAt"])
@Index(["userId", "createdAt"])
export class AgentMessage {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: "varchar", length: 36 })
  sessionId: string;

  @Column()
  userId: number;

  @Column({ type: "enum", enum: ["USER", "AGENT"] })
  role: "USER" | "AGENT";

  @Column({ type: "text" })
  content: string;

  @Column({ type: "varchar", length: 20, nullable: true })
  intent?: AgentIntent;

  @Column({ type: "json", nullable: true })
  destination?: Record<string, unknown>;

  @CreateDateColumn()
  createdAt: Date;
}
