<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import {
  ElButton,
  ElDialog,
  ElEmpty,
  ElInput,
  ElPagination,
  ElScrollbar,
  ElTag
} from 'element-plus'
import { Search } from '@element-plus/icons-vue'
import {
  getCategoryListApi,
  getProductDetailApi,
  getProductListApi,
  type Product,
  type ProductCategory
} from '@/api-new/shop'
import { getImageUrl } from '@/utils/image'
import { extractPagedTableData } from '@/utils/pagination'
import { normalizeSelectedProductIds } from '@/views/Product/homepageConfig.helpers'

interface ProductSelectorConfirmPayload {
  ids: number[]
  products: Product[]
}

const props = withDefaults(
  defineProps<{
    modelValue: boolean
    title?: string
    width?: string
    multiple?: boolean
    selectedIds?: number[]
    pageSize?: number
  }>(),
  {
    title: '选择商品',
    width: '960px',
    multiple: false,
    selectedIds: () => [],
    pageSize: 8
  }
)

const emit = defineEmits<{
  (event: 'update:modelValue', value: boolean): void
  (event: 'confirm', payload: ProductSelectorConfirmPayload): void
}>()

const loading = ref(false)
const productList = ref<Product[]>([])
const total = ref(0)
const currentPage = ref(1)
const keyword = ref('')
const categoryOptions = ref<ProductCategory[]>([])
const tempSelectedIds = ref<number[]>([])
const productCache = ref<Record<number, Product>>({})

const dialogVisible = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value)
})

const selectedCountText = computed(() => {
  return props.multiple ? `已选 ${tempSelectedIds.value.length} 个商品` : '仅可选择 1 个商品'
})

const upsertProducts = (products: Product[]) => {
  if (products.length === 0) {
    return
  }

  productCache.value = products.reduce<Record<number, Product>>(
    (result, product) => {
      result[product.id] = product
      return result
    },
    { ...productCache.value }
  )
}

const findCategoryName = (categories: ProductCategory[], categoryId?: number): string => {
  if (!categoryId) {
    return ''
  }

  for (const category of categories) {
    if (category.id === categoryId) {
      return category.name
    }

    if (Array.isArray(category.children) && category.children.length > 0) {
      const childName = findCategoryName(category.children, categoryId)
      if (childName) {
        return childName
      }
    }
  }

  return ''
}

const getProductCategoryName = (product: Product): string => {
  return findCategoryName(categoryOptions.value, product.categoryId) || product.category || '未分类'
}

const loadCategories = async () => {
  if (categoryOptions.value.length > 0) {
    return
  }

  try {
    const response = await getCategoryListApi({ includeChildren: true })
    categoryOptions.value = Array.isArray(response?.data) ? response.data : []
  } catch (error) {
    console.error('加载商品分类失败:', error)
  }
}

const ensureSelectedProductsLoaded = async (productIds: number[]) => {
  const missingProductIds = productIds.filter((productId) => !productCache.value[productId])
  if (missingProductIds.length === 0) {
    return
  }

  try {
    const responses = await Promise.all(
      missingProductIds.map((productId) => getProductDetailApi(productId))
    )
    const products = responses
      .map((response) => response?.data)
      .filter((product): product is Product => Boolean(product))
    upsertProducts(products)
  } catch (error) {
    console.error('加载已选商品详情失败:', error)
  }
}

const loadProducts = async () => {
  try {
    loading.value = true
    const response = await getProductListApi({
      page: currentPage.value,
      pageSize: props.pageSize,
      keyword: keyword.value.trim() || undefined,
      isActive: true
    })
    const { list, total: totalCount } = extractPagedTableData<Product>(response)
    productList.value = list
    total.value = totalCount
    upsertProducts(list)
  } catch (error) {
    console.error('加载商品列表失败:', error)
    productList.value = []
    total.value = 0
  } finally {
    loading.value = false
  }
}

const initializeDialog = async () => {
  tempSelectedIds.value = normalizeSelectedProductIds(props.selectedIds)
  keyword.value = ''
  currentPage.value = 1

  await Promise.all([
    loadCategories(),
    ensureSelectedProductsLoaded(tempSelectedIds.value),
    loadProducts()
  ])
}

const handleSearch = async () => {
  currentPage.value = 1
  await loadProducts()
}

const handleReset = async () => {
  keyword.value = ''
  currentPage.value = 1
  await loadProducts()
}

const handlePageChange = async (page: number) => {
  currentPage.value = page
  await loadProducts()
}

const isSelected = (productId: number): boolean => {
  return tempSelectedIds.value.includes(productId)
}

const handleToggleProduct = (product: Product) => {
  const nextSelectedIds = normalizeSelectedProductIds(tempSelectedIds.value)
  const currentIndex = nextSelectedIds.indexOf(product.id)

  upsertProducts([product])

  if (props.multiple) {
    if (currentIndex >= 0) {
      nextSelectedIds.splice(currentIndex, 1)
    } else {
      nextSelectedIds.push(product.id)
    }
    tempSelectedIds.value = nextSelectedIds
    return
  }

  tempSelectedIds.value = currentIndex >= 0 ? [] : [product.id]
}

