import assert from 'node:assert/strict'
import {
  createBannerItem,
  createHotProductSelections,
  normalizeSelectedProductIds,
  serializeHotProductIds
} from '../src/views/Product/homepageConfig.helpers'

assert.deepEqual(createBannerItem(2), {
  id: 'local-banner-2',
  imageUrl: '',
  actionType: 'product',
  productId: undefined,
  sortOrder: 2
})

assert.deepEqual(normalizeSelectedProductIds([3, 1, 3, 0, -1, 2.2, 5]), [3, 1, 5])

const selections = createHotProductSelections([12, 9, 12, 6])
assert.deepEqual(selections, [
  { productId: 12, sortOrder: 1 },
  { productId: 9, sortOrder: 2 },
  { productId: 6, sortOrder: 3 }
])

assert.deepEqual(
  serializeHotProductIds([
    { productId: 12, sortOrder: 20 },
    { productId: 9, sortOrder: 5 },
    { productId: 6, sortOrder: 5 },
    { productId: 0, sortOrder: 1 }
  ]),
  [9, 6, 12]
)

console.log('homepage config selection regression checks passed')
