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
import { Doctor } from '../../doctors/entities/doctor.entity';
import { User } from '../../users/entities/user.entity';
import { Hospital } from '../../hospitals/entities/hospital.entity';

/**
 * 预约类型
 */
export enum AppointmentType {
  VACCINE = 'vaccine', // 疫苗接种
  DEWORMING = 'deworming', // 驱虫
  CHECKUP = 'checkup', // 体检
}

/**
 * 预约状态
 */
export enum AppointmentStatus {
  PENDING = 'pending', // 待确认
  CONFIRMED = 'confirmed', // 已确认
  IN_PROGRESS = 'in_progress', // 进行中
  COMPLETED = 'completed', // 已完成
  CANCELLED = 'cancelled', // 已取消
  NO_SHOW = 'no_show', // 未到诊
}

/**
 * 预约记录表
 * 存储用户预约信息
 */
@Entity('appointments', { comment: '预约记录表' })
@Index(['status'])
@Index(['userId'])
@Index(['hospitalId'])
@Index(['doctorId'])
@Index(['appointmentTime'])
@Index(['type'])
@Index(['userId', 'deletedAt'])
@Index(['hospitalId', 'status'])
@Index(['doctorId', 'status'])
export class Appointment {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({
    type: 'enum',
    enum: AppointmentType,
    comment: '预约类型',
  })
  type: AppointmentType;

  @Column({
    type: 'enum',
    enum: AppointmentStatus,
    default: AppointmentStatus.PENDING,
    comment: '预约状态',
  })
  status: AppointmentStatus;

  @Column({ type: 'datetime', comment: '预约时间' })
  appointmentTime: Date;

  @Column({ type: 'datetime', nullable: true, comment: '确认时间' })
  confirmedAt?: Date;

  @Column({ type: 'datetime', nullable: true, comment: '下次预约时间' })
  nextAppointmentTime?: Date;

  @Column({ type: 'text', nullable: true, comment: '症状描述' })
  symptoms: string;

  @Column({ type: 'text', nullable: true, comment: '诊断结果' })
  diagnosis: string;

  @Column({ type: 'text', nullable: true, comment: '治疗方案' })
  treatment: string;

  @Column({ type: 'text', nullable: true, comment: '备注' })
  notes?: string;

  @ManyToOne(() => Pet)
  @JoinColumn()
  pet: Pet;

  @Column({ comment: '宠物ID' })
  petId: number;

  @ManyToOne(() => Doctor, { nullable: true })
  @JoinColumn({ name: 'doctorId' })
  doctor?: Doctor;

  @Column({ nullable: true, comment: '医生ID' })
  doctorId?: number;

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

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'confirmedById' })
  confirmedBy?: User;

  @Column({ nullable: true, comment: '确认人ID' })
  confirmedById?: number;

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
