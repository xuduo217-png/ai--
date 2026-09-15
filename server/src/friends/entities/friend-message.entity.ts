import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

/**
 * 消息类型枚举
 */
export enum MessageType {
  TEXT = 'text', // 文字消息
  IMAGE = 'image', // 图片消息
  VOICE = 'voice', // 语音消息
  VIDEO = 'video', // 视频消息
}

/**
 * 好友消息实体
 * 存储所有好友之间的消息记录（永久保存）
 *
 * 业务规则：
 * - 消息永久保存，不过期，供 Admin 监管和审计
 * - 云端文件（图片/语音）30 天后自动清理
 * - 文字消息直接存储在 content 字段
 * - 图片/语音消息存储 JSON 格式（包含 URL、尺寸/时长等）
 */
@Entity('friend_messages', { comment: '好友消息记录表（永久保存，供Admin查看）' })
@Index(['conversationId', 'createdAt']) // 用于会话消息查询
@Index(['senderId', 'createdAt']) // 用于发送人消息查询
@Index(['receiverId', 'createdAt']) // 用于接收人消息查询
@Index(['createdAt']) // 用于全局消息查询
@Index(['messageType', 'createdAt']) // 用于按消息类型统计
@Index(['receiverId', 'isRead', 'createdAt']) // 用于未读消息统计
export class FriendMessage {
  @PrimaryGeneratedColumn({ type: 'bigint', comment: '主键' })
  id: number;

  /**
   * 消息唯一ID（UUID）
   * 用于客户端去重和 ACK 确认
   */
  @Column({ type: 'varchar', length: 36, unique: true, comment: '消息唯一ID（UUID）' })
  messageId: string;

  /**
   * 会话ID
   * 格式：小ID_大ID（如 123_456）
   * 确保同一对好友的会话ID唯一
   */
  @Column({ type: 'varchar', length: 50, comment: '会话ID（userA_userId 格式，小的在前）' })
  conversationId: string;

  /**
   * 发送人ID
   */
  @Column({ type: 'int', comment: '发送人ID' })
  senderId: number;

  /**
   * 接收人ID
   */
  @Column({ type: 'int', comment: '接收人ID' })
  receiverId: number;

  /**
   * 消息类型
   */
  @Column({
    type: 'enum',
    enum: MessageType,
    comment: '消息类型（text:文字, image:图片, voice:语音）',
  })
  messageType: MessageType;

  /**
   * 消息内容
   * - 文字消息：直接存储文本内容
   * - 图片消息：存储 JSON {url, width, height}
   * - 语音消息：存储 JSON {url, duration}
   * - 视频消息：存储 JSON {url, thumbnail, width, height, duration, size, fileName, mimeType}
   */
  @Column({ type: 'text', comment: '消息内容（JSON或文本）' })
  content: string;

  /**
   * 云端文件URL（仅图片/语音）
   * 30 天后可能已过期
   */
  @Column({ type: 'varchar', length: 500, nullable: true, comment: '云端文件URL（仅图片/语音）' })
  cloudFileUrl: string;

  /**
   * 是否已读
   */
  @Column({ type: 'tinyint', default: 0, comment: '是否已读（0:未读, 1:已读）' })
  isRead: number;

  @Column({ type: 'tinyint', default: 0, comment: '是否已撤回（0:否, 1:是）' })
  isRevoked: number;

  @Column({ type: 'datetime', nullable: true, comment: '撤回时间' })
  revokedAt: Date | null;

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
}
