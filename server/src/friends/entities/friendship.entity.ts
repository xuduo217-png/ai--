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
 * 好友关系方向枚举
 * 用于标识谁主动添加谁
 */
export enum FriendshipDirection {
  SENT = 'sent', // 主动添加（我添加了对方）
  RECEIVED = 'received', // 被动添加（对方添加了我）
}

/**
 * 好友关系实体
 * 存储用户之间的双向好友关系
 *
 * 业务规则：
 * - 每对好友关系会创建两条记录（双向）
 * - 使用唯一索引防止重复添加
 * - direction 字段标识谁主动添加谁
 */
@Entity('friendships', { comment: '好友关系表' })
@Index(['userId', 'friendId'], { unique: true }) // 防止重复添加好友
@Index(['userId', 'lastChatAt']) // 用于会话列表排序
@Index(['friendId']) // 用于查询好友关系
export class Friendship {
  @PrimaryGeneratedColumn({ type: 'bigint', comment: '主键' })
  id: number;

  /**
   * 用户ID（关系的拥有者）
   */
  @Column({ type: 'int', comment: '用户ID' })
  userId: number;

  /**
   * 好友ID
   */
  @Column({ type: 'int', comment: '好友ID' })
  friendId: number;

  /**
   * 关系方向
   * sent: 我主动添加对方
   * received: 对方主动添加我
   */
  @Column({
    type: 'enum',
    enum: FriendshipDirection,
    comment: '关系方向（sent:主动添加, received:被动添加）',
  })
  direction: FriendshipDirection;

  /**
   * 备注名（用户给好友设置的备注）
   */
  @Column({ type: 'varchar', length: 100, nullable: true, comment: '备注名' })
  remark: string;

  /**
   * 最后聊天时间
   * 用于会话列表排序
   */
  @Column({ type: 'timestamp', nullable: true, comment: '最后聊天时间（用于会话排序）' })
  lastChatAt: Date;

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
   * 关联用户实体
   */
  @ManyToOne(() => User, { nullable: false })
  @JoinColumn({ name: 'userId' })
  user: User;

  /**
   * 关联好友实体
   */
  @ManyToOne(() => User, { nullable: false })
  @JoinColumn({ name: 'friendId' })
  friend: User;
}
