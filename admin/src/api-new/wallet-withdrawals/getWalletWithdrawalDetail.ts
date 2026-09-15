import request from '@/axios'
import type { WalletWithdrawal } from './types'

const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

export const getWalletWithdrawalDetail = async (params: { id: number }) => {
  try {
    return await request.get<WalletWithdrawal>({
      url: `${BASE_URL}/admin/wallet/withdrawals/${params.id}`
    })
  } catch (error) {
    return Promise.reject(error)
  }
}
