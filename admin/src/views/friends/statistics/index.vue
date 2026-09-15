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
      <ElCol :span="6">
        <ElCard shadow="hover">
          <div class="stat-card">
            <div class="stat-icon" style="background: #409eff">
              <Icon icon="ep:user" :size="32" color="#fff" />
            </div>
            <div class="stat-content">
              <div class="stat-value">{{ statistics.totalFriendships }}</div>
              <div class="stat-label">总好友对数</div>
            </div>
          </div>
        </ElCard>
      </ElCol>
      <ElCol :span="6">
        <ElCard shadow="hover">
          <div class="stat-card">
            <div class="stat-icon" style="background: #67c23a">
              <Icon icon="ep:plus" :size="32" color="#fff" />
            </div>
            <div class="stat-content">
              <div class="stat-value">{{ statistics.todayNewFriendships }}</div>
              <div class="stat-label">今日新增好友</div>
            </div>
          </div>
        </ElCard>
      </ElCol>
      <ElCol :span="6">
        <ElCard shadow="hover">
          <div class="stat-card">
            <div class="stat-icon" style="background: #e6a23c">
              <Icon icon="ep:message" :size="32" color="#fff" />
            </div>
            <div class="stat-content">
              <div class="stat-value">{{ statistics.totalMessages }}</div>
              <div class="stat-label">总消息数</div>
            </div>
          </div>
        </ElCard>
      </ElCol>
      <ElCol :span="6">
        <ElCard shadow="hover">
          <div class="stat-card">
            <div class="stat-icon" style="background: #f56c6c">
              <Icon icon="ep:bell" :size="32" color="#fff" />
            </div>
            <div class="stat-content">
              <div class="stat-value">{{ statistics.pendingRequests }}</div>
              <div class="stat-label">待处理申请</div>
            </div>
          </div>
        </ElCard>
      </ElCol>
    </ElRow>

    <ElRow :gutter="20" class="mb-20px">
      <ElCol :span="6">
        <ElCard shadow="hover">
          <div class="stat-card">
            <div class="stat-icon" style="background: #909399">
              <Icon icon="ep:chat-dot-round" :size="32" color="#fff" />
            </div>
            <div class="stat-content">
              <div class="stat-value">{{ statistics.todayMessages }}</div>
              <div class="stat-label">今日消息数</div>
            </div>
          </div>
        </ElCard>
      </ElCol>
      <ElCol :span="6">
        <ElCard shadow="hover">
          <div class="stat-card">
            <div class="stat-icon" style="background: #5470c6">
              <Icon icon="ep:user-filled" :size="32" color="#fff" />
            </div>
            <div class="stat-content">
              <div class="stat-value">{{ statistics.activeUsers }}</div>
              <div class="stat-label">7天活跃用户</div>
            </div>
          </div>
        </ElCard>
      </ElCol>
      <ElCol :span="6">
        <ElCard shadow="hover">
          <div class="stat-card">
            <div class="stat-icon" style="background: #91cc75">
              <Icon icon="ep:data-analysis" :size="32" color="#fff" />
            </div>
            <div class="stat-content">
              <div class="stat-value">{{ statistics.avgFriendsPerUser.toFixed(1) }}</div>
              <div class="stat-label">平均好友数</div>
            </div>
          </div>
        </ElCard>
      </ElCol>
      <ElCol :span="6">
        <ElCard shadow="hover">
          <div class="stat-card">
            <div class="stat-icon" style="background: #fac858">
              <Icon icon="ep:warning" :size="32" color="#fff" />
            </div>
            <div class="stat-content">
              <div class="stat-value">{{ statistics.offlineQueueSize }}</div>
              <div class="stat-label">离线消息队列</div>
            </div>
          </div>
        </ElCard>
      </ElCol>
    </ElRow>

    <!-- 消息类型分布饼图 -->
    <ElRow :gutter="20" class="mb-20px">
      <ElCol :span="12">
        <ElCard shadow="never">
          <template #header>
            <div class="card-header">
              <span>消息类型分布</span>
            </div>
          </template>
          <div ref="messageTypeChartRef" style="width: 100%; height: 300px"></div>
        </ElCard>
      </ElCol>

      <!-- 活跃用户趋势图 -->
      <ElCol :span="12">
        <ElCard shadow="never">
          <template #header>
            <div class="card-header">
              <span>近30天活跃用户趋势</span>
            </div>
          </template>
          <div ref="activeUserChartRef" style="width: 100%; height: 300px"></div>
        </ElCard>
      </ElCol>
    </ElRow>
  </ContentWrap>
</template>

