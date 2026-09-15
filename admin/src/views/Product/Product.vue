<script setup lang="tsx">
import { computed, reactive, ref, unref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useTable } from '@/hooks/web/useTable'
import { useI18n } from '@/hooks/web/useI18n'
import { Table, TableColumn } from '@/components/Table'
import {
  ElTag,
  ElButton,
  ElTabs,
  ElTabPane,
  ElDialog,
  ElDescriptions,
  ElDescriptionsItem,
  ElTable,
  ElTableColumn,
  ElImageViewer,
  ElImage
} from 'element-plus'
import { Search } from '@/components/Search'
import { ContentWrap } from '@/components/ContentWrap'
import { BaseButton } from '@/components/Button'
import { productApi, getCategoryListApi, getProductDetailApi, type Product } from '@/api-new/shop'
import { ElMessage } from 'element-plus'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { getImageUrl } from '@/utils/image'
import { extractPagedTableData } from './productList.helpers'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()

const publishSource = computed<Product['publishSource']>(() =>
  route.meta.publishSource === 'USER' ? 'USER' : 'ADMIN'
)
const isSecondHandList = computed(() => publishSource.value === 'USER')

// 搜索参数
const searchParams = ref<any>({})

// 分类数据（树形结构）
const categoryOptions = ref<any[]>([])

// 加载分类列表
const loadCategories = async () => {
  try {
    const res = await getCategoryListApi({ includeChildren: true })
    // 直接使用原始 API 响应，不需要转换
    categoryOptions.value = Array.isArray(res.data) ? res.data : []
  } catch (error) {
    console.error('加载分类失败:', error)
    ElMessage.error('加载分类失败')
  }
}

onMounted(() => {
  loadCategories()
})

const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const { pageSize, currentPage } = tableState
    const params = unref(searchParams) || {}
    const res = await productApi.getProductListApi({
      page: unref(currentPage),
      pageSize: unref(pageSize),
      // 传递搜索参数
      keyword: params.name,
      categoryId: params.categoryId,
      isActive: params.isActive,
      publishSource: publishSource.value
    })
    return extractPagedTableData(res)
  }
})

const { loading, dataList, total, currentPage, pageSize } = tableState
const { getList } = tableMethods

watch(publishSource, async () => {
  currentPage.value = 1
  await getList()
})

