import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
} from 'typeorm';

/**
 * 验证码类型
 */
export enum VerificationCodeType {
  REGISTER = 'register', // 注册
  RESET_PASSWORD = 'reset_password', // 重置密码
  LOGIN = 'login', // 登录
}

/**
 * 短信验证码表
 * 存储短信验证码记录
 */
@Entity('verification_codes', { comment: '短信验证码表' })
export class VerificationCode {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '手机号' })
  phone: string;

  @Column({ comment: '验证码' })
  code: string;

  @Column({
    type: 'enum',
    enum: VerificationCodeType,
    comment: '验证码类型',
  })
  type: VerificationCodeType;

  @Column({ comment: '过期时间' })
  expiredAt: Date;

  @Column({ default: false, comment: '是否已使用' })
  used: boolean;

  @Column({ nullable: true, comment: '使用时间' })
  usedAt: Date;

  @CreateDateColumn({ name: 'createdAt', comment: '创建时间' })
  createdAt: Date;
}
