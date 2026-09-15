import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  Index,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

/**
 * 支付状态
 */
export enum PaymentStatus {
  PENDING = 'pending', // 待支付
  PROCESSING = 'processing', // 支付中
  SUCCESS = 'success', // 支付成功
  FAILED = 'failed', // 支付失败
  REFUNDING = 'refunding', // 退款中
  REFUNDED = 'refunded', // 已退款
  CLOSED = 'closed', // 已关闭
}

/**
 * 支付渠道
 */
export enum PaymentChannel {
  BALANCE = 'balance', // 余额支付
  ALIPAY = 'alipay', // 支付宝
  WECHAT = 'wechat', // 微信支付
  ALIPAY_WAP = 'alipay_wap', // 支付宝 WAP（手机网站支付，预留）
  ALIPAY_WEB = 'alipay_web', // 支付宝网页支付（预留）
  WECHAT_JSAPI = 'wechat_jsapi', // 微信 JSAPI 支付（预留）
  WECHAT_H5 = 'wechat_h5', // 微信 H5 支付（预留）
  WECHAT_NATIVE = 'wechat_native', // 微信扫码支付（预留）
}

/**
 * 支付方式（APP/Web/扫码等）
 */
export enum PaymentMethod {
  APP = 'app', // APP 支付
  WEB = 'web', // 网页支付
  NATIVE = 'native', // 扫码支付
  H5 = 'h5', // H5 支付
  JSAPI = 'jsapi', // JSAPI 支付（公众号/小程序）
}

/**
 * 业务类型（用于关联不同模块的订单）
 */
export enum BusinessType {
  SHOP_ORDER = 'shop_order', // 商城订单
  WALLET_RECHARGE = 'wallet_recharge', // 钱包充值
  CHAT_PACKAGE = 'chat_package', // 聊天套餐
  APPOINTMENT = 'appointment', // 预约挂号（预留）
  CONSULTATION = 'consultation', // 问诊服务（预留）
  CHARITY_DONATION = 'charity_donation', // 公益捐款
}

/**
 * 支付记录表
 * 存储所有支付记录和状态
 */
@Entity('payments', { comment: '支付记录表' })
@Index('IDX_payments_userId', ['userId'])
@Index('IDX_payments_status', ['status'])
@Index('IDX_payments_channel', ['channel'])
@Index('IDX_payments_businessType', ['businessType'])
@Index('IDX_payments_businessId', ['businessId'])
export class Payment {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ unique: true, comment: '支付单号（系统生成，UUID）' })
  paymentNo: string;

  @Column({
    unique: true,
    comment: '商户订单号（关联业务订单号，格式：{businessType}_{businessId}）',
  })
  outTradeNo: string;

  @Column({
    type: 'enum',
    enum: PaymentChannel,
    comment: '支付渠道',
  })
  channel: PaymentChannel;

  @Column({
    type: 'enum',
    enum: PaymentMethod,
    default: PaymentMethod.APP,
    comment: '支付方式',
  })
  method: PaymentMethod;

  @Column({
    type: 'enum',
    enum: PaymentStatus,
    default: PaymentStatus.PENDING,
    comment: '支付状态',
  })
  status: PaymentStatus;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    comment: '支付金额（元）',
  })
  amount: number;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0,
    comment: '退款金额（元）',
  })
  refundAmount: number;

  @Column({ nullable: true, comment: '第三方交易号（支付宝/微信返回）' })
  transactionId: string;

  @Column({ nullable: true, comment: '第三方流水号（用于查账）' })
  thirdPartyTradeNo: string;

  @Column({ comment: '支付用户ID' })
  userId: number;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column({
    type: 'enum',
    enum: BusinessType,
    comment: '业务类型（关联不同模块）',
  })
  businessType: BusinessType;

  @Column({ comment: '业务ID（订单ID等）' })
  businessId: number;

  @Column({ type: 'varchar', length: 256, comment: '商品标题/描述' })
  subject: string;

  @Column({ type: 'text', nullable: true, comment: '商品详情（可选）' })
  body: string;

  @Column({
    type: 'varchar',
    length: 256,
    nullable: true,
    comment: '商品描述（用于微信支付等）',
  })
  description: string;

  @Column({
    type: 'varchar',
    length: 64,
    nullable: true,
    comment: '客户端IP（用于风控）',
  })
  clientIp: string;

  @Column({ type: 'json', nullable: true, comment: '扩展信息（JSON格式）' })
  metadata: Record<string, any>;

  @Column({ type: 'timestamp', nullable: true, comment: '支付完成时间' })
  paidAt: Date;

  @Column({ type: 'timestamp', nullable: true, comment: '退款时间' })
  refundedAt: Date;

  @Column({ type: 'timestamp', nullable: true, comment: '关闭时间' })
  closedAt: Date;

  @Column({ type: 'timestamp', nullable: true, comment: '过期时间' })
  expiredAt: Date;

  @Column({ type: 'text', nullable: true, comment: '失败原因' })
  failReason: string;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @Column({ type: 'timestamp', nullable: true, comment: '更新时间' })
  updatedAt: Date;
}
