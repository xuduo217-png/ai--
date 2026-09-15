import request from '@/axios'
import type { AdminAfterSale, ReviewAfterSaleParams } from './types'

const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

export const reviewAfterSaleApi = async (params: ReviewAfterSaleParams) => {
  try {
    const { id, ...data } = params
    return await request.post<AdminAfterSale>({
      url: `${BASE_URL}/shop/admin/after-sales/${id}/review`,
      data
    })
  } catch (error) {
    return Promise.reject(error)
  }
}
