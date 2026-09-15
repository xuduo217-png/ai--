<template>
  <ContentWrap>
    <!-- 搜索区域 -->
    <Search
      :schema="allSchemas.searchSchema"
      @search="setSearchParams"
      @reset="setSearchParams({})"
    />

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

<script setup lang="tsx">
import { ref, unref } from 'vue'
import { useRouter } from 'vue-router'
import { ElTag, ElButton, ElMessageBox, ElMessage } from 'element-plus'
import { Table } from '@/components/Table'
import { ContentWrap } from '@/components/ContentWrap'
import { Search } from '@/components/Search'
import { useTable } from '@/hooks/web/useTable'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import {
  getAiDiagnosisReportsApi,
  deleteAiDiagnosisReportApi
} from '@/api-new/ai-diagnosis-reports'

defineOptions({
  name: 'AiDiagnosisReports'
})

const router = useRouter()

// 搜索参数
const searchParams = ref<Record<string, any>>({})

// 设置搜索参数
const setSearchParams = (params: any) => {
  // 处理日期范围：将 dateRange 转换为 startDate 和 endDate
  const processedParams = { ...params }
  if (
    processedParams.dateRange &&
    Array.isArray(processedParams.dateRange) &&
    processedParams.dateRange.length === 2
  ) {
    processedParams.startDate = processedParams.dateRange[0]
    processedParams.endDate = processedParams.dateRange[1]
    delete processedParams.dateRange
  }

  searchParams.value = processedParams
  currentPage.value = 1
  getList()
}

// 表格相关
const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const { pageSize, currentPage } = tableState

    // 处理日期范围
    const params = { ...unref(searchParams) }
    if (params.dateRange && Array.isArray(params.dateRange) && params.dateRange.length === 2) {
      params.startDate = params.dateRange[0]
      params.endDate = params.dateRange[1]
      delete params.dateRange
    }

    const res = await getAiDiagnosisReportsApi({
      page: unref(currentPage),
      pageSize: unref(pageSize),
      ...params
    })

    return {
      list: res.data || [],
      total: res.pagination?.total || 0
    }
  }
})

const { total, loading, dataList, pageSize, currentPage } = tableState
const { getList } = tableMethods

/**
 * 查看详情
 */
const handleViewDetail = (row: any) => {
  router.push({
    name: 'AiDiagnosisReportDetail',
    params: { id: row.id }
  })
}

/**
 * 删除报告
 */
const handleDelete = async (row: any) => {
  try {
    await ElMessageBox.confirm('确定删除该报告吗？', '提示', {
      type: 'warning'
    })

    await deleteAiDiagnosisReportApi(row.id)
    ElMessage.success('删除成功')
    getList()
  } catch (error) {
    // 取消删除
  }
}

/**
 * 获取状态标签类型
 */
const getStatusType = (status: string) => {
  const map: Record<string, any> = {
    PENDING: 'info',
    PROCESSING: 'warning',
    COMPLETED: 'success',
    FAILED: 'danger',
    TIMEOUT: 'danger'
  }
  return map[status] || 'info'
}

/**
 * 获取状态文本
 */
const getStatusText = (status: string) => {
  const map: Record<string, string> = {
    PENDING: '待生成',
    PROCESSING: '生成中',
    COMPLETED: '已完成',
    FAILED: '失败',
    TIMEOUT: '超时'
  }
  return map[status] || status
}

// CRUD Schema 定义
const crudSchemas: CrudSchema[] = [
  {
    field: 'index',
    label: '序号',
    form: { hidden: true },
    search: { hidden: true },
    table: { type: 'index', width: 60 }
  },
  {
    field: 'status',
    label: '状态',
    search: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '全部', value: '' },
          { label: '待生成', value: 'PENDING' },
          { label: '生成中', value: 'PROCESSING' },
          { label: '已完成', value: 'COMPLETED' },
          { label: '失败', value: 'FAILED' },
          { label: '超时', value: 'TIMEOUT' }
        ]
      }
    },
    form: { hidden: true },
    table: {
      show: true,
      width: 100,
      slots: {
        default: (data: any) => {
          return (
            <ElTag type={getStatusType(data.row.status)}>{getStatusText(data.row.status)}</ElTag>
          )
        }
      }
    }
  },
  {
    field: 'id',
    label: 'ID搜索',
    search: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入报告ID'
      }
    },
    form: { hidden: true },
    table: {
      hidden: true
    }
  },
  {
    field: 'keyword',
    label: '关键词',
    search: {
      component: 'Input',
      componentProps: {
        placeholder: '搜索症状描述'
      }
    },
    form: { hidden: true },
    table: {
      hidden: true
    }
  },
  {
    field: 'userPhone',
    label: '用户手机号',
    search: {
      component: 'Input',
      componentProps: {
        placeholder: '搜索用户手机号'
      }
    },
    form: { hidden: true },
    table: {
      hidden: true
    }
  },
  {
    field: 'dateRange',
    label: '创建时间',
    search: {
      component: 'DatePicker',
      componentProps: {
        type: 'daterange',
        format: 'YYYY-MM-DD',
        valueFormat: 'YYYY-MM-DD',
        rangeSeparator: '至',
        startPlaceholder: '开始日期',
        endPlaceholder: '结束日期',
        clearable: true
      }
    },
    form: { hidden: true },
    table: {
      hidden: true
    }
  },
  {
    field: 'id',
    label: '报告ID',
    form: { hidden: true },
    search: { hidden: true },
    table: { show: true, width: 80 }
  },
  {
    field: 'petName',
    label: '宠物名称',
    form: { hidden: true },
    search: { hidden: true },
    table: { show: true, width: 120 }
  },
  {
    field: 'userPhone',
    label: '用户手机号',
    form: { hidden: true },
    search: { hidden: true },
    table: { show: true, width: 140 }
  },
  {
    field: 'createdAt',
    label: '创建时间',
    form: { hidden: true },
    search: { hidden: true },
    table: { show: true, width: 180 }
  },
  {
    field: 'action',
    label: '操作',
    form: { hidden: true },
    search: { hidden: true },
    table: {
      show: true,
      width: 150,
      slots: {
        default: (data: any) => {
          return (
            <div style="display: flex; align-items: center; gap: 8px;">
              <ElButton type="primary" size="small" onClick={() => handleViewDetail(data.row)}>
                查看详情
              </ElButton>
              <ElButton type="danger" size="small" onClick={() => handleDelete(data.row)}>
                删除
              </ElButton>
            </div>
          )
        }
      }
    }
  }
]

// 生成所有 schemas
const { allSchemas } = useCrudSchemas(crudSchemas)
</script>
