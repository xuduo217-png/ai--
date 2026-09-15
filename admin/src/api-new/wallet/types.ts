/**
 * 钱包模块类型定义
 */

/**
 * 钱包交易状态枚举
 */
export enum WalletTransactionStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected'
}

/**
 * 钱包交易类型枚举
 */
export enum WalletTransactionType {
  INCOME = 'income',
  EXPENSE = 'expense',
  FREEZE = 'freeze',
  UNFREEZE = 'unfreeze'
}

/**
 * 关联类型枚举
 */
export enum RelatedType {
  ORDER = 'order',
  REFUND = 'refund',
  RECHARGE = 'recharge',
  WITHDRAW = 'withdraw',
  ADJUSTMENT = 'adjustment'
}

/**
 * 钱包交易明细
 */
export interface WalletTransaction {
  id: number
  userId: number
  user?: {
    id: number
    phone: string
    username?: string
  }
  type: WalletTransactionType
  amount: number
  balanceBefore: number
  balanceAfter: number
  relatedType: RelatedType
  relatedId: number
  status: WalletTransactionStatus
  remark?: string
  frozenAmount?: number
  rejectReason?: string
  reviewedAt?: string
  reviewedBy?: number
  autoProcessed?: boolean
  withdrawalStatus?: string
  withdrawalNo?: string
  historicalAdjustment?: boolean
  createdAt: string
  waitingDays?: number
  isOverdue?: boolean
}

/**
 * 获取钱包流水列表请求参数
 */
export interface GetWalletTransactionListParams {
  page?: number
  limit?: number
  userId?: number
  status?: WalletTransactionStatus
  type?: WalletTransactionType
  relatedType?: RelatedType
}

/**
 * 审核通过请求
 */
export interface ApproveTransactionRequest {
  remark?: string
}

/**
 * 审核拒绝请求
 */
export interface RejectTransactionRequest {
  reason: string
}
