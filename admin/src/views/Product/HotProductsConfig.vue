<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import {
  ElButton,
  ElCard,
  ElEmpty,
  ElForm,
  ElFormItem,
  ElInputNumber,
  ElMessage
} from 'element-plus'
import { ProductSelectorDialog } from '@/components/ProductSelectorDialog'
import {
  getCategoryListApi,
  getMallHomepageHotProductsConfigApi,
  getProductDetailApi,
  updateMallHomepageHotProductsConfigApi,
  type Product,
  type ProductCategory
} from '@/api-new/shop'
import { getImageUrl } from '@/utils/image'
import {
  createHotProductSelections,
  findCategoryNameById,
  mergeHotProductSelections,
  serializeHotProductIds,
  sortHotProductSelections,
  type HotProductSelection
} from './homepageConfig.helpers'

const loading = ref(false)
const saving = ref(false)
const productSelectorDialogVisible = ref(false)
const categoryOptions = ref<ProductCategory[]>([])
const productSelections = ref<HotProductSelection[]>([])
const selectedProductMap = ref<Record<number, Product>>({})

const selectedProductIds = computed(() => {
  return productSelections.value.map((selection) => selection.productId)
})

const selectedProductCards = computed(() => {
  return sortHotProductSelections(productSelections.value)
    .map((selection) => {
      const product = selectedProductMap.value[selection.productId]
      if (!product) {
        return null
      }

      return {
        ...selection,
        product
      }
    })
    .filter(
      (
        item
      ): item is {
        productId: number
        sortOrder: number
        product: Product
      } => Boolean(item)
    )
})

const upsertSelectedProducts = (products: Product[]) => {
  if (products.length === 0) {
    return
  }

  selectedProductMap.value = products.reduce<Record<number, Product>>(
    (result, product) => {
      result[product.id] = product
      return result
    },
    { ...selectedProductMap.value }
  )
}

const ensureSelectedProductsLoaded = async (productIds: number[]) => {
  const missingProductIds = productIds.filter((productId) => !selectedProductMap.value[productId])
  if (missingProductIds.length === 0) {
    return
  }

  try {
    const responses = await Promise.all(
      missingProductIds.map((productId) => getProductDetailApi(productId))
    )
    upsertSelectedProducts(
      responses
        .map((response) => response?.data)
        .filter((product): product is Product => Boolean(product))
    )
  } catch (error) {
    console.error('加载热门商品详情失败:', error)
  }
}

const getProductCategoryName = (product: Product) => {
  return (
    findCategoryNameById(categoryOptions.value, product.categoryId) || product.category || '未分类'
  )
}

const loadData = async () => {
  try {
    loading.value = true

    const [configRes, categoryRes] = await Promise.all([
      getMallHomepageHotProductsConfigApi(),
      getCategoryListApi({ includeChildren: true }).catch(() => undefined)
    ])

    const rawConfig = configRes.data
    categoryOptions.value = Array.isArray(categoryRes?.data) ? categoryRes.data : []
    productSelections.value = createHotProductSelections(rawConfig?.productIds || [])

    await ensureSelectedProductsLoaded(selectedProductIds.value)
  } catch (error) {
    console.error('加载商城首页热门商品配置失败:', error)
    ElMessage.error('加载配置失败')
  } finally {
    loading.value = false
  }
}

const handleProductConfirm = (payload: { ids: number[]; products: Product[] }) => {
  upsertSelectedProducts(payload.products)
  productSelections.value = mergeHotProductSelections(productSelections.value, payload.ids)
}

const handleRemoveProduct = (productId: number) => {
  productSelections.value = productSelections.value.filter(
    (selection) => selection.productId !== productId
  )
}

const handleSortOrderChange = (productId: number, value?: number) => {
  const targetSelection = productSelections.value.find(
    (selection) => selection.productId === productId
  )
  if (!targetSelection) {
    return
  }

  const nextSortOrder = Number(value)
  targetSelection.sortOrder =
    Number.isFinite(nextSortOrder) && nextSortOrder > 0 ? nextSortOrder : 1
}

const saveConfig = async () => {
  try {
    saving.value = true
    const productIds = serializeHotProductIds(productSelections.value)

    const response = await updateMallHomepageHotProductsConfigApi({
      productIds
    })

    const nextConfig = response.data
    const nextProductIds = Array.isArray(nextConfig?.productIds) ? nextConfig.productIds : []

    productSelections.value = createHotProductSelections(nextProductIds)
    await ensureSelectedProductsLoaded(nextProductIds)

    ElMessage.success('热门商品配置已保存')
  } catch (error) {
    console.error('保存商城首页热门商品配置失败:', error)
    ElMessage.error('保存失败，请稍后重试')
  } finally {
    saving.value = false
  }
}

