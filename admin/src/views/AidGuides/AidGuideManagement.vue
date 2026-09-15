<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { Table } from '@/components/Table'
import { Plus } from '@element-plus/icons-vue'
import { ref, unref, reactive, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElTag, ElMessage, ElMessageBox } from 'element-plus'
import {
  getGuideListApi,
  deleteGuideApi,
  toggleGuideStatusApi,
  getAidGuideCategoryListApi,
  type AidGuide,
  type AidCategory
} from '@/api-new/aid-guides'
import { useTable } from '@/hooks/web/useTable'
import { Search } from '@/components/Search'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { BaseButton } from '@/components/Button'
import { getImageUrl } from '@/utils/image'

defineOptions({
  name: 'AidGuideManagement'
})

const router = useRouter()
const route = useRoute()

// 监听路由变化，刷新列表
watch(
  () => route.path,
  () => {
    if (route.path === '/aid-guides/list') {
      getList()
    }
  }
)

// 获取分类列表（用于下拉选项）
const categoryOptions = ref<any[]>([])
const loadCategories = async () => {
  try {
    const res = await getAidGuideCategoryListApi({ page: 1, pageSize: 100 })
    categoryOptions.value = (res.data || []).map((item: AidCategory) => ({
      label: item.name,
      value: item.id
    }))
  } catch (error) {
    console.error('获取分类列表失败', error)
  }
}
onMounted(() => {
  loadCategories()
  getList()
})

// 搜索参数
const searchParams = ref<Record<string, any>>({})
const setSearchParams = (params: any) => {
  searchParams.value = params
  getList()
}

// 表格配置
const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const { pageSize, currentPage } = tableState
    const res = await getGuideListApi({
      page: unref(currentPage),
      pageSize: unref(pageSize),
      ...unref(searchParams)
    })

    return {
      list: res.data || [],
      total: res.pagination?.total || 0
    }
  }
})

const { total, loading, dataList, pageSize, currentPage } = tableState
const { getList } = tableMethods

// CRUD Schema 定义
const crudSchemas = reactive<CrudSchema[]>([
  {
    field: 'selection',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: { type: 'selection' }
  },
  {
    field: 'index',
    label: '序号',
    form: { hidden: true },
    search: { hidden: true },
    detail: { hidden: true },
    table: { type: 'index' }
  },
  {
    field: 'icon',
    label: '指南图标',
    search: { hidden: true },
    form: {
      component: 'ImageUpload',
      componentProps: {
        placeholder: '点击上传指南图标',
        aspectRatio: 1,
        cropBoxWidth: 200,
        cropBoxHeight: 200,
        category: 'aid-guide-icon',
        circle: false,
        previewWidth: 120,
        previewHeight: 120
      },
      colProps: { span: 24 }
    },
    table: {
      show: true,
      width: 120,
      slots: {
        default: (data: any) => {
          return data.row.icon ? (
            <img
              src={getImageUrl(data.row.icon)}
              style={{ width: '50px', height: '50px', objectFit: 'cover', borderRadius: '4px' }}
              alt="指南图标"
            />
          ) : (
            <span>-</span>
          )
        }
      }
    }
  },
  {
    field: 'title',
    label: '指南标题',
    search: {
      component: 'Input'
    },
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入指南标题'
      },
      colProps: { span: 24 }
    },
    table: {
      show: true
    }
  },
  {
    field: 'summary',
    label: '指南摘要',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        type: 'textarea',
        rows: 3,
        placeholder: '请输入指南摘要'
      },
      colProps: { span: 24 }
    },
    table: {
      show: true
    }
  },
  {
    field: 'content',
    label: '指南内容',
    search: { hidden: true },
    form: {
      component: 'Editor',
      componentProps: {
        placeholder: '请输入指南内容'
      },
      colProps: { span: 24 }
    },
    table: {
      hidden: true
    }
  },
  {
    field: 'categoryId',
    label: '分类',
    search: {
      component: 'Select',
      componentProps: {
        options: categoryOptions,
        placeholder: '选择分类'
      }
    },
    form: {
      component: 'Select',
      componentProps: {
        options: categoryOptions,
        placeholder: '请选择分类'
      },
      colProps: { span: 12 }
    },
    table: {
      show: true,
      width: 120,
      slots: {
        default: (data: any) => {
          return data.row.category?.name || '-'
        }
      }
    }
  },
  {
    field: 'status',
    label: '状态',
    search: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '草稿', value: 'DRAFT' },
          { label: '已发布', value: 'PUBLISHED' }
        ]
      }
    },
    form: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '草稿', value: 'DRAFT' },
          { label: '已发布', value: 'PUBLISHED' }
        ],
        placeholder: '请选择状态'
      },
      colProps: { span: 12 }
    },
    table: {
      show: true,
      width: 100,
      slots: {
        default: (data: any) => {
          return data.row.status === 'PUBLISHED' ? (
            <ElTag type="success">已发布</ElTag>
          ) : (
            <ElTag type="info">草稿</ElTag>
          )
        }
      }
    }
  },
  {
    field: 'viewCount',
    label: '浏览量',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 100
    }
  },
  {
    field: 'likeCount',
    label: '点赞数',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 100
    }
  },
  {
    field: 'createdAt',
    label: '创建时间',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
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
    label: '操作',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 320,
      slots: {
        default: (data: any) => {
          return (
            <>
              <BaseButton type="primary" link onClick={() => handleEdit(data.row)}>
                编辑
              </BaseButton>
              {data.row.status === 'DRAFT' ? (
                <BaseButton type="success" link onClick={() => handlePublish(data.row)}>
                  发布
                </BaseButton>
              ) : (
                <BaseButton type="warning" link onClick={() => handleUnpublish(data.row)}>
                  取消发布
                </BaseButton>
              )}
              <BaseButton type="danger" link onClick={() => handleDelete(data.row)}>
                删除
              </BaseButton>
            </>
          )
        }
      }
    }
  }
])

