<script setup lang="tsx">
import { ref, watch } from 'vue'
import { ElTag } from 'element-plus'
import { getUserWalletTransactionsApi } from '@/api-new/wallet/wallet'
import type { WalletTransaction } from '@/api-new/wallet/types'
import { extractWalletTransactionsResult } from '../userList.helpers'

interface Props {
  userId: number
}

const props = defineProps<Props>()

const transactions = ref<WalletTransaction[]>([])
const loading = ref(false)
const currentPage = ref(1)
const pageSize = ref(10)
const total = ref(0)

/**
 * 交易状态配置
 */
const STATUS_CONFIG = {
  pending: { label: '待审核', type: 'warning' as const },
  approved: { label: '已审核', type: 'success' as const },
  rejected: { label: '已拒绝', type: 'danger' as const }
}

/**
 * 交易类型配置
 */
const TYPE_CONFIG = {
  income: { label: '收入', color: '#10b981' },
  expense: { label: '支出', color: '#ef4444' },
  freeze: { label: '冻结', color: '#f59e0b' },
  unfreeze: { label: '解冻', color: '#3b82f6' }
}

/**
 * 加载钱包明细
 */
const loadTransactions = async () => {
  try {
    loading.value = true
    const res = await getUserWalletTransactionsApi(props.userId, {
      page: currentPage.value,
      limit: pageSize.value
    })
    const { list, total: nextTotal } = extractWalletTransactionsResult(res)
    transactions.value = list
    total.value = nextTotal
  } catch (error) {
    console.error('加载钱包明细失败:', error)
  } finally {
    loading.value = false
  }
}

/**
 * 刷新列表
 */
const handleRefresh = () => {
  currentPage.value = 1
  loadTransactions()
}

/**
 * 格式化金额
 */
const formatAmount = (amount: number) => {
  return `¥${Number(amount).toFixed(2)}`
}

/**
 * 格式化时间
 */
const formatTime = (timeString: string) => {
  return new Date(timeString).toLocaleString('zh-CN')
}

// 监听 userId 变化
watch(
  () => props.userId,
  () => {
    handleRefresh()
  },
  { immediate: true }
)
</script>

<template>
  <div class="wallet-detail-list">
    <!-- 筛选栏 -->
    <div class="filter-bar">
      <el-button type="primary" size="small" @click="handleRefresh" :loading="loading">
        刷新
      </el-button>
      <span class="total-count">共 {{ total }} 条记录</span>
    </div>

    <!-- 列表 -->
    <div v-loading="loading" class="transaction-list">
      <div v-if="transactions.length === 0" class="empty-state">
        <p>暂无交易记录</p>
      </div>

      <div v-for="transaction in transactions" :key="transaction.id" class="transaction-item">
        <div class="transaction-left">
          <div class="transaction-type">
            <span class="type-label">{{ TYPE_CONFIG[transaction.type]?.label }}</span>
            <span class="type-amount" :style="{ color: TYPE_CONFIG[transaction.type]?.color }">
              {{ transaction.type === 'income' ? '+' : '-' }}{{ formatAmount(transaction.amount) }}
            </span>
          </div>
          <div class="transaction-time">{{ formatTime(transaction.createdAt) }}</div>
          <div v-if="transaction.remark" class="transaction-remark">{{ transaction.remark }}</div>
        </div>

        <div class="transaction-right">
          <ElTag :type="STATUS_CONFIG[transaction.status]?.type" size="small">
            {{ STATUS_CONFIG[transaction.status]?.label }}
          </ElTag>
        </div>
      </div>
    </div>

    <!-- 分页 -->
    <div v-if="total > 0" class="pagination-bar">
      <el-pagination
        v-model:current-page="currentPage"
        v-model:page-size="pageSize"
        :total="total"
        :page-sizes="[10, 20, 50]"
        layout="total, sizes, prev, pager, next"
        @current-change="loadTransactions"
        @size-change="handleRefresh"
      />
    </div>
  </div>
</template>

<style scoped>
.wallet-detail-list {
  padding: 0;
}

.filter-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  padding-bottom: 12px;
  border-bottom: 1px solid #eee;
}

.total-count {
  font-size: 14px;
  color: #666;
}

.transaction-list {
  min-height: 200px;
}

.empty-state {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 200px;
  color: #999;
}

.transaction-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px;
  margin-bottom: 12px;
  background-color: #f9f9f9;
  border-radius: 8px;
  transition: all 0.2s;
}

.transaction-item:hover {
  background-color: #f0f0f0;
}

.transaction-left {
  flex: 1;
}

.transaction-type {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 8px;
}

.type-label {
  font-size: 14px;
  color: #333;
  font-weight: 500;
}

.type-amount {
  font-size: 16px;
  font-weight: bold;
}

.transaction-time {
  font-size: 12px;
  color: #999;
  margin-bottom: 4px;
}

.transaction-remark {
  font-size: 13px;
  color: #666;
}

.transaction-right {
  flex-shrink: 0;
}

.pagination-bar {
  display: flex;
  justify-content: center;
  margin-top: 20px;
  padding-top: 16px;
  border-top: 1px solid #eee;
}
</style>
