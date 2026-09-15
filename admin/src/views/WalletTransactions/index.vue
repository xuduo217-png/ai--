<script setup lang="tsx">
import { onMounted, reactive, ref, unref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElDescriptions, ElDescriptionsItem, ElDialog, ElTag } from 'element-plus'
import { ContentWrap } from '@/components/ContentWrap'
import { Search } from '@/components/Search'
import { Table } from '@/components/Table'
import { BaseButton } from '@/components/Button'
import { getWalletTransactionsApi } from '@/api-new/wallet/wallet'
import {
  WalletTransactionStatus,
  WalletTransactionType,
  type WalletTransaction
} from '@/api-new/wallet/types'
import { useTable } from '@/hooks/web/useTable'
import { useSearch } from '@/hooks/web/useSearch'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'

defineOptions({
  name: 'WalletTransactions'
})

const TYPE_CONFIG: Record<
  string,
  { label: string; tagType: 'success' | 'danger' | 'warning' | 'info' }
> = {
  income: { label: '收入', tagType: 'success' },
  expense: { label: '支出', tagType: 'danger' },
  freeze: { label: '冻结', tagType: 'warning' },
  unfreeze: { label: '解冻', tagType: 'info' }
}

const STATUS_CONFIG: Record<
  string,
  { label: string; tagType: 'success' | 'danger' | 'warning' | 'info' }
> = {
  pending: { label: '待处理', tagType: 'warning' },
  approved: { label: '已完成', tagType: 'success' },
  rejected: { label: '已拒绝', tagType: 'danger' }
}

const RELATED_TYPE_LABELS: Record<string, string> = {
  order: '订单',
  refund: '退款',
  recharge: '充值',
  withdraw: '提现',
  adjustment: '平台调整',
  charity: '公益捐款'
}

const route = useRoute()
const router = useRouter()

const normalizeUserId = (value: unknown): number | undefined => {
  const rawValue = Array.isArray(value) ? value[0] : value
  const parsed = Number(rawValue)
  return Number.isInteger(parsed) && parsed > 0 ? parsed : undefined
}

const routeUserId = normalizeUserId(route.query.userId)
const searchParams = ref<Record<string, any>>(routeUserId ? { userId: routeUserId } : {})
const detailDialogVisible = ref(false)
const detailTransaction = ref<WalletTransaction | null>(null)

const { searchRegister, searchMethods } = useSearch()

const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const { pageSize, currentPage } = tableState
    const response = await getWalletTransactionsApi({
      page: unref(currentPage),
      limit: unref(pageSize),
      ...unref(searchParams)
    })

    return {
      list: response.data?.items || [],
      total: response.data?.total || 0
    }
  }
})

const { total, loading, dataList, pageSize, currentPage } = tableState
const { getList } = tableMethods

const reloadFromFirstPage = () => {
  if (currentPage.value === 1) {
    getList()
    return
  }
  currentPage.value = 1
}

const setSearchParams = (params: Record<string, any>) => {
  const nextParams = { ...params }
  const userId = normalizeUserId(nextParams.userId)
  if (userId) {
    nextParams.userId = userId
  } else {
    delete nextParams.userId
  }
  searchParams.value = nextParams
  reloadFromFirstPage()
}

onMounted(() => {
  if (routeUserId) {
    searchMethods.setValues({ userId: routeUserId })
  }
})

watch(
  () => route.query.userId,
  (value) => {
    const userId = normalizeUserId(value)
    if (userId === searchParams.value.userId) {
      return
    }

    const nextParams = { ...searchParams.value }
    if (userId) {
      nextParams.userId = userId
    } else {
      delete nextParams.userId
    }
    searchParams.value = nextParams
    searchMethods.setValues({ userId })
    reloadFromFirstPage()
  }
)

const getTypeConfig = (type: string) =>
  TYPE_CONFIG[type] || { label: type || '未知', tagType: 'info' as const }

const getStatusConfig = (status: string) =>
  STATUS_CONFIG[status] || { label: status || '未知', tagType: 'info' as const }