const crudSchemas = reactive<CrudSchema[]>([
  {
    field: 'index',
    label: t('tableDemo.index'),
    type: 'index',
    search: {
      hidden: true
    },
    form: {
      hidden: true
    },
    detail: {
      hidden: true
    }
  },
  {
    field: 'id',
    label: 'ID',
    search: {
      hidden: true
    },
    form: {
      hidden: true
    },
    table: {
      width: 80
    }
  },
  {
    field: 'name',
    label: '商品名称',
    search: {
      hidden: false
    },
    form: {
      component: 'Input',
      colProps: {
        span: 24
      }
    },
    table: {
      minWidth: 200
    }
  },
  {
    field: 'categoryId',
    label: '商品分类',
    search: {
      hidden: false,
      component: 'TreeSelect',
      componentProps: {
        options: categoryOptions,
        clearable: true,
        placeholder: '请选择商品分类',
        data: categoryOptions,
        'check-strictly': true,
        'render-after-expand': false,
        'default-expand-all': true,
        props: {
          label: 'name',
          value: 'id',
          children: 'children'
        }
      }
    },
    form: {
      component: 'Select',
      componentProps: {
        options: categoryOptions,
        clearable: true,
        placeholder: '请选择商品分类'
      }
    },
    table: {
      width: 150,
      slots: {
        default: (data: any) => {
          // 递归查找分类名称
          const findCategoryName = (categories: any[], id: number): string => {
            for (const cat of categories) {
              if (cat.id === id) return cat.name
              if (cat.children) {
                const found = findCategoryName(cat.children, id)
                if (found) return found
              }
            }
            return ''
          }
          const categoryName = data.row.categoryId
            ? findCategoryName(categoryOptions.value, data.row.categoryId)
            : ''
          return categoryName || '-'
        }
      }
    }
  },
  {
    field: 'price',
    label: '价格',
    search: {
      hidden: true
    },
    form: {
      component: 'InputNumber',
      componentProps: {
        min: 0,
        precision: 2,
        step: 0.1
      }
    },
    table: {
      width: 100,
      formatter: (_: any, __: TableColumn, cellValue: number, row: Product) => {
        return row.hasSku ? '多规格' : `¥${cellValue}`
      }
    }
  },
  {
    field: 'stock',
    label: '库存',
    search: {
      hidden: true
    },
    form: {
      component: 'InputNumber',
      componentProps: {
        min: 0,
        step: 1
      }
    },
    table: {
      width: 100
    }
  },
  {
    field: 'isActive',
    label: '状态',
    search: {
      hidden: false,
      component: 'Select',
      componentProps: {
        options: [
          { label: '全部', value: undefined },
          { label: '上架', value: true },
          { label: '下架', value: false }
        ],
        clearable: true,
        placeholder: '请选择状态'
      }
    },
    form: {
      component: 'RadioGroup',
      componentProps: {
        options: [
          { label: '上架', value: true },
          { label: '下架', value: false }
        ],
        value: true
      }
    },
    table: {
      width: 100,
      slots: {
        default: (data: any) => {
          return (
            <>
              <ElTag type={data.row.isActive ? 'success' : 'danger'}>
                {data.row.isActive ? '上架' : '下架'}
              </ElTag>
            </>
          )
        }
      }
    }
  },
  {
    field: 'isVirtual',
    label: '虚拟商品',
    search: {
      hidden: true
    },
    form: {
      component: 'RadioGroup',
      componentProps: {
        options: [
          { label: '是', value: true },
          { label: '否', value: false }
        ],
        value: false
      }
    },
    table: {
      width: 100,
      slots: {
        default: (data: any) => {
          return (
            <>
              <ElTag type={data.row.isVirtual ? 'warning' : 'info'}>
                {data.row.isVirtual ? '虚拟商品' : '实物商品'}
              </ElTag>
            </>
          )
        }
      }
    }
  },
  {
    field: 'publishSource',
    label: '发布来源',
    search: {
      hidden: true
    },
    form: {
      hidden: true
    },
    table: {
      width: 100,
      slots: {
        default: (data: any) => {
          return (
            <>
              <ElTag type={data.row.publishSource === 'ADMIN' ? 'primary' : 'success'}>
                {data.row.publishSource === 'ADMIN' ? '平台商品' : '用户发布'}
              </ElTag>
            </>
          )
        }
      }
    }
  },
  {
    field: 'publisher',
    label: '发布用户',
    search: {
      hidden: true
    },
    form: {
      hidden: true
    },
    table: {
      width: 180,
      slots: {
        default: (data: any) => {
          // 只有当发布来源是用户发布时，才显示发布用户信息
          if (data.row.publishSource === 'USER' && data.row.publisher) {
            return (
              <div>
                <div style="font-weight: 500">{data.row.publisher.username || '-'}</div>
                <div style="font-size: 12px; color: #909399">{data.row.publisher.phone || '-'}</div>
              </div>
            )
          }
          return <span>-</span>
        }
      }
    }
  },
  {
    field: 'hasSku',
    label: '多规格',
    search: {
      hidden: true
    },
    form: {
      hidden: true
    },
    table: {
      width: 80,
      slots: {
        default: (data: any) => {
          return (
            <>
              <ElTag type={data.row.hasSku ? 'success' : 'info'}>
                {data.row.hasSku ? '是' : '否'}
              </ElTag>
            </>
          )
        }
      }
    }
  },
  {
    field: 'description',
    label: '商品描述',
    search: {
      hidden: true
    },
    form: {
      component: 'Editor',
      colProps: {
        span: 24
      }
    },
    table: {
      hidden: true
    }
  },
  {
    field: 'action',
    width: '260px',
    label: t('tableDemo.action'),
    search: {
      hidden: true
    },
    form: {
      hidden: true
    },
    detail: {
      hidden: true
    },
    table: {
      slots: {
        default: (data: any) => {
          return (
            <>
              <BaseButton type="info" onClick={() => handleView(data.row)}>
                查看
              </BaseButton>
              {!isSecondHandList.value && (
                <BaseButton type="primary" onClick={() => action(data.row)}>
                  {t('exampleDemo.edit')}
                </BaseButton>
              )}
              <BaseButton type="danger" onClick={() => delData(data.row)}>
                {t('exampleDemo.del')}
              </BaseButton>
            </>
          )
        }
      }
    }
  }
])