onMounted(() => {
  loadData()
})
</script>

<template>
  <div class="hot-products-config-page" v-loading="loading">
    <ElCard>
      <template #header>
        <div class="card-header">
          <div>
            <div class="card-title">商城首页热门商品</div>
            <div class="card-description">
              配置后将按所选顺序展示；如果不配置，移动端会继续使用当前热门商品规则。
            </div>
          </div>
          <ElButton type="primary" :loading="saving" @click="saveConfig">保存配置</ElButton>
        </div>
      </template>

      <ElForm label-width="120px">
        <ElFormItem label="热门商品">
          <div class="selector-trigger">
            <ElButton type="primary" plain @click="productSelectorDialogVisible = true">
              选择商品
            </ElButton>
            <span class="selector-trigger-text">已选择 {{ selectedProductIds.length }} 个商品</span>
          </div>
        </ElFormItem>
      </ElForm>

      <div class="preview-section">
        <div class="preview-title">当前展示顺序</div>
        <div class="preview-description">可修改排序序号，保存时会按排序序号从小到大展示。</div>

        <div v-if="selectedProductCards.length > 0" class="selected-products">
          <div
            v-for="item in selectedProductCards"
            :key="item.productId"
            class="selected-product-item"
          >
            <div class="selected-product-main">
              <div class="selected-product-image-wrapper">
                <img
                  v-if="item.product.image"
                  :src="getImageUrl(item.product.image)"
                  :alt="item.product.name"
                  class="selected-product-image"
                />
                <div v-else class="selected-product-image-placeholder">暂无图片</div>
              </div>

              <div class="selected-product-content">
                <div class="selected-product-name">{{ item.product.name }}</div>
                <div class="selected-product-category">
                  {{ getProductCategoryName(item.product) }}
                </div>
              </div>
            </div>

            <div class="selected-product-actions">
              <div class="sort-editor">
                <span class="sort-editor-label">排序</span>
                <ElInputNumber
                  :model-value="item.sortOrder"
                  :min="1"
                  controls-position="right"
                  @update:model-value="handleSortOrderChange(item.productId, $event)"
                />
              </div>
              <ElButton text type="danger" @click="handleRemoveProduct(item.productId)">
                移除
              </ElButton>
            </div>
          </div>
        </div>

        <ElEmpty v-else description="暂未配置首页热门商品，移动端将按默认规则展示" />
      </div>
    </ElCard>

    <ProductSelectorDialog
      v-model="productSelectorDialogVisible"
      title="选择热门商品"
      multiple
      :selected-ids="selectedProductIds"
      @confirm="handleProductConfirm"
    />
  </div>
</template>

<style scoped lang="scss">
.hot-products-config-page {
  padding: 20px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 16px;
}

.card-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--el-text-color-primary);
}

.card-description {
  margin-top: 6px;
  font-size: 13px;
  color: var(--el-text-color-secondary);
}

.preview-section {
  margin-top: 24px;
}

.preview-title {
  margin-bottom: 6px;
  font-size: 14px;
  font-weight: 600;
  color: var(--el-text-color-primary);
}

.preview-description {
  margin-bottom: 12px;
  font-size: 13px;
  color: var(--el-text-color-secondary);
}

.selector-trigger {
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 32px;
}

.selector-trigger-text {
  color: var(--el-text-color-secondary);
  font-size: 13px;
}

.selected-products {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.selected-product-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 20px;
  padding: 12px 14px;
  border: 1px solid var(--el-border-color-light);
  border-radius: 10px;
  background-color: var(--el-fill-color-blank);
}

.selected-product-main {
  display: flex;
  align-items: center;
  gap: 14px;
  min-width: 0;
  flex: 1;
}

.selected-product-image-wrapper {
  flex-shrink: 0;
  width: 72px;
  height: 72px;
  border-radius: 10px;
  overflow: hidden;
  background: var(--el-fill-color-light);
}

.selected-product-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.selected-product-image-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
  color: var(--el-text-color-secondary);
  font-size: 12px;
}

.selected-product-content {
  min-width: 0;
}

.selected-product-name {
  color: var(--el-text-color-primary);
  font-size: 14px;
  font-weight: 600;
  line-height: 1.5;
}

.selected-product-category {
  margin-top: 6px;
  color: var(--el-text-color-secondary);
  font-size: 13px;
}

.selected-product-actions {
  display: flex;
  align-items: center;
  gap: 16px;
  flex-shrink: 0;
}

.sort-editor {
  display: flex;
  align-items: center;
  gap: 8px;
}

.sort-editor-label {
  color: var(--el-text-color-secondary);
  font-size: 13px;
}

.sort-editor :deep(.el-input-number) {
  width: 120px;
}
</style>
