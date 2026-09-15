import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  Index,
} from 'typeorm';

/**
 * 医院状态
 */
export enum HospitalStatus {
  ACTIVE = 'active', // 营业中
  INACTIVE = 'inactive', // 未营业
  SUSPENDED = 'suspended', // 暂停营业
}

/**
 * 医院表
 * 存储宠物医院的基本信息
 */
@Entity('hospitals', { comment: '医院表' })
@Index(['status'])
@Index(['name'])
@Index(['city'])
@Index(['deletedAt'])
export class Hospital {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '医院名称' })
  name: string;

  @Column({ nullable: true, comment: '医院Logo' })
  logo: string;

  @Column({ type: 'text', nullable: true, comment: '医院描述' })
  description: string;

  @Column({ comment: '省份' })
  province: string;

  @Column({ comment: '城市' })
  city: string;

  @Column({ comment: '区/县' })
  county: string;

  @Column({ type: 'text', comment: '详细地址' })
  address: string;

  @Column({ comment: '联系电话' })
  phone: string;

  @Column({ nullable: true, comment: '邮箱' })
  email: string;

  @Column({ type: 'json', nullable: true, comment: '营业时间（JSON格式）' })
  businessHours?: {
    monday?: { open: string; close: string; isClosed: boolean };
    tuesday?: { open: string; close: string; isClosed: boolean };
    wednesday?: { open: string; close: string; isClosed: boolean };
    thursday?: { open: string; close: string; isClosed: boolean };
    friday?: { open: string; close: string; isClosed: boolean };
    saturday?: { open: string; close: string; isClosed: boolean };
    sunday?: { open: string; close: string; isClosed: boolean };
  };

  @Column({ type: 'double', nullable: true, comment: '纬度' })
  latitude: number;

  @Column({ type: 'double', nullable: true, comment: '经度' })
  longitude: number;

  @Column({
    type: 'enum',
    enum: HospitalStatus,
    default: HospitalStatus.ACTIVE,
    comment: '医院状态',
  })
  status: HospitalStatus;

  // 前端兼容字段 - 根据 status 自动计算
  get isActive(): boolean {
    return this.status === HospitalStatus.ACTIVE;
  }

  // 前端设置 isActive 时自动更新 status
  set isActive(value: boolean) {
    this.status = value ? HospitalStatus.ACTIVE : HospitalStatus.INACTIVE;
  }

  @Column({
    type: 'text',
    nullable: true,
    comment: '设施服务（JSON数组字符串）',
  })
  facilities: string;

  @Column({
    type: 'decimal',
    precision: 3,
    scale: 2,
    default: 0,
    comment: '评分（0-5）',
  })
  rating: number;

  @Column({ default: 0, comment: '评论数' })
  reviewCount: number;

  @Column({ type: 'int', default: 0, comment: '预约次数' })
  appointmentCount: number;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;

  @DeleteDateColumn({
    type: 'timestamp',
    nullable: true,
    comment: '删除时间（软删除）',
  })
  deletedAt?: Date;
}
