import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
  ManyToOne,
  JoinColumn,
} from "typeorm";
import { User } from "../../users/entities/user.entity";
import { Category } from "./category.entity";

/**
 * 商品新旧程度枚举
 */
export enum ProductCondition {
  NEW = "new", // 全新
  NINETY_PERCENT = "90%", // 9成新
  EIGHTY_PERCENT = "80%", // 8成新
  SEVENTY_PERCENT = "70%", // 7成新
  SIXTY_PERCENT_BELOW = "60%", // 6成新及以下
}

/**
 * 商品审核状态枚举
 */
export enum PendingProductStatus {
  UNDER_REVIEW = "under_review", // 审核中
  APPROVED = "approved", // 兼容旧值（等同于已上架）
  ON_SHELF = "on_shelf", // 已上架
  OFF_SHELF = "off_shelf", // 已下架
  REJECTED = "rejected", // 审核未通过
  SOLD = "sold", // 已售出
}

/**
 * 商品临时表（用户发布的二手商品待审核）
 * 存储待审核的商品信息，审核通过后复制到正式表
 */
@Entity("products_pending", { comment: "商品临时表（待审核）" })
@Index(["userId"])
@Index(["productId"])
@Index(["categoryId"])
@Index(["status"])
export class ProductPending {
  @PrimaryGeneratedColumn({ comment: "主键ID" })
  id: number;

  @Column({ comment: "发布用户ID" })
  userId: number;

  /**
   * 正式表商品ID（编辑时关联）
   * 如果为空，表示是新发布的商品
   * 如果有值，表示是编辑已有商品
   */
  @Column({ nullable: true, comment: "正式表商品ID（编辑时关联）" })
  productId: number;

  @Column({ comment: "商品标题" })
  title: string;

  @Column({ type: "text", comment: "商品描述" })
  description: string;

  @Column({ type: "decimal", precision: 10, scale: 2, comment: "商品价格" })
  price: number;

  @Column({ default: 1, comment: "库存数量" })
  stock: number;

  @Column({ default: false, comment: "是否可议价" })
  negotiable: boolean;

  /**
   * 商品图片数组（半路径）
   * 例如: ["/uploads/products/img1.jpg", "/uploads/products/img2.jpg"]
   */
  @Column({ type: "json", comment: "商品图片数组（半路径）" })
  images: string[];

  @Column({ comment: "商品分类ID" })
  categoryId: number;

  @Column({
    type: "enum",
    enum: ProductCondition,
    comment: "新旧程度",
  })
  condition: ProductCondition;

  @Column({
    type: "decimal",
    precision: 10,
    scale: 2,
    default: 0,
    comment: "运费（0表示包邮）",
  })
  shippingFee: number;

  @Column({
    type: "enum",
    enum: PendingProductStatus,
    default: PendingProductStatus.UNDER_REVIEW,
    comment: "审核/上架状态",
  })
  status: PendingProductStatus;

  @Column({ type: "text", nullable: true, comment: "审核未通过原因" })
  rejectReason: string;

  // ========== 关联关系 ==========

  @ManyToOne(() => User)
  @JoinColumn({ name: "userId" })
  user: User;

  @ManyToOne(() => Category)
  @JoinColumn({ name: "categoryId" })
  category: Category;

  // ========== 时间戳 ==========

  @CreateDateColumn({ comment: "创建时间" })
  createdAt: Date;

  @UpdateDateColumn({ comment: "更新时间" })
  updatedAt: Date;
}
