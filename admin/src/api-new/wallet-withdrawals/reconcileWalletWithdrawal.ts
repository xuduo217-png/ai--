import request from '@/axios'
import type { WalletWithdrawal } from './types'

const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

export const reconcileWalletWithdrawal = async (params: { id: number }) => {
  try {
    return await request.post<WalletWithdrawal>({
      url: `${BASE_URL}/admin/wallet/withdrawals/${params.id}/reconcile`
    })
  } catch (error) {
    return Promise.reject(error)
  }
}
