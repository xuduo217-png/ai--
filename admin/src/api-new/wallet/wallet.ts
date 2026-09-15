/**
 * 钱包管理 API
 */
import request from '@/axios'
import type {
  WalletTransaction,
  GetWalletTransactionListParams,
  ApproveTransactionRequest,
  RejectTransactionRequest
} from './types'

// 重新导出类型，方便外部使用
export type {
  WalletTransaction,
  GetWalletTransactionListParams,
  ApproveTransactionRequest,
  RejectTransactionRequest
}

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 获取钱包流水列表
 *
 * GET /admin/wallet/transactions
 */
export const getWalletTransactionsApi = async (params: GetWalletTransactionListParams = {}) => {
  try {
    return await request.get<{
      items: WalletTransaction[]
      total: number
      page: number
      limit: number
    }>({
      url: `${BASE_URL}/admin/wallet/transactions`,
      params
    })
  } catch (error) {
    return Promise.reject(error)
  }
}

/**
 * 审核通过
 * POST /admin/wallet/transactions/:id/approve
 */
export const approveTransactionApi = (id: number, data?: ApproveTransactionRequest) => {
  return request.post<WalletTransaction>({
    url: `${BASE_URL}/admin/wallet/transactions/${id}/approve`,
    data
  })
}

/**
 * 审核拒绝
 * POST /admin/wallet/transactions/:id/reject
 */
export const rejectTransactionApi = (id: number, data: RejectTransactionRequest) => {
  return request.post<WalletTransaction>({
    url: `${BASE_URL}/admin/wallet/transactions/${id}/reject`,
    data
  })
}

/**
 * 获取用户钱包明细
 * GET /users/:userId/wallet-transactions
 */
export const getUserWalletTransactionsApi = (
  userId: number,
  params?: {
    page?: number
    limit?: number
    type?: string
    status?: string
  }
) => {
  return request.get<{
    data: WalletTransaction[]
    total: number
    page: number
    limit: number
  }>({
    url: `${BASE_URL}/users/${userId}/wallet-transactions`,
    params
  })
}
