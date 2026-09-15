export type WalletWithdrawalStatus =
  | 'pending_review'
  | 'processing'
  | 'succeeded'
  | 'rejected'
  | 'failed'

export interface WalletWithdrawalUser {
  id: number
  phone: string
  username?: string
}

export interface WalletWithdrawalLog {
  id: number
  fromStatus?: WalletWithdrawalStatus | null
  toStatus: WalletWithdrawalStatus
  action: string
  actorType: 'user' | 'admin' | 'system'
  actorId?: number | null
  externalCode?: string | null
  description?: string | null
  createdAt: string
}

export interface WalletWithdrawal {
  id: number
  withdrawalNo: string
  amount: number
  status: WalletWithdrawalStatus
  payeeIdentityType: 'ALIPAY_LOGON_ID'
  payeeAccountMasked: string
  payeeNameMasked: string
  outBizNo?: string | null
  alipayOrderId?: string | null
  payFundOrderId?: string | null
  alipayStatus?: string | null
  failureCode?: string | null
  failureMessage?: string | null
  rejectReason?: string | null
  reviewedBy?: number | null
  reviewedAt?: string | null
  processingAt?: string | null
  completedAt?: string | null
  failedAt?: string | null
  createdAt: string
  updatedAt: string
  user?: WalletWithdrawalUser | null
  logs?: WalletWithdrawalLog[]
}

export interface WalletWithdrawalListParams {
  page?: number
  limit?: number
  withdrawalNo?: string
  userId?: number
  phone?: string
  status?: WalletWithdrawalStatus
  startDate?: string
  endDate?: string
}

export interface WalletWithdrawalConfig {
  businessEnabled: boolean
  minAmount: number
  maxAmountPerRequest: number
  maxAmountPerDay: number
  transferConfigured: boolean
  piiEncryptionConfigured: boolean
  unavailableReason?: string | null
}

export interface UpdateWalletWithdrawalConfigParams {
  businessEnabled: boolean
  minAmount: string
  maxAmountPerRequest: string
  maxAmountPerDay: string
}
