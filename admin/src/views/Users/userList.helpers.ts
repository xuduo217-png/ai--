import type {
  AdjustUserBalanceRequest,
  AdjustUserBalanceType,
  ResetUserPasswordRequest
} from '../../api-new/users'
import type { WalletTransaction } from '../../api-new/wallet/types'
import type { FormSchema } from '../../components/Form'
import { extractPagedTableData } from '@/utils/pagination'

export const getUserDialogFormSchema = (
  formSchema: FormSchema[],
  isEdit: boolean
): FormSchema[] => {
  if (!isEdit) {
    return formSchema
  }

  return formSchema.filter((schema) => schema.field !== 'password')
}

export const buildResetUserPasswordPayload = (
  password: string
): Pick<ResetUserPasswordRequest, 'password'> => {
  return {
    password: password.trim()
  }
}

export const normalizeBalanceAdjustAmount = (value: string): number => {
  return Number(Number(value.trim()).toFixed(2))
}

export const buildAdjustUserBalancePayload = (
  type: AdjustUserBalanceType,
  amount: number,
  remark?: string
): AdjustUserBalanceRequest => {
  return {
    type,
    amount,
    remark: remark?.trim() || (type === 'increase' ? '管理员手动增加余额' : '管理员手动减少余额')
  }
}

export const extractWalletTransactionsResult = (
  response: any
): {
  list: WalletTransaction[]
  total: number
} => {
  /**
   * 钱包明细同样走公共分页解析，兼容顶层 data 数组与历史嵌套分页结构
   */
  const { list, total } = extractPagedTableData<WalletTransaction>(response)

  return {
    list,
    total
  }
}
