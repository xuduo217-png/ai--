import request from '@/axios'
import type { AdminAfterSale, ArbitrationDecision } from './types'

const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

export const arbitrateAfterSaleApi = async (params: {
  id: number
  decision: ArbitrationDecision
  remark?: string
}) => {
  try {
    return await request.post<AdminAfterSale>({
      url: `${BASE_URL}/shop/admin/after-sales/${params.id}/arbitrate`,
      data: { decision: params.decision, remark: params.remark }
    })
  } catch (error) {
    return Promise.reject(error)
  }
}
