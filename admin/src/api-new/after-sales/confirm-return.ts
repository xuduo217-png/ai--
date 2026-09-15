import request from '@/axios'
import type { AdminAfterSale, ConfirmAfterSaleReturnParams } from './types'

const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

export const confirmAfterSaleReturnApi = async (params: ConfirmAfterSaleReturnParams) => {
  try {
    const { id, ...data } = params
    return await request.post<AdminAfterSale>({
      url: `${BASE_URL}/shop/admin/after-sales/${id}/confirm-return`,
      data
    })
  } catch (error) {
    return Promise.reject(error)
  }
}
