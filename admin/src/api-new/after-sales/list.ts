import request from '@/axios'
import type { AfterSaleListParams, AfterSalePage } from './types'

const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

export const getAfterSaleListApi = async (params: AfterSaleListParams) => {
  try {
    return await request.get<AfterSalePage>({
      url: `${BASE_URL}/shop/admin/after-sales`,
      params
    })
  } catch (error) {
    return Promise.reject(error)
  }
}
