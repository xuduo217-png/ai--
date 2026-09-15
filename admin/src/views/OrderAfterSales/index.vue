<script setup lang="ts">
import { onMounted, reactive, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import {
  ElButton,
  ElDatePicker,
  ElForm,
  ElFormItem,
  ElInput,
  ElMessage,
  ElOption,
  ElPagination,
  ElSelect,
  ElTable,
  ElTableColumn,
  ElTabs,
  ElTabPane,
  ElTag
} from 'element-plus'
import { Refresh, Search, View } from '@element-plus/icons-vue'
import { getAfterSaleListApi } from '@/api-new/after-sales'
import type { AdminAfterSale, AfterSaleListParams, AfterSaleStatus } from '@/api-new/after-sales'

const router = useRouter()
const loading = ref(false)
const rows = ref<AdminAfterSale[]>([])
const activeView = ref<AfterSaleListParams['view']>('platform_pending')
const createdRange = ref<[Date, Date]>()
const query = reactive<AfterSaleListParams>({ page: 1, pageSize: 20, keyword: '' })
const total = ref(0)

const statusText: Record<AfterSaleStatus, string> = {
  pending_handler: '等待处理',
  handler_rejected: '处理方已拒绝',
  handler_timeout: '处理超时',
  waiting_buyer_return: '等待买家退货',
  waiting_handler_receipt: '等待确认退货',
  arbitration_pending: '平台仲裁中',
  refunding: '退款处理中',
  refunded: '已退款',
  closed: '已关闭'
}

const statusType = (status: AfterSaleStatus) => {
  if (status === 'arbitration_pending' || status === 'pending_handler') return 'warning'
  if (status === 'refunding') return 'primary'
  if (status === 'refunded') return 'success'
  if (status === 'closed') return 'info'
  return 'danger'
}

const load = async () => {
  loading.value = true
  try {
    const [createdFrom, createdTo] = createdRange.value || []
    const response = await getAfterSaleListApi({
      ...query,
      view: activeView.value,
      createdFrom: createdFrom ? formatDate(createdFrom) : undefined,
      createdTo: createdTo ? formatDate(createdTo) : undefined
    })
    const payload = response.data as any
    rows.value = Array.isArray(payload) ? payload : payload?.data || []
    total.value = Number(payload?.total ?? (response as any).meta?.total ?? 0)
  } catch (error) {
    console.error('获取售后仲裁列表失败:', error)
    ElMessage.error('获取售后仲裁列表失败')
  } finally {
    loading.value = false
  }
}

const formatDate = (value: Date) => {
  const year = value.getFullYear()
  const month = String(value.getMonth() + 1).padStart(2, '0')
  const day = String(value.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

const reset = () => {
  query.keyword = ''
  query.status = undefined
  query.orderType = undefined
  query.handlerType = undefined
  query.overdue = undefined
  query.page = 1
  createdRange.value = undefined
  load()
}

watch(activeView, () => {
  query.page = 1
  load()
})

onMounted(load)
</script>

<template>
  <div class="after-sale-list">
    <section class="filter-panel">
      <el-tabs v-model="activeView">
        <el-tab-pane label="平台待处理" name="platform_pending" />
        <el-tab-pane label="二手待仲裁" name="second_hand_arbitration" />
        <el-tab-pane label="处理中" name="processing" />
        <el-tab-pane label="已结束" name="finished" />
        <el-tab-pane label="全部" name="all" />
      </el-tabs>
      <el-form :inline="true">
        <el-form-item label="关键词">
          <el-input
            v-model="query.keyword"
            clearable
            placeholder="编号 / 买家 / 卖家"
            style="width: 240px"
            @keyup.enter="load"
          />
        </el-form-item>
        <el-form-item label="售后状态">
          <el-select v-model="query.status" clearable placeholder="全部" style="width: 180px">
            <el-option
              v-for="(label, value) in statusText"
              :key="value"
              :label="label"
              :value="value"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="订单类型">
          <el-select v-model="query.orderType" clearable placeholder="全部" style="width: 140px">
            <el-option label="平台商城" value="normal" />
            <el-option label="二手交易" value="second_hand" />
          </el-select>
        </el-form-item>
        <el-form-item label="处理方">
          <el-select v-model="query.handlerType" clearable placeholder="全部" style="width: 130px">
            <el-option label="平台" value="platform" />
            <el-option label="卖家" value="seller" />
          </el-select>
        </el-form-item>
        <el-form-item label="超时状态">
          <el-select v-model="query.overdue" clearable placeholder="全部" style="width: 130px">
            <el-option label="已超时" value="true" />
            <el-option label="未超时" value="false" />
          </el-select>
        </el-form-item>
        <el-form-item label="创建时间">
          <el-date-picker v-model="createdRange" type="daterange" range-separator="至" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :icon="Search" @click="load">查询</el-button>
          <el-button :icon="Refresh" @click="reset">重置</el-button>
        </el-form-item>
      </el-form>
    </section>

    <section class="table-panel">
      <el-table v-loading="loading" :data="rows" border stripe>
        <el-table-column prop="afterSaleNo" label="售后编号" min-width="190" fixed="left" />
        <el-table-column prop="order.orderNo" label="订单号" min-width="190" />
        <el-table-column label="买家" width="130">
          <template #default="scope">{{ scope.row.buyer?.username || scope.row.buyerId }}</template>
        </el-table-column>
        <el-table-column label="卖家" width="130">
          <template #default="scope">{{
            scope.row.handlerType === 'platform'
              ? '平台'
              : scope.row.seller?.username || scope.row.sellerId
          }}</template>
        </el-table-column>
        <el-table-column label="商品" min-width="180">
          <template #default="scope">
            {{ scope.row.items?.[0]?.productName || '-' }}
            <span v-if="scope.row.items?.length > 1">等 {{ scope.row.items.length }} 项</span>
          </template>
        </el-table-column>
        <el-table-column label="处理方" width="90">
          <template #default="scope">
            <el-tag :type="scope.row.handlerType === 'platform' ? 'primary' : 'info'">
              {{ scope.row.handlerType === 'platform' ? '平台' : '卖家' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="140">
          <template #default="scope">
            <el-tag :type="statusType(scope.row.status)">{{ statusText[scope.row.status] }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="是否超时" width="100">
          <template #default="scope">
            <el-tag :type="scope.row.isOverdue ? 'danger' : 'info'">
              {{ scope.row.isOverdue ? '已超时' : '正常' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="创建时间" min-width="180" />
        <el-table-column prop="arbitrationAt" label="仲裁时间" min-width="180">
          <template #default="scope">{{ scope.row.arbitrationAt || '-' }}</template>
        </el-table-column>
        <el-table-column label="操作" width="92" fixed="right">
          <template #default="scope">
            <el-button
              type="primary"
              link
              :icon="View"
              @click="router.push(`/orders/after-sales/${scope.row.id}`)"
            >
              详情
            </el-button>
          </template>
        </el-table-column>
      </el-table>
      <el-pagination
        v-model:current-page="query.page"
        v-model:page-size="query.pageSize"
        :total="total"
        :page-sizes="[10, 20, 50, 100]"
        layout="total, sizes, prev, pager, next, jumper"
        @current-change="load"
        @size-change="load"
      />
    </section>
  </div>
</template>

<style scoped lang="scss">
.after-sale-list {
  padding: 16px;
}
.filter-panel {
  margin-bottom: 16px;
  padding: 16px 16px 0;
  background: #fff;
  border: 1px solid #ebeef5;
  border-radius: 6px;
}
.table-panel {
  padding: 16px;
  background: #fff;
  border: 1px solid #ebeef5;
  border-radius: 6px;
}
:deep(.el-pagination) {
  justify-content: flex-end;
  margin-top: 16px;
}
</style>
