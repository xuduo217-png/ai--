import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { SelfCheckQuestion } from './self-check-question.entity';

/**
 * 自查表实体
 * 用于管理公共项和特定项自查表
 */
@Entity('self_check_lists', { comment: '自查表列表' })
export class SelfCheckList {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  /**
   * 自查表标题
   */
  @Column({ length: 200, comment: '自查表标题' })
  title: string;

  /**
   * 类型：公共项/特定项
   * PUBLIC - 公共项，所有宠物通用
   * SPECIFIC - 特定项，关联特定宠物分类
   */
  @Column({
    type: 'enum',
    enum: ['PUBLIC', 'SPECIFIC'],
    default: 'PUBLIC',
    comment: '类型：公共项/特定项',
  })
  type: 'PUBLIC' | 'SPECIFIC';

  /**
   * 关联的宠物一级分类ID
   * 仅当 type 为 SPECIFIC 时有效
   */
  @Column({ nullable: true, comment: '关联的宠物一级分类ID' })
  categoryId: number | null;

  /**
   * 状态：启用/禁用
   */
  @Column({
    type: 'enum',
    enum: ['ACTIVE', 'INACTIVE'],
    default: 'ACTIVE',
    comment: '状态：启用/禁用',
  })
  status: 'ACTIVE' | 'INACTIVE';

  /**
   * 排序序号，用于自定义显示顺序
   */
  @Column({ default: 0, comment: '排序序号' })
  sortOrder: number;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;

  /**
   * 关联的问题列表
   */
  @OneToMany(() => SelfCheckQuestion, (question) => question.list, {
    cascade: true,
  })
  questions: SelfCheckQuestion[];
}