<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount, nextTick } from 'vue'
import { ContentWrap } from '@/components/ContentWrap'
import { ElRow, ElCol, ElCard, ElButton, ElMessage } from 'element-plus'
import { getFriendsStatisticsApi, type FriendsStatistics } from '@/api-new/friends'
import * as echarts from 'echarts'

/**
 * 统计数据
 */
const statistics = ref<FriendsStatistics>({
  totalFriendships: 0,
  todayNewFriendships: 0,
  activeUsers: 0,
  totalMessages: 0,
  todayMessages: 0,
  pendingRequests: 0,
  offlineQueueSize: 0,
  avgFriendsPerUser: 0,
  messageStatsByType: {
    text: 0,
    image: 0,
    voice: 0
  },
  activeUserGrowth: []
})

/**
 * 图表引用
 */
const messageTypeChartRef = ref<HTMLDivElement>()
const activeUserChartRef = ref<HTMLDivElement>()

/**
 * 图表实例
 */
let messageTypeChart: echarts.ECharts | null = null
let activeUserChart: echarts.ECharts | null = null
let resizeHandler: (() => void) | null = null

/**
 * 加载统计数据
 */
const loadStatistics = async () => {
  try {
    const res = await getFriendsStatisticsApi()
    // 确保 activeUserGrowth 始终是数组
    const data = res.data || statistics.value
    statistics.value = {
      ...data,
      activeUserGrowth: data.activeUserGrowth || []
    }

    // 等待 DOM 更新后初始化图表
    await nextTick()
    initCharts()
  } catch (error) {
    console.error('获取统计数据失败:', error)
    ElMessage.error('获取统计数据失败')
  }
}

/**
 * 初始化图表
 */
const initCharts = () => {
  initMessageTypeChart()
  initActiveUserChart()
}

/**
 * 初始化消息类型分布饼图
 */
const initMessageTypeChart = () => {
  if (!messageTypeChartRef.value) return

  // 销毁旧图表
  if (messageTypeChart) {
    messageTypeChart.dispose()
  }

  messageTypeChart = echarts.init(messageTypeChartRef.value)

  const option = {
    tooltip: {
      trigger: 'item',
      formatter: '{a} <br/>{b}: {c} ({d}%)'
    },
    legend: {
      orient: 'vertical',
      left: 'left'
    },
    series: [
      {
        name: '消息类型',
        type: 'pie',
        radius: '50%',
        data: [
          { value: statistics.value.messageStatsByType.text, name: '文字消息' },
          { value: statistics.value.messageStatsByType.image, name: '图片消息' },
          { value: statistics.value.messageStatsByType.voice, name: '语音消息' }
        ],
        emphasis: {
          itemStyle: {
            shadowBlur: 10,
            shadowOffsetX: 0,
            shadowColor: 'rgba(0, 0, 0, 0.5)'
          }
        }
      }
    ]
  }

  messageTypeChart.setOption(option)
}

/**
 * 初始化活跃用户趋势图
 */
const initActiveUserChart = () => {
  if (!activeUserChartRef.value) return

  // 销毁旧图表
  if (activeUserChart) {
    activeUserChart.dispose()
  }

  activeUserChart = echarts.init(activeUserChartRef.value)

  // 确保 activeUserGrowth 是数组
  const growthData = statistics.value.activeUserGrowth || []
  const dates = growthData.map((item) => item.date)
  const counts = growthData.map((item) => item.count)

  const option = {
    tooltip: {
      trigger: 'axis'
    },
    xAxis: {
      type: 'category',
      data: dates,
      axisLabel: {
        rotate: 45
      }
    },
    yAxis: {
      type: 'value',
      name: '活跃用户数'
    },
    series: [
      {
        name: '活跃用户',
        type: 'line',
        data: counts,
        smooth: true,
        areaStyle: {
          color: 'rgba(64, 158, 255, 0.2)'
        },
        itemStyle: {
          color: '#409eff'
        }
      }
    ]
  }

  activeUserChart.setOption(option)
}

/**
 * 刷新
 */
const handleRefresh = () => {
  loadStatistics()
}

/**
 * 组件挂载时加载数据
 */
onMounted(() => {
  loadStatistics()

  // 监听窗口大小变化，重新调整图表大小
  resizeHandler = () => {
    messageTypeChart?.resize()
    activeUserChart?.resize()
  }
  window.addEventListener('resize', resizeHandler)
})

onBeforeUnmount(() => {
  if (resizeHandler) {
    window.removeEventListener('resize', resizeHandler)
    resizeHandler = null
  }

  messageTypeChart?.dispose()
  activeUserChart?.dispose()
  messageTypeChart = null
  activeUserChart = null
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
