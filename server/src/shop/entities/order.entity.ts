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
import { Coupon } from './coupon.entity';
import { Logistics } from '../../logistics/entities/logistics.entity';
import { WalletTransaction } from './wallet-transaction.entity';

/**
 * 订单类型枚举
 */
export enum OrderType {
  NORMAL = 'normal', // 普通商品订单
  SECOND_HAND = 'second_hand', // 二手商品订单
}

/**
 * 订单状态枚举
 */
export enum OrderStatus {
  PENDING = 'pending', // 待支付
  PAID = 'paid', // 已支付
  SHIPPED = 'shipped', // 已发货
  COMPLETED = 'completed', // 已完成
  CANCELLED = 'cancelled', // 已取消
}

/**
 * 结算状态枚举（二手商品订单）
 */
export enum SettlementStatus {
  PENDING = 'pending', // 待结算
  SETTLING = 'settling', // 结算中
  SETTLED = 'settled', // 已结算
}

/**
 * 订单项接口
 */
export interface OrderItem {
  lineKey?: string;
  productId: number;
  productName: string;
  productImage?: string;
  quantity: number;
  price: number;
  discountAmount?: number;
  paidAmount?: number;
  skuId?: number;
  skuName?: string;
}

/**
 * 商城订单表
 * 存储商品订单信息和二手商品订单信息
 */
@Entity('orders', { comment: '商城订单表' })
@Index(['userId'])
@Index(['status'])
@Index(['orderType'])
@Index(['sellerId'])
export class Order {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ unique: true, comment: '订单号（唯一）' })
  orderNo: string;

  @Column({
    type: 'enum',
    enum: OrderType,
    default: OrderType.NORMAL,
    comment: '订单类型（普通/二手）',
  })
  orderType: OrderType;

  @Column({
    type: 'enum',
    enum: OrderStatus,
    default: OrderStatus.PENDING,
    comment: '订单状态',
  })
  status: OrderStatus;

  @Column({ type: 'decimal', precision: 10, scale: 2, comment: '订单总金额' })
  totalAmount: number;

  @Column({ nullable: true, comment: '使用的优惠券ID' })
  couponId: number;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0,
    comment: '优惠券优惠金额',
  })
  couponDiscount: number;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    comment: '原始总金额（优惠前）',
  })
  originalAmount: number;

  @Column({ type: 'json', nullable: true, comment: '订单商品列表（JSON格式）' })
  items: OrderItem[];

  @Column({ type: 'text', nullable: true, comment: '收货地址' })
  shippingAddress: string;

  @Column({ type: 'text', nullable: true, comment: '收货人姓名' })
  receiverName: string;

  @Column({ nullable: true, comment: '收货人电话' })
  receiverPhone: string;

  @Column({ nullable: true, comment: '订单备注' })
  remark: string;

  @Column({ comment: '购买用户ID（买家）' })
  userId: number;

  // ========== 二手商品订单字段 ==========

  @Column({ nullable: true, comment: '卖家ID（二手商品订单）' })
  sellerId: number;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    nullable: true,
    default: 0,
    comment: '平台手续费（二手商品订单）',
  })
  platformFee: number;

  @Column({
    type: 'decimal',
    precision: 5,
    scale: 2,
    nullable: true,
    comment: '支付时平台费率快照（百分比）',
  })
  platformFeeRate: number;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    nullable: true,
    comment: '卖家实际收入（二手商品订单）',
  })
  sellerIncome: number;

  @Column({ nullable: true, default: false, comment: '是否已付款（二手商品订单）' })
  isPaid: boolean;

  @Column({ type: 'datetime', nullable: true, comment: '确认收货时间（二手商品订单）' })
  confirmAt: Date;

  @Column({ nullable: true, default: 7, comment: '自动确认天数（二手商品订单，默认7）' })
  autoConfirmDays: number;

  @Column({ type: 'datetime', nullable: true, comment: '自动确认收货时间' })
  autoConfirmAt: Date;

  @Column({ type: 'datetime', nullable: true, comment: '库存恢复时间（幂等标记）' })
  inventoryRestoredAt: Date;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0,
    comment: '订单累计成功退款金额',
  })
  refundedAmount: number;

  @Column({ type: 'datetime', nullable: true, comment: '普通订单售后截止时间' })
  afterSaleDeadlineAt: Date;

  @Column({
    type: 'enum',
    enum: SettlementStatus,
    nullable: true,
    comment: '结算状态（二手商品订单）',
  })
  settlementStatus: SettlementStatus;

  @Column({ nullable: true, comment: '关联钱包明细ID（二手商品订单）' })
  settlementId: number;

  // ========== 关联关系 ==========

  @ManyToOne(() => User)
  @JoinColumn()
  user: User;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'sellerId' })
  seller: User;

  @ManyToOne(() => Coupon)
  @JoinColumn()
  coupon: Coupon;

  @ManyToOne(() => Logistics)
  @JoinColumn()
  logistics: Logistics;

  @ManyToOne(() => WalletTransaction)
  @JoinColumn({ name: 'settlementId' })
  settlement: WalletTransaction;

  // ========== 时间戳 ==========

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;

  @Column({ type: 'datetime', nullable: true, comment: '支付时间' })
  paidAt: Date;

  @Column({ type: 'datetime', nullable: true, comment: '发货时间' })
  shippedAt: Date;

  @Column({ type: 'datetime', nullable: true, comment: '完成时间' })
  completedAt: Date;

  // ========== 支付相关字段 ==========

  @Column({ nullable: true, comment: '支付方式（alipay/wechat/balance）' })
  paymentMethod: string;

  @Column({ nullable: true, comment: '支付单号' })
  paymentNo: string;

  @Column({ nullable: true, comment: '第三方交易流水号' })
  transactionId: string;

  // ========== 取消相关字段 ==========

  @Column({ type: 'text', nullable: true, comment: '取消原因' })
  cancelReason: string;

  @Column({ type: 'datetime', nullable: true, comment: '取消时间' })
  cancelledAt: Date;

  /** 订单详情返回字段：商城自动公益入账减去退款冲销后的净额。 */
  charityDonationAmount?: number | null;

  // ========== 物流相关字段 ==========

  @Column({ nullable: true, comment: '物流公司ID' })
  logisticsId: number;

  @Column({ length: 100, nullable: true, comment: '物流单号' })
  trackingNumber: string;
}
