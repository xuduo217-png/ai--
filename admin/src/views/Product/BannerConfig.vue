<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import {
  ElButton,
  ElCard,
  ElEmpty,
  ElInputNumber,
  ElMessage,
  ElOption,
  ElSelect
} from 'element-plus'
import { ProductSelectorDialog } from '@/components/ProductSelectorDialog'
import { ImageUpload } from '@/components/ImageUpload'
import {
  getCategoryListApi,
  getMallHomepageBannersConfigApi,
  getProductDetailApi,
  updateMallHomepageBannersConfigApi,
  type MallHomepageBannerActionType,
  type MallHomepageBannerItem,
  type ProductCategory,
  type Product
} from '@/api-new/shop'
import { getImageUrl } from '@/utils/image'
import {
  createBannerItem,
  findCategoryNameById,
  normalizeBannerItem,
  normalizeSelectedProductIds
} from './homepageConfig.helpers'

const loading = ref(false)
const saving = ref(false)
const banners = ref<MallHomepageBannerItem[]>([])
const categoryOptions = ref<ProductCategory[]>([])
const bannerProductMap = ref<Record<number, Product>>({})
const productSelectDialogVisible = ref(false)
const activeBannerIndex = ref<number | null>(null)

const ACTION_TYPE_PRODUCT: MallHomepageBannerActionType = 'product'
const bannerActionOptions = [{ label: '商品跳转', value: ACTION_TYPE_PRODUCT }]

const currentBannerSelectedIds = computed(() => {
  if (activeBannerIndex.value === null) {
    return []
  }

  return normalizeSelectedProductIds([banners.value[activeBannerIndex.value]?.productId])
})

const upsertBannerProducts = (products: Product[]) => {
  if (products.length === 0) {
    return
  }

  bannerProductMap.value = products.reduce<Record<number, Product>>(
    (result, product) => {
      result[product.id] = product
      return result
    },
    { ...bannerProductMap.value }
  )
}

const ensureBannerProductsLoaded = async (productIds: number[]) => {
  const missingProductIds = productIds.filter((productId) => !bannerProductMap.value[productId])
  if (missingProductIds.length === 0) {
    return
  }

  try {
    const responses = await Promise.all(
      missingProductIds.map((productId) => getProductDetailApi(productId))
    )
    upsertBannerProducts(
      responses
        .map((response) => response?.data)
        .filter((product): product is Product => Boolean(product))
    )
  } catch (error) {
    console.error('加载 Banner 跳转商品详情失败:', error)
  }
}

const loadData = async () => {
  try {
    loading.value = true
    const [configRes, categoryRes] = await Promise.all([
      getMallHomepageBannersConfigApi(),
      getCategoryListApi({ includeChildren: true }).catch(() => undefined)
    ])
    const rawConfig = configRes.data
    categoryOptions.value = Array.isArray(categoryRes?.data) ? categoryRes.data : []

    banners.value = Array.isArray(rawConfig?.banners)
      ? rawConfig.banners.map((banner: MallHomepageBannerItem, index: number) =>
          normalizeBannerItem(banner, index)
        )
      : []

    await ensureBannerProductsLoaded(
      normalizeSelectedProductIds(banners.value.map((banner) => banner.productId))
    )
  } catch (error) {
    console.error('加载商城首页 Banner 配置失败:', error)
    ElMessage.error('加载配置失败')
  } finally {
    loading.value = false
  }
}

const addBanner = () => {
  banners.value.push(
    createBannerItem(banners.value.length, `${Date.now()}-${banners.value.length}`)
  )
}

const removeBanner = (index: number) => {
  banners.value.splice(index, 1)

  if (activeBannerIndex.value === null) {
    return
  }

  if (activeBannerIndex.value === index) {
    productSelectDialogVisible.value = false
    activeBannerIndex.value = null
    return
  }

  if (activeBannerIndex.value > index) {
    activeBannerIndex.value -= 1
  }
}

