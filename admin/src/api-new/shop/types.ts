/**
 * 商品相关类型定义
 */

// 商品分类
export interface ProductCategory {
  id: number
  name: string
  icon?: string
  image?: string
  description?: string
  status: 'ACTIVE' | 'DISABLED'
  sortOrder: number
  parentId?: number
  parent?: ProductCategory
  children?: ProductCategory[]
  createdAt: string
  updatedAt: string
}

// 商品 SKU
export interface ProductSku {
  id: number
  name: string
  specs: Record<string, string>
  price: number
  originalPrice?: number
  stock: number
  status: 'ACTIVE' | 'INACTIVE' | 'OUT_OF_STOCK'
  image?: string
  skuCode?: string
  productId: number
  createdAt: string
  updatedAt: string
}

// 商品
export interface Product {
  id: number
  name: string
  description?: string
  price: number
  stock: number
  image?: string
  images?: string[]
  isActive: boolean
  isVirtual: boolean
  category: string // 原有枚举分类
  categoryId?: number // 新增分类ID
  hasSku: boolean // 是否多规格
  publishSource: 'ADMIN' | 'USER'
  publishedBy?: number
  auditedBy?: number
  auditedAt?: string
  auditRemark?: string
  publisher?: any
  auditor?: any
  skus?: ProductSku[]
  version?: number
  createdAt: string
  updatedAt: string
}

// 商品查询参数
export interface ProductQueryParams {
  page?: number
  pageSize?: number
  keyword?: string
  category?: string
  categoryId?: number
  publishSource?: 'ADMIN' | 'USER'
  minPrice?: number
  maxPrice?: number
  publishedBy?: number
  isActive?: boolean
  sortBy?: string
  sortOrder?: 'ASC' | 'DESC'
}

// 商品创建/更新参数
export interface ProductCreateParams {
  name: string
  description?: string
  price: number
  stock: number
  image?: string
  images?: string[]
  isActive?: boolean
  isVirtual?: boolean
  category: string
  categoryId?: number
  hasSku?: boolean
  skus?: Partial<ProductSku>[]
}

export interface ProductUpdateParams extends Partial<ProductCreateParams> {
  id: number
}

export interface MallHomepageHotProductsConfig {
  productIds: number[]
}

export type MallHomepageBannerActionType = 'none' | 'product'

export interface MallHomepageBannerItem {
  id?: string
  imageUrl: string
  actionType?: MallHomepageBannerActionType
  productId?: number
  link?: string
  sortOrder: number
}

export interface MallHomepageBannersConfig {
  banners: MallHomepageBannerItem[]
}

// 优惠券
export interface Coupon {
  id: number
  name: string
  description?: string
  type: 'FULL_REDUCTION' | 'DISCOUNT' | 'DIRECT_DISCOUNT'
  couponStatus: 'ACTIVE' | 'EXPIRED' | 'REVOKED'
  minAmount: string | number
  discountValue: string | number
  maxDiscount?: string | number | null
  stock: number
  claimedCount: number
  perUserLimit: number
  validFrom: string
  validAt: string
  // 新增字段
  scope: 'ALL' | 'SPECIFIC'
  minOrderAmount: string | number
  canStack: number
  isEnabled: number
  isExpired: number
  isClaimedOut: number
  claimType?: 'NEW_USER' | 'SCAN_CODE'
  claimCode?: string
  products?: Product[]
  createdAt: string
  updatedAt: string
}

// 优惠券创建/更新参数
export interface CouponCreateParams {
  name: string
  description?: string
  type: 'FULL_REDUCTION' | 'DISCOUNT' | 'DIRECT_DISCOUNT'
  minAmount: number
  discountValue: number
  maxDiscount?: number
  stock: number
  perUserLimit: number
  validFrom: string
  validAt: string
  // 新增字段
  scope?: 'ALL' | 'SPECIFIC'
  productIds?: number[]
  minOrderAmount?: number
  canStack?: number
  isEnabled?: number
  claimType?: 'NEW_USER' | 'SCAN_CODE'
}

export interface CouponUpdateParams extends Partial<CouponCreateParams> {
  id: number
}

// 用户优惠券
export interface UserCoupon {
  id: number
  userId: number
  couponId: number
  coupon?: Coupon & {
    validUntil?: string
    isEnabled?: boolean
  }
  status: 'AVAILABLE' | 'USED' | 'EXPIRED'
  validFrom?: string
  validUntil?: string
  usedAt?: string
  orderId?: number
  expiresAt: string
  createdAt: string
}
