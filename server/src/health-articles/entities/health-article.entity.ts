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
import { HealthCategory } from './health-category.entity';

/**
 * 文章状态枚举
 */
export enum ArticleStatus {
  DRAFT = 'DRAFT', // 草稿
  PUBLISHED = 'PUBLISHED', // 已发布
}

/**
 * 健康知识文章实体
 * 存储宠物健康相关的知识文章
 */
@Entity('health_articles', { comment: '健康知识文章表' })
@Index(['deletedAt'])
@Index(['status'])
@Index(['categoryId'])
@Index(['publishedAt'])
export class HealthArticle {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '文章标题' })
  title: string;

  @Column({ type: 'text', comment: '文章摘要' })
  summary: string;

  @Column({ type: 'longtext', comment: '文章内容（HTML 或 Markdown）' })
  content: string;

  @Column({ nullable: true, comment: '封面图片 URL' })
  coverImage?: string;

  @Column({ comment: '所属分类 ID' })
  categoryId: number;

  /**
   * 关联的分类信息
   */
  @ManyToOne(() => HealthCategory)
  @JoinColumn({ name: 'categoryId' })
  category?: HealthCategory;

  @Column({
    type: 'enum',
    enum: ArticleStatus,
    default: ArticleStatus.DRAFT,
    comment: '文章状态',
  })
  status: ArticleStatus;

  @Column({ type: 'timestamp', nullable: true, comment: '发布时间' })
  publishedAt?: Date;

  @Column({ default: 0, comment: '浏览次数' })
  viewCount: number;

  @Column({ default: 0, comment: '收藏次数' })
  favoriteCount: number;

  @Column({ default: 0, comment: '点赞次数' })
  likeCount: number;

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
