import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Doctor } from '../../doctors/entities/doctor.entity';
import { DoctorServiceItem } from '../../doctors/entities/doctor-service-item.entity';

/**
 * 订单状态枚举
 */
export enum OrderStatus {
  PENDING = 'PENDING', // 待支付
  PAID = 'PAID', // 已支付
  REFUNDED = 'REFUNDED', // 已退款
  EXPIRED = 'EXPIRED', // 已过期
  CANCELLED = 'CANCELLED', // 已取消
}

/**
 * 聊天订单表
 * 用户购买聊天套餐的订单记录
 */
@Index(['userId'])
@Index(['doctorId'])
@Index(['status'])
@Index(['userId', 'doctorId', 'createdAt'])
@Entity('chat_orders', { comment: '聊天订单表' })
export class ChatOrder {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ unique: true, comment: '订单号（唯一）' })
  orderNo: string;

  @Column({ comment: '购买用户ID' })
  userId: number;

  @Column({ comment: '目标医生ID' })
  doctorId: number;

  @Column({ comment: '购买的收费项ID（医生服务项）' })
  serviceItemId: number;

  @Column({ type: 'int', comment: '服务时长（分钟）' })
  durationMinutes: number;

  @Column({ type: 'decimal', precision: 10, scale: 2, comment: '订单金额' })
  amount: number;

  @Column({
    type: 'enum',
    enum: OrderStatus,
    default: OrderStatus.PENDING,
    comment: '订单状态',
  })
  status: OrderStatus;

  @Column({ type: 'timestamp', nullable: true, comment: '支付时间' })
  paidAt?: Date;

  @Column({ type: 'timestamp', nullable: true, comment: '服务开始时间' })
  serviceStartAt?: Date;

  @Column({ type: 'timestamp', nullable: true, comment: '服务结束时间' })
  serviceEndAt?: Date;

  @Column({ type: 'timestamp', nullable: true, comment: '订单过期时间' })
  expiredAt?: Date;

  @Column({ type: 'text', nullable: true, comment: '备注' })
  remark?: string;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;

  @ManyToOne(() => User)
  @JoinColumn()
  user: User;

  @ManyToOne(() => Doctor)
  @JoinColumn()
  doctor: Doctor;

  @ManyToOne(() => DoctorServiceItem)
  @JoinColumn()
  serviceItem: DoctorServiceItem;
}
