import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
} from 'typeorm';
import { SelfCheckQuestion } from './self-check-question.entity';

/**
 * 自查表选项实体
 * 用于单选和多选题的选项管理
 */
@Entity('self_check_options', { comment: '自查表选项表' })
export class SelfCheckOption {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  /**
   * 所属问题ID
   */
  @Column({ comment: '所属问题ID' })
  questionId: number;

  /**
   * 选项描述
   */
  @Column({ length: 500, comment: '选项描述' })
  optionText: string;

  /**
   * 选项表现图片URL（可选）
   * 用于图文展示选项
   */
  @Column({ nullable: true, comment: '选项表现图片URL' })
  optionImage: string | null;

  /**
   * 排序序号，用于自定义选项显示顺序
   */
  @Column({ default: 0, comment: '排序序号' })
  sortOrder: number;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;

  /**
   * 所属问题
   */
  @ManyToOne(() => SelfCheckQuestion, (question) => question.options)
  question: SelfCheckQuestion;
}
