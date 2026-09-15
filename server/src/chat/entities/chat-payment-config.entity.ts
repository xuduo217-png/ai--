import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  Index,
} from 'typeorm';
import { ChatPackage } from './chat-package.entity';

/**
 * 聊天付费配置表
 * 定义医生的付费聊天设置和免费自动回复次数
 */
@Index(['doctorId'])
@Entity('chat_payment_configs', { comment: '聊天付费配置表' })
export class ChatPaymentConfig {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({
    type: 'int',
    nullable: true,
    comment: '关联医生ID（null表示全局配置）',
  })
  doctorId?: number;

  @Column({ type: 'int', default: 3, comment: '最大免费自动回复次数' })
  maxFreeReplies: number;

  @Column({ type: 'boolean', default: true, comment: '是否启用' })
  isActive: boolean;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;

  @OneToMany(() => ChatPackage, (pkg) => pkg.config)
  packages: ChatPackage[];
}