// @ts-ignore
const { allSchemas } = useCrudSchemas(crudSchemas)

const AddAction = () => {
  router.push('/product/form')
}

/**
 * 处理搜索
 * 搜索条件变化后强制回到第一页，避免旧页码超出筛选结果范围时出现空列表。
 */
const handleSearch = async (params: any) => {
  searchParams.value = params || {}
  currentPage.value = 1
  await getList()
}

/**
 * 处理重置
 * 重置筛选条件后同步回到第一页，确保分页状态与查询条件保持一致。
 */
const handleReset = async () => {
  searchParams.value = {}
  currentPage.value = 1
  await getList()
}

const delData = async (row: Product) => {
  await productApi.deleteProductApi(row.id)
  ElMessage.success('删除成功')
  getList()
}

const action = (row: Product) => {
  router.push(`/product/form/${row.id}`)
}

// 详情对话框
const detailDialogVisible = ref(false)
const detailLoading = ref(false)
const productDetail = ref<any>(null)
const activeTab = ref('basic')

// 图片预览相关
const imageViewerVisible = ref(false)
const currentImageUrl = ref('')
const imageViewerIndex = ref(0)

/**
 * 获取所有图片列表
 */
const getAllImages = (product: any) => {
  if (!product) return []
  const images: string[] = []
  // 添加主图
  if (product.image) {
    images.push(product.image)
  }
  // 添加图片数组
  if (product.images && Array.isArray(product.images)) {
    images.push(...product.images)
  }
  return images
}

/**
 * 预览图片
 */
const previewImage = (url: string, index: number) => {
  currentImageUrl.value = url
  imageViewerIndex.value = index
  imageViewerVisible.value = true
}

/**
 * 关闭图片预览
 */
const closeImageViewer = () => {
  imageViewerVisible.value = false
}

/**
 * 查看商品详情
 */
const handleView = async (row: Product) => {
  detailDialogVisible.value = true
  detailLoading.value = true
  activeTab.value = 'basic'

  try {
    const res = await getProductDetailApi(row.id)
    productDetail.value = res.data
  } catch (error) {
    console.error('获取商品详情失败:', error)
    ElMessage.error('获取商品详情失败')
    detailDialogVisible.value = false
  } finally {
    detailLoading.value = false
  }
}

/**
 * 格式化时间为 YYYY-MM-DD HH:mm:ss
 */
