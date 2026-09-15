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
import { User } from '../../users/entities/user.entity';

/**
 * 用户优惠券状态
 */
export enum UserCouponStatus {
  AVAILABLE = 'AVAILABLE', // 可用
  USED = 'USED', // 已使用
  EXPIRED = 'EXPIRED', // 已过期
}

/**
 * 用户优惠券表
 * 记录用户领取的优惠券状态
 */
@Entity('user_coupons', { comment: '用户优惠券表' })
@Index(['userId'])
@Index(['couponId'])
@Index(['status'])
export class UserCoupon {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '用户ID' })
  userId: number;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column({ comment: '优惠券ID' })
  couponId: number;

  @ManyToOne(() => Coupon)
  @JoinColumn({ name: 'couponId' })
  coupon: Coupon;

  @Column({
    type: 'enum',
    enum: UserCouponStatus,
    default: UserCouponStatus.AVAILABLE,
    comment: '优惠券状态',
  })
  status: UserCouponStatus;

  @Column({ nullable: true, comment: '使用的订单ID' })
  orderId: number;

  @Column({ type: 'timestamp', nullable: true, comment: '使用时间' })
  usedAt: Date;

  @Column({ type: 'timestamp', comment: '过期时间' })
  expiredAt: Date;

  @CreateDateColumn({ comment: '领取时间' })
  createdAt: Date;
}
