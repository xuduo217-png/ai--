import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  VersionColumn,
  Index,
  ManyToOne,
  JoinColumn,
  OneToMany,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Category } from './category.entity';
import { ProductSku } from './product-sku.entity';

/**
 * 商品分类（旧版，保留用于兼容）
 */
export enum ProductCategory {
  FOOD = 'food',
  TOY = 'toy',
  MEDICINE = 'medicine',
  ACCESSORY = 'accessory',
  OTHER = 'other',
}

/**
 * 商品发布来源
 */
export enum PublishSource {
  ADMIN = 'ADMIN', // 后台发布
  USER = 'USER', // 用户发布
}

// 审核状态和二手商品状态已移除，统一使用 isActive 字段判断上下架状态

/**
 * 商品新旧程度
 */
export enum ProductCondition {
  NEW = 'new', // 全新
  NINETY_PERCENT = '90%', // 9成新
  EIGHTY_PERCENT = '80%', // 8成新
  SEVENTY_PERCENT = '70%', // 7成新
  SIXTY_PERCENT_BELOW = '60%', // 6成新及以下
}

/**
 * 商品表
 * 存储商品基本信息、规格、审核状态等
 */
@Entity('products', { comment: '商品表' })
@Index(['price'])
@Index(['category'])
@Index(['categoryId'])
@Index(['isActive'])
@Index(['stock'])
@Index(['sells'])
@Index(['isHot'])
@Index(['isTop'])
@Index(['publishSource'])
@Index(['publishedBy'])
@Index(['pendingProductId'])
export class Product {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '商品名称' })
  name: string;

  @Column({ type: 'text', nullable: true, comment: '商品描述' })
  description: string;

  @Column({ type: 'decimal', precision: 10, scale: 2, comment: '商品价格' })
  price: number;

  @Column({ default: 0, comment: '库存数量' })
  stock: number;

  @Column({ default: 0, comment: '销量' })
  sells: number;

  @Column({ default: false, comment: '是否热门商品' })
  isHot: boolean;

  @Column({ default: false, comment: '是否置顶推荐' })
  isTop: boolean;

  @Column({ nullable: true, comment: '商品主图' })
  image: string;

  @Column({ default: true, comment: '是否启用' })
  isActive: boolean;

  @Column({
    type: 'enum',
    enum: ProductCategory,
    comment: '商品分类（旧版）',
  })
  category: ProductCategory;

  // ========== SKU 相关字段 ==========

  @Column({
    nullable: true,
    comment: '商品分类ID（关联到product_categories表）',
  })
  categoryId: number;

  @Column({ default: false, comment: '是否多规格商品（true使用SKU数据）' })
  hasSku: boolean;

  @Column({ type: 'json', nullable: true, comment: '商品图片列表（JSON数组）' })
  images: string[];

  @Column({ default: false, comment: '是否虚拟商品（true不需要物流）' })
  isVirtual: boolean;

  // ========== 审核相关字段 ==========

  @Column({
    type: 'enum',
    enum: PublishSource,
    default: PublishSource.ADMIN,
    comment: '发布来源（后台/用户）',
  })
  publishSource: PublishSource;

  @Column({ nullable: true, comment: '发布者ID' })
  publishedBy: number;

  @Column({ nullable: true, comment: '临时表商品ID（用户发布的二手商品，用于双向关联）' })
  pendingProductId: number;

  @Column({ nullable: true, comment: '审核者ID（管理员）' })
  auditedBy: number;

  @Column({ type: 'timestamp', nullable: true, comment: '审核时间' })
  auditedAt: Date;

  @Column({ type: 'text', nullable: true, comment: '审核备注（拒绝原因等）' })
  auditRemark: string;

  // ========== 二手商品相关字段 ==========

  @Column({ default: false, comment: '是否可议价' })
  negotiable: boolean;

  @Column({
    type: 'enum',
    enum: ProductCondition,
    nullable: true,
    comment: '新旧程度',
  })
  condition: ProductCondition;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0,
    comment: '运费（0表示包邮）',
  })
  shippingFee: number;

  @Column({ default: 0, comment: '浏览次数' })
  viewCount: number;

  @Column({ type: 'timestamp', nullable: true, comment: '售出时间' })
  soldAt: Date;

  // 历史字段：此前用于记录下架时间，当前数据库未包含该列，避免插入失败故禁用持久化
  // 如需恢复，请先添加数据库列再移除 insert/update 限制
  @Column({ type: 'timestamp', nullable: true, select: false, insert: false, update: false, comment: '下架时间(禁用持久化)' })
  offlinedAt: Date;

  // ========== 关联关系 ==========

  @ManyToOne(() => User)
  @JoinColumn({ name: 'publishedBy' })
  publisher: User;

  // 关联的临时表商品（用户发布的二手商品）
  // 注意：这里需要避免循环引用，所以不直接导入 ProductPending
  // @ManyToOne(() => ProductPending)
  // @JoinColumn({ name: 'pendingProductId' })
  // pendingProduct: ProductPending;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'auditedBy' })
  auditor: User;

  @ManyToOne(() => Category)
  @JoinColumn({ name: 'categoryId' })
  categoryRelation: Category;

  @OneToMany(() => ProductSku, (sku) => sku.product, { cascade: true })
  skus: ProductSku[];

  // ========== 乐观锁 ==========

  @VersionColumn({ comment: '乐观锁版本号（防止并发冲突）' })
  version: number;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;
}
