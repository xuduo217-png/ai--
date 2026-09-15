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
import { Hospital } from '../../hospitals/entities/hospital.entity';

/**
 * 科室表
 * 医院科室信息
 */
@Entity('departments', { comment: '科室表' })
@Index(['hospitalId']) // 添加索引以优化按医院查询的性能
export class Department {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  /**
   * 关联的医院
   * 每个科室属于一个特定的医院
   */
  @ManyToOne(() => Hospital)
  @JoinColumn({ name: 'hospital_id' })
  hospital: Hospital;

  /**
   * 所属医院ID
   * 必填字段，用于关联科室与医院
   */
  @Column({ comment: '所属医院ID', nullable: true })
  hospitalId: number;

  @Column({ comment: '科室名称' })
  name: string;

  @Column({ type: 'text', nullable: true, comment: '科室描述' })
  description: string;

  @Column({ default: true, comment: '是否启用' })
  isActive: boolean;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;
}
