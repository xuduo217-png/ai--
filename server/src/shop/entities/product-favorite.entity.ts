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

/**
 * 商品收藏实体
 */
@Entity('product_favorites', { comment: '商品收藏表' })
// 复合唯一索引：防止同一用户重复收藏同一商品
@Index(['userId', 'productId'], { unique: true })
export class ProductFavorite {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '用户ID' })
  userId: number;

  @Column({ comment: '商品ID' })
  productId: number;

  // ========== 关系 ==========

  @ManyToOne(() => User)
  @JoinColumn({ name: 'userId' })
  user: User;

  @ManyToOne(() => Product, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'productId' })
  product: Product;

  // ========== 时间戳 ==========

  @CreateDateColumn({ comment: '收藏时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;
}
