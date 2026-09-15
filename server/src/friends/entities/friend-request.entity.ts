import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

/**
 * 好友申请状态枚举
 */
export enum FriendRequestStatus {
  PENDING = 'pending', // 待处理
  ACCEPTED = 'accepted', // 已接受
  REJECTED = 'rejected', // 已拒绝
  EXPIRED = 'expired', // 已过期
}

/**
 * 好友申请实体
 * 存储用户之间的好友申请记录
 *
 * 业务规则：
 * - 申请有效期为 7 天
 * - 使用唯一索引防止重复申请
 * - 过期申请由定时任务自动标记为 expired
 */
@Entity('friend_requests', { comment: '好友申请表' })
@Index(['receiverId', 'status', 'createdAt']) // 用于接收人查询未处理申请
@Index(['requesterId', 'receiverId'], { unique: true }) // 防止重复申请
@Index(['expiresAt', 'status']) // 用于定时清理过期申请
export class FriendRequest {
  @PrimaryGeneratedColumn({ type: 'bigint', comment: '主键' })
  id: number;

  /**
   * 申请人ID
   */
  @Column({ type: 'int', comment: '申请人ID' })
  requesterId: number;

  /**
   * 接收人ID
   */
  @Column({ type: 'int', comment: '接收人ID' })
  receiverId: number;

  /**
   * 申请附言（最多50字符）
   */
  @Column({ type: 'varchar', length: 50, nullable: true, comment: '申请附言（最多50字符）' })
  message: string;

  /**
   * 申请状态
   */
  @Column({
    type: 'enum',
    enum: FriendRequestStatus,
    default: FriendRequestStatus.PENDING,
    comment: '申请状态（pending:待处理, accepted:已接受, rejected:已拒绝, expired:已过期）',
  })
  status: FriendRequestStatus;

  /**
   * 拒绝原因（可选）
   */
  @Column({ type: 'varchar', length: 200, nullable: true, comment: '拒绝原因' })
  rejectionReason: string;

  /**
   * 过期时间（创建时间 + 7天）
   */
  @Column({ type: 'timestamp', comment: '过期时间（创建时间+7天）' })
  expiresAt: Date;

  /**
   * 创建时间
   */
  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  /**
   * 更新时间
   */
  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;

  /**
   * 关联申请人实体
   */
  @ManyToOne(() => User, { nullable: false })
  @JoinColumn({ name: 'requesterId' })
  requester: User;

  /**
   * 关联接收人实体
   */
  @ManyToOne(() => User, { nullable: false })
  @JoinColumn({ name: 'receiverId' })
  receiver: User;
}
