import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

/**
 * 宠物类别树节点接口
 */
export interface PetCategoryTreeNode {
  id: number;
  name: string;
  parentId: number | null;
  sortOrder: number;
  createdAt: Date;
  updatedAt: Date;
  children?: PetCategoryTreeNode[];
}

/**
 * 宠物类别表
 * 存储宠物类型的二级分类体系
 * 支持两级分类：一级分类（如：狗、猫、鸟）和二级分类（如：金毛、英短）
 */
@Entity('pet_categories', { comment: '宠物类别分类表' })
@Index(['parentId'])
@Index(['sortOrder'])
export class PetCategory {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ type: 'varchar', length: 100, comment: '分类名称' })
  name: string;

  @Column({
    type: 'int',
    nullable: true,
    comment: '父级分类ID（一级分类为NULL）',
  })
  parentId: number | null;

  @Column({ type: 'int', default: 0, comment: '排序序号（越小越靠前）' })
  sortOrder: number;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;
}
