import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
  VersionColumn,
} from "typeorm";
import { OrderAfterSale } from "./order-after-sale.entity";

@Entity("order_after_sale_items", { comment: "订单售后商品行快照" })
@Index(["afterSaleId", "lineKey"], { unique: true })
@Index(["productId"])
export class OrderAfterSaleItem {
  @PrimaryGeneratedColumn({ comment: "主键ID" })
  id: number;

  @Column({ comment: "售后单ID" })
  afterSaleId: number;

  @ManyToOne(() => OrderAfterSale, (afterSale) => afterSale.items)
  @JoinColumn({ name: "afterSaleId" })
  afterSale: OrderAfterSale;

  @Column({ length: 80, comment: "订单商品稳定行键" })
  lineKey: string;

  @Column({ comment: "商品ID快照" })
  productId: number;

  @Column({ nullable: true, comment: "SKU ID快照" })
  skuId: number | null;

  @Column({ length: 255, comment: "商品名称快照" })
  productName: string;

  @Column({ length: 255, nullable: true, comment: "SKU名称快照" })
  skuName: string | null;

  @Column({ length: 500, nullable: true, comment: "商品图片快照" })
  productImage: string | null;

  @Column({ type: "int", comment: "申请售后数量" })
  requestedQuantity: number;

  @Column({ type: "int", default: 0, comment: "审批退款数量" })
  approvedQuantity: number;

  @Column({ type: "int", default: 0, comment: "已成功退款数量" })
  refundedQuantity: number;

  @Column({ type: "decimal", precision: 10, scale: 2, comment: "成交单价快照" })
  unitPrice: number;

  @Column({ type: "decimal", precision: 10, scale: 2, comment: "申请数量优惠分摊" })
  discountAmount: number;

  @Column({ type: "decimal", precision: 10, scale: 2, comment: "申请数量实付金额" })
  paidAmount: number;

  @Column({ type: "decimal", precision: 10, scale: 2, default: 0, comment: "审批退款金额" })
  approvedAmount: number;

  @Column({ type: "decimal", precision: 10, scale: 2, default: 0, comment: "已成功退款金额" })
  refundedAmount: number;

  @Column({ type: "int", default: 0, comment: "审批可回补库存数量" })
  restockQuantity: number;

  @Column({ type: "int", default: 0, comment: "已回补库存数量" })
  inventoryRestoredQuantity: number;

  @VersionColumn({ comment: "乐观锁版本" })
  version: number;

  @CreateDateColumn({ comment: "创建时间" })
  createdAt: Date;

  @UpdateDateColumn({ comment: "更新时间" })
  updatedAt: Date;
}
