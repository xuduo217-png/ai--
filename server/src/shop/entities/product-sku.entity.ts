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
} from 'typeorm';
import { Product } from './product.entity';

/**
 * SKU 状态
 */
export enum SkuStatus {
  ACTIVE = 'ACTIVE', // 上架
  INACTIVE = 'INACTIVE', // 下架
  OUT_OF_STOCK = 'OUT_OF_STOCK', // 缺货
}

/**
 * 商品 SKU 表
 * 用于支持商品多规格（如：颜色、尺寸等）
 */
@Entity('product_skus', { comment: '商品SKU表' })
@Index(['productId'])
@Index(['status'])
export class ProductSku {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: 'SKU名称（如：红色-L、蓝色-M）' })
  name: string;

  @Column({
    type: 'json',
    comment: 'SKU规格（JSON格式，如：{"颜色": "红色", "尺寸": "L"}）',
  })
  specs: Record<string, string>;

  @Column({ type: 'decimal', precision: 10, scale: 2, comment: 'SKU价格' })
  price: number;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    nullable: true,
    comment: 'SKU原价（用于显示折扣）',
  })
  originalPrice: number;

  @Column({ default: 0, comment: 'SKU库存' })
  stock: number;

  @Column({
    type: 'enum',
    enum: SkuStatus,
    default: SkuStatus.ACTIVE,
    comment: 'SKU状态',
  })
  status: SkuStatus;

  @Column({
    nullable: true,
    comment: 'SKU图片（可选，用于显示不同规格的图片）',
  })
  image: string;

  @Column({ nullable: true, unique: true, comment: 'SKU编码（外部系统编码）' })
  skuCode: string;

  @Column({ name: 'productId', comment: '商品ID' })
  productId: number;

  @ManyToOne(() => Product, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'productId' })
  product: Product;

  // ========== 乐观锁 ==========

  @VersionColumn({ comment: '乐观锁版本号（防止并发冲突）' })
  version: number;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;
}
