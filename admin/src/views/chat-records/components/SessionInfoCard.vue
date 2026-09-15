<template>
  <div class="session-info-card">
    <!-- 标题栏：可折叠 -->
    <div class="session-info-card__header" @click="toggleCollapse">
      <span class="session-info-card__title">会话信息</span>
      <el-icon class="session-info-card__collapse-icon" :class="{ 'is-collapsed': isCollapsed }">
        <ArrowRight />
      </el-icon>
    </div>

    <!-- 内容区：可折叠 -->
    <el-collapse-transition>
      <div v-show="!isCollapsed" class="session-info-card__content">
        <el-descriptions :column="2" border>
          <!-- 会话状态 -->
          <el-descriptions-item label="会话状态">
            <el-tag :type="statusTag.type" effect="plain">
              {{ statusTag.icon }} {{ statusTag.label }}
            </el-tag>
          </el-descriptions-item>

          <!-- 会话ID -->
          <el-descriptions-item label="会话ID">
            <span class="session-info-card__value">{{ sessionInfo.conversationId }}</span>
          </el-descriptions-item>

          <!-- 医生信息 -->
          <el-descriptions-item label="医生姓名">
            <span class="session-info-card__value">{{ sessionInfo.doctorName }}</span>
          </el-descriptions-item>

          <!-- 用户信息 -->
          <el-descriptions-item label="用户昵称">
            <span class="session-info-card__value">{{ sessionInfo.userName }}</span>
          </el-descriptions-item>

          <!-- 医院信息 -->
          <el-descriptions-item label="所属医院">
            <span class="session-info-card__value">{{ sessionInfo.hospitalName }}</span>
          </el-descriptions-item>

          <!-- 科室信息 -->
          <el-descriptions-item label="所属科室">
            <span class="session-info-card__value">{{ sessionInfo.departmentName }}</span>
          </el-descriptions-item>

          <!-- 服务项目 -->
          <el-descriptions-item label="服务项目" :span="2">
            <span class="session-info-card__value">{{ sessionInfo.serviceItemName }}</span>
          </el-descriptions-item>

          <!-- 服务开始时间 -->
          <el-descriptions-item label="服务开始时间">
            <span class="session-info-card__value">{{
              formatTime(sessionInfo.serviceStartAt)
            }}</span>
          </el-descriptions-item>

          <!-- 服务结束时间 -->
          <el-descriptions-item label="服务结束时间">
            <span class="session-info-card__value">{{ formatTime(sessionInfo.serviceEndAt) }}</span>
          </el-descriptions-item>

          <!-- 消息数量 -->
          <el-descriptions-item label="消息数量">
            <span class="session-info-card__value">{{ sessionInfo.messageCount }} 条</span>
          </el-descriptions-item>

          <!-- 创建时间 -->
          <el-descriptions-item label="创建时间">
            <span class="session-info-card__value">{{ formatTime(sessionInfo.createdAt) }}</span>
          </el-descriptions-item>
        </el-descriptions>
      </div>
    </el-collapse-transition>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { ArrowRight } from '@element-plus/icons-vue'

/**
 * 会话信息卡片组件
 * 可折叠展示会话详细信息
 */
interface SessionInfo {
  conversationId: string
  userId: number
  userName: string
  userAvatar?: string
  doctorId: number
  doctorName: string
  doctorAvatar?: string
  hospitalId: number
  hospitalName: string
  departmentId: number
  departmentName: string
  status: string
  serviceItemId: number
  serviceItemName: string
  serviceStartAt: string
  serviceEndAt: string
  messageCount: number
  createdAt: string
}

interface Props {
  /** 会话信息 */
  sessionInfo: SessionInfo
}

const props = defineProps<Props>()

/** 折叠状态 */
const isCollapsed = ref(false)

/** 切换折叠状态 */
const toggleCollapse = () => {
  isCollapsed.value = !isCollapsed.value
}

/** 格式化时间 */
const formatTime = (time: string) => {
  if (!time) return '-'
  try {
    const date = new Date(time)
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    const hours = String(date.getHours()).padStart(2, '0')
    const minutes = String(date.getMinutes()).padStart(2, '0')
    return `${year}-${month}-${day} ${hours}:${minutes}`
  } catch {
    return time
  }
}

/** 状态标签配置 */
const statusTag = computed(() => {
  const statusMap = {
    PAID: { icon: '🔵', label: '服务中', type: 'success' },
    EXPIRED: { icon: '⚪', label: '已过期', type: 'info' },
    COMPLETED: { icon: '✅', label: '已完成', type: 'primary' },
    FREE: { icon: '🎁', label: '免费咨询', type: 'warning' }
  }
  return statusMap[props.sessionInfo.status] || { icon: '❓', label: '未知', type: 'default' }
})
</script>

<script lang="ts">
export default {
  name: 'SessionInfoCard'
}
</script>

<style lang="less" scoped>
.session-info-card {
  background-color: #f5f7fa;
  border-radius: 8px;
  padding: 16px;
  margin-bottom: 20px;

  &__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    cursor: pointer;
    user-select: none;
    margin-bottom: 16px;
  }

  &__title {
    font-size: 16px;
    font-weight: 600;
    color: #303133;
  }

  &__collapse-icon {
    color: #909399;
    transition: transform 0.3s;

    &.is-collapsed {
      transform: rotate(0deg);
    }

    &:not(.is-collapsed) {
      transform: rotate(90deg);
    }
  }

  &__content {
    // 折叠动画由 el-collapse-transition 处理
  }

  &__value {
    color: #303133;
    font-size: 14px;
    font-weight: 400;
  }
}

// 覆盖 el-descriptions 的标签样式
:deep(.el-descriptions__label) {
  color: #909399 !important;
  font-size: 13px;
  font-weight: 500;
}
</style>
