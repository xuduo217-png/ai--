import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  Tree,
  TreeParent,
  TreeChildren,
  Index,
} from 'typeorm';

/**
 * 商品分类状态
 */
export enum CategoryStatus {
  ACTIVE = 'ACTIVE', // 启用
  DISABLED = 'DISABLED', // 禁用
}

/**
 * 商品分类实体
 * 使用 TypeORM 的树形结构支持多级分类
 */
@Entity('product_categories', { comment: '商品分类表' })
@Index(['status'])
@Index(['sortOrder'])
export class Category {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '分类名称' })
  name: string;

  @Column({ nullable: true, comment: '分类图标' })
  icon: string;

  @Column({ nullable: true, comment: '分类图片' })
  image: string;

  @Column({ type: 'text', nullable: true, comment: '分类描述' })
  description: string;

  @Column({
    type: 'enum',
    enum: CategoryStatus,
    default: CategoryStatus.ACTIVE,
    comment: '分类状态',
  })
  status: CategoryStatus;

  @Column({ default: 0, comment: '排序顺序（数字越小越靠前）' })
  sortOrder: number;

  @Column({ nullable: true, comment: '父分类ID（null表示根分类）' })
  parentId: number;

  // ========== 树形结构关系 ==========

  @TreeParent()
  parent: Category;

  @TreeChildren()
  children: Category[];

  // ========== 时间戳 ==========

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;
}
