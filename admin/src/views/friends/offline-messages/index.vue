<template>
  <ContentWrap>
    <div class="mb-10px">
      <ElButton type="primary" @click="handleRefresh">
        <Icon icon="ep:refresh" class="mr-5px" />
        刷新
      </ElButton>
    </div>

    <!-- 统计卡片 -->
    <ElRow :gutter="20" class="mb-20px">
      <ElCol :span="8">
        <ElCard shadow="hover">
          <div class="stat-card">
            <div class="stat-icon" style="background: #409eff">
              <Icon icon="ep:user" :size="32" color="#fff" />
            </div>
            <div class="stat-content">
              <div class="stat-value">{{ queueStatus.totalUsers }}</div>
              <div class="stat-label">离线用户数</div>
            </div>
          </div>
        </ElCard>
      </ElCol>
      <ElCol :span="8">
        <ElCard shadow="hover">
          <div class="stat-card">
            <div class="stat-icon" style="background: #67c23a">
              <Icon icon="ep:message" :size="32" color="#fff" />
            </div>
            <div class="stat-content">
              <div class="stat-value">{{ queueStatus.totalMessages }}</div>
              <div class="stat-label">离线消息总数</div>
            </div>
          </div>
        </ElCard>
      </ElCol>
      <ElCol :span="8">
        <ElCard shadow="hover">
          <div class="stat-card">
            <div class="stat-icon" style="background: #e6a23c">
              <Icon icon="ep:warning" :size="32" color="#fff" />
            </div>
            <div class="stat-content">
              <div class="stat-value">{{ avgMessagesPerUser }}</div>
              <div class="stat-label">平均每用户消息数</div>
            </div>
          </div>
        </ElCard>
      </ElCol>
    </ElRow>

    <!-- 离线消息队列详情表格 -->
    <ElCard shadow="never">
      <template #header>
        <div class="card-header">
          <span>离线消息队列详情</span>
        </div>
      </template>

      <ElTable :data="queueStatus.queueDetails" border stripe v-loading="loading">
        <ElTableColumn prop="userId" label="用户ID" width="100" />
        <ElTableColumn prop="userName" label="用户昵称" width="150">
          <template #default="{ row }">
            {{ row.userName || '-' }}
          </template>
        </ElTableColumn>
        <ElTableColumn prop="messageCount" label="离线消息数" width="120">
          <template #default="{ row }">
            <ElTag type="warning">{{ row.messageCount }}</ElTag>
          </template>
        </ElTableColumn>
        <ElTableColumn prop="oldestMessageTime" label="最早消息时间" width="180">
          <template #default="{ row }">
            {{ row.oldestMessageTime ? formatDate(new Date(row.oldestMessageTime)) : '-' }}
          </template>
        </ElTableColumn>
        <ElTableColumn prop="newestMessageTime" label="最新消息时间" width="180">
          <template #default="{ row }">
            {{ row.newestMessageTime ? formatDate(new Date(row.newestMessageTime)) : '-' }}
          </template>
        </ElTableColumn>
        <ElTableColumn label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <ElButton type="danger" size="small" @click="handleClearQueue(row.userId)">
              清空队列
            </ElButton>
          </template>
        </ElTableColumn>
      </ElTable>
    </ElCard>
  </ContentWrap>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { ContentWrap } from '@/components/ContentWrap'
import {
  ElRow,
  ElCol,
  ElCard,
  ElButton,
  ElTable,
  ElTableColumn,
  ElTag,
  ElMessage,
  ElMessageBox
} from 'element-plus'
import {
  getOfflineQueueStatusApi,
  clearUserOfflineQueueApi,
  type OfflineQueueStatus
} from '@/api-new/friends'
import { formatDate } from '@/utils/dateUtil'

/**
 * 加载状态
 */
const loading = ref(false)

/**
 * 离线消息队列状态
 */
const queueStatus = ref<OfflineQueueStatus>({
  totalUsers: 0,
  totalMessages: 0,
  queueDetails: []
})

/**
 * 计算平均每用户消息数
 */
const avgMessagesPerUser = computed(() => {
  if (queueStatus.value.totalUsers === 0) return 0
  return Math.round(queueStatus.value.totalMessages / queueStatus.value.totalUsers)
})

/**
 * 加载离线消息队列状态
 */
const loadQueueStatus = async () => {
  loading.value = true
  try {
    const res = await getOfflineQueueStatusApi()
    queueStatus.value = res.data || {
      totalUsers: 0,
      totalMessages: 0,
      queueDetails: []
    }
  } catch (error) {
    console.error('获取离线消息队列状态失败:', error)
    ElMessage.error('获取离线消息队列状态失败')
  } finally {
    loading.value = false
  }
}

/**
 * 刷新
 */
const handleRefresh = () => {
  loadQueueStatus()
}

/**
 * 清空指定用户的离线消息队列
 */
const handleClearQueue = async (userId: number) => {
  try {
    await ElMessageBox.confirm(
      `确定要清空用户 ${userId} 的离线消息队列吗？此操作不可恢复！`,
      '警告',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      }
    )

    await clearUserOfflineQueueApi(userId)
    ElMessage.success('清空离线消息队列成功')
    loadQueueStatus()
  } catch (error: any) {
    if (error !== 'cancel') {
      console.error('清空离线消息队列失败:', error)
      ElMessage.error(error.message || '清空离线消息队列失败')
    }
  }
}

/**
 * 组件挂载时加载数据
 */
onMounted(() => {
  loadQueueStatus()
})
</script>

<style scoped lang="less">
.stat-card {
  display: flex;
  align-items: center;
  gap: 20px;

  .stat-icon {
    width: 60px;
    height: 60px;
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .stat-content {
    flex: 1;

    .stat-value {
      font-size: 28px;
      font-weight: bold;
      color: #303133;
      margin-bottom: 5px;
    }

    .stat-label {
      font-size: 14px;
      color: #909399;
    }
  }
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>
