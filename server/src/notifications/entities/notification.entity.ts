import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

/**
 * 消息类型枚举
 */
export enum NotificationType {
  SYSTEM = 'system',           // 系统通知
  ANNOUNCEMENT = 'announcement', // 公告资讯
  INTERACTION = 'interaction',   // 互动消息
}

/**
 * 跳转类型枚举
 */
export enum ActionType {
  NONE = 'none',              // 无操作
  PAGE = 'page',              // 跳转到页面
  URL = 'url',                // 打开 URL
  ORDER = 'order',            // 跳转到订单详情
  APPOINTMENT = 'appointment', // 跳转到预约详情
}

/**
 * 通知(Notification)实体
 *
 * 用于管理用户站内信，支持系统自动触发的各类通知消息
 */
@Entity('notifications', { comment: '站内信表' })
@Index(['userId'])
@Index(['userId', 'createdAt'])
@Index(['userId', 'isRead'])
export class Notification {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ type: 'int', comment: '接收用户ID' })
  userId: number;

  @Column({
    type: 'enum',
    enum: NotificationType,
    comment: '消息类型',
  })
  type: NotificationType;

  @Column({ length: 200, comment: '消息标题' })
  title: string;

  @Column({ type: 'text', comment: '消息描述/内容' })
  content: string;

  @Column({ type: 'boolean', default: false, comment: '是否已读' })
  isRead: boolean;

  @Column({
    type: 'enum',
    enum: ActionType,
    default: ActionType.NONE,
    comment: '跳转类型',
  })
  actionType: ActionType;

  @Column({ type: 'json', nullable: true, comment: '跳转参数（JSON格式）' })
  actionData: Record<string, any>;

  @Column({ type: 'int', default: 0, comment: '优先级（预留字段）' })
  priority: number;

  @Column({ type: 'bigint', comment: '创建时间（时间戳，毫秒）' })
  createdAt: number;

  @Column({ type: 'bigint', comment: '更新时间（时间戳，毫秒）' })
  updatedAt: number;

  @Column({ type: 'bigint', nullable: true, comment: '已读时间（时间戳，毫秒）' })
  readAt: number;

  // ==================== 关联关系 ====================

  /**
   * 关联用户
   */
  @ManyToOne(() => User, { eager: false })
  @JoinColumn({ name: 'userId' })
  user: User;

  // ==================== 额外字段（不保存到数据库） ====================

  /**
   * 用户名称（用于查询时返回）
   */
  userName?: string;
}
