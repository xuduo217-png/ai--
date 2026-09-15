<template>
  <div class="home-container">
    <!-- 欢迎横幅 -->
    <ElCard shadow="never" class="welcome-card">
      <ElRow :gutter="20" justify="space-between" align="middle">
        <ElCol :xl="12" :lg="12" :md="12" :sm="24" :xs="24">
          <div class="flex items-center">
            <div class="welcome-icon">
              <Icon icon="vi-mdi:home" :size="40" />
            </div>
            <div class="ml-20px">
              <div class="text-24px font-bold text-gray-800">
                {{ getGreeting() }}，{{ currentUser.username || '管理员' }}
              </div>
              <div class="mt-8px text-14px text-gray-500">
                欢迎使用宠物医院管理系统，祝您工作顺利！
              </div>
            </div>
          </div>
        </ElCol>
        <ElCol :xl="12" :lg="12" :md="12" :sm="24" :xs="24">
          <div class="flex h-full items-center justify-end lt-sm:mt-20px">
            <div class="text-right">
              <div class="text-12px text-gray-400">{{ getCurrentDate() }}</div>
              <div class="text-14px text-gray-600 mt-4px">{{ getCurrentTime() }}</div>
            </div>
          </div>
        </ElCol>
      </ElRow>
    </ElCard>

    <!-- 统计卡片 -->
    <ElRow :gutter="20" class="mt-20px">
      <ElCol :xl="6" :lg="6" :md="12" :sm="24" :xs="24" class="mb-20px">
        <ElSkeleton :loading="statsLoading" animated>
          <template #template>
            <ElCard shadow="hover">
              <div class="stat-content">
                <div class="stat-icon hospitals-icon">
                  <div class="skeleton-icon"></div>
                </div>
                <div class="stat-info">
                  <ElSkeletonItem
                    variant="text"
                    style="width: 80px; height: 32px; margin-bottom: 8px"
                  />
                  <ElSkeletonItem variant="text" style="width: 60px; height: 14px" />
                </div>
              </div>
            </ElCard>
          </template>
          <template #default>
            <ElCard shadow="hover" class="stat-card stat-card-hospitals">
              <div class="stat-content">
                <div class="stat-icon hospitals-icon">
                  <Icon icon="vi-mdi:hospital-building" :size="32" />
                </div>
                <div class="stat-info">
                  <div class="stat-value">
                    <CountTo :start-val="0" :end-val="stats.hospitals" :duration="1000" />
                  </div>
                  <div class="stat-label">合作医院</div>
                </div>
              </div>
            </ElCard>
          </template>
        </ElSkeleton>
      </ElCol>

      <ElCol :xl="6" :lg="6" :md="12" :sm="24" :xs="24" class="mb-20px">
        <ElSkeleton :loading="statsLoading" animated>
          <template #template>
            <ElCard shadow="hover">
              <div class="stat-content">
                <div class="stat-icon doctors-icon">
                  <div class="skeleton-icon"></div>
                </div>
                <div class="stat-info">
                  <ElSkeletonItem
                    variant="text"
                    style="width: 80px; height: 32px; margin-bottom: 8px"
                  />
                  <ElSkeletonItem variant="text" style="width: 60px; height: 14px" />
                </div>
              </div>
            </ElCard>
          </template>
          <template #default>
            <ElCard shadow="hover" class="stat-card stat-card-doctors">
              <div class="stat-content">
                <div class="stat-icon doctors-icon">
                  <Icon icon="vi-mdi:doctor" :size="32" />
                </div>
                <div class="stat-info">
                  <div class="stat-value">
                    <CountTo :start-val="0" :end-val="stats.doctors" :duration="1000" />
                  </div>
                  <div class="stat-label">在职医生</div>
                </div>
              </div>
            </ElCard>
          </template>
        </ElSkeleton>
      </ElCol>

      <ElCol :xl="6" :lg="6" :md="12" :sm="24" :xs="24" class="mb-20px">
        <ElSkeleton :loading="statsLoading" animated>
          <template #template>
            <ElCard shadow="hover">
              <div class="stat-content">
                <div class="stat-icon users-icon">
                  <div class="skeleton-icon"></div>
                </div>
                <div class="stat-info">
                  <ElSkeletonItem
                    variant="text"
                    style="width: 80px; height: 32px; margin-bottom: 8px"
                  />
                  <ElSkeletonItem variant="text" style="width: 60px; height: 14px" />
                </div>
              </div>
            </ElCard>
          </template>
          <template #default>
            <ElCard shadow="hover" class="stat-card stat-card-users">
              <div class="stat-content">
                <div class="stat-icon users-icon">
                  <Icon icon="vi-mdi:account-multiple" :size="32" />
                </div>
                <div class="stat-info">
                  <div class="stat-value">
                    <CountTo :start-val="0" :end-val="stats.users" :duration="1000" />
                  </div>
                  <div class="stat-label">注册用户</div>
                </div>
              </div>
            </ElCard>
          </template>
        </ElSkeleton>
      </ElCol>

      <ElCol :xl="6" :lg="6" :md="12" :sm="24" :xs="24" class="mb-20px">
        <ElSkeleton :loading="statsLoading" animated>
          <template #template>
            <ElCard shadow="hover">
              <div class="stat-content">
                <div class="stat-icon pets-icon">
                  <div class="skeleton-icon"></div>
                </div>
                <div class="stat-info">
                  <ElSkeletonItem
                    variant="text"
                    style="width: 80px; height: 32px; margin-bottom: 8px"
                  />
                  <ElSkeletonItem variant="text" style="width: 60px; height: 14px" />
                </div>
              </div>
            </ElCard>
          </template>
          <template #default>
            <ElCard shadow="hover" class="stat-card stat-card-pets">
              <div class="stat-content">
                <div class="stat-icon pets-icon">
                  <Icon icon="vi-mdi:paw" :size="32" />
                </div>
                <div class="stat-info">
                  <div class="stat-value">
                    <CountTo :start-val="0" :end-val="stats.pets" :duration="1000" />
                  </div>
                  <div class="stat-label">宠物档案</div>
                </div>
              </div>
            </ElCard>
          </template>
        </ElSkeleton>
      </ElCol>
    </ElRow>

    <!-- 快捷操作 -->
    <ElRow :gutter="20" class="mt-20px">
      <ElCol :span="24">
        <ElCard shadow="never">
          <template #header>
            <div class="flex items-center justify-between">
              <span class="text-16px font-semibold">快捷操作</span>
            </div>
          </template>
          <ElRow :gutter="16">
            <ElCol
              v-for="(operation, index) in quickOperations"
              :key="`operation-${index}`"
              :xl="4"
              :lg="6"
              :md="8"
              :sm="12"
              :xs="24"
              class="mb-16px"
            >
              <div class="operation-item" @click="handleOperation(operation.path)">
                <div class="operation-icon" :class="`operation-icon-${operation.color}`">
                  <Icon :icon="operation.icon" :size="24" />
                </div>
                <div class="operation-label">{{ operation.label }}</div>
              </div>
            </ElCol>
          </ElRow>
        </ElCard>
      </ElCol>
    </ElRow>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/store/modules/user'
