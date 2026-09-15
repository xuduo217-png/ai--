<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { Table } from '@/components/Table'
import { ref, unref, reactive } from 'vue'
import {
  ElTag,
  ElMessage,
  ElMessageBox,
  ElDescriptions,
  ElDescriptionsItem,
  ElDialog,
  ElTabs,
  ElTabPane,
  ElTable,
  ElTableColumn
} from 'element-plus'
import {
  getWalletTransactionsApi,
  approveTransactionApi,
  rejectTransactionApi,
  type WalletTransaction
} from '@/api-new/wallet/wallet'
import { RelatedType, WalletTransactionType } from '@/api-new/wallet/types'
import { useTable } from '@/hooks/web/useTable'
import { Search } from '@/components/Search'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { BaseButton } from '@/components/Button'
import { getOrderDetailApi } from '@/api-new/orders'
import type { Order } from '@/api-new/types'

const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const { pageSize, currentPage } = tableState
    const res = await getWalletTransactionsApi({
      page: unref(currentPage),
      limit: unref(pageSize),
      ...unref(searchParams),
      type: WalletTransactionType.INCOME,
      relatedType: RelatedType.ORDER
    })

    return {
      list: res.data?.items || [],
      total: res.data?.total || 0
    }
  }
})
const { total, loading, dataList, pageSize, currentPage } = tableState
const { getList } = tableMethods

// 搜索参数
const searchParams = ref<Record<string, any>>({
  status: '' // 默认显示所有状态
})
const setSearchParams = (params: any) => {
  currentPage.value = 1
  // 过滤掉空值参数
  const filteredParams = Object.keys(params).reduce(
    (acc, key) => {
      if (params[key] !== '' && params[key] !== null && params[key] !== undefined) {
        acc[key] = params[key]
      }
      return acc
    },
    {} as Record<string, any>
  )
  searchParams.value = filteredParams
  getList()
}

// 审核操作加载状态
const auditLoading = ref(false)
const auditTransactionId = ref<number | null>(null)

