import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
  VersionColumn,
} from "typeorm";
import { User } from "../../users/entities/user.entity";
import { Refund } from "../../payment/entities/refund.entity";
import { Order, OrderType } from "./order.entity";
import { OrderAfterSaleItem } from "./order-after-sale-item.entity";

export enum AfterSaleStatus {
  PENDING_HANDLER = "pending_handler",
  HANDLER_REJECTED = "handler_rejected",
  HANDLER_TIMEOUT = "handler_timeout",
  WAITING_BUYER_RETURN = "waiting_buyer_return",
  WAITING_HANDLER_RECEIPT = "waiting_handler_receipt",
  ARBITRATION_PENDING = "arbitration_pending",
  REFUNDING = "refunding",
  REFUNDED = "refunded",
  CLOSED = "closed",
}

export enum AfterSaleHandlerType {
  SELLER = "seller",
  PLATFORM = "platform",
}

export enum AfterSaleType {
  REFUND_ONLY = "refund_only",
  RETURN_REFUND = "return_refund",
}

export enum HandlerDecision {
  APPROVED = "approved",
  REJECTED = "rejected",
}

export enum ArbitrationDecision {
  SUPPORT_BUYER = "support_buyer",
  SUPPORT_SELLER = "support_seller",
}

export const ACTIVE_AFTER_SALE_STATUSES = [
  AfterSaleStatus.PENDING_HANDLER,
  AfterSaleStatus.HANDLER_REJECTED,
  AfterSaleStatus.HANDLER_TIMEOUT,
  AfterSaleStatus.WAITING_BUYER_RETURN,
  AfterSaleStatus.WAITING_HANDLER_RECEIPT,
  AfterSaleStatus.ARBITRATION_PENDING,
  AfterSaleStatus.REFUNDING,
] as const;

@Entity("order_after_sales", { comment: "商城订单统一售后单" })
@Index(["orderId", "status"])
@Index(["buyerId", "status"])
@Index(["sellerId", "status"])
export class OrderAfterSale {
  @PrimaryGeneratedColumn({ comment: "主键ID" })
  id: number;

  @Column({ length: 40, unique: true, comment: "售后编号" })
  afterSaleNo: string;

  @Column({ comment: "订单ID" })
  orderId: number;

  @ManyToOne(() => Order)
  @JoinColumn({ name: "orderId" })
  order: Order;

  @Column({ type: "enum", enum: OrderType, comment: "订单类型快照" })
  orderType: OrderType;

  @Column({ type: "enum", enum: AfterSaleHandlerType, comment: "售后处理方" })
  handlerType: AfterSaleHandlerType;

  @Column({ type: "enum", enum: AfterSaleType, comment: "申请售后类型" })
  afterSaleType: AfterSaleType;

  @Column({ comment: "买家ID" })
  buyerId: number;

  @ManyToOne(() => User)
  @JoinColumn({ name: "buyerId" })
  buyer: User;

  @Column({ nullable: true, comment: "卖家ID，平台售后为空" })
  sellerId: number | null;

  @ManyToOne(() => User)
  @JoinColumn({ name: "sellerId" })
  seller: User;

  @Column({ type: "enum", enum: AfterSaleStatus, comment: "售后状态" })
  status: AfterSaleStatus;

  @Column({ length: 50, comment: "售后原因编码" })
  reasonCode: string;

  @Column({ type: "text", nullable: true, comment: "售后说明" })
  description: string;

  @Column({ type: "json", nullable: true, comment: "买家凭证图片" })
  evidenceUrls: string[];

  @Column({
    type: "enum",
    enum: HandlerDecision,
    nullable: true,
    comment: "处理方决定",
  })
  handlerDecision: HandlerDecision;

  @Column({ type: "text", nullable: true, comment: "处理方说明" })
  handlerReason: string;

  @Column({ type: "boolean", nullable: true, comment: "是否要求退货" })
  returnRequired: boolean;

  @Column({ type: "text", nullable: true, comment: "退货地址" })
  returnAddress: string;

  @Column({ length: 100, nullable: true, comment: "买家退货物流单号" })
  returnTrackingNumber: string;

  @Column({ type: "json", nullable: true, comment: "买家退货凭证图片" })
  returnEvidenceUrls: string[];

  @Column({ type: "text", nullable: true, comment: "仲裁申请理由" })
  arbitrationReason: string;

  @Column({ type: "json", nullable: true, comment: "仲裁凭证图片" })
  arbitrationEvidenceUrls: string[];

  @Column({
    type: "enum",
    enum: ArbitrationDecision,
    nullable: true,
    comment: "仲裁结果",
  })
  arbitrationDecision: ArbitrationDecision;

  @Column({ type: "text", nullable: true, comment: "仲裁说明" })
  arbitrationRemark: string;

  @Column({ nullable: true, comment: "仲裁管理员ID" })
  arbitratorId: number;

  @ManyToOne(() => User)
  @JoinColumn({ name: "arbitratorId" })
  arbitrator: User;

  @Column({ nullable: true, comment: "平台审批管理员ID" })
  reviewerId: number | null;

  @ManyToOne(() => User)
  @JoinColumn({ name: "reviewerId" })
  reviewer: User;

  @Column({ type: "datetime", nullable: true, comment: "平台审批时间" })
  reviewedAt: Date | null;

  @Column({ nullable: true, comment: "有效退款记录ID" })
  refundId: number;

  @ManyToOne(() => Refund)
  @JoinColumn({ name: "refundId" })
  refund: Refund;

  @Column({ type: "decimal", precision: 10, scale: 2, comment: "买家申请金额" })
  requestedAmount: number;

  @Column({ type: "decimal", precision: 10, scale: 2, nullable: true, comment: "审批退款金额" })
  approvedAmount: number | null;

  @Column({ type: "text", nullable: true, comment: "最近一次退款失败原因" })
  refundFailureReason: string;

  @Column({ type: "datetime", nullable: true, comment: "处理方处理截止时间" })
  handlerDeadlineAt: Date;

  @Column({ type: "datetime", nullable: true, comment: "买家申请仲裁截止时间" })
  arbitrationDeadlineAt: Date;

  @Column({ type: "datetime", nullable: true, comment: "买家退货截止时间" })
  buyerReturnDeadlineAt: Date;

  @Column({ type: "datetime", nullable: true, comment: "处理方确认退货截止时间" })
  handlerReceiptDeadlineAt: Date;

  @Column({ type: "datetime", nullable: true, comment: "仲裁申请时间" })
  arbitrationAt: Date;

  @Column({ type: "datetime", nullable: true, comment: "退款完成时间" })
  refundedAt: Date;

  @Column({ type: "datetime", nullable: true, comment: "售后关闭时间" })
  closedAt: Date;

  @OneToMany(() => OrderAfterSaleItem, (item) => item.afterSale)
  items: OrderAfterSaleItem[];

  @VersionColumn({ comment: "乐观锁版本" })
  version: number;

  @CreateDateColumn({ comment: "创建时间" })
  createdAt: Date;

  @UpdateDateColumn({ comment: "更新时间" })
  updatedAt: Date;
}