const handleConfirm = async () => {
  const ids = normalizeSelectedProductIds(tempSelectedIds.value)
  await ensureSelectedProductsLoaded(ids)

  emit('confirm', {
    ids,
    products: ids
      .map((productId) => productCache.value[productId])
      .filter((product): product is Product => Boolean(product))
  })

  dialogVisible.value = false
}

watch(
  () => props.modelValue,
  async (visible) => {
    if (visible) {
      await initializeDialog()
    }
  }
)
</script>

<template>
  <ElDialog
    v-model="dialogVisible"
    :title="title"
    :width="width"
    :close-on-click-modal="false"
    destroy-on-close
  >
    <div class="selector-toolbar">
      <div class="toolbar-search">
        <ElInput
          v-model="keyword"
          clearable
          placeholder="请输入商品名称搜索"
          @keyup.enter="handleSearch"
        >
          <template #prefix>
            <Search class="search-icon" />
          </template>
        </ElInput>
        <ElButton type="primary" @click="handleSearch">搜索</ElButton>
        <ElButton @click="handleReset">重置</ElButton>
      </div>
      <ElTag type="info" effect="plain">{{ selectedCountText }}</ElTag>
    </div>

    <div class="selector-body" v-loading="loading">
      <ElEmpty v-if="productList.length === 0" description="暂无可选商品" />

      <ElScrollbar v-else height="420px">
        <div class="product-list">
          <button
            v-for="product in productList"
            :key="product.id"
            type="button"
            class="product-item"
            :class="{ 'is-selected': isSelected(product.id) }"
            @click="handleToggleProduct(product)"
          >
            <div class="product-image-wrapper">
              <img
                v-if="product.image"
                :src="getImageUrl(product.image)"
                :alt="product.name"
                class="product-image"
              />
              <div v-else class="product-image-placeholder">暂无图片</div>
            </div>

            <div class="product-content">
              <div class="product-name">{{ product.name }}</div>
              <div class="product-category">{{ getProductCategoryName(product) }}</div>
            </div>

            <div class="product-status">
              <span>{{
                isSelected(product.id) ? '已选择' : multiple ? '点击选择' : '点击切换'
              }}</span>
            </div>
          </button>
        </div>
      </ElScrollbar>
    </div>

    <div class="selector-pagination">
      <ElPagination
        background
        layout="prev, pager, next, total"
        :current-page="currentPage"
        :page-size="pageSize"
        :total="total"
        @current-change="handlePageChange"
      />
    </div>

    <template #footer>
      <div class="selector-footer">
        <ElButton @click="dialogVisible = false">取消</ElButton>
        <ElButton
          type="primary"
          :disabled="!multiple && tempSelectedIds.length === 0"
          @click="handleConfirm"
        >
          确定
        </ElButton>
      </div>
    </template>
  </ElDialog>
</template>

<style scoped lang="scss">
.selector-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 16px;
}

.toolbar-search {
  display: flex;
  align-items: center;
  gap: 12px;
  flex: 1;
}

.toolbar-search :deep(.el-input) {
  max-width: 360px;
}

.search-icon {
  width: 16px;
  height: 16px;
  color: var(--el-text-color-secondary);
}

.selector-body {
  min-height: 420px;
}

.product-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding-right: 4px;
}

.product-item {
  display: flex;
  align-items: center;
  gap: 16px;
  width: 100%;
  padding: 14px 16px;
  border: 1px solid var(--el-border-color-light);
  border-radius: 12px;
  background: var(--el-fill-color-blank);
  text-align: left;
  transition:
    border-color 0.2s ease,
    box-shadow 0.2s ease,
    transform 0.2s ease;
  cursor: pointer;
}

.product-item:hover {
  border-color: var(--el-color-primary-light-5);
  box-shadow: 0 8px 18px rgba(0, 0, 0, 0.06);
  transform: translateY(-1px);
}

.product-item.is-selected {
  border-color: var(--el-color-primary);
  background: var(--el-color-primary-light-9);
}

.product-image-wrapper {
  flex-shrink: 0;
  width: 72px;
  height: 72px;
  border-radius: 10px;
  overflow: hidden;
  background: var(--el-fill-color-light);
}

.product-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.product-image-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
  color: var(--el-text-color-secondary);
  font-size: 12px;
}

.product-content {
  flex: 1;
  min-width: 0;
}

.product-name {
  font-size: 14px;
  font-weight: 600;
  color: var(--el-text-color-primary);
  line-height: 1.5;
}

.product-category {
  margin-top: 6px;
  color: var(--el-text-color-secondary);
  font-size: 13px;
}

.product-status {
  flex-shrink: 0;
  color: var(--el-color-primary);
  font-size: 12px;
  white-space: nowrap;
}

.selector-pagination {
  display: flex;
  justify-content: flex-end;
  margin-top: 16px;
}

.selector-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}
</style>