// 详情弹窗状态
const detailDialogVisible = ref(false)
const detailTransaction = ref<WalletTransaction | null>(null)
const relatedOrder = ref<Order | null>(null)
const detailLoading = ref(false)
const activeTab = ref('basic')

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
    field: 'id',
    label: '明细ID',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      width: 80
    }
  },
  {
    field: 'user.phone',
    label: '用户手机号',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      width: 130
    }
  },
  {
    field: 'status',
    label: '审核状态',
    search: {
      component: 'Select',
      componentProps: {
        placeholder: '全部状态',
        options: [
          { label: '全部状态', value: '' },
          { label: '待审核', value: 'pending' },
          { label: '已通过', value: 'approved' },
          { label: '已拒绝', value: 'rejected' }
        ]
      }
    },
    form: { hidden: true },
    table: {
      width: 100,
      slots: {
        default: (data: any) => {
          const row = data.row as WalletTransaction
          const statusMap: Record<string, { label: string; type: any }> = {
            pending: { label: '待审核', type: 'warning' as const },
            approved: { label: '已通过', type: 'success' as const },
            rejected: { label: '已拒绝', type: 'danger' as const }
          }
          const status = statusMap[row.status] || { label: row.status, type: 'info' as const }
          return <ElTag type={status.type}>{status.label}</ElTag>
        }
      }
    }
  },
  {
    field: 'type',
    label: '交易类型',
    search: {
      component: 'Select',
      componentProps: {
        placeholder: '全部类型',
        options: [
          { label: '全部类型', value: '' },
          { label: '收入', value: 'income' },
          { label: '冻结', value: 'freeze' },
          { label: '解冻', value: 'unfreeze' }
        ]
      }
    },
    form: { hidden: true },
    table: {
      width: 100,
      slots: {
        default: (data: any) => {
          const row = data.row as WalletTransaction
          const typeMap: Record<string, { label: string; type: any }> = {
            income: { label: '收入', type: 'success' as const },
            freeze: { label: '冻结', type: 'warning' as const },
            unfreeze: { label: '解冻', type: 'info' as const }
          }
          const type = typeMap[row.type] || { label: row.type, type: 'info' as const }
          return <ElTag type={type.type}>{type.label}</ElTag>
        }
      }
    }
  },
  {
    field: 'amount',
    label: '金额',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      slots: {
        default: (data: any) => {
          const row = data.row as WalletTransaction
          return `¥${Number(row.amount).toFixed(2)}`
        }
      }
    }
  },
  {
    field: 'relatedType',
    label: '关联类型',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      width: 120,
      slots: {
        default: (data: any) => {
          const row = data.row as WalletTransaction
          const typeMap: Record<string, string> = {
            order: '订单',
            refund: '退款',
            recharge: '充值',
            withdraw: '提现'
          }
          return typeMap[row.relatedType] || row.relatedType
        }
      }
    }
  },
  {
    field: 'relatedId',
    label: '关联ID',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      width: 100
    }
  },
  {
    field: 'createdAt',
    label: '创建时间',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      width: 180,
      slots: {
        default: (data: any) => {
          const row = data.row as WalletTransaction
          return new Date(row.createdAt).toLocaleString('zh-CN')
        }
      }
    }
  },
  // {
  //   field: 'waitingDays',
  //   label: '等待天数',
  //   search: { hidden: true },
  //   form: { hidden: true },
  //   table: {
  //     width: 120,
  //     slots: {
  //       default: (data: any) => {
  //         const row = data.row as WalletTransaction
  //         const days = row.waitingDays || 0
  //         const isOverdue = row.isOverdue || false
  //         return (
  //           <>
  //             <span>{days} 天</span>
  //             {isOverdue && (
  //               <ElTag type="danger" size="small" style={{ marginLeft: '8px' }}>
  //                 已超期
  //               </ElTag>
  //             )}
  //           </>
  //         )
  //       }
  //     }
  //   }
  // },
  {
    field: 'action',
    label: '操作',
    form: { hidden: true },
    detail: { hidden: true },
    search: { hidden: true },
    table: {
      width: 280,
      slots: {
        default: (data: any) => {
          const row = data.row as WalletTransaction
          const isLoading = auditLoading.value && auditTransactionId.value === row.id

          // 待审核状态：显示详情、审核通过、审核拒绝
          if (row.status === 'pending') {
            return (
              <>
                <BaseButton type="default" onClick={() => handleViewDetail(row)}>
                  详情
                </BaseButton>
                <BaseButton type="primary" loading={isLoading} onClick={() => handleApprove(row)}>
                  审核通过
                </BaseButton>
                <BaseButton type="danger" loading={isLoading} onClick={() => handleReject(row)}>
                  审核拒绝
                </BaseButton>
              </>
            )
          }
          // 已拒绝状态：显示详情、重新审核
          else if (row.status === 'rejected') {
            return (
              <>
                <BaseButton type="default" onClick={() => handleViewDetail(row)}>
                  详情
                </BaseButton>
                <BaseButton type="primary" loading={isLoading} onClick={() => handleReApprove(row)}>
                  重新审核
                </BaseButton>
              </>
            )
          }
          // 已通过状态：只显示详情
          else {
            return (
              <>
                <BaseButton type="default" onClick={() => handleViewDetail(row)}>
                  详情
                </BaseButton>
              </>
            )
          }
        }
      }
    }
  }
])

const { allSchemas } = useCrudSchemas(crudSchemas)

/**
 * 查看详情
 */
const handleViewDetail = async (row: WalletTransaction) => {
  detailTransaction.value = row
  detailDialogVisible.value = true

  // 如果关联的是订单，则加载订单详情
  if (row.relatedType === 'order' && row.relatedId) {
    try {
      detailLoading.value = true
      const res = await getOrderDetailApi(row.relatedId)
      relatedOrder.value = res.data
    } catch (error) {
      console.error('加载订单详情失败:', error)
      ElMessage.error('加载订单详情失败')
    } finally {
      detailLoading.value = false
    }
  } else {
    relatedOrder.value = null
  }
}

