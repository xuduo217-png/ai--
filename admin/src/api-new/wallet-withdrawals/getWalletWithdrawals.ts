import request from '@/axios'
import type { WalletWithdrawal, WalletWithdrawalListParams } from './types'

const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

export const getWalletWithdrawals = async (params: WalletWithdrawalListParams) => {
  try {
    return await request.get<WalletWithdrawal[]>({
      url: `${BASE_URL}/admin/wallet/withdrawals`,
      params
    })
  } catch (error) {
    return Promise.reject(error)
  }
}
