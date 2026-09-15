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
import { Pet } from '../../pets/entities/pet.entity';
import { Hospital } from '../../hospitals/entities/hospital.entity';
import { Doctor } from '../../doctors/entities/doctor.entity';
import { User } from '../../users/entities/user.entity';

/**
 * 健康预约类型
 */
export enum HealthAppointmentType {
  VACCINE = 'vaccine', // 疫苗接种
  DEWORMING = 'deworming', // 驱虫
  CHECKUP = 'checkup', // 体检
}

/**
 * 健康预约状态
 */
export enum HealthAppointmentStatus {
  PENDING = 'pending', // 待确认
  CONFIRMED = 'confirmed', // 已确认
  COMPLETED = 'completed', // 已完成
  CANCELLED = 'cancelled', // 已取消
}

/**
 * 健康预约表
 * 存储健康相关的预约记录（疫苗、驱虫、体检）
 */
@Entity('health_appointments', { comment: '健康预约表' })
@Index(['status'])
@Index(['userId'])
@Index(['petId'])
@Index(['hospitalId'])
@Index(['doctorId'])
@Index(['appointmentDate'])
@Index(['type'])
@Index(['userId', 'deletedAt'])
export class HealthAppointment {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({
    type: 'enum',
    enum: HealthAppointmentType,
    comment: '预约类型：vaccine=疫苗, deworming=驱虫, checkup=体检',
  })
  type: HealthAppointmentType;

  @Column({
    type: 'enum',
    enum: HealthAppointmentStatus,
    default: HealthAppointmentStatus.PENDING,
    comment: '预约状态',
  })
  status: HealthAppointmentStatus;

  @Column({ type: 'date', comment: '预约日期（YYYY-MM-DD）' })
  appointmentDate: Date;

  @Column({
    type: 'varchar',
    length: 20,
    comment: '预约时间段（如：09:00-10:00）',
  })
  timeSlot: string;

  @ManyToOne(() => Pet)
  @JoinColumn()
  pet: Pet;

  @Column({ comment: '宠物ID' })
  petId: number;

  @ManyToOne(() => Hospital)
  @JoinColumn()
  hospital: Hospital;

  @Column({ comment: '医院ID' })
  hospitalId: number;

  @ManyToOne(() => User)
  @JoinColumn()
  user: User;

  @Column({ comment: '用户ID' })
  userId: number;

  @ManyToOne(() => Doctor, {
    eager: true,
    nullable: true,
    createForeignKeyConstraints: false // 不创建外键约束，避免数据迁移问题
  })
  @JoinColumn({ name: 'doctorId' })
  doctor: Doctor;

  @Column({ nullable: true, name: 'doctorId', comment: '医生ID（关联 doctors 表）' })
  doctorId: number;

  @Column({ type: 'text', nullable: true, comment: '备注' })
  notes?: string;

  @Column({
    type: 'varchar',
    length: 1000,
    nullable: true,
    comment: '本次操作内容（已完成预约时填写）',
  })
  operationContent?: string;

  @Column({
    type: 'text',
    nullable: true,
    comment: '详情内容（已完成预约时填写，支持富文本）',
  })
  detailContent?: string;

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
