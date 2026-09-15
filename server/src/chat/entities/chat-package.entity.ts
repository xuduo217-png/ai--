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
import { ChatPaymentConfig } from './chat-payment-config.entity';

/**
 * 聊天套餐表
 * 定义不同时长的聊天服务套餐
 */
@Index(['configId'])
@Index(['price'])
@Entity('chat_packages', { comment: '聊天套餐表' })
export class ChatPackage {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '关联付费配置ID' })
  configId: number;

  @Column({ type: 'int', default: 30, comment: '服务时长（天）' })
  durationDays: number;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 9.9,
    comment: '套餐价格',
  })
  price: number;

  @Column({ type: 'varchar', length: 100, comment: '套餐名称' })
  name: string;

  @Column({ type: 'text', nullable: true, comment: '套餐描述' })
  description?: string;

  @Column({ type: 'int', default: 0, comment: '排序序号' })
  sortOrder: number;

  @Column({ type: 'boolean', default: true, comment: '是否启用' })
  isActive: boolean;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;

  @ManyToOne(() => ChatPaymentConfig)
  @JoinColumn()
  config: ChatPaymentConfig;
}
