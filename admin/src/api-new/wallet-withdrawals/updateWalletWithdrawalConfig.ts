import request from '@/axios'
import type { UpdateWalletWithdrawalConfigParams, WalletWithdrawalConfig } from './types'

const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

export const updateWalletWithdrawalConfig = async (params: UpdateWalletWithdrawalConfigParams) => {
  try {
    return await request.put<WalletWithdrawalConfig>({
      url: `${BASE_URL}/admin/wallet/withdrawal-config`,
      data: params
    })
  } catch (error) {
    return Promise.reject(error)
  }
}
