/**
 * 首页统计数据响应
 */
export interface DashboardStatsResponse {
  hospitals: number
  doctors: number
  users: number
  pets: number
}

/**
 * 通用分页响应类型（兼容多种后端格式）
 */
export interface PaginatedResponse<T> {
  // 列表数据（可能是 data 或 list）
  data?: T[]
  list?: T[]
  // 分页信息（可能在顶层或 meta/pagination 中）
  total?: number
  page?: number
  limit?: number
  pageSize?: number
  totalPages?: number
  meta?: {
    total: number
    page: number
    limit: number
  }
  pagination?: {
    total: number
    page: number
    pageSize: number
    totalPages: number
  }
}

/**
 * 物流公司类型定义
 */
export interface Logistics {
  id: number
  name: string
  code: string
  isEnabled: boolean
  createdAt: string
  updatedAt: string
}

/**
 * 物流公司表单数据
 */
export interface LogisticsForm {
  name: string
  code: string
  isEnabled?: boolean
}

/**
 * 订单状态枚举
 */
export enum OrderStatus {
  PENDING = 'pending',
  PAID = 'paid',
  SHIPPED = 'shipped',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled'
}

/**
 * 订单状态文本映射
 */
export const OrderStatusText: Record<OrderStatus, string> = {
  [OrderStatus.PENDING]: '待支付',
  [OrderStatus.PAID]: '已支付',
  [OrderStatus.SHIPPED]: '已发货',
  [OrderStatus.COMPLETED]: '已完成',
  [OrderStatus.CANCELLED]: '已取消'
}

/**
 * 订单类型枚举
 */
export enum OrderType {
  NORMAL = 'normal', // 普通商品订单
  SECOND_HAND = 'second_hand' // 二手商品订单
}

/**
 * 订单类型定义
 */
export interface Order {
  id: number
  orderNo: string
  orderType?: OrderType | string // 订单类型（普通/二手）
  status: OrderStatus | string // 兼容后端返回的字符串
  totalAmount: number | string // 后端返回字符串
  originalAmount: number | string
  couponDiscount: number | string
  items: OrderItem[]
  shippingAddress: string
  receiverName: string
  receiverPhone: string
  remark?: string
  userId: number // 买家ID
  sellerId?: number // 卖家ID（二手商品订单）
  user?: {
    id: number
    username: string
    phone?: string
    email?: string
    role: string
    isActive: boolean
    verified: boolean
    gender?: number
    avatar?: string
  }
  seller?: {
    id: number
    username: string
    phone?: string
  }
  createdAt: string
  paidAt?: string
  shippedAt?: string
  completedAt?: string
  cancelledAt?: string
  cancelReason?: string
  // 物流相关字段
  logisticsId?: number
  logistics?: Logistics
  trackingNumber?: string
  autoConfirmAt?: string
  platformFeeRate?: number | string
  platformFee?: number | string
  sellerIncome?: number | string
  settlementStatus?: 'pending' | 'settling' | 'settled'
  afterSaleSummary?: {
    id: number
    afterSaleNo: string
    status: string
    refundAmount: number | string
    updatedAt: string
  } | null
  // 支付相关字段
  paymentMethod?: string
  paymentNo?: string
  transactionId?: string
  // 优惠券相关
  couponId?: number | null
}

/**
 * 订单项
 */
export interface OrderItem {
  productId: number
  productName: string
  productImage?: string
  quantity: number
  price: number
  skuId?: number
  skuName?: string
}

/**
 * 订单查询参数
 */
export interface OrderQueryParams {
  search?: string
  status?: OrderStatus
  orderType?: OrderType
  afterSaleStatus?: string
  settlementStatus?: 'pending' | 'settling' | 'settled'
  page?: number
  limit?: number
}

/**
 * 更新订单状态 DTO
 */
export interface UpdateOrderStatusDto {
  status: OrderStatus
  cancelReason?: string
}

/**
 * 设置物流信息 DTO
 */
export interface UpdateShippingDto {
  logisticsId: number
  trackingNumber: string
}
