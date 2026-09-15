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
// TODO: 等待 ai-diagnosis-report 模块创建完成后更新引用
// import { AiConsultation } from '../../ai-consultation/entities/ai-consultation.entity';
import { ChatOrder } from './chat-order.entity';

/**
 * 消息类型枚举
 */
export enum MessageType {
  TEXT = 'TEXT', // 文本消息
  IMAGE = 'IMAGE', // 图片消息
  VIDEO = 'VIDEO', // 视频消息
  VOICE = 'VOICE', // 语音消息
  AI_CONSULTATION = 'AI_CONSULTATION', // AI 问诊记录转发
  SYSTEM = 'SYSTEM', // 系统消息
  PAYMENT_SUCCESS = 'PAYMENT_SUCCESS', // 支付成功消息（医疗服务订单）
  PAYMENT_PROMPT = 'PAYMENT_PROMPT', // 付费提示消息（提示用户购买套餐）
}

/**
 * 消息状态枚举
 */
export enum MessageStatus {
  SENDING = 'SENDING', // 发送中
  SENT = 'SENT', // 已发送
  DELIVERED = 'DELIVERED', // 已送达
  READ = 'READ', // 已读
}

/**
 * 聊天消息表
 * 存储用户与医生之间的聊天消息
 */
@Index(['conversationId', 'createdAt'])
@Index(['senderId', 'receiverId'])
@Index(['senderId', 'createdAt'])
@Index(['aiConsultationId'])
@Index(['orderId']) // 用于按订单查询消息
@Entity('messages', { comment: '聊天消息表' })
export class Message {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ type: 'text', comment: '消息内容' })
  content: string;

  @Column({
    type: 'enum',
    enum: MessageType,
    default: MessageType.TEXT,
    comment: '消息类型',
  })
  type: MessageType;

  @Column({ default: false, comment: '是否已读' })
  isRead: boolean;

  @Column({ nullable: true, comment: '发送者ID' })
  senderId?: number;

  @Column({
    type: 'enum',
    enum: ['user', 'doctor'],
    nullable: true,
    comment: '发送者类型（user=普通用户, doctor=医生）',
  })
  senderType?: 'user' | 'doctor';

  @Column({ nullable: true, comment: '接收者ID' })
  receiverId?: number;

  @Column({
    type: 'enum',
    enum: ['user', 'doctor'],
    nullable: true,
    comment: '接收者类型（user=普通用户, doctor=医生）',
  })
  receiverType?: 'user' | 'doctor';

  @Column({ default: false, comment: '是否为自动回复' })
  isAutoReply: boolean;

  @Column({ default: false, comment: '是否已删除' })
  isDeleted: boolean;

  @Column({ default: false, comment: '是否已撤回' })
  isRevoked: boolean;

  @Column({ type: 'datetime', nullable: true, comment: '撤回时间' })
  revokedAt: Date | null;

  @Column({
    type: 'enum',
    enum: MessageStatus,
    default: MessageStatus.SENT,
    comment: '消息状态',
  })
  status: MessageStatus;

  @Column({ comment: '会话ID（用户ID_医生ID格式）' })
  conversationId: string;

  @Column({ type: 'int', nullable: true, comment: '关联AI问诊ID' })
  aiConsultationId?: number;

  @Column({ type: 'int', nullable: true, comment: '关联医疗服务订单ID' })
  orderId?: number;

  @Column({
    type: 'json',
    nullable: true,
    comment: '付费提示消息的套餐列表（仅 PAYMENT_PROMPT 类型使用）',
  })
  packages?: any[];

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;

  @ManyToOne(() => User, { nullable: true, createForeignKeyConstraints: false })
  @JoinColumn({ name: 'senderId' })
  sender?: User;

  @ManyToOne(() => User, { nullable: true, createForeignKeyConstraints: false })
  @JoinColumn({ name: 'receiverId' })
  receiver?: User;

  // TODO: 等待 ai-diagnosis-report 模块创建完成后更新引用
  // @ManyToOne(() => AiConsultation, { nullable: true })
  // @JoinColumn()
  // aiConsultation?: AiConsultation;

  @ManyToOne(() => ChatOrder, { nullable: true })
  @JoinColumn()
  order?: ChatOrder;
}
