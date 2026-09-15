import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  JoinColumn,
  ManyToOne,
  Index,
} from "typeorm";
import { User } from "../../users/entities/user.entity";

/**
 * 社区资料实体
 * 仅存放社区公开资料，避免社区页面继续直接复用通用用户资料。
 */
@Entity("community_profiles", { comment: "社区公开资料表" })
@Index(["userId"], { unique: true })
export class CommunityProfile {
  @PrimaryGeneratedColumn({ comment: "主键ID" })
  id: number;

  /**
   * 用户ID
   */
  @Column({ type: "int", comment: "用户ID" })
  userId: number;

  /**
   * 关联用户实体
   */
  @ManyToOne(() => User, { nullable: false, onDelete: "CASCADE" })
  @JoinColumn({ name: "userId" })
  user: User;

  /**
   * 社区简介
   * 用于社区主页展示的公开文案，不与通用用户资料强耦合。
   */
  @Column({ type: "varchar", length: 200, nullable: true, comment: "社区简介" })
  bio?: string | null;

  /**
   * 社区主页封面图
   */
  @Column({
    type: "varchar",
    length: 500,
    nullable: true,
    comment: "社区主页封面图",
  })
  coverImage?: string | null;

  /**
   * 创建时间
   */
  @CreateDateColumn({ comment: "创建时间" })
  createdAt: Date;

  /**
   * 更新时间
   */
  @UpdateDateColumn({ comment: "更新时间" })
  updatedAt: Date;
}
