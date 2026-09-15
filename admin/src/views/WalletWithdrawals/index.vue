<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  ElAlert,
  ElButton,
  ElDatePicker,
  ElDescriptions,
  ElDescriptionsItem,
  ElDialog,
  ElForm,
  ElFormItem,
  ElInput,
  ElMessage,
  ElMessageBox,
  ElOption,
  ElPagination,
  ElSelect,
  ElSwitch,
  ElTable,
  ElTableColumn,
  ElTag
} from 'element-plus'
import { Refresh, Search, Setting } from '@element-plus/icons-vue'
import { ContentWrap } from '@/components/ContentWrap'
import { extractPagedTableData } from '@/utils/pagination'
import {
  approveWalletWithdrawal,
  getWalletWithdrawalConfig,
  getWalletWithdrawalDetail,
  getWalletWithdrawals,
  reconcileWalletWithdrawal,
  rejectWalletWithdrawal,
  updateWalletWithdrawalConfig,
  type UpdateWalletWithdrawalConfigParams,
  type WalletWithdrawal,
  type WalletWithdrawalConfig,
  type WalletWithdrawalStatus
} from '@/api-new/wallet-withdrawals'

defineOptions({ name: 'WalletWithdrawals' })

const STATUS_CONFIG: Record<
  WalletWithdrawalStatus,
  { label: string; type: 'warning' | 'primary' | 'success' | 'danger' | 'info' }
> = {
  pending_review: { label: '待审核', type: 'warning' },
  processing: { label: '转账中', type: 'primary' },
  succeeded: { label: '已到账', type: 'success' },
  rejected: { label: '已拒绝', type: 'info' },
  failed: { label: '转账失败', type: 'danger' }
}

const route = useRoute()
const router = useRouter()
const loading = ref(false)
const actionId = ref<number | null>(null)
const rows = ref<WalletWithdrawal[]>([])
const total = ref(0)
const filters = reactive({
  page: 1,
  limit: 20,
  withdrawalNo: '',
  userId: undefined as number | undefined,
  phone: '',
  status: '' as WalletWithdrawalStatus | '',
  dateRange: '' as '' | [Date, Date]
})

const detailVisible = ref(false)
const detailLoading = ref(false)
const detail = ref<WalletWithdrawal | null>(null)
const configVisible = ref(false)
const configLoading = ref(false)
const config = ref<WalletWithdrawalConfig | null>(null)
const configForm = reactive<UpdateWalletWithdrawalConfigParams>({
  businessEnabled: false,
  minAmount: '1.00',
  maxAmountPerRequest: '50000.00',
  maxAmountPerDay: '50000.00'
})

const canEnableBusiness = computed(() =>
  Boolean(config.value?.transferConfigured && config.value?.piiEncryptionConfigured)
)

const formatAmount = (amount: number) => `¥${Number(amount || 0).toFixed(2)}`
const formatDateTime = (value?: string | null) => {
  if (!value) return '-'
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? '-' : date.toLocaleString('zh-CN')
}

const statusConfig = (status: WalletWithdrawalStatus) => STATUS_CONFIG[status]

const loadList = async () => {
  loading.value = true
  try {
    const [startDate, endDate] = Array.isArray(filters.dateRange) ? filters.dateRange : []
    const response = await getWalletWithdrawals({
      page: filters.page,
      limit: filters.limit,
      withdrawalNo: filters.withdrawalNo || undefined,
      userId: filters.userId,
      phone: filters.phone || undefined,
      status: filters.status || undefined,
      startDate: startDate?.toISOString(),
      endDate: endDate
        ? new Date(
            endDate.getFullYear(),
            endDate.getMonth(),
            endDate.getDate(),
            23,
            59,
            59,
            999
          ).toISOString()
        : undefined
    })
    const pageData = extractPagedTableData<WalletWithdrawal>(response)
    rows.value = pageData.list
    total.value = pageData.total
  } finally {
    loading.value = false
  }
}

const search = () => {
  filters.page = 1
  loadList()
}

const resetFilters = () => {
  filters.withdrawalNo = ''
  filters.userId = undefined
  filters.phone = ''
  filters.status = ''
  filters.dateRange = ''
  search()
}

const openDetail = async (id: number) => {
  detailVisible.value = true
  detailLoading.value = true
  try {
    const response = await getWalletWithdrawalDetail({ id })
    detail.value = response.data || null
  } finally {
    detailLoading.value = false
  }
}

