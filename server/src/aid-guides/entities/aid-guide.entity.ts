import {
  Column,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { AidCategory } from './aid-category.entity';

/**
 * 指南状态枚举
 */
export enum GuideStatus {
  DRAFT = 'DRAFT', // 草稿
  PUBLISHED = 'PUBLISHED', // 已发布
}

/**
 * 急救指南实体
 * 存储急救指南的内容和元数据
 */
@Entity('aid_guides', { comment: '急救指南表' })
@Index(['deletedAt'])
@Index(['status'])
@Index(['categoryId'])
@Index(['publishedAt'])
@Index(['categoryId', 'status'])
export class AidGuide {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '指南标题' })
  title: string;

  @Column({ nullable: true, comment: '指南图标 URL' })
  icon?: string;

  @Column({ type: 'longtext', comment: '指南内容（HTML 富文本）' })
  content: string;

  @Column({ comment: '所属分类 ID' })
  categoryId: number;

  /**
   * 关联的分类信息
   */
  @ManyToOne(() => AidCategory)
  @JoinColumn({ name: 'categoryId' })
  category?: AidCategory;

  @Column({
    type: 'enum',
    enum: GuideStatus,
    default: GuideStatus.DRAFT,
    comment: '指南状态',
  })
  status: GuideStatus;

  @Column({ default: 0, comment: '排序权重（数字越小越靠前）' })
  sortOrder: number;

  @Column({ type: 'timestamp', nullable: true, comment: '发布时间' })
  publishedAt?: Date;

  @Column({ comment: '作者 ID（管理员 ID）' })
  authorId: number;

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
}
