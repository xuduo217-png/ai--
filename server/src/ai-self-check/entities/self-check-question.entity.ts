import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  OneToMany,
} from 'typeorm';
import { SelfCheckList } from './self-check-list.entity';
import { SelfCheckOption } from './self-check-option.entity';

/**
 * 自查表问题实体
 */
@Entity('self_check_questions', { comment: '自查表问题表' })
export class SelfCheckQuestion {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  /**
   * 所属自查表ID
   */
  @Column({ comment: '所属自查表ID' })
  listId: number;

  /**
   * 问题描述
   */
  @Column({ type: 'text', comment: '问题描述' })
  questionText: string;

  /**
   * 问题类型
   * SINGLE - 单选题
   * MULTIPLE - 多选题
   * TEXT - 填空题
   */
  @Column({
    type: 'enum',
    enum: ['SINGLE', 'MULTIPLE', 'TEXT'],
    default: 'SINGLE',
    comment: '问题类型',
  })
  questionType: 'SINGLE' | 'MULTIPLE' | 'TEXT';

  /**
   * 是否必填
   */
  @Column({ default: true, comment: '是否必填' })
  required: boolean;

  /**
   * 排序序号，用于自定义问题显示顺序
   */
  @Column({ default: 0, comment: '排序序号' })
  sortOrder: number;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;

  /**
   * 所属自查表
   */
  @ManyToOne(() => SelfCheckList, (list) => list.questions)
  list: SelfCheckList;

  /**
   * 关联的选项列表
   */
  @OneToMany(() => SelfCheckOption, (option) => option.question, {
    cascade: true,
  })
  options: SelfCheckOption[];
}
