import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  Index,
} from 'typeorm';

/**
 * 短信类型
 */
export enum SmsType {
  REGISTER = 'register', // 注册
  RESET_PASSWORD = 'reset_password', // 重置密码
  LOGIN = 'login', // 登录
}

/**
 * 短信状态
 */
export enum SmsStatus {
  PENDING = 'pending', // 待发送
  SENT = 'sent', // 已发送
  FAILED = 'failed', // 发送失败
  EXPIRED = 'expired', // 已过期
}

/**
 * 短信发送记录表
 * 记录所有短信发送历史
 */
@Entity('sms_records', { comment: '短信发送记录表' })
@Index(['phone'])
@Index(['type'])
@Index(['status'])
@Index(['sentAt'])
@Index(['phone', 'status'])
export class SmsRecord {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '手机号' })
  phone: string;

  @Column({
    type: 'enum',
    enum: SmsType,
    comment: '短信类型',
  })
  type: SmsType;

  @Column({
    type: 'enum',
    enum: SmsStatus,
    default: SmsStatus.PENDING,
    comment: '短信状态',
  })
  status: SmsStatus;

  @Column({ nullable: true, comment: '验证码（如果是验证码短信）' })
  code?: string;

  @Column({ comment: '短信模板ID' })
  templateId: string;

  @Column({ type: 'json', nullable: true, comment: '短信参数（JSON格式）' })
  params?: Record<string, any>;

  @Column({ type: 'text', nullable: true, comment: '错误信息' })
  errorMessage?: string;

  @Column({ nullable: true, comment: '第三方请求ID' })
  requestId?: string;

  @Column({ type: 'int', default: 0, comment: '重试次数' })
  retryCount: number;

  @CreateDateColumn({ name: 'sentAt', comment: '发送时间' })
  sentAt: Date;

  @Column({ type: 'timestamp', nullable: true, comment: '送达时间' })
  deliveredAt?: Date;

  @Column({ type: 'int', default: 300, comment: '有效期（秒）' })
  expiresIn: number;
}