const { allSchemas } = useCrudSchemas(crudSchemas)

// 操作方法
const handleAdd = () => {
  router.push('/aid-guides/create')
}

const handleEdit = (row: AidGuide) => {
  router.push({
    path: '/aid-guides/create',
    query: { id: row.id }
  })
}

const handleDelete = async (row: AidGuide) => {
  try {
    await ElMessageBox.confirm(`确定要删除指南"${row.title}"吗？`, '提示', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    })

    await deleteGuideApi(row.id)
    ElMessage.success('删除成功')
    getList()
  } catch (error) {
    if (error !== 'cancel') {
      console.error('删除失败', error)
      ElMessage.error('删除失败')
    }
  }
}

const handlePublish = async (row: AidGuide) => {
  try {
    await toggleGuideStatusApi(row.id)
    ElMessage.success('发布成功')
    getList()
  } catch (error) {
    console.error('发布失败', error)
    ElMessage.error('发布失败')
  }
}

const handleUnpublish = async (row: AidGuide) => {
  try {
    await toggleGuideStatusApi(row.id)
    ElMessage.success('已取消发布')
    getList()
  } catch (error) {
    console.error('取消发布失败', error)
    ElMessage.error('取消发布失败')
  }
}
</script>

<template>
  <ContentWrap>
    <!-- 搜索区域 -->
    <Search
      :schema="allSchemas.searchSchema"
      @search="setSearchParams"
      @reset="setSearchParams({})"
    />

    <!-- 操作按钮 -->
    <div class="mb-10px flex items-center justify-between">
      <span class="text-info">共 {{ total }} 篇指南</span>
      <BaseButton type="primary" :icon="Plus" @click="handleAdd"> 新增指南 </BaseButton>
    </div>

    <!-- 表格 -->
    <Table
      v-model:pageSize="pageSize"
      v-model:currentPage="currentPage"
      :columns="allSchemas.tableColumns"
      :data="dataList"
      :loading="loading"
      :pagination="{ total }"
      @register="tableRegister"
    />
  </ContentWrap>
</template>

<style scoped>
.text-info {
  color: var(--el-text-color-secondary);
  font-size: 14px;
}
</style>
