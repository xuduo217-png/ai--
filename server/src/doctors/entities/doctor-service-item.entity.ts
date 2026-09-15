import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Doctor } from './doctor.entity';

/**
 * 医生收费项表
 * 定义医生提供的各种服务项目及其价格
 */
@Index(['doctorId'])
@Index(['isActive'])
@Index(['sortOrder'])
@Entity('doctor_service_items', { comment: '医生收费项表' })
export class DoctorServiceItem {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '关联医生ID' })
  doctorId: number;

  @Column({
    type: 'varchar',
    length: 100,
    comment: '服务名称（如：图文咨询、电话咨询）',
  })
  name: string;

  @Column({ type: 'int', comment: '服务时长（分钟）' })
  duration: number;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    comment: '服务价格（元）',
  })
  price: number;

  @Column({ type: 'text', nullable: true, comment: '服务描述' })
  description?: string;

  @Column({ type: 'int', default: 0, comment: '排序序号（数字越小越靠前）' })
  sortOrder: number;

  @Column({ type: 'boolean', default: true, comment: '是否启用' })
  isActive: boolean;

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

  @ManyToOne(() => Doctor)
  @JoinColumn()
  doctor: Doctor;
}
