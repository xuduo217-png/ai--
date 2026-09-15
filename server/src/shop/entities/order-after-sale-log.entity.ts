import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from "typeorm";
import { AfterSaleStatus, OrderAfterSale } from "./order-after-sale.entity";

export enum AfterSaleOperatorType {
  BUYER = "buyer",
  SELLER = "seller",
  ADMIN = "admin",
  SYSTEM = "system",
}

@Entity("order_after_sale_logs", { comment: "二手订单售后操作日志" })
@Index(["afterSaleId", "createdAt"])
export class OrderAfterSaleLog {
  @PrimaryGeneratedColumn({ comment: "主键ID" })
  id: number;

  @Column({ comment: "售后单ID" })
  afterSaleId: number;

  @ManyToOne(() => OrderAfterSale)
  @JoinColumn({ name: "afterSaleId" })
  afterSale: OrderAfterSale;

  @Column({ type: "enum", enum: AfterSaleOperatorType, comment: "操作人类型" })
  operatorType: AfterSaleOperatorType;

  @Column({ nullable: true, comment: "操作人ID" })
  operatorId: number;

  @Column({ length: 50, comment: "操作名称" })
  action: string;

  @Column({
    type: "enum",
    enum: AfterSaleStatus,
    nullable: true,
    comment: "原状态",
  })
  fromStatus: AfterSaleStatus;

  @Column({
    type: "enum",
    enum: AfterSaleStatus,
    nullable: true,
    comment: "新状态",
  })
  toStatus: AfterSaleStatus;

  @Column({ type: "text", nullable: true, comment: "操作说明" })
  description: string;

  @Column({ type: "json", nullable: true, comment: "操作快照" })
  snapshot: Record<string, unknown>;

  @CreateDateColumn({ comment: "操作时间" })
  createdAt: Date;
}