import { ElCard, ElRow, ElCol, ElSkeleton, ElSkeletonItem } from 'element-plus'
import { CountTo } from '@/components/CountTo'
import { getDashboardStatsApi } from '@/api-new/statistics'

/**
 * 首页组件
 * 登录后的默认页面，显示欢迎信息和系统概览
 */

const router = useRouter()
const userStore = useUserStore()

// 当前用户信息
const currentUser = ref({
  username: userStore.getUserInfo?.username || '管理员'
})

// 当前时间
const currentTime = ref('')
let timeInterval: NodeJS.Timeout | null = null

/**
 * 统计数据
 * 从后端 API 获取真实数据
 */
const stats = reactive({
  hospitals: 0,
  doctors: 0,
  users: 0,
  pets: 0
})

// 加载状态
const statsLoading = ref(true)

/**
 * 获取统计数据
 */
const fetchStats = async () => {
  try {
    statsLoading.value = true
    const res = await getDashboardStatsApi()

    if (res?.data) {
      Object.assign(stats, res.data)
    }
  } catch (error) {
    console.error('获取统计数据失败:', error)
    // 失败时使用默认值，避免页面显示异常
    Object.assign(stats, {
      hospitals: 0,
      doctors: 0,
      users: 0,
      pets: 0
    })
  } finally {
    statsLoading.value = false
  }
}

