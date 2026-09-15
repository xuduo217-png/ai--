import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Product } from './product.entity';
import { ProductSku } from './product-sku.entity';

/**
 * 购物车实体
 */
@Entity('shopping_carts', { comment: '购物车表' })
// 复合唯一索引：防止同一用户重复添加同一商品（同一SKU）到购物车
@Index(['userId', 'productId', 'skuId'], { unique: true })
export class ShoppingCart {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '用户ID' })
  userId: number;

  @Column({ comment: '商品ID' })
  productId: number;

  @Column({ comment: 'SKU ID（如果商品有规格）', nullable: true })
  skuId: number;

  @Column({ type: 'int', default: 1, comment: '数量' })
  quantity: number;

  // ========== 关系 ==========

  @ManyToOne(() => User)
  @JoinColumn({ name: 'userId' })
  user: User;

  @ManyToOne(() => Product)
  @JoinColumn({ name: 'productId' })
  product: Product;

  @ManyToOne(() => ProductSku, { nullable: true })
  @JoinColumn({ name: 'skuId' })
  sku: ProductSku;

  // ========== 时间戳 ==========

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;
}
