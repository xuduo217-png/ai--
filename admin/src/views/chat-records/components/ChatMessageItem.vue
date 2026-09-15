<template>
  <div
    :class="[
      'chat-message-item',
      `chat-message-item--${messageType}`,
      { 'is-system': isSystemMessage }
    ]"
  >
    <!-- 付费提示消息（居中显示，带套餐列表） -->
    <div v-if="message.type === 'PAYMENT_PROMPT'" class="chat-message-item__payment-prompt">
      <div class="payment-prompt-header">
        <span class="payment-icon">💰</span>
        <span class="payment-title">免费咨询次数已用完</span>
      </div>
      <div v-if="message.packages && message.packages.length > 0" class="payment-packages">
        <div v-for="pkg in message.packages" :key="pkg.id" class="package-card">
          <div class="package-name">{{ pkg.name }}</div>
          <div class="package-price">¥{{ pkg.price }}</div>
          <div class="package-duration"
            >{{ pkg.durationDays || Math.ceil(pkg.duration / 60 / 24) }}天</div
          >
        </div>
      </div>
      <div v-else class="payment-empty">暂无可用套餐</div>
    </div>

    <!-- 购买成功消息（居中显示，绿色） -->
    <div v-else-if="message.type === 'PAYMENT_SUCCESS'" class="chat-message-item__payment-success">
      <span class="success-icon">✅</span>
      <span class="success-content">{{ message.content }}</span>
      <span v-if="message.orderId" class="order-id">订单: #{{ message.orderId }}</span>
    </div>

    <!-- 系统消息（居中显示） -->
    <div v-else-if="isSystemMessage" class="chat-message-item__system">
      <span class="system-icon">ℹ️</span>
      <span class="system-content">{{ message.content }}</span>
    </div>

    <!-- 用户消息（右侧） -->
    <template v-else-if="messageType === 'user'">
      <div class="chat-message-item__timestamp">
        {{ formattedTime }}
      </div>
      <div class="chat-message-item__bubble user-bubble">
        <ElTag v-if="message.isRevoked" type="danger" size="small" effect="dark">已撤回</ElTag>
        <!-- 自动回复标签 -->
        <span v-if="message.isAutoReply" class="auto-reply-tag">⚡ 自动回复</span>
        <!-- 图片消息 -->
        <ElImage
          v-if="message.type === 'IMAGE'"
          :src="imageUrl"
          class="message-image"
          :preview-src-list="previewList"
          :preview-teleported="true"
          :z-index="9999"
          fit="cover"
          alt="聊天图片"
        />
        <video
          v-else-if="message.type === 'VIDEO'"
          class="message-video"
          :src="videoUrl"
          controls
          preload="metadata"
        ></video>
        <!-- 文本消息 -->
        <span v-else class="bubble-content">{{ message.content }}</span>
      </div>
      <ChatAvatar :type="'user'" :avatar-url="message.senderAvatar" :size="40" />
    </template>

    <!-- 医生消息（左侧） -->
    <template v-else>
      <ChatAvatar :type="'doctor'" :avatar-url="message.senderAvatar" :size="40" />
      <div class="chat-message-item__bubble doctor-bubble">
        <ElTag v-if="message.isRevoked" type="danger" size="small" effect="dark">已撤回</ElTag>
        <!-- 自动回复标签 -->
        <span v-if="message.isAutoReply" class="auto-reply-tag">⚡ 自动回复</span>
        <!-- 图片消息 -->
        <ElImage
          v-if="message.type === 'IMAGE'"
          :src="imageUrl"
          class="message-image"
          :preview-src-list="previewList"
          :preview-teleported="true"
          :z-index="9999"
          fit="cover"
          alt="聊天图片"
        />
        <video
          v-else-if="message.type === 'VIDEO'"
          class="message-video"
          :src="videoUrl"
          controls
          preload="metadata"
        ></video>
        <!-- 文本消息 -->
        <span v-else class="bubble-content">{{ message.content }}</span>
      </div>
      <div class="chat-message-item__timestamp">
        {{ formattedTime }}
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { ElImage, ElTag } from 'element-plus'
import ChatAvatar from './ChatAvatar.vue'
import { getImageUrl } from '@/utils/image'

