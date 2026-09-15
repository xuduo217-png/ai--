<script setup lang="tsx">
import { reactive, ref, unref, onMounted } from 'vue'
import { useTable } from '@/hooks/web/useTable'
import { useI18n } from '@/hooks/web/useI18n'
import { ElTag, ElImage } from 'element-plus'
import { Search } from '@/components/Search'
import { ContentWrap } from '@/components/ContentWrap'
import { BaseButton } from '@/components/Button'
import { Dialog } from '@/components/Dialog'
import { Table } from '@/components/Table'
import {
  getPendingProductsForAuditApi,
  getPendingProductDetailApi,
  getCategoryListApi
} from '@/api-new/shop'
import { ElMessage } from 'element-plus'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import ProductAuditDialog from './components/ProductAuditDialog.vue'
import { getImageUrl } from '@/utils/image'
import { extractPagedTableData } from './productList.helpers'

const { t } = useI18n()

// 搜索参数
const searchParams = ref<any>({
  status: 'under_review' // 默认展示待审核状态
})

// 分类数据（树形结构）
const categoryOptions = ref<any[]>([])

// 审核对话框
const auditDialogVisible = ref(false)
const auditProductData = ref<any>(null)

// 加载分类列表
const loadCategories = async () => {
  try {
    const res = await getCategoryListApi({ includeChildren: true })
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
    const res = await getPendingProductsForAuditApi({
      page: unref(currentPage),
      pageSize: unref(pageSize),
      status: params.status,
      keyword: params.title,
      categoryId: params.categoryId
    })
    return extractPagedTableData(res)
  }
})

const { loading, dataList, total, currentPage, pageSize } = tableState
const { getList } = tableMethods

// 状态映射
const statusMap = {
  under_review: { type: 'warning' as const, text: '待审核' },
  on_shelf: { type: 'success' as const, text: '已上架' },
  approved: { type: 'success' as const, text: '已上架(兼容)' },
  off_shelf: { type: 'info' as const, text: '已下架' },
  rejected: { type: 'danger' as const, text: '已拒绝' },
  sold: { type: 'info' as const, text: '已售出' }
}

// 新旧程度映射
const conditionMap = {
  new: '全新',
  '90%': '9成新',
  '80%': '8成新',
  '70%': '7成新',
  '60%': '6成新及以下'
}

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

// 查看详情
const handleViewDetail = async (row: any) => {
  try {
    const res = await getPendingProductDetailApi(row.id)
    auditProductData.value = res.data
    auditDialogVisible.value = true
  } catch (error) {
    ElMessage.error('获取商品详情失败')
  }
}

// 审核操作
const handleAudit = (row: any) => {
  auditProductData.value = row
  auditDialogVisible.value = true
}

// 审核成功回调
const handleAuditSuccess = () => {
  auditDialogVisible.value = false
  getList()
  ElMessage.success('审核成功')
}

/**
 * 处理搜索
 * 搜索条件变化后回到第一页，避免旧页码超出筛选结果范围导致列表为空。
 */
const handleSearch = async (params: any) => {
  searchParams.value = params || { status: 'under_review' }
  currentPage.value = 1
  await getList()
}

/**
 * 处理重置
 * 恢复默认筛选条件时同步重置页码，保证分页状态与查询条件一致。
 */
const handleReset = async () => {
  searchParams.value = { status: 'under_review' }
  currentPage.value = 1
  await getList()
}

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
    },
    table: {
      width: 60
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
    field: 'title',
    label: '商品标题',
    search: {
      hidden: false
    },
    form: {
      hidden: true
    },
    table: {
      minWidth: 200
    }
  },
  {
    field: 'user.username',
    label: '发布用户',
    search: {
      hidden: true
    },
    form: {
      hidden: true
    },
    table: {
      width: 120
    }
  },
  {
    field: 'categoryId',
    label: '分类',
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
      hidden: true
    },
    table: {
      width: 120,
      slots: {
        default: (data: any) => {
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
      hidden: true
    },
    table: {
      width: 100,
      slots: {
        default: (data: any) => {
          return `¥${data.row.price}`
        }
      }
    }
  },
  {
    field: 'condition',
    label: '新旧程度',
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
          return conditionMap[data.row.condition] || data.row.condition
        }
      }
    }
  },
  {
    field: 'status',
    label: '审核状态',
    search: {
      hidden: false,
      component: 'Select',
      componentProps: {
        options: [
          { label: '全部', value: '' },
          { label: '待审核', value: 'under_review' },
          { label: '已上架', value: 'on_shelf' },
          { label: '已下架', value: 'off_shelf' },
          { label: '已拒绝', value: 'rejected' },
          { label: '已售出', value: 'sold' }
        ],
        clearable: false,
        placeholder: '请选择审核状态'
      }
    },
    form: {
      hidden: true
    },
    table: {
      width: 100,
      slots: {
        default: (data: any) => {
          const status = statusMap[data.row.status] || { type: 'info', text: data.row.status }
          return <ElTag type={status.type}>{status.text}</ElTag>
        }
      }
    }
  },
  {
    field: 'images',
    label: '商品图片',
    search: {
      hidden: true
    },
    form: {
      hidden: true
    },
    table: {
      width: 120,
      slots: {
        default: (data: any) => {
          const images = data.row.images || []
          if (images.length === 0) return <span>-</span>
          // 使用 getImageUrl 拼接完整的图片 URL
          const fullImages = images.map((img: string) => getImageUrl(img))
          return (
            <ElImage
              style={{ width: 60, height: 60 }}
              src={fullImages[0]}
              preview-src-list={fullImages}
              preview-teleported
              fit="cover"
            />
          )
        }
      }
    }
  },
  {
    field: 'createdAt',
    label: '提交时间',
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
          return new Date(data.row.createdAt).toLocaleString('zh-CN')
        }
      }
    }
  },
  {
    field: 'action',
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
      width: 200,
      fixed: 'right',
      slots: {
        default: (data: any) => {
          return (
            <>
              <BaseButton type="info" size="small" onClick={() => handleViewDetail(data.row)}>
                查看详情
              </BaseButton>
              {data.row.status === 'under_review' && (
                <BaseButton type="primary" size="small" onClick={() => handleAudit(data.row)}>
                  审核
                </BaseButton>
              )}
            </>
          )
        }
      }
    }
  }
])

const { allSchemas } = useCrudSchemas(crudSchemas)
</script>

<template>
  <div>
    <ContentWrap>
      <Search
        :schema="allSchemas.searchSchema"
        :default-values="{ status: 'under_review' }"
        @search="handleSearch"
        @reset="handleReset"
      />

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

    <!-- 审核对话框 -->
    <Dialog
      v-model="auditDialogVisible"
      title="商品审核"
      width="1200px"
      :fullscreen="false"
      max-height="70vh"
    >
      <ProductAuditDialog
        v-if="auditDialogVisible && auditProductData"
        :product-data="auditProductData"
        @success="handleAuditSuccess"
        @cancel="auditDialogVisible = false"
      />
    </Dialog>
  </div>
</template>
