import assert from 'node:assert/strict'
import { extractPagedTableData } from '../src/views/Product/productList.helpers'

const normalizedResponse = {
  data: [
    { id: 1, title: '二手猫粮' },
    { id: 2, title: '二手猫窝' }
  ],
  pagination: {
    total: 2,
    page: 1,
    pageSize: 10,
    limit: 10
  }
}

assert.deepEqual(extractPagedTableData(normalizedResponse), {
  list: normalizedResponse.data,
  total: 2
})

const legacyNestedResponse = {
  data: {
    data: [{ id: 3, title: '旧结构商品' }],
    total: 1
  }
}

assert.deepEqual(extractPagedTableData(legacyNestedResponse), {
  list: legacyNestedResponse.data.data,
  total: 1
})

console.log('shop list response regression checks passed')