/**
 * 聊天消息组件
 * 根据发送者类型展示不同样式的消息气泡
 */
interface ChatMessage {
  id: number
  conversationId: string
  senderId: number
  senderName: string
  senderAvatar?: string
  receiverId: number
  receiverName: string
  content: string
  type: string
  isAutoReply: boolean
  isRevoked: boolean
  revokedAt?: string
  createdAt: string
  packages?: any[] // 付费提示消息的套餐列表
  orderId?: number // 订单 ID（用于 PAYMENT_SUCCESS 消息）
}

interface Props {
  /** 消息数据 */
  message: ChatMessage
  /** 当前用户ID（用于判断消息类型） */
  currentUserId: number
}

const props = defineProps<Props>()

/** 消息类型：user（用户）或 doctor（医生）或 system（系统） */
const messageType = computed(() => {
  // 付费相关消息也作为系统消息处理
  if (['PAYMENT_PROMPT', 'PAYMENT_SUCCESS'].includes(props.message.type)) {
    return 'system'
  }
  // 系统消息
  if (props.message.type === 'SYSTEM') {
    return 'system'
  }
  // 判断是否为当前用户（用户）发送的消息
  if (props.message.senderId === props.currentUserId) {
    return 'user'
  }
  // 否则为医生消息
  return 'doctor'
})

/** 是否为系统消息 */
const isSystemMessage = computed(() => messageType.value === 'system')

/**
 * 格式化时间
 * 将后端返回的时间格式化为更友好的显示格式
 */