const getBannerProduct = (productId?: number) => {
  return productId ? bannerProductMap.value[productId] : undefined
}

const getProductCategoryName = (product?: Product) => {
  if (!product) {
    return '未分类'
  }

  return (
    findCategoryNameById(categoryOptions.value, product.categoryId) || product.category || '未分类'
  )
}

const handleActionTypeChange = (
  banner: MallHomepageBannerItem,
  actionType: MallHomepageBannerActionType
) => {
  banner.actionType = actionType || ACTION_TYPE_PRODUCT
}

const handleOpenProductSelector = (index: number) => {
  activeBannerIndex.value = index
  productSelectDialogVisible.value = true
}

const handleProductConfirm = (payload: { ids: number[]; products: Product[] }) => {
  if (activeBannerIndex.value === null) {
    return
  }

  const targetBanner = banners.value[activeBannerIndex.value]
  if (!targetBanner) {
    return
  }

  upsertBannerProducts(payload.products)
  targetBanner.actionType = ACTION_TYPE_PRODUCT
  targetBanner.productId = payload.ids[0]
}

const saveConfig = async () => {
  try {
    saving.value = true

    const invalidProductBannerIndex = banners.value.findIndex((banner) => {
      if ((banner.imageUrl?.trim() || '') === '') {
        return false
      }

      const productId = Number(banner.productId)
      return !(Number.isInteger(productId) && productId > 0)
    })

    if (invalidProductBannerIndex >= 0) {
      ElMessage.error(`请选择 Banner ${invalidProductBannerIndex + 1} 的跳转商品`)
      return
    }

    const normalizedBanners = banners.value
      .map((banner, index) => ({
        id: banner.id || `banner-${index + 1}`,
        imageUrl: banner.imageUrl?.trim() || '',
        actionType: ACTION_TYPE_PRODUCT,
        productId: Number(banner.productId),
        sortOrder: Number.isFinite(Number(banner.sortOrder)) ? Number(banner.sortOrder) : index
      }))
      .filter((banner) => banner.imageUrl)

    const response = await updateMallHomepageBannersConfigApi({
      banners: normalizedBanners
    })

    const nextConfig = response.data

    banners.value = Array.isArray(nextConfig?.banners)
      ? nextConfig.banners.map((banner: MallHomepageBannerItem, index: number) =>
          normalizeBannerItem(banner, index)
        )
      : []

    await ensureBannerProductsLoaded(
      normalizeSelectedProductIds(banners.value.map((banner) => banner.productId))
    )

    ElMessage.success('Banner 配置已保存')
  } catch (error) {
    console.error('保存商城首页 Banner 配置失败:', error)
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
  <div class="banner-config-page" v-loading="loading">
    <ElCard>
      <template #header>
        <div class="card-header">
          <div>
            <div class="card-title">商城首页Banner管理</div>
            <div class="card-description">
              Banner 会展示在商城首页搜索框下方。上传图片时会按 2:1 固定比例裁剪。
            </div>
          </div>
          <div class="header-actions">
            <ElButton @click="addBanner">新增 Banner</ElButton>
            <ElButton type="primary" :loading="saving" @click="saveConfig">保存配置</ElButton>
          </div>
        </div>
      </template>

      <div v-if="banners.length > 0" class="banner-list">
        <div v-for="(banner, index) in banners" :key="banner.id || index" class="banner-item">
          <div class="banner-item-header">
            <div class="banner-item-title">Banner {{ index + 1 }}</div>
            <ElButton text type="danger" @click="removeBanner(index)">删除</ElButton>
          </div>

          <div class="banner-item-body">
            <div class="banner-upload">
              <ImageUpload
                v-model="banner.imageUrl"
                :aspect-ratio="2 / 1"
                :crop-box-width="750"
                :crop-box-height="375"
                :preview-width="240"
                :preview-height="135"
                category="mall-home-banner"
                dialog-title="上传商城 Banner"
              />
            </div>

            <div class="banner-fields">
              <div class="field-label">跳转类型</div>
              <ElSelect
                :model-value="banner.actionType || ACTION_TYPE_PRODUCT"
                placeholder="请选择跳转类型"
                @update:model-value="handleActionTypeChange(banner, $event)"
              >
                <ElOption
                  v-for="option in bannerActionOptions"
                  :key="option.value"
                  :label="option.label"
                  :value="option.value"
                />
              </ElSelect>

              <div class="field-label">跳转商品</div>
              <div class="product-picker-actions">
                <ElButton type="primary" plain @click="handleOpenProductSelector(index)">
                  {{ getBannerProduct(banner.productId) ? '重新选择商品' : '选择商品' }}
                </ElButton>
              </div>

              <div v-if="getBannerProduct(banner.productId)" class="selected-product-card">
                <div class="selected-product-image-wrapper">
                  <img
                    v-if="getBannerProduct(banner.productId)?.image"
                    :src="getImageUrl(getBannerProduct(banner.productId)?.image)"
                    :alt="getBannerProduct(banner.productId)?.name"
                    class="selected-product-image"
                  />
                  <div v-else class="selected-product-image-placeholder">暂无图片</div>
                </div>

                <div class="selected-product-content">
                  <div class="selected-product-name">
                    {{ getBannerProduct(banner.productId)?.name }}
                  </div>
                  <div class="selected-product-category">
                    {{ getProductCategoryName(getBannerProduct(banner.productId)) }}
                  </div>
                </div>
              </div>

              <div v-else class="selected-product-placeholder">请选择要跳转的商品</div>

              <div class="field-label">排序值</div>
              <ElInputNumber
                v-model="banner.sortOrder"
                :min="0"
                :step="1"
                controls-position="right"
              />
            </div>
          </div>
        </div>
      </div>

      <ElEmpty v-else description="暂未配置首页 Banner，移动端会继续使用当前默认 Banner" />
    </ElCard>

    <ProductSelectorDialog
      v-model="productSelectDialogVisible"
      title="选择跳转商品"
      :selected-ids="currentBannerSelectedIds"
      @confirm="handleProductConfirm"
    />
  </div>
</template>

<style scoped lang="scss">
.banner-config-page {
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

.header-actions {
  display: flex;
  gap: 12px;
}

.banner-list {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.banner-item {
  padding: 16px;
  border: 1px solid var(--el-border-color-light);
  border-radius: 12px;
  background-color: var(--el-fill-color-blank);
}

.banner-item-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 16px;
}

.banner-item-title {
  font-size: 14px;
  font-weight: 600;
  color: var(--el-text-color-primary);
}

.banner-item-body {
  display: flex;
  gap: 24px;
  align-items: flex-start;
}

.banner-upload {
  flex-shrink: 0;
}

.banner-fields {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.field-label {
  font-size: 13px;
  font-weight: 500;
  color: var(--el-text-color-secondary);
}

.product-picker-actions {
  display: flex;
}

.selected-product-card {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 14px;
  border: 1px solid var(--el-border-color-light);
  border-radius: 12px;
  background: var(--el-fill-color-light);
}

.selected-product-image-wrapper {
  flex-shrink: 0;
  width: 72px;
  height: 72px;
  border-radius: 10px;
  overflow: hidden;
  background: var(--el-fill-color-blank);
}

.selected-product-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.selected-product-image-placeholder,
.selected-product-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--el-text-color-secondary);
  font-size: 13px;
}

.selected-product-content {
  min-width: 0;
  flex: 1;
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

.selected-product-placeholder {
  min-height: 72px;
  padding: 0 16px;
  border: 1px dashed var(--el-border-color);
  border-radius: 12px;
  background: var(--el-fill-color-light);
}
</style>
