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
 * 登录方式
 */
export enum LoginMethod {
  PHONE_PASSWORD = 'phone_password', // 手机号+密码
  PHONE_SMS = 'phone_sms', // 手机号+短信验证码
}

/**
 * 登录状态
 */
export enum LoginStatus {
  SUCCESS = 'success', // 成功
  FAILED = 'failed', // 失败
}

/**
 * 登录历史表
 * 记录用户登录历史
 */
@Entity('login_histories', { comment: '登录历史表' })
export class LoginHistory {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '用户ID' })
  userId: number;

  @ManyToOne(() => User)
  @JoinColumn()
  user: User;

  @Column({ comment: 'IP地址' })
  ipAddress: string;

  @Column({ nullable: true, comment: '用户代理（浏览器信息）' })
  userAgent: string;

  @Column({
    type: 'enum',
    enum: LoginMethod,
    comment: '登录方式',
  })
  loginMethod: LoginMethod;

  @Column({
    type: 'enum',
    enum: LoginStatus,
    default: LoginStatus.SUCCESS,
    comment: '登录状态',
  })
  status: LoginStatus;

  @Column({ nullable: true, comment: '失败原因' })
  failureReason: string;

  @CreateDateColumn({ name: 'loginAt', comment: '登录时间' })
  loginAt: Date;
}
