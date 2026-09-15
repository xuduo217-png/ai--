import {
  Column,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
} from 'typeorm';

/**
 * 急救指南分类实体
 * 用于管理急救指南的分类信息
 */
@Entity('aid_categories', { comment: '急救指南分类表' })
@Index(['deletedAt'])
@Index(['isActive'])
@Index(['sortOrder'])
export class AidCategory {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '分类名称' })
  name: string;

  @Column({ nullable: true, comment: '分类图标 URL' })
  icon?: string;

  @Column({ default: 0, comment: '排序权重（数字越小越靠前）' })
  sortOrder: number;

  @Column({ default: true, comment: '是否启用' })
  isActive: boolean;

  @Column({ default: 0, comment: '该分类下的指南数量（冗余字段）' })
  guideCount: number;

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
