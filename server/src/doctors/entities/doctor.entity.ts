import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  ManyToOne,
  JoinColumn,
  OneToMany,
  Index,
} from 'typeorm';
import { Exclude } from 'class-transformer';
import { Hospital } from '../../hospitals/entities/hospital.entity';
import { Department } from '../../departments/entities/department.entity';
import { Schedule } from '../../schedules/entities/schedule.entity';
import { DoctorServiceItem } from './doctor-service-item.entity';

@Index(['hospitalId'])
@Index(['departmentId'])
@Index(['isActive'])
@Index(['deletedAt'])
@Entity('doctors', { comment: '医生表' })
export class Doctor {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  // ========== 独立账号信息 ==========
  @Column({
    unique: true,
    nullable: false,
    comment: '登录用户名（必填，唯一）',
  })
  username: string;

  /**
   * 登录密码（必填，加密存储）
   * 使用 @Exclude() 装饰器确保在序列化时不返回密码字段
   */
  @Exclude()
  @Column({ nullable: false, comment: '登录密码（必填，加密存储）' })
  password: string;

  @Column({ unique: true, nullable: false, comment: '手机号（必填，唯一）' })
  phone: string;

  // ========== 基本信息 ==========
  @Column({ comment: '姓名（必填）' })
  name: string;

  @Column({ nullable: true, comment: '头像' })
  avatar: string;

  @Column({ comment: '专长（必填）' })
  specialty: string;

  @Column({ type: 'text', nullable: true, comment: '简介' })
  description: string;

  @Column({ default: 0, comment: '经验年限（年）' })
  experience: number;

  @Column({
    type: 'decimal',
    precision: 3,
    scale: 2,
    default: 0,
    comment: '评分（0-5）',
  })
  rating: number;

  @Column({ default: false, comment: '是否为金牌医师' })
  isGoldDoctor: boolean;

  @Column({ default: 0, comment: '已支付咨询订单数（同步缓存）' })
  consultationCount: number;

  @Column({ default: true, comment: '是否在职' })
  isActive: boolean;

  @Column({
    type: 'enum',
    enum: ['ONLINE', 'OFFLINE'],
    default: 'OFFLINE',
    comment: '在线状态（ONLINE-在线，OFFLINE-离线）',
  })
  onlineStatus: 'ONLINE' | 'OFFLINE';

  @Column({ nullable: true, comment: '最后登录时间' })
  lastLoginAt: Date;

  // ========== 关联医院和科室 ==========
  @ManyToOne(() => Hospital)
  @JoinColumn()
  hospital: Hospital;

  @Column({ comment: '关联医院ID' })
  hospitalId: number;

  @ManyToOne(() => Department)
  @JoinColumn()
  department: Department;

  @Column({ comment: '关联科室ID' })
  departmentId: number;

  // ========== 其他信息 ==========
  @Column({ type: 'text', nullable: true, comment: '资质证书' })
  qualifications?: string;

  @Column({ type: 'simple-array', nullable: true, comment: '标签' })
  tags?: string[];

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

  @OneToMany(() => Schedule, (schedule) => schedule.doctor)
  schedules: Schedule[];

  @OneToMany(() => DoctorServiceItem, (serviceItem) => serviceItem.doctor)
  serviceItems: DoctorServiceItem[];
}
