import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

/**
 * 优惠券类型
 */
export enum CouponType {
  FULL_REDUCTION = 'FULL_REDUCTION', // 满减券（满N元减M元）
  DISCOUNT = 'DISCOUNT', // 折扣券（打折）
  DIRECT_DISCOUNT = 'DIRECT_DISCOUNT', // 直减券（直接减去固定金额）
}

/**
 * 优惠券状态
 */
export enum CouponStatus {
  ACTIVE = 'ACTIVE', // 生效中
  EXPIRED = 'EXPIRED', // 已过期
  REVOKED = 'REVOKED', // 已作废
}

/**
 * 优惠券使用范围
 */
export enum CouponScope {
  ALL = 'ALL', // 全品类
  SPECIFIC = 'SPECIFIC', // 指定商品
}

/**
 * 领取方式
 */
export enum ClaimType {
  NEW_USER = 'NEW_USER',       // 新用户领取
  SCAN_CODE = 'SCAN_CODE',     // 扫码领取
}

/**
 * 优惠券表
 * 定义优惠券的规则和使用条件
 */
@Entity('coupons', { comment: '优惠券表' })
@Index(['type'])
@Index(['status'])
@Index(['validFrom'])
@Index(['validAt'])
export class Coupon {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '优惠券名称' })
  name: string;

  @Column({ type: 'text', nullable: true, comment: '优惠券描述' })
  description: string;

  @Column({
    type: 'enum',
    enum: CouponType,
    comment: '优惠券类型',
  })
  type: CouponType;

  @Column({
    name: 'status',
    type: 'enum',
    enum: CouponStatus,
    default: CouponStatus.ACTIVE,
    comment: '优惠券状态',
  })
  status: CouponStatus;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0,
    comment: '满减门槛（元）',
  })
  minAmount: number;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0,
    comment: '最低订单金额限制（元）',
  })
  minOrderAmount: number;

  @Column({
    type: 'enum',
    enum: CouponScope,
    default: CouponScope.ALL,
    comment: '使用范围：ALL-全品类，SPECIFIC-指定商品',
  })
  scope: CouponScope;

  @Column({
    type: 'tinyint',
    default: 0,
    comment: '是否可叠加使用（0-否，1-是）',
  })
  canStack: number;

  @Column({
    type: 'tinyint',
    default: 0,
    comment: '启用状态（0-启用，1-禁用）',
  })
  isEnabled: number;

  @Column({
    type: 'tinyint',
    default: 0,
    comment: '是否已过期（0-否，1-是）',
  })
  isExpired: number;

  @Column({
    type: 'tinyint',
    default: 0,
    comment: '是否已领完（0-否，1-是）',
  })
  isClaimedOut: number;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    comment: '优惠值（满减券为减免金额，折扣券为折扣比例）',
  })
  discountValue: number;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    nullable: true,
    comment: '最大优惠金额（折扣券专用）',
  })
  maxDiscount: number;

  @Column({ default: 0, comment: '发放总量' })
  stock: number;

  @Column({ default: 0, comment: '已领取数量' })
  claimedCount: number;

  @Column({ default: 1, comment: '每人限领数量' })
  perUserLimit: number;

  @Column({ type: 'timestamp', comment: '有效期开始时间' })
  validFrom: Date;

  @Column({ type: 'timestamp', comment: '有效期结束时间' })
  validAt: Date;

  @Column({
    name: 'claim_type',
    type: 'enum',
    enum: ClaimType,
    nullable: true,
    comment: '领取方式：NEW_USER-新用户领取，SCAN_CODE-扫码领取'
  })
  claimType: ClaimType;

  @Column({
    name: 'claim_code',
    type: 'varchar',
    length: 50,
    nullable: true,
    unique: true,
    comment: '特殊领取码（扫码领取专用）'
  })
  claimCode: string;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;
}
