import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  Index,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Coupon } from './coupon.entity';
import { Product } from './product.entity';

/**
 * 优惠券商品关联表
 * 用于指定商品优惠券
 */
@Entity('coupon_products', { comment: '优惠券商品关联表' })
@Index(['couponId'])
@Index(['productId'])
@Index(['couponId', 'productId'], { unique: true })
export class CouponProduct {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '优惠券ID' })
  couponId: number;

  @Column({ comment: '商品ID' })
  productId: number;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  // 关联关系
  @ManyToOne(() => Coupon)
  @JoinColumn({ name: 'couponId' })
  coupon: Coupon;

  @ManyToOne(() => Product)
  @JoinColumn({ name: 'productId' })
  product: Product;
}
