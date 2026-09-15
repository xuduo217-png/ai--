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
import { Doctor } from '../../doctors/entities/doctor.entity';

/**
 * 自动回复表
 * 用于配置全局自动回复消息（与医生解耦）
 *
 * 业务逻辑：
 * - 管理员配置 N 条自动回复（按 sortOrder 排序）
 * - 用户发送消息后，系统按顺序依次发送这 N 条回复
 * - 用户发一条 → 系统回第 1 条
 * - 用户再发 → 系统回第 2 条
 * - ...直到 N 条发完 → 用户再发送一条消息后提示付费
 */
@Index(['doctorId', 'isActive'])
@Entity('auto_replies', { comment: '自动回复表' })
export class AutoReply {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ type: 'varchar', length: 500, comment: '自动回复内容' })
  content: string;

  @Column({
    type: 'int',
    nullable: true,
    comment: '关联医生ID（null表示全局自动回复）',
  })
  doctorId?: number;

  @Column({
    type: 'int',
    default: 0,
    comment: '排序序号（数字越小越靠前，从1开始）',
  })
  sortOrder: number;

  @Column({ type: 'boolean', default: true, comment: '是否启用' })
  isActive: boolean;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;

  @ManyToOne(() => Doctor, { nullable: true })
  @JoinColumn()
  doctor?: Doctor;
}
