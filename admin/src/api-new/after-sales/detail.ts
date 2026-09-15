import request from '@/axios'
import type { AdminAfterSale } from './types'

const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

export const getAfterSaleDetailApi = async (params: { id: number }) => {
  try {
    return await request.get<AdminAfterSale>({
      url: `${BASE_URL}/shop/admin/after-sales/${params.id}`
    })
  } catch (error) {
    return Promise.reject(error)
  }
}
