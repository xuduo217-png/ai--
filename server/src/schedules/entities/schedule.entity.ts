import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Doctor } from '../../doctors/entities/doctor.entity';

/**
 * 排班时段
 */
export enum SchedulePeriod {
  MORNING = 'morning', // 上午
  AFTERNOON = 'afternoon', // 下午
  EVENING = 'evening', // 晚上
  FULL_DAY = 'full_day', // 全天
}

/**
 * 医生排班表
 * 记录医生的排班信息
 */
@Entity('schedules', { comment: '医生排班表' })
export class Schedule {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ type: 'date', comment: '排班日期' })
  date: Date;

  @Column({
    type: 'enum',
    enum: SchedulePeriod,
    comment: '排班时段',
  })
  period: SchedulePeriod;

  @Column({ default: true, comment: '是否可用' })
  isAvailable: boolean;

  @ManyToOne(() => Doctor)
  @JoinColumn()
  doctor: Doctor;

  @Column({ comment: '医生ID' })
  doctorId: number;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;
}