const formatDateTime = (dateStr: string) => {
  if (!dateStr) return '-'
  const date = new Date(dateStr)
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  const hours = String(date.getHours()).padStart(2, '0')
  const minutes = String(date.getMinutes()).padStart(2, '0')
  const seconds = String(date.getSeconds()).padStart(2, '0')
  return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`
}
</script>

<template>
  <div>
    <ContentWrap>
      <Search :schema="allSchemas.searchSchema" @search="handleSearch" @reset="handleReset" />

      <div class="mb-10px">
        <BaseButton v-if="!isSecondHandList" type="primary" @click="AddAction">
          {{ t('exampleDemo.add') }}
        </BaseButton>
      </div>

      <Table
        v-model:pageSize="pageSize"
        v-model:currentPage="currentPage"
        :columns="allSchemas.tableColumns"
        :data="dataList"
        :loading="loading"
        :pagination="{
          total: total
        }"
        @register="tableRegister"
      />
    </ContentWrap>

    <!-- 商品详情对话框 -->
    <el-dialog
      v-model="detailDialogVisible"
      title="商品详情"
      width="1200px"
      top="5vh"
      :close-on-click-modal="false"
      class="product-detail-dialog"
    >
      <el-tabs v-if="productDetail" v-model="activeTab">
        <!-- 基本信息 -->
        <el-tab-pane label="基本信息" name="basic">
          <!-- 商品图片展示 -->
          <div v-if="getAllImages(productDetail).length > 0" class="product-images-section">
            <div class="section-title">商品图片</div>
            <div class="images-grid">
              <div
                v-for="(img, index) in getAllImages(productDetail)"
                :key="index"
                class="image-item"
                @click="previewImage(img, index)"
              >
                <el-image
                  :src="getImageUrl(img)"
                  fit="cover"
                  class="product-image"
                  :preview-src-list="[]"
                  :width="120"
                  :height="120"
                >
                  <template #error>
                    <div class="image-error">
                      <span>加载失败</span>
                    </div>
                  </template>
                </el-image>
              </div>
            </div>
          </div>

          <el-descriptions :column="2" border>
            <el-descriptions-item label="商品ID">
              {{ productDetail.id }}
            </el-descriptions-item>
            <el-descriptions-item label="商品名称">
              {{ productDetail.name }}
            </el-descriptions-item>
            <el-descriptions-item label="商品分类">
              {{
                productDetail.categoryId
                  ? categoryOptions.find((c) => c.id === productDetail.categoryId)?.name || '-'
                  : '-'
              }}
            </el-descriptions-item>
            <el-descriptions-item label="价格"> ¥{{ productDetail.price }} </el-descriptions-item>
            <el-descriptions-item label="库存">
              {{ productDetail.stock }}
            </el-descriptions-item>
            <el-descriptions-item label="状态">
              <el-tag :type="productDetail.isActive ? 'success' : 'danger'">
                {{ productDetail.isActive ? '上架' : '下架' }}
              </el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="发布来源">
              <el-tag :type="productDetail.publishSource === 'ADMIN' ? 'primary' : 'success'">
                {{ productDetail.publishSource === 'ADMIN' ? '平台商品' : '用户发布' }}
              </el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="多规格">
              <el-tag :type="productDetail.hasSku ? 'success' : 'info'">
                {{ productDetail.hasSku ? '是' : '否' }}
              </el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="虚拟商品">
              <el-tag :type="productDetail.isVirtual ? 'warning' : 'info'">
                {{ productDetail.isVirtual ? '是' : '否' }}
              </el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="创建时间" :span="2">
              {{ formatDateTime(productDetail.createdAt) }}
            </el-descriptions-item>
            <!-- 发布人信息（如果是用户发布的商品） -->
            <template v-if="productDetail.publishSource === 'USER' && productDetail.publisher">
              <el-descriptions-item label="发布人ID">
                {{ productDetail.publisher.id }}
              </el-descriptions-item>
              <el-descriptions-item label="发布人昵称">
                {{ productDetail.publisher.username || '-' }}
              </el-descriptions-item>
              <el-descriptions-item label="发布人手机" :span="2">
                {{ productDetail.publisher.phone || '-' }}
              </el-descriptions-item>
            </template>
          </el-descriptions>
        </el-tab-pane>

        <!-- 商品详情（富文本） -->
        <el-tab-pane label="商品详情" name="detail">
          <div
            v-if="productDetail.description"
            v-html="productDetail.description"
            class="rich-text-content"
          ></div>
          <div v-else class="empty-text">暂无商品详情</div>
        </el-tab-pane>

        <!-- SKU 信息 -->
        <el-tab-pane v-if="productDetail.hasSku && productDetail.skus" label="SKU信息" name="sku">
          <el-table :data="productDetail.skus" border>
            <el-table-column prop="id" label="SKU ID" width="80" />
            <el-table-column prop="name" label="规格名称" min-width="120" />
            <el-table-column label="规格属性" min-width="150">
              <template #default="{ row }">
                <div v-for="(value, key) in row.specs" :key="key"> {{ key }}: {{ value }} </div>
              </template>
            </el-table-column>
            <el-table-column prop="price" label="价格" width="100">
              <template #default="{ row }">¥{{ row.price }}</template>
            </el-table-column>
            <el-table-column prop="originalPrice" label="原价" width="100">
              <template #default="{ row }">
                {{ row.originalPrice ? `¥${row.originalPrice}` : '-' }}
              </template>
            </el-table-column>
            <el-table-column prop="stock" label="库存" width="80" />
            <el-table-column prop="skuCode" label="SKU编码" width="120">
              <template #default="{ row }">{{ row.skuCode || '-' }}</template>
            </el-table-column>
            <el-table-column prop="status" label="状态" width="100">
              <template #default="{ row }">
                <el-tag
                  :type="
                    row.status === 'ACTIVE'
                      ? 'success'
                      : row.status === 'INACTIVE'
                        ? 'info'
                        : 'danger'
                  "
                >
                  {{
                    row.status === 'ACTIVE' ? '启用' : row.status === 'INACTIVE' ? '停用' : '缺货'
                  }}
                </el-tag>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>
      </el-tabs>

      <div v-else class="loading-text">
        {{ detailLoading ? '加载中...' : '暂无数据' }}
      </div>

      <template #footer>
        <el-button @click="detailDialogVisible = false">关闭</el-button>
      </template>
    </el-dialog>

    <!-- 图片预览查看器 -->
    <el-image-viewer
      v-if="imageViewerVisible"
      :url-list="getAllImages(productDetail).map((img) => getImageUrl(img))"
      :initial-index="imageViewerIndex"
      @close="closeImageViewer"
    />
  </div>
</template>

<style scoped>
.rich-text-content {
  padding: 16px;
  min-height: 200px;
  max-height: 500px;
  overflow-y: auto;
}

.rich-text-content :deep(img) {
  max-width: 100%;
  height: auto;
}

.empty-text,
.loading-text {
  text-align: center;
  padding: 40px 0;
  color: #909399;
}

/* 商品图片展示区域 */
.product-images-section {
  margin-bottom: 20px;
  padding: 16px;
  background-color: #f5f7fa;
  border-radius: 4px;
}

.section-title {
  font-size: 14px;
  font-weight: 600;
  color: #303133;
  margin-bottom: 12px;
}

.images-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
  gap: 12px;
}

.image-item {
  width: 120px;
  height: 120px;
  border-radius: 4px;
  overflow: hidden;
  cursor: pointer;
  border: 1px solid #dcdfe6;
  transition: all 0.3s;
}

.image-item:hover {
  border-color: #409eff;
  transform: scale(1.05);
}

.product-image {
  width: 100%;
  height: 100%;
}

.product-image :deep(.el-image__inner) {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.image-error {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
  background-color: #f5f7fa;
  color: #909399;
  font-size: 12px;
}

/* 增加对话框高度 */
.product-detail-dialog :deep(.el-dialog) {
  height: 90vh;
  display: flex;
  flex-direction: column;
}

.product-detail-dialog :deep(.el-dialog__body) {
  flex: 1;
  overflow: hidden;
  padding: 20px;
}

.product-detail-dialog :deep(.el-tabs) {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.product-detail-dialog :deep(.el-tabs__header) {
  flex-shrink: 0;
}

.product-detail-dialog :deep(.el-tabs__content) {
  flex: 1;
  overflow-y: auto;
}
</style>
