import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

/**
 * 物流公司实体
 */
@Entity('logistics', { comment: '物流公司表' })
export class Logistics {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ length: 100, comment: '物流公司名称' })
  name: string;

  @Column({
    length: 50,
    unique: true,
    comment: '物流编码（如 SF、YTO、ZTO）',
  })
  code: string;

  @Column({
    type: 'tinyint',
    width: 1,
    default: 1,
    comment: '是否启用',
  })
  isEnabled: boolean;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;
}