/**
 * 审核通过
 */
const handleApprove = async (row: WalletTransaction) => {
  try {
    await ElMessageBox.confirm(
      `确定要通过用户 ${row.user?.phone || row.userId} 的 ¥${Number(row.amount).toFixed(2)} 收入结算吗？`,
      '审核通过',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'success'
      }
    )

    auditLoading.value = true
    auditTransactionId.value = row.id

    await approveTransactionApi(row.id, {})
    ElMessage.success('审核通过成功')
    getList()
  } catch (error) {
    if (error !== 'cancel') {
      console.error('审核通过失败:', error)
      ElMessage.error('审核通过失败')
    }
  } finally {
    auditLoading.value = false
    auditTransactionId.value = null
  }
}

/**
 * 审核拒绝
 */
const handleReject = async (row: WalletTransaction) => {
  try {
    const { value } = await ElMessageBox.prompt(
      `请输入拒绝用户 ${row.user?.phone || row.userId} 的 ¥${Number(row.amount).toFixed(2)} 收入结算的原因：`,
      '审核拒绝',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        inputPattern: /\S+/,
        inputErrorMessage: '请输入拒绝原因'
      }
    )

    if (!value) {
      ElMessage.warning('请输入拒绝原因')
      return
    }

    auditLoading.value = true
    auditTransactionId.value = row.id

    await rejectTransactionApi(row.id, { reason: value })
    ElMessage.success('审核拒绝成功')
    getList()
  } catch (error) {
    if (error !== 'cancel') {
      console.error('审核拒绝失败:', error)
      ElMessage.error('审核拒绝失败')
    }
  } finally {
    auditLoading.value = false
    auditTransactionId.value = null
  }
}

/**
 * 重新审核（针对已拒绝的记录）
 */
const handleReApprove = async (row: WalletTransaction) => {
  try {
    await ElMessageBox.confirm(
      `确定要重新审核通过用户 ${row.user?.phone || row.userId} 的 ¥${Number(row.amount).toFixed(2)} 收入结算吗？\n\n原拒绝原因：${row.rejectReason || '无'}`,
      '重新审核',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning',
        dangerouslyUseHTMLString: true
      }
    )

    auditLoading.value = true
    auditTransactionId.value = row.id

    await approveTransactionApi(row.id, {})
    ElMessage.success('重新审核成功')
    getList()
  } catch (error) {
    if (error !== 'cancel') {
      console.error('重新审核失败:', error)
      ElMessage.error('重新审核失败')
    }
  } finally {
    auditLoading.value = false
    auditTransactionId.value = null
  }
}
</script>