const approve = async (row: WalletWithdrawal) => {
  try {
    await ElMessageBox.confirm(
      `确认向 ${row.payeeAccountMasked}（${row.payeeNameMasked}）转账 ${formatAmount(row.amount)}？该操作会立即发起真实支付宝转账。`,
      '审核通过并转账',
      {
        confirmButtonText: '确认并发起转账',
        cancelButtonText: '取消',
        type: 'warning'
      }
    )
    actionId.value = row.id
    const response = await approveWalletWithdrawal({ id: row.id })
    const result = response.data
    ElMessage.success(
      result?.status === 'succeeded' ? '支付宝转账成功' : '已发起转账，等待结果确认'
    )
    await loadList()
  } catch (error) {
    if (error !== 'cancel' && error !== 'close') throw error
  } finally {
    actionId.value = null
  }
}

const reject = async (row: WalletWithdrawal) => {
  try {
    const { value } = await ElMessageBox.prompt(
      '拒绝后资金将完整退回用户可提现余额。',
      '拒绝提现',
      {
        confirmButtonText: '确认拒绝',
        cancelButtonText: '取消',
        inputPlaceholder: '请输入拒绝原因',
        inputValidator: (value) => {
          const length = value.trim().length
          return length >= 2 && length <= 500
        },
        inputErrorMessage: '请输入 2 至 500 个字符的拒绝原因'
      }
    )
    actionId.value = row.id
    await rejectWalletWithdrawal({ id: row.id, reason: value.trim() })
    ElMessage.success('已拒绝，资金已退回')
    await loadList()
  } catch (error) {
    if (error !== 'cancel' && error !== 'close') throw error
  } finally {
    actionId.value = null
  }
}

const reconcile = async (row: WalletWithdrawal) => {
  actionId.value = row.id
  try {
    const response = await reconcileWalletWithdrawal({ id: row.id })
    const result = response.data
    ElMessage.success(result?.status === 'processing' ? '支付宝结果仍待确认' : '提现状态已更新')
    await loadList()
  } finally {
    actionId.value = null
  }
}

const openConfig = async () => {
  configVisible.value = true
  configLoading.value = true
  try {
    const response = await getWalletWithdrawalConfig({})
    config.value = response.data || null
    if (config.value) {
      configForm.businessEnabled = config.value.businessEnabled
      configForm.minAmount = Number(config.value.minAmount).toFixed(2)
      configForm.maxAmountPerRequest = Number(config.value.maxAmountPerRequest).toFixed(2)
      configForm.maxAmountPerDay = Number(config.value.maxAmountPerDay).toFixed(2)
    }
  } finally {
    configLoading.value = false
  }
}

const saveConfig = async () => {
  const amountPattern = /^(?:0\.(?:0[1-9]|[1-9]\d?)|[1-9]\d{0,7}(?:\.\d{1,2})?)$/
  const amounts = [configForm.minAmount, configForm.maxAmountPerRequest, configForm.maxAmountPerDay]
  if (!amounts.every((value) => amountPattern.test(value))) {
    ElMessage.warning('金额必须大于 0，且最多保留两位小数')
    return
  }
  if (
    Number(configForm.maxAmountPerRequest) < Number(configForm.minAmount) ||
    Number(configForm.maxAmountPerDay) < Number(configForm.minAmount)
  ) {
    ElMessage.warning('单笔和单日上限不能低于最低提现金额')
    return
  }
  configLoading.value = true
  try {
    const response = await updateWalletWithdrawalConfig({ ...configForm })
    config.value = response.data || null
    configVisible.value = false
    ElMessage.success('提现规则已更新')
  } finally {
    configLoading.value = false
  }
}

const handlePageChange = (page: number) => {
  filters.page = page
  loadList()
}

const handleSizeChange = (limit: number) => {
  filters.limit = limit
  filters.page = 1
  loadList()
}

onMounted(async () => {
  await loadList()
  const queryId = Number(
    Array.isArray(route.query.withdrawalId) ? route.query.withdrawalId[0] : route.query.withdrawalId
  )
  if (Number.isInteger(queryId) && queryId > 0) {
    await openDetail(queryId)
    await router.replace({ query: { ...route.query, withdrawalId: undefined } })
  }
})
</script>

