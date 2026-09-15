import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  JoinColumn,
  ManyToOne,
  Index,
} from "typeorm";
import { User } from "../../users/entities/user.entity";

/**
 * 社区关注实体
 * 关注关系是单向关系，与好友体系完全独立，只服务社区内容分发。
 */
@Entity("community_follows", { comment: "社区关注关系表" })
@Index(["followerId", "followingId"], { unique: true })
@Index(["followerId", "createdAt"])
@Index(["followingId", "createdAt"])
export class CommunityFollow {
  @PrimaryGeneratedColumn({ comment: "主键ID" })
  id: number;

  /**
   * 关注者ID
   */
  @Column({ type: "int", comment: "关注者ID" })
  followerId: number;

  /**
   * 被关注者ID
   */
  @Column({ type: "int", comment: "被关注者ID" })
  followingId: number;

  /**
   * 关注者实体
   */
  @ManyToOne(() => User, { nullable: false, onDelete: "CASCADE" })
  @JoinColumn({ name: "followerId" })
  follower: User;

  /**
   * 被关注者实体
   */
  @ManyToOne(() => User, { nullable: false, onDelete: "CASCADE" })
  @JoinColumn({ name: "followingId" })
  following: User;

  /**
   * 创建时间
   * 关注流和关注列表都依赖该时间排序。
   */
  @CreateDateColumn({ comment: "创建时间" })
  createdAt: Date;
}