<template>
  <ContentWrap>
    <!-- 搜索区域 -->
    <Search :schema="allSchemas.searchSchema" @reset="setSearchParams" @search="setSearchParams" />

    <!-- 表格区域 -->
    <Table
      v-model:current-page="currentPage"
      v-model:page-size="pageSize"
      :columns="allSchemas.tableColumns"
      :data="dataList"
      :loading="loading"
      @register="tableRegister"
      :pagination="{
        total: total || 0
      }"
    />
  </ContentWrap>

  <!-- 详情弹窗 -->
  <ElDialog v-model="detailDialogVisible" title="交易详情" width="900px">
    <div v-if="detailTransaction">
      <el-tabs v-model="activeTab">
        <!-- 基本信息 Tab -->
        <el-tab-pane label="基本信息" name="basic">
          <el-descriptions :column="2" border>
            <el-descriptions-item label="交易ID">
              {{ detailTransaction.id }}
            </el-descriptions-item>
            <el-descriptions-item label="用户手机号">
              {{ detailTransaction.user?.phone || detailTransaction.userId }}
            </el-descriptions-item>
            <el-descriptions-item label="用户名">
              {{ detailTransaction.user?.username || '-' }}
            </el-descriptions-item>
            <el-descriptions-item label="金额">
              <span style="color: #10b981; font-weight: 600; font-size: 16px">
                ¥{{ Number(detailTransaction.amount).toFixed(2) }}
              </span>
            </el-descriptions-item>
            <el-descriptions-item label="交易类型">
              {{ detailTransaction.type === 'income' ? '收入' : '支出' }}
            </el-descriptions-item>
            <el-descriptions-item label="关联类型">
              {{
                detailTransaction.relatedType === 'order'
                  ? '订单'
                  : detailTransaction.relatedType === 'refund'
                    ? '退款'
                    : detailTransaction.relatedType === 'recharge'
                      ? '充值'
                      : detailTransaction.relatedType === 'withdraw'
                        ? '提现'
                        : detailTransaction.relatedType
              }}
            </el-descriptions-item>
            <el-descriptions-item label="关联ID">
              {{ detailTransaction.relatedId }}
            </el-descriptions-item>
            <el-descriptions-item label="状态">
              <ElTag
                :type="
                  detailTransaction.status === 'pending'
                    ? 'warning'
                    : detailTransaction.status === 'approved'
                      ? 'success'
                      : 'danger'
                "
              >
                {{
                  detailTransaction.status === 'pending'
                    ? '待审核'
                    : detailTransaction.status === 'approved'
                      ? '已通过'
                      : '已拒绝'
                }}
              </ElTag>
            </el-descriptions-item>
            <el-descriptions-item label="变动前余额">
              ¥{{ Number(detailTransaction.balanceBefore || 0).toFixed(2) }}
            </el-descriptions-item>
            <el-descriptions-item label="变动后余额">
              ¥{{ Number(detailTransaction.balanceAfter || 0).toFixed(2) }}
            </el-descriptions-item>
            <el-descriptions-item label="创建时间" :span="2">
              {{ new Date(detailTransaction.createdAt).toLocaleString('zh-CN') }}
            </el-descriptions-item>
            <!-- 审核时间（已审核） -->
            <el-descriptions-item
              v-if="detailTransaction.status !== 'pending'"
              label="审核时间"
              :span="2"
            >
              {{
                detailTransaction.reviewedAt
                  ? new Date(detailTransaction.reviewedAt).toLocaleString('zh-CN')
                  : '-'
              }}
            </el-descriptions-item>
            <!-- 拒绝原因（已拒绝） -->
            <el-descriptions-item
              v-if="detailTransaction.status === 'rejected' && detailTransaction.rejectReason"
              label="拒绝原因"
              :span="2"
            >
              {{ detailTransaction.rejectReason }}
            </el-descriptions-item>
            <el-descriptions-item label="备注" :span="2">
              {{ detailTransaction.remark || '-' }}
            </el-descriptions-item>
          </el-descriptions>
        </el-tab-pane>

        <!-- 关联数据 Tab -->
        <el-tab-pane label="关联数据" name="related">
          <template v-if="relatedOrder">
            <!-- 订单信息 -->
            <div style="margin-bottom: 16px; font-weight: 600; font-size: 14px">订单信息</div>
            <el-descriptions
              :column="2"
              border
              style="margin-bottom: 24px"
              v-loading="detailLoading"
            >
              <el-descriptions-item label="订单号">
                {{ relatedOrder.orderNo }}
              </el-descriptions-item>
              <el-descriptions-item label="订单类型">
                <ElTag :type="relatedOrder.orderType === 'second_hand' ? 'warning' : 'primary'">
                  {{ relatedOrder.orderType === 'second_hand' ? '二手订单' : '普通订单' }}
                </ElTag>
              </el-descriptions-item>
              <el-descriptions-item label="订单状态">
                <ElTag
                  :type="
                    relatedOrder.status === 'completed'
                      ? 'success'
                      : relatedOrder.status === 'cancelled'
                        ? 'danger'
                        : relatedOrder.status === 'pending'
                          ? 'warning'
                          : 'info'
                  "
                >
                  {{
                    relatedOrder.status === 'completed'
                      ? '已完成'
                      : relatedOrder.status === 'cancelled'
                        ? '已取消'
                        : relatedOrder.status === 'pending'
                          ? '待支付'
                          : relatedOrder.status === 'paid'
                            ? '已支付'
                            : relatedOrder.status === 'shipped'
                              ? '已发货'
                              : relatedOrder.status
                  }}
                </ElTag>
              </el-descriptions-item>
              <el-descriptions-item label="订单金额">
                ¥{{ Number(relatedOrder.totalAmount || 0).toFixed(2) }}
              </el-descriptions-item>
              <el-descriptions-item label="买家">
                {{ relatedOrder.user?.username || '-' }} ({{ relatedOrder.user?.phone || '-' }})
              </el-descriptions-item>
              <el-descriptions-item label="卖家" v-if="relatedOrder.orderType === 'second_hand'">
                {{ relatedOrder.seller?.username || '-' }}
                ({{ relatedOrder.seller?.phone || '-' }})
              </el-descriptions-item>
              <el-descriptions-item label="收货人">
                {{ relatedOrder.receiverName || '-' }}
              </el-descriptions-item>
              <el-descriptions-item label="联系电话">
                {{ relatedOrder.receiverPhone || '-' }}
              </el-descriptions-item>
              <el-descriptions-item label="收货地址" :span="2">
                {{ relatedOrder.shippingAddress || '-' }}
              </el-descriptions-item>
              <el-descriptions-item label="下单时间" :span="2">
                {{ new Date(relatedOrder.createdAt).toLocaleString('zh-CN') }}
              </el-descriptions-item>
              <el-descriptions-item label="订单备注" :span="2">
                {{ relatedOrder.remark || '-' }}
              </el-descriptions-item>
            </el-descriptions>

            <!-- 商品列表 -->
            <div style="margin-bottom: 12px; font-weight: 600; font-size: 14px">商品列表</div>
            <el-table :data="relatedOrder.items || []" border style="width: 100%">
              <el-table-column label="商品图片" width="100">
                <template #default="{ row }">
                  <el-image
                    v-if="row.productImage"
                    :src="row.productImage"
                    style="width: 60px; height: 60px; border-radius: 4px"
                    fit="cover"
                  />
                  <span v-else>-</span>
                </template>
              </el-table-column>
              <el-table-column prop="productName" label="商品名称" min-width="200" />
              <el-table-column label="商品来源" width="150">
                <template #default>
                  <ElTag
                    v-if="relatedOrder.orderType === 'second_hand'"
                    :type="relatedOrder.sellerId === detailTransaction.userId ? 'success' : 'info'"
                  >
                    {{
                      relatedOrder.sellerId === detailTransaction.userId
                        ? '当前用户发布'
                        : '其他用户发布'
                    }}
                  </ElTag>
                  <span v-else>-</span>
                </template>
              </el-table-column>
              <el-table-column prop="skuName" label="规格" width="120">
                <template #default="{ row }">
                  {{ row.skuName || '-' }}
                </template>
              </el-table-column>
              <el-table-column prop="price" label="单价" width="100">
                <template #default="{ row }"> ¥{{ Number(row.price).toFixed(2) }} </template>
              </el-table-column>
              <el-table-column prop="quantity" label="数量" width="80" />
              <el-table-column label="小计" width="120">
                <template #default="{ row }">
                  ¥{{ (Number(row.price) * row.quantity).toFixed(2) }}
                </template>
              </el-table-column>
            </el-table>
          </template>
          <el-empty v-else description="暂无关联订单数据" />
        </el-tab-pane>
      </el-tabs>
    </div>

    <template #footer>
      <BaseButton @click="detailDialogVisible = false">关闭</BaseButton>
    </template>
  </ElDialog>
</template>

<style scoped>
:deep(.el-table .cell) {
  white-space: nowrap;
}
</style>