/**
 * 快捷操作列表
 * 根据项目实际路由配置，选择最常用的功能入口
 */
const quickOperations = ref([
  // 基础数据管理
  {
    label: '医院列表',
    icon: 'vi-mdi:hospital-building',
    path: '/hospitals/list',
    color: 'primary',
    description: '管理合作医院信息'
  },
  {
    label: '医生列表',
    icon: 'vi-mdi:doctor',
    path: '/hospitals/doctors/list',
    color: 'success',
    description: '管理医生资料信息'
  },
  {
    label: '用户列表',
    icon: 'vi-mdi:account-multiple',
    path: '/users/list',
    color: 'warning',
    description: '查看平台注册用户'
  },
  // 核心业务
  {
    label: '宠物档案',
    icon: 'vi-mdi:paw',
    path: '/pets/list',
    color: 'danger',
    description: '管理宠物健康档案'
  },
  {
    label: '预约管理',
    icon: 'vi-mdi:calendar-clock',
    path: '/pets/appointments',
    color: 'info',
    description: '查看预约信息'
  },
  {
    label: '聊天记录',
    icon: 'vi-mdi:chat-processing',
    path: '/online-service/chat-records',
    color: 'primary',
    description: '查看医生问诊记录'
  },
  // AI 和在线服务
  {
    label: 'AI 问诊报告',
    icon: 'vi-mdi:robot',
    path: '/ai-consultation/diagnosis-reports',
    color: 'success',
    description: '查看 AI 问诊报告'
  },
  {
    label: '自查表管理',
    icon: 'vi-mdi:clipboard-list',
    path: '/ai-consultation/self-check-lists',
    color: 'warning',
    description: '管理自查表问题'
  },
  // 内容管理
  {
    label: '商品管理',
    icon: 'vi-ant-design:shopping-cart-outlined',
    path: '/product/index',
    color: 'danger',
    description: '管理商城商品'
  },
  {
    label: '健康文章',
    icon: 'vi-mdi:book-open-page-variant',
    path: '/health-articles/list',
    color: 'info',
    description: '发布健康知识'
  },
  {
    label: '急救指南',
    icon: 'vi-ant-design:medicine-box-outlined',
    path: '/aid-guides/categories',
    color: 'primary',
    description: '管理急救指南'
  },
  {
    label: '系统配置',
    icon: 'vi-mdi:cog',
    path: '/system-configs/system-configs',
    color: 'warning',
    description: '系统参数配置'
  }
])

/**
 * 获取问候语
 * 根据当前时间返回不同的问候语
 */
const getGreeting = () => {
  const hour = new Date().getHours()
  if (hour < 6) return '夜深了'
  if (hour < 9) return '早上好'
  if (hour < 12) return '上午好'
  if (hour < 14) return '中午好'
  if (hour < 18) return '下午好'
  if (hour < 22) return '晚上好'
  return '夜深了'
}

/**
 * 获取当前日期
 */
const getCurrentDate = () => {
  const now = new Date()
  const year = now.getFullYear()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  const weekDays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
  const weekDay = weekDays[now.getDay()]
  return `${year}-${month}-${day} ${weekDay}`
}

/**
 * 获取当前时间
 */