<template>
  <ContentWrap>
    <ElForm inline class="withdrawal-filters" @submit.prevent="search">
      <ElFormItem label="提现单号">
        <ElInput v-model="filters.withdrawalNo" clearable placeholder="请输入提现单号" />
      </ElFormItem>
      <ElFormItem label="用户ID">
        <ElInput v-model.number="filters.userId" clearable placeholder="请输入用户ID" />
      </ElFormItem>
      <ElFormItem label="手机号">
        <ElInput v-model="filters.phone" clearable placeholder="请输入手机号" />
      </ElFormItem>
      <ElFormItem label="状态">
        <ElSelect v-model="filters.status" clearable placeholder="全部状态" style="width: 140px">
          <ElOption
            v-for="(item, key) in STATUS_CONFIG"
            :key="key"
            :label="item.label"
            :value="key"
          />
        </ElSelect>
      </ElFormItem>
      <ElFormItem label="申请时间">
        <ElDatePicker
          v-model="filters.dateRange"
          type="daterange"
          start-placeholder="开始日期"
          end-placeholder="结束日期"
        />
      </ElFormItem>
      <ElFormItem>
        <ElButton type="primary" :icon="Search" @click="search">查询</ElButton>
        <ElButton :icon="Refresh" @click="resetFilters">重置</ElButton>
        <ElButton :icon="Setting" @click="openConfig">提现规则</ElButton>
      </ElFormItem>
    </ElForm>

    <ElTable :data="rows" :loading="loading" row-key="id" border>
      <ElTableColumn prop="withdrawalNo" label="提现单号" min-width="210" />
      <ElTableColumn label="用户" width="150">
        <template #default="{ row }">{{ row.user?.phone || row.user?.username || '-' }}</template>
      </ElTableColumn>
      <ElTableColumn label="金额" width="120">
        <template #default="{ row }"
          ><strong>{{ formatAmount(row.amount) }}</strong></template
        >
      </ElTableColumn>
      <ElTableColumn label="收款信息" min-width="190">
        <template #default="{ row }"
          >{{ row.payeeAccountMasked }} / {{ row.payeeNameMasked }}</template
        >
      </ElTableColumn>
      <ElTableColumn label="状态" width="100">
        <template #default="{ row }"
          ><ElTag :type="statusConfig(row.status).type">{{
            statusConfig(row.status).label
          }}</ElTag></template
        >
      </ElTableColumn>
      <ElTableColumn prop="reviewedBy" label="审核人ID" width="100" />
      <ElTableColumn prop="outBizNo" label="外部业务单号" min-width="220" show-overflow-tooltip />
      <ElTableColumn label="申请时间" width="180">
        <template #default="{ row }">{{ formatDateTime(row.createdAt) }}</template>
      </ElTableColumn>
      <ElTableColumn label="完成时间" width="180">
        <template #default="{ row }">{{ formatDateTime(row.completedAt) }}</template>
      </ElTableColumn>
      <ElTableColumn label="操作" fixed="right" width="270">
        <template #default="{ row }">
          <ElButton link type="primary" @click="openDetail(row.id)">详情</ElButton>
          <template v-if="row.status === 'pending_review'">
            <ElButton link type="success" :loading="actionId === row.id" @click="approve(row)"
              >审核通过</ElButton
            >
            <ElButton link type="danger" :loading="actionId === row.id" @click="reject(row)"
              >拒绝</ElButton
            >
          </template>
          <ElButton
            v-else-if="row.status === 'processing'"
            link
            type="warning"
            :loading="actionId === row.id"
            @click="reconcile(row)"
            >查询状态</ElButton
          >
        </template>
      </ElTableColumn>
    </ElTable>

    <ElPagination
      class="withdrawal-pagination"
      :current-page="filters.page"
      :page-size="filters.limit"
      :page-sizes="[10, 20, 50, 100]"
      :total="total"
      layout="total, sizes, prev, pager, next, jumper"
      @current-change="handlePageChange"
      @size-change="handleSizeChange"
    />
  </ContentWrap>

  <ElDialog v-model="detailVisible" title="提现详情" width="820px">
    <ElDescriptions v-loading="detailLoading" :column="2" border>
      <template v-if="detail">
        <ElDescriptionsItem label="提现单号">{{ detail.withdrawalNo }}</ElDescriptionsItem>
        <ElDescriptionsItem label="状态"
          ><ElTag :type="statusConfig(detail.status).type">{{
            statusConfig(detail.status).label
          }}</ElTag></ElDescriptionsItem
        >
        <ElDescriptionsItem label="申请金额">{{ formatAmount(detail.amount) }}</ElDescriptionsItem>
        <ElDescriptionsItem label="用户">{{
          detail.user?.phone || detail.user?.username || '-'
        }}</ElDescriptionsItem>
        <ElDescriptionsItem label="支付宝账号">{{ detail.payeeAccountMasked }}</ElDescriptionsItem>
        <ElDescriptionsItem label="实名姓名">{{ detail.payeeNameMasked }}</ElDescriptionsItem>
        <ElDescriptionsItem label="外部业务单号">{{ detail.outBizNo || '-' }}</ElDescriptionsItem>
        <ElDescriptionsItem label="支付宝资金单号">{{
          detail.payFundOrderId || '-'
        }}</ElDescriptionsItem>
        <ElDescriptionsItem label="申请时间">{{
          formatDateTime(detail.createdAt)
        }}</ElDescriptionsItem>
        <ElDescriptionsItem label="审核时间">{{
          formatDateTime(detail.reviewedAt)
        }}</ElDescriptionsItem>
        <ElDescriptionsItem label="完成时间">{{
          formatDateTime(detail.completedAt)
        }}</ElDescriptionsItem>
        <ElDescriptionsItem label="审核人ID">{{ detail.reviewedBy || '-' }}</ElDescriptionsItem>
        <ElDescriptionsItem v-if="detail.rejectReason" label="拒绝原因" :span="2">{{
          detail.rejectReason
        }}</ElDescriptionsItem>
        <ElDescriptionsItem v-if="detail.failureMessage" label="失败原因" :span="2">{{
          detail.failureMessage
        }}</ElDescriptionsItem>
      </template>
    </ElDescriptions>
  </ElDialog>

  <ElDialog v-model="configVisible" title="支付宝提现规则" width="600px">
    <ElAlert
      v-if="config?.unavailableReason"
      :title="config.unavailableReason"
      type="warning"
      :closable="false"
      show-icon
      class="config-alert"
    />
    <ElForm label-width="150px" v-loading="configLoading">
      <ElFormItem label="业务开关">
        <ElSwitch
          v-model="configForm.businessEnabled"
          :disabled="!canEnableBusiness && !configForm.businessEnabled"
        />
      </ElFormItem>
      <ElFormItem label="转账配置状态"
        ><ElTag :type="config?.transferConfigured ? 'success' : 'danger'">{{
          config?.transferConfigured ? '已配置' : '未配置'
        }}</ElTag></ElFormItem
      >
      <ElFormItem label="隐私加密状态"
        ><ElTag :type="config?.piiEncryptionConfigured ? 'success' : 'danger'">{{
          config?.piiEncryptionConfigured ? '已配置' : '未配置'
        }}</ElTag></ElFormItem
      >
      <ElFormItem label="最低提现金额"
        ><ElInput v-model="configForm.minAmount" inputmode="decimal"
          ><template #prepend>¥</template></ElInput
        ></ElFormItem
      >
      <ElFormItem label="单笔提现上限"
        ><ElInput v-model="configForm.maxAmountPerRequest" inputmode="decimal"
          ><template #prepend>¥</template></ElInput
        ></ElFormItem
      >
      <ElFormItem label="单日提现上限"
        ><ElInput v-model="configForm.maxAmountPerDay" inputmode="decimal"
          ><template #prepend>¥</template></ElInput
        ></ElFormItem
      >
    </ElForm>
    <template #footer>
      <ElButton @click="configVisible = false">取消</ElButton>
      <ElButton type="primary" :loading="configLoading" @click="saveConfig">保存</ElButton>
    </template>
  </ElDialog>
</template>

<style scoped>
.withdrawal-filters :deep(.el-input) {
  width: 180px;
}

.withdrawal-pagination {
  display: flex;
  justify-content: flex-end;
  margin-top: 16px;
}

.config-alert {
  margin-bottom: 18px;
}

@media (max-width: 760px) {
  .withdrawal-filters {
    display: grid;
  }

  .withdrawal-pagination {
    justify-content: flex-start;
    overflow-x: auto;
  }
}
</style>
