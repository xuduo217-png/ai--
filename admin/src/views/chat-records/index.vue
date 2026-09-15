<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { Table } from '@/components/Table'
import { ref, unref, reactive } from 'vue'
import { ElTag, ElButton } from 'element-plus'
import { useTable } from '@/hooks/web/useTable'
import { Search } from '@/components/Search'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { getChatRecordsApi, type ChatSessionRecord } from '@/api-new/chat-records'
import { extractPagedTableData } from '@/utils/pagination'
import ChatDetailDialog from './components/ChatDetailDialog.vue'

defineOptions({
  name: 'ChatRecords'
})

// 表格相关
const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const { pageSize, currentPage } = tableState
    const res = await getChatRecordsApi({
      page: unref(currentPage),
      pageSize: unref(pageSize),
      ...unref(searchParams)
    })

    return extractPagedTableData<ChatSessionRecord>(res)
  }
})

const { total, loading, dataList, pageSize, currentPage } = tableState
const { getList } = tableMethods

// 搜索参数
const searchParams = ref<Record<string, any>>({})
const setSearchParams = (params: any) => {
  currentPage.value = 1
  searchParams.value = params
  getList()
}

// 详情对话框
const detailDialogVisible = ref(false)
const currentConversation = ref<ChatSessionRecord | null>(null)

/**
 * 格式化时间
 */
const formatTime = (time: string | null) => {
  if (!time) return '-'
  return new Date(time).toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  })
}

/**
 * 获取状态标签类型
 */
const getStatusType = (status: string) => {
  const map: Record<string, any> = {
    PAID: 'success',
    EXPIRED: 'info',
    COMPLETED: 'primary',
    FREE: 'warning'
  }
  return map[status] || 'default'
}

/**
 * 获取状态文本
 */
const getStatusText = (status: string) => {
  const map: Record<string, string> = {
    PAID: '服务中',
    EXPIRED: '已过期',
    COMPLETED: '已完成',
    FREE: '免费咨询'
  }
  return map[status] || status
}

/**
 * 查看详情
 */
const handleViewDetail = (row: ChatSessionRecord) => {
  currentConversation.value = row
  detailDialogVisible.value = true
}

// CRUD Schema 定义
const crudSchemas = reactive<CrudSchema[]>([
  {
    field: 'index',
    label: '序号',
    form: { hidden: true },
    search: { hidden: true },
    table: { type: 'index', width: 60 }
  },
  {
    field: 'id',
    label: '会话ID',
    form: { hidden: true },
    search: { hidden: true },
    table: { show: true, width: 80 }
  },
  {
    field: 'doctorName',
    label: '医生姓名',
    form: { hidden: true },
    search: { hidden: true },
    table: { show: true, width: 120 }
  },
  {
    field: 'userName',
    label: '用户昵称',
    form: { hidden: true },
    search: { hidden: true },
    table: { show: true, width: 120 }
  },
  {
    field: 'hospitalName',
    label: '医院',
    form: { hidden: true },
    search: {
      component: 'Input',
      label: '医院',
      componentProps: {
        placeholder: '请输入医院名称'
      }
    },
    table: { show: true, width: 150 }
  },
  {
    field: 'departmentName',
    label: '科室',
    form: { hidden: true },
    search: {
      component: 'Input',
      label: '科室',
      componentProps: {
        placeholder: '请输入科室名称'
      }
    },
    table: { show: true, width: 120 }
  },
  {
    field: 'serviceItemName',
    label: '套餐',
    form: { hidden: true },
    search: { hidden: true },
    table: {
      show: true,
      width: 150,
      slots: {
        default: (data: any) => {
          return <span>{data.row.serviceItemName || '-'}</span>
        }
      }
    }
  },
  {
    field: 'serviceStartAt',
    label: '开始时间',
    form: { hidden: true },
    search: { hidden: true },
    table: {
      show: true,
      width: 180,
      slots: {
        default: (data: any) => {
          return <span>{formatTime(data.row.serviceStartAt)}</span>
        }
      }
    }
  },
  {
    field: 'serviceEndAt',
    label: '结束时间',
    form: { hidden: true },
    search: { hidden: true },
    table: {
      show: true,
      width: 180,
      slots: {
        default: (data: any) => {
          return <span>{formatTime(data.row.serviceEndAt)}</span>
        }
      }
    }
  },
  {
    field: 'status',
    label: '状态',
    form: { hidden: true },
    search: {
      component: 'Select',
      label: '状态',
      componentProps: {
        placeholder: '请选择状态',
        options: [
          { label: '全部', value: '' },
          { label: '服务中', value: 'PAID' },
          { label: '已过期', value: 'EXPIRED' },
          { label: '已完成', value: 'COMPLETED' }
        ]
      }
    },
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
    field: 'messageCount',
    label: '消息数',
    form: { hidden: true },
    search: { hidden: true },
    table: {
      show: true,
      width: 100,
      slots: {
        default: (data: any) => {
          return <span>{data.row.messageCount || 0}</span>
        }
      }
    }
  },
  {
    field: 'action',
    label: '操作',
    form: { hidden: true },
    search: { hidden: true },
    table: {
      show: true,
      width: 120,
      slots: {
        default: (data: any) => {
          return (
            <ElButton type="primary" link onClick={() => handleViewDetail(data.row)}>
              查看详情
            </ElButton>
          )
        }
      }
    }
  }
])

const { allSchemas } = useCrudSchemas(crudSchemas)
</script>

<template>
  <ContentWrap>
    <Search
      :schema="allSchemas.searchSchema"
      @search="setSearchParams"
      @reset="setSearchParams({})"
    />

    <Table
      v-if="allSchemas.tableColumns && allSchemas.tableColumns.length > 0"
      v-model:pageSize="pageSize"
      v-model:currentPage="currentPage"
      :columns="allSchemas.tableColumns"
      :data="dataList"
      :loading="loading"
      :pagination="{
        total
      }"
      @register="tableRegister"
      style="min-height: 400px"
    />
    <div v-else style="padding: 20px; text-align: center; background: #fff">
      <p>表格配置加载中...</p>
    </div>

    <!-- 聊天记录详情对话框（微信风格） -->
    <ChatDetailDialog v-model="detailDialogVisible" :session-info="currentConversation" />
  </ContentWrap>
</template>

<style lang="less" scoped>
// 样式已移至组件内部和独立样式文件
</style>