const getCurrentTime = () => {
  return currentTime.value
}

/**
 * 更新时间
 */
const updateTime = () => {
  const now = new Date()
  const hours = String(now.getHours()).padStart(2, '0')
  const minutes = String(now.getMinutes()).padStart(2, '0')
  const seconds = String(now.getSeconds()).padStart(2, '0')
  currentTime.value = `${hours}:${minutes}:${seconds}`
}

/**
 * 处理快捷操作点击
 */
const handleOperation = (path: string) => {
  router.push(path)
}

/**
 * 组件挂载时启动定时器并获取统计数据
 */
onMounted(() => {
  updateTime()
  timeInterval = setInterval(updateTime, 1000)
  fetchStats()
})

/**
 * 组件卸载时清除定时器
 */
onUnmounted(() => {
  if (timeInterval) {
    clearInterval(timeInterval)
  }
})
</script>

<style lang="less" scoped>
.home-container {
  width: 100%;
  min-height: 100%;
  background-color: #f5f7fa;
  padding: 0;
}

// 欢迎卡片
.welcome-card {
  margin-bottom: 0;
  border-radius: 8px;

  :deep(.el-card__body) {
    padding: 24px;
  }
}

.welcome-icon {
  width: 64px;
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 12px;
  color: #ffffff;
}

// 统计卡片
.stat-card {
  border-radius: 8px;
  transition: all 0.3s ease;
  cursor: pointer;

  &:hover {
    transform: translateY(-4px);
    box-shadow: 0 8px 16px rgba(0, 0, 0, 0.1);
  }

  :deep(.el-card__body) {
    padding: 20px;
  }
}

.stat-content {
  display: flex;
  align-items: center;
}

.stat-icon {
  width: 56px;
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
  margin-right: 16px;
  flex-shrink: 0;
}

.hospitals-icon {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: #ffffff;
}

.doctors-icon {
  background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
  color: #ffffff;
}

.users-icon {
  background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
  color: #ffffff;
}

.pets-icon {
  background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);
  color: #ffffff;
}

.stat-info {
  flex: 1;
}

.stat-value {
  font-size: 28px;
  font-weight: bold;
  color: #303133;
  line-height: 1.2;
  margin-bottom: 4px;
}

.stat-label {
  font-size: 14px;
  color: #909399;
}

// 骨架屏图标样式
.skeleton-icon {
  width: 56px;
  height: 56px;
  border-radius: 12px;
  background: linear-gradient(90deg, #f2f2f2 25%, #e6e6e6 50%, #f2f2f2 75%);
  background-size: 200% 100%;
  animation: loading 1.5s ease-in-out infinite;
}

@keyframes loading {
  0% {
    background-position: 200% 0;
  }
  100% {
    background-position: -200% 0;
  }
}

// 快捷操作
.operation-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 20px;
  border-radius: 8px;
  background-color: #f5f7fa;
  cursor: pointer;
  transition: all 0.3s ease;

  &:hover {
    background-color: #e6f7ff;
    transform: translateY(-2px);
  }
}

.operation-icon {
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
  margin-bottom: 12px;
  color: #ffffff;
  transition: all 0.3s ease;
}

.operation-icon-primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.operation-icon-success {
  background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);
}

.operation-icon-warning {
  background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
}

.operation-icon-danger {
  background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
}

.operation-icon-info {
  background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
}

.operation-label {
  font-size: 14px;
  color: #606266;
  text-align: center;
}

// 系统信息
.system-info {
  .info-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .info-label {
    font-size: 14px;
    color: #909399;
  }

  .info-value {
    font-size: 14px;
    color: #303133;
    font-weight: 500;
  }
}

// 响应式调整
@media (max-width: 768px) {
  .welcome-icon {
    width: 48px;
    height: 48px;
  }

  .stat-value {
    font-size: 24px;
  }

  .operation-item {
    padding: 16px;
  }
}
</style>