const getRelatedTypeLabel = (relatedType: string, historicalAdjustment = false) =>
  historicalAdjustment ? '历史余额调整' : RELATED_TYPE_LABELS[relatedType] || relatedType || '-'

const isCredit = (type: WalletTransactionType) =>
  type === WalletTransactionType.INCOME || type === WalletTransactionType.UNFREEZE

const formatAmount = (amount: number) => `¥${Number(amount || 0).toFixed(2)}`

const formatDateTime = (value?: string) => {
  if (!value) return '-'
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? '-' : date.toLocaleString('zh-CN')
}

const openDetail = (row: WalletTransaction) => {
  detailTransaction.value = row
  detailDialogVisible.value = true
}

const openWithdrawalDetail = (row: WalletTransaction) => {
  router.push({ name: 'WalletWithdrawals', query: { withdrawalId: row.relatedId } })
}

const crudSchemas = reactive<CrudSchema[]>([
  {
    field: 'index',
    label: '序号',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: { type: 'index', width: 70 }
  },
  {
    field: 'id',
    label: '流水ID',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: { width: 90 }
  },
  {
    field: 'userId',
    label: '用户ID',
    search: {
      component: 'InputNumber',
      componentProps: {
        min: 1,
        precision: 0,
        controls: false,
        placeholder: '请输入用户ID'
      }
    },
    form: { hidden: true },
    detail: { hidden: true },
    table: { width: 90 }
  },
  {
    field: 'user.phone',
    label: '用户手机号',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: {
      width: 130,
      slots: {
        default: (data: any) => data.row.user?.phone || '-'
      }
    }
  },
  {
    field: 'type',
    label: '交易类型',
    search: {
      component: 'Select',
      componentProps: {
        clearable: true,
        placeholder: '全部类型',
        options: [
          { label: '收入', value: WalletTransactionType.INCOME },
          { label: '支出', value: WalletTransactionType.EXPENSE },
          { label: '冻结', value: WalletTransactionType.FREEZE },
          { label: '解冻', value: WalletTransactionType.UNFREEZE }
        ]
      }
    },
    form: { hidden: true },
    detail: { hidden: true },
    table: {
      width: 100,
      slots: {
        default: (data: any) => {
          const config = getTypeConfig(data.row.type)
          return <ElTag type={config.tagType}>{config.label}</ElTag>
        }
      }
    }
  },
  {
    field: 'amount',
    label: '金额',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: {
      width: 120,
      slots: {
        default: (data: any) => {
          const credit = isCredit(data.row.type)
          return (
            <span style={{ color: credit ? '#16845B' : '#C2413B', fontWeight: 600 }}>
              {credit ? '+' : '-'}
              {formatAmount(data.row.amount)}
            </span>
          )
        }
      }
    }
  },
  {
    field: 'relatedType',
    label: '业务来源',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: {
      width: 110,
      slots: {
        default: (data: any) =>
          getRelatedTypeLabel(data.row.relatedType, data.row.historicalAdjustment)
      }
    }
  },
  {
    field: 'relatedId',
    label: '关联ID',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: { width: 90 }
  },
  {
    field: 'status',
    label: '状态',
    search: {
      component: 'Select',
      componentProps: {
        clearable: true,
        placeholder: '全部状态',
        options: [
          { label: '待处理', value: WalletTransactionStatus.PENDING },
          { label: '已完成', value: WalletTransactionStatus.APPROVED },
          { label: '已拒绝', value: WalletTransactionStatus.REJECTED }
        ]
      }
    },
    form: { hidden: true },
    detail: { hidden: true },
    table: {
      width: 100,
      slots: {
        default: (data: any) => {
          const config = getStatusConfig(data.row.status)
          return <ElTag type={config.tagType}>{config.label}</ElTag>
        }
      }
    }
  },
  {
    field: 'balanceChange',
    label: '余额变化',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: {
      width: 190,
      slots: {
        default: (data: any) =>
          `${formatAmount(data.row.balanceBefore)} -> ${formatAmount(data.row.balanceAfter)}`
      }
    }
  },
  {
    field: 'remark',
    label: '备注',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: { minWidth: 220, showOverflowTooltip: true }
  },
  {
    field: 'createdAt',
    label: '创建时间',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: {
      width: 180,
      slots: {
        default: (data: any) => formatDateTime(data.row.createdAt)
      }
    }
  },
  {
    field: 'action',
    label: '操作',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: {
      fixed: 'right',
      width: 180,
      slots: {
        default: (data: any) => (
          <>
            <BaseButton type="primary" onClick={() => openDetail(data.row)}>
              详情
            </BaseButton>
            {data.row.relatedType === 'withdraw' && data.row.withdrawalNo && (
              <BaseButton type="success" onClick={() => openWithdrawalDetail(data.row)}>
                提现详情
              </BaseButton>
            )}
          </>
        )
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
      @register="searchRegister"
      @reset="setSearchParams"
      @search="setSearchParams"
    />

    <Table
      v-model:current-page="currentPage"
      v-model:page-size="pageSize"
      :columns="allSchemas.tableColumns"
      :data="dataList"
      :loading="loading"
      :pagination="{ total: total || 0 }"
      @register="tableRegister"
    />
  </ContentWrap>

  <ElDialog v-model="detailDialogVisible" title="钱包流水详情" width="760px">
    <ElDescriptions v-if="detailTransaction" :column="2" border>
      <ElDescriptionsItem label="流水ID">
        {{ detailTransaction.id }}
      </ElDescriptionsItem>
      <ElDescriptionsItem label="用户">
        {{ detailTransaction.user?.phone || detailTransaction.userId }}
      </ElDescriptionsItem>
      <ElDescriptionsItem label="交易类型">
        <ElTag :type="getTypeConfig(detailTransaction.type).tagType">
          {{ getTypeConfig(detailTransaction.type).label }}
        </ElTag>
      </ElDescriptionsItem>
      <ElDescriptionsItem label="状态">
        <ElTag :type="getStatusConfig(detailTransaction.status).tagType">
          {{ getStatusConfig(detailTransaction.status).label }}
        </ElTag>
      </ElDescriptionsItem>
      <ElDescriptionsItem label="金额">
        {{ isCredit(detailTransaction.type) ? '+' : '-'
        }}{{ formatAmount(detailTransaction.amount) }}
      </ElDescriptionsItem>
      <ElDescriptionsItem label="业务来源">
        {{
          getRelatedTypeLabel(detailTransaction.relatedType, detailTransaction.historicalAdjustment)
        }}
      </ElDescriptionsItem>
      <ElDescriptionsItem label="关联ID">
        {{ detailTransaction.relatedId || '-' }}
      </ElDescriptionsItem>
      <ElDescriptionsItem label="创建时间">
        {{ formatDateTime(detailTransaction.createdAt) }}
      </ElDescriptionsItem>
      <ElDescriptionsItem label="变动前余额">
        {{ formatAmount(detailTransaction.balanceBefore) }}
      </ElDescriptionsItem>
      <ElDescriptionsItem label="变动后余额">
        {{ formatAmount(detailTransaction.balanceAfter) }}
      </ElDescriptionsItem>
      <ElDescriptionsItem v-if="detailTransaction.reviewedAt" label="处理时间" :span="2">
        {{ formatDateTime(detailTransaction.reviewedAt) }}
      </ElDescriptionsItem>
      <ElDescriptionsItem v-if="detailTransaction.rejectReason" label="拒绝原因" :span="2">
        {{ detailTransaction.rejectReason }}
      </ElDescriptionsItem>
      <ElDescriptionsItem label="备注" :span="2">
        {{ detailTransaction.remark || '-' }}
      </ElDescriptionsItem>
    </ElDescriptions>

    <template #footer>
      <BaseButton @click="detailDialogVisible = false">关闭</BaseButton>
    </template>
  </ElDialog>
</template>