const formatTime = (time: string) => {
  if (!time) return ''
  try {
    const date = new Date(time)
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    const hours = String(date.getHours()).padStart(2, '0')
    const minutes = String(date.getMinutes()).padStart(2, '0')
    const seconds = String(date.getSeconds()).padStart(2, '0')
    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`
  } catch {
    return time
  }
}

/** 格式化时间 */
const formattedTime = computed(() => {
  return formatTime(props.message.createdAt)
})

const resolveStructuredMediaUrl = (content: string) => {
  const trimmedContent = content?.trim()
  if (!trimmedContent) return ''

  if (!trimmedContent.startsWith('{')) {
    return getImageUrl(trimmedContent)
  }

  try {
    const parsed = JSON.parse(trimmedContent)
    const url = typeof parsed?.url === 'string' ? parsed.url : ''
    return getImageUrl(url)
  } catch {
    return getImageUrl(trimmedContent)
  }
}

/**
 * 计算图片完整 URL
 * 使用 getImageUrl 工具函数自动处理相对路径和完整 URL
 */
const imageUrl = computed(() => {
  if (props.message.type !== 'IMAGE') return ''
  return resolveStructuredMediaUrl(props.message.content)
})

/**
 * 计算视频完整 URL
 */
const videoUrl = computed(() => {
  if (props.message.type !== 'VIDEO') return ''
  return resolveStructuredMediaUrl(props.message.content)
})

/**
 * 图片预览列表
 * 使用 computed 缓存，避免每次渲染都创建新数组
 */
const previewList = computed(() => {
  if (props.message.type !== 'IMAGE') return []
  return [imageUrl.value]
})
</script>

<script lang="ts">
export default {
  name: 'ChatMessageItem'
}
</script>

<style lang="less" scoped>
.chat-message-item {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  margin-bottom: 24px;
  animation: fadeInUp 0.3s ease-out;

  /** 消息进入动画 */
  @keyframes fadeInUp {
    from {
      opacity: 0;
      transform: translateY(20px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  /** 用户消息：右对齐 */
  &--user {
    flex-direction: row-reverse;
  }

  /** 医生消息：左对齐 */
  &--doctor {
    flex-direction: row;
  }

  /** 系统消息：居中 */
  &.is-system {
    justify-content: center;
  }

  &__system {
    display: flex;
    align-items: center;
    gap: 8px;
    background-color: #fff3e0;
    color: #e65100;
    padding: 8px 16px;
    border-radius: 12px;
    font-size: 13px;
    white-space: nowrap;
  }

  :deep(.el-tag) {
    margin-bottom: 6px;
  }

  /** 付费提示消息 */
  &__payment-prompt {
    background-color: #fff9e6;
    border: 1px solid #ffe8a1;
    border-radius: 12px;
    padding: 16px;
    max-width: 500px;
    width: 100%;
  }

  .payment-prompt-header {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 12px;
    padding-bottom: 8px;
    border-bottom: 1px solid #ffe8a1;
  }

  .payment-icon {
    font-size: 20px;
  }

  .payment-title {
    font-size: 14px;
    font-weight: 600;
    color: #856404;
  }

  .payment-packages {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .package-card {
    display: flex;
    align-items: center;
    gap: 12px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    padding: 12px;
    border-radius: 8px;
  }

  .package-name {
    font-size: 14px;
    font-weight: 600;
    flex: 1;
  }

  .package-price {
    font-size: 18px;
    font-weight: bold;
  }

  .package-duration {
    font-size: 12px;
    opacity: 0.9;
  }

  .payment-empty {
    text-align: center;
    color: #999;
    font-size: 13px;
    padding: 12px;
  }

  /** 购买成功消息 */
  &__payment-success {
    display: flex;
    align-items: center;
    gap: 8px;
    background-color: #d1fae5;
    border: 1px solid #a7f3d0;
    color: #065f46;
    padding: 12px 16px;
    border-radius: 12px;
    font-size: 13px;
  }

  .success-icon {
    font-size: 20px;
  }

  .success-content {
    flex: 1;
  }

  .order-id {
    font-size: 11px;
    color: #047857;
    opacity: 0.8;
  }

  &__timestamp {
    display: flex;
    align-items: center;
    font-size: 11px;
    color: #999999;
    font-family: 'Monaco', 'Consolas', monospace;
    white-space: nowrap;
  }

  &__bubble {
    max-width: 60%;
    padding: 12px 16px;
    font-size: 14px;
    line-height: 1.6;
    color: #333333;
    border-radius: 12px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
    cursor: pointer;
    transition: transform 0.2s ease;

    /** 气泡点击效果 */
    &:active {
      transform: scale(0.98);
    }

    /** 悬停上移效果 */
    &:hover {
      transform: translateY(-2px);
    }
  }

  /** 用户气泡（浅蓝色） */
  .user-bubble {
    background-color: #e3f2fd;
    border-radius: 12px 12px 4px 12px;
    box-shadow: 0 2px 8px rgba(227, 242, 253, 0.6);

    &:hover {
      transform: translateY(-2px);
    }
  }

  /** 医生气泡（白色） */
  .doctor-bubble {
    background-color: #ffffff;
    border-radius: 12px 12px 12px 4px;

    &:hover {
      transform: translateY(-2px);
    }
  }

  /** 自动回复标签 */
  .auto-reply-tag {
    display: inline-block;
    background-color: #409eff;
    color: #ffffff;
    font-size: 12px;
    padding: 2px 8px;
    border-radius: 4px;
    margin-right: 8px;
    white-space: nowrap;
  }

  .bubble-content {
    word-break: break-word;
    white-space: pre-wrap;
  }

  .message-image {
    // 设置固定的预览尺寸（小尺寸）
    width: 200px;
    height: 200px;
    border-radius: 8px;
    cursor: pointer;
    display: block;

    // Element Plus 的 ElImage 组件会处理预览功能，这里只需要设置显示尺寸
    :deep(.el-image__inner) {
      width: 100%;
      height: 100%;
      object-fit: cover;
      border-radius: 8px;
    }
  }

  .message-video {
    width: 240px;
    max-width: 100%;
    border-radius: 8px;
    display: block;
    background-color: #000000;
  }
}
</style>
