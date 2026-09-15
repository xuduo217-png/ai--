import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

/**
 * 审计操作类型
 */
export enum AuditAction {
  USER_CREATED = 'user_created', // 用户创建
  USER_UPDATED = 'user_updated', // 用户更新
  USER_DELETED = 'user_deleted', // 用户删除
  ROLE_CHANGED = 'role_changed', // 角色变更
  PASSWORD_RESET = 'password_reset', // 密码重置
  PASSWORD_CHANGED = 'password_changed', // 密码修改
}

/**
 * 审计日志表
 * 记录系统操作日志
 */
@Entity('audit_logs', { comment: '审计日志表' })
export class AuditLog {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '操作人ID' })
  userId: number;

  @ManyToOne(() => User)
  @JoinColumn()
  user: User;

  @Column({ comment: '目标用户ID' })
  targetUserId: number;

  @Column({
    type: 'enum',
    enum: AuditAction,
    comment: '操作类型',
  })
  action: AuditAction;

  @Column({ type: 'json', nullable: true, comment: '旧值（JSON格式）' })
  oldValues: Record<string, any>;

  @Column({ type: 'json', nullable: true, comment: '新值（JSON格式）' })
  newValues: Record<string, any>;

  @Column({ comment: 'IP地址' })
  ipAddress: string;

  @Column({ nullable: true, comment: '用户代理（浏览器信息）' })
  userAgent: string;

  @CreateDateColumn({ name: 'createdAt', comment: '创建时间' })
  createdAt: Date;
}
