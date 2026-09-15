import request from '@/axios'
import type { AdminAfterSale } from './types'

const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

export const retryAfterSaleRefundApi = async (params: { id: number }) => {
  try {
    return await request.post<AdminAfterSale>({
      url: `${BASE_URL}/shop/admin/after-sales/${params.id}/refund/retry`
    })
  } catch (error) {
    return Promise.reject(error)
  }
}
