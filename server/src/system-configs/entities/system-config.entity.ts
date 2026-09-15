import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

/**
 * 系统配置表
 * 用于存储系统级配置信息（如联系方式、支付配置等）
 *
 * 业务逻辑：
 * - 每个配置通过 configKey 唯一标识
 * - configValue 字段存储 JSON 格式的配置数据
 * - 管理员可编辑所有配置
 * - 移动端可读取配置（无需认证或仅需用户认证）
 */
@Entity('system_configs', { comment: '系统配置表' })
export class SystemConfig {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({
    type: 'varchar',
    length: 100,
    unique: true,
    comment: '配置标识（唯一键）',
  })
  configKey: string;

  @Column({
    type: 'json',
    comment: '配置值（JSON 格式）',
  })
  configValue: Record<string, any>;

  @Column({
    type: 'varchar',
    length: 500,
    comment: '配置说明',
  })
  description: string;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;
}
