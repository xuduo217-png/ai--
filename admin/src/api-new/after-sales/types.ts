export type AfterSaleStatus =
  | 'pending_handler'
  | 'handler_rejected'
  | 'handler_timeout'
  | 'waiting_buyer_return'
  | 'waiting_handler_receipt'
  | 'arbitration_pending'
  | 'refunding'
  | 'refunded'
  | 'closed'

export type ArbitrationDecision = 'support_buyer' | 'support_seller'
export type AfterSaleHandlerType = 'seller' | 'platform'
export type AfterSaleType = 'refund_only' | 'return_refund'
export type AfterSaleOrderType = 'normal' | 'second_hand'

export interface AfterSaleUserSummary {
  id: number
  username: string
  phone?: string
  avatar?: string
}

export interface AfterSaleLog {
  id: number
  operatorType: 'buyer' | 'seller' | 'admin' | 'system'
  action: string
  fromStatus?: AfterSaleStatus
  toStatus?: AfterSaleStatus
  description?: string
  snapshot?: Record<string, unknown>
  createdAt: string
}

export interface AfterSaleOrderItem {
  lineKey: string
  productId: number
  productName: string
  productImage?: string
  quantity: number
  price: number
}

export interface AdminAfterSaleItem {
  id: number
  lineKey: string
  productId: number
  skuId?: number
  productName: string
  skuName?: string
  productImage?: string
  requestedQuantity: number
  approvedQuantity: number
  refundedQuantity: number
  unitPrice: number | string
  discountAmount: number | string
  paidAmount: number | string
  approvedAmount: number | string
  refundedAmount: number | string
  restockQuantity: number
  inventoryRestoredQuantity: number
}

export interface AdminAfterSale {
  id: number
  afterSaleNo: string
  orderId: number
  buyerId: number
  sellerId?: number | null
  orderType: AfterSaleOrderType
  handlerType: AfterSaleHandlerType
  afterSaleType: AfterSaleType
  status: AfterSaleStatus
  reasonCode: string
  description?: string
  evidenceUrls?: string[]
  sellerDecision?: 'approved' | 'rejected'
  sellerReason?: string
  handlerDecision?: 'approved' | 'rejected'
  handlerReason?: string | null
  returnRequired?: boolean
  returnAddress?: string
  returnTrackingNumber?: string
  returnEvidenceUrls?: string[]
  arbitrationReason?: string
  arbitrationEvidenceUrls?: string[]
  arbitrationDecision?: ArbitrationDecision
  arbitrationRemark?: string | null
  refundId?: number
  refundAmount: number | string
  refundFailureReason?: string
  sellerDeadlineAt?: string
  arbitrationDeadlineAt?: string
  buyerReturnDeadlineAt?: string
  sellerReceiptDeadlineAt?: string
  currentDeadlineAt?: string
  arbitrationAt?: string
  refundedAt?: string
  closedAt?: string
  createdAt: string
  updatedAt: string
  isOverdue: boolean
  availableActions: string[]
  requestedAmount: number | string
  approvedAmount?: number | string
  items: AdminAfterSaleItem[]
  buyer?: AfterSaleUserSummary
  seller?: AfterSaleUserSummary
  order?: {
    id: number
    orderNo: string
    totalAmount: number | string
    status: string
    paymentMethod?: string
    paymentNo?: string
    transactionId?: string
    shippedAt?: string
    trackingNumber?: string
    receiverName?: string
    receiverPhone?: string
    shippingAddress?: string
    items: AfterSaleOrderItem[]
  }
  logs?: AfterSaleLog[]
}

export interface AfterSaleListParams {
  page?: number
  pageSize?: number
  keyword?: string
  status?: AfterSaleStatus
  orderType?: AfterSaleOrderType
  handlerType?: AfterSaleHandlerType
  productId?: number
  buyerId?: number
  overdue?: 'true' | 'false'
  view?:
    | 'pending'
    | 'platform_pending'
    | 'second_hand_arbitration'
    | 'processing'
    | 'finished'
    | 'all'
  createdFrom?: string
  createdTo?: string
}

export interface ReviewAfterSaleParams {
  id: number
  decision: 'approve' | 'reject'
  afterSaleType?: AfterSaleType
  approvedItems?: Array<{ lineKey: string; quantity: number }>
  reason?: string
  returnAddress?: string
}

export interface ConfirmAfterSaleReturnParams {
  id: number
  items: Array<{ lineKey: string; restockQuantity: number }>
  remark?: string
}

export interface AfterSalePage {
  data: AdminAfterSale[]
  total: number
  page: number
  pageSize: number
  totalPages: number
}
