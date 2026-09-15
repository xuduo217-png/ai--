import assert from 'node:assert/strict'
import type { FormSchema } from '../src/components/Form'
import {
  extractWalletTransactionsResult,
  buildResetUserPasswordPayload,
  getUserDialogFormSchema
} from '../src/views/Users/userList.helpers'

const baseSchemas = [
  { field: 'username' },
  { field: 'password' },
  { field: 'phone' }
] as FormSchema[]

const createSchemas = getUserDialogFormSchema(baseSchemas, false)
assert.equal(
  createSchemas.some((schema) => schema.field === 'password'),
  true,
  '新增用户时应显示密码字段'
)

const editSchemas = getUserDialogFormSchema(baseSchemas, true)
assert.equal(
  editSchemas.some((schema) => schema.field === 'password'),
  false,
  '编辑用户时应移除密码字段'
)

assert.equal(
  baseSchemas.some((schema) => schema.field === 'password'),
  true,
  'schema 过滤逻辑不应修改原始数组'
)

assert.deepEqual(buildResetUserPasswordPayload('  new-password-123  '), {
  password: 'new-password-123'
})

const normalizedWalletResponse = {
  data: [
    {
      id: 1,
      type: 'income',
      amount: 50
    }
  ],
  pagination: {
    total: 1,
    page: 1,
    pageSize: 10,
    limit: 10
  }
}

assert.deepEqual(extractWalletTransactionsResult(normalizedWalletResponse), {
  list: normalizedWalletResponse.data,
  total: 1
})

const legacyWalletResponse = {
  data: {
    data: [
      {
        id: 2,
        type: 'expense',
        amount: 20
      }
    ],
    total: 1
  }
}

assert.deepEqual(extractWalletTransactionsResult(legacyWalletResponse), {
  list: legacyWalletResponse.data.data,
  total: 1
})

console.log('user-list regression checks passed')
