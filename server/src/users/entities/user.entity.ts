import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Exclude } from 'class-transformer';
import { Pet } from '../../pets/entities/pet.entity';
import { Hospital } from '../../hospitals/entities/hospital.entity';

export enum UserRole {
  SUPER_ADMIN = 'SUPER_ADMIN',
  HOSPITAL_ADMIN = 'HOSPITAL_ADMIN',
  STAFF = 'STAFF',
  // 移除 DOCTOR 角色 - 医生使用独立的认证系统
  USER = 'USER',
}

/**
 * 用户性别枚举
 */
export enum UserGender {
  UNKNOWN = 0, // 未知
  MALE = 1, // 男
  FEMALE = 2, // 女
}

@Index(['role'])
@Index(['hospitalId'])
@Entity('users', { comment: '用户表' })
export class User {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ unique: true, nullable: true, comment: '用户名（唯一）' })
  username: string;

  /**
   * 密码（加密存储）
   * 使用 @Exclude() 装饰器确保在序列化时不返回密码字段
   */
  @Exclude()
  @Column({ comment: '密码（加密存储）' })
  password: string;

  @Column({ unique: true, nullable: true, comment: '邮箱（唯一）' })
  email: string;

  @Column({
    type: 'enum',
    enum: UserRole,
    default: UserRole.USER,
    comment: '用户角色',
  })
  role: UserRole;

  @Column({ nullable: true, comment: '头像URL' })
  avatar: string;

  @Column({
    type: 'tinyint',
    default: UserGender.UNKNOWN,
    comment: '性别：0-未知，1-男，2-女',
  })
  gender: UserGender;

  @Column({ unique: true, nullable: false, comment: '手机号（必填，唯一）' })
  phone: string;

  @Column({ default: false, comment: '是否已验证' })
  verified: boolean;

  @Column({ nullable: true, comment: '最后登录时间' })
  lastLoginAt: Date;

  @Column({ default: true, comment: '是否激活' })
  isActive: boolean;

  // 关联医院（医院员工和医生）
  @ManyToOne(() => Hospital, { nullable: true })
  @JoinColumn({ name: 'hospitalId' })
  hospital?: Hospital;

  @Column({ nullable: true, comment: '关联医院ID' })
  hospitalId?: number;

  @Column({ type: 'text', nullable: true, comment: '备注' })
  remarks?: string;

  // ========== 钱包相关字段 ==========

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0,
    comment: '可用余额',
  })
  balance: number;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0,
    comment: '待审核余额',
  })
  pendingBalance: number;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0,
    comment: '提现处理中冻结余额',
  })
  withdrawalFrozenBalance: number;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;

  // 与宠物的关系（一个用户可以有多只宠物）
  @OneToMany(() => Pet, (pet) => pet.owner)
  pets: Pet[];
}
