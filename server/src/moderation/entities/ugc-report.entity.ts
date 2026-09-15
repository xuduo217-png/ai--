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
import { User } from "../../users/entities/user.entity";

export enum ReportTargetType {
  COMMUNITY_POST = "COMMUNITY_POST",
  COMMUNITY_COMMENT = "COMMUNITY_COMMENT",
  LOST_FOUND_RECORD = "LOST_FOUND_RECORD",
  LOST_FOUND_COMMENT = "LOST_FOUND_COMMENT",
  ACTIVITY_COMMENT = "ACTIVITY_COMMENT",
  ACTIVITY_VOTE_OPTION = "ACTIVITY_VOTE_OPTION",
  SECOND_HAND_PRODUCT = "SECOND_HAND_PRODUCT",
  CHAT_MESSAGE = "CHAT_MESSAGE",
  MARKETPLACE_MESSAGE = "MARKETPLACE_MESSAGE",
  USER = "USER",
}

export enum ReportReason {
  HARASSMENT = "HARASSMENT",
  PORNOGRAPHY = "PORNOGRAPHY",
  VIOLENCE = "VIOLENCE",
  FRAUD = "FRAUD",
  SPAM = "SPAM",
  ILLEGAL = "ILLEGAL",
  MISINFORMATION = "MISINFORMATION",
  OTHER = "OTHER",
}

export enum ReportStatus {
  PENDING = "PENDING",
  PROCESSING = "PROCESSING",
  RESOLVED = "RESOLVED",
  REJECTED = "REJECTED",
}

export enum ReportAction {
  NONE = "NONE",
  CONTENT_REMOVED = "CONTENT_REMOVED",
  USER_WARNED = "USER_WARNED",
  USER_BLOCKED = "USER_BLOCKED",
  ACCOUNT_DISABLED = "ACCOUNT_DISABLED",
}

export interface ReportTargetSnapshot {
  title?: string;
  summary?: string;
  images?: string[];
  author?: {
    id: number;
    nickname: string;
    avatar?: string | null;
  };
  metadata?: Record<string, unknown>;
}

@Entity("ugc_reports", { comment: "UGC 举报记录表" })
@Index("IDX_ugc_reports_reporter_target", [
  "reporterId",
  "targetType",
  "targetId",
])
@Index("IDX_ugc_reports_target", ["targetType", "targetId"])
@Index("IDX_ugc_reports_status_created", ["status", "createdAt"])
@Index("IDX_ugc_reports_target_user", ["targetUserId"])
export class UGCReport {
  @PrimaryGeneratedColumn({ comment: "主键ID" })
  id: number;

  @Column({ type: "int", comment: "举报人ID" })
  reporterId: number;

  @ManyToOne(() => User, { createForeignKeyConstraints: false })
  @JoinColumn({ name: "reporterId" })
  reporter?: User;

  @Column({
    type: "enum",
    enum: ReportTargetType,
    comment: "举报目标类型",
  })
  targetType: ReportTargetType;

  @Column({ type: "varchar", length: 64, comment: "举报目标ID" })
  targetId: string;

  @Column({ type: "int", nullable: true, comment: "被举报用户ID" })
  targetUserId?: number | null;

  @ManyToOne(() => User, { createForeignKeyConstraints: false })
  @JoinColumn({ name: "targetUserId" })
  targetUser?: User;

  @Column({
    type: "enum",
    enum: ReportReason,
    comment: "举报原因",
  })
  reason: ReportReason;

  @Column({ type: "varchar", length: 500, nullable: true, comment: "补充说明" })
  description?: string | null;

  @Column({ type: "json", nullable: true, comment: "目标内容快照" })
  targetSnapshot?: ReportTargetSnapshot | null;

  @Column({
    type: "enum",
    enum: ReportStatus,
    default: ReportStatus.PENDING,
    comment: "处理状态",
  })
  status: ReportStatus;

  @Column({
    type: "enum",
    enum: ReportAction,
    default: ReportAction.NONE,
    comment: "处理动作",
  })
  action: ReportAction;

  @Column({ type: "int", nullable: true, comment: "处理人ID" })
  handledBy?: number | null;

  @ManyToOne(() => User, { createForeignKeyConstraints: false })
  @JoinColumn({ name: "handledBy" })
  handler?: User;

  @Column({ type: "varchar", length: 500, nullable: true, comment: "处理备注" })
  handlingRemark?: string | null;

  @Column({ type: "timestamp", nullable: true, comment: "处理时间" })
  handledAt?: Date | null;

  @CreateDateColumn({ comment: "创建时间" })
  createdAt: Date;

  @UpdateDateColumn({ comment: "更新时间" })
  updatedAt: Date;
}
