import request from '@/axios'
import type { WalletWithdrawalConfig } from './types'

const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

export const getWalletWithdrawalConfig = async (_params: Record<string, never>) => {
  try {
    return await request.get<WalletWithdrawalConfig>({
      url: `${BASE_URL}/admin/wallet/withdrawal-config`
    })
  } catch (error) {
    return Promise.reject(error)
  }
}
