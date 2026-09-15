<template>
  <div class="chat-message-list">
    <!-- 消息列表容器 -->
    <div ref="messageListRef" class="message-list" :class="{ 'is-loading': isLoading }">
      <!-- 骨架屏加载状态 -->
      <div v-if="isLoading && messages.length === 0" class="message-skeleton">
        <div
          v-for="i in 3"
          :key="i"
          :class="`skeleton-item skeleton-item--${i % 2 === 0 ? 'user' : 'doctor'}`"
        >
          <div class="skeleton-avatar"></div>
          <div class="skeleton-bubble"></div>
        </div>
      </div>

      <!-- 空状态 -->
      <div v-else-if="messages.length === 0 && !isLoading" class="message-empty">
        <el-empty description="暂无消息记录">
          <template #image>
            <el-icon :size="80" color="#909399">
              <ChatLineSquare />
            </el-icon>
          </template>
        </el-empty>
      </div>

      <!-- 消息列表 -->
      <template v-else>
        <!-- 加载更多按钮 -->
        <div v-if="hasMore" class="load-more">
          <el-button :loading="isLoadingMore" class="load-more-button" @click="handleLoadMore">
            <template #icon>
              <el-icon>
                <ArrowDown />
              </el-icon>
            </template>
            加载更多
          </el-button>
        </div>

        <!-- 消息项列表 -->
        <ChatMessageItem
          v-for="message in messages"
          :key="message.id"
          :message="message"
          :current-user-id="currentUserId"
        />
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, nextTick } from 'vue'
import { ChatLineSquare, ArrowDown } from '@element-plus/icons-vue'
import ChatMessageItem from './ChatMessageItem.vue'

/**
 * 聊天消息列表组件
 * 负责消息列表展示、加载更多、空状态等
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
}

interface Props {
  /** 消息列表 */
  messages: ChatMessage[]
  /** 当前用户ID */
  currentUserId: number
  /** 是否正在加载 */
  isLoading: boolean
  /** 是否还有更多消息 */
  hasMore: boolean
  /** 是否正在加载更多 */
  isLoadingMore: boolean
}

interface Emits {
  (e: 'load-more'): void
}

defineProps<Props>()
const emit = defineEmits<Emits>()

/** 消息列表容器引用 */
const messageListRef = ref<HTMLElement>()

/**
 * 加载更多消息
 */
const handleLoadMore = () => {
  emit('load-more')
}

/**
 * 滚动到底部
 */
const scrollToBottom = () => {
  nextTick(() => {
    if (messageListRef.value) {
      messageListRef.value.scrollTop = messageListRef.value.scrollHeight
    }
  })
}

/**
 * 滚动到顶部
 */
const scrollToTop = () => {
  nextTick(() => {
    if (messageListRef.value) {
      messageListRef.value.scrollTop = 0
    }
  })
}

// 暴露方法供父组件调用
defineExpose({
  scrollToBottom,
  scrollToTop
})
</script>

<script lang="ts">
export default {
  name: 'ChatMessageList'
}
</script>

<style lang="less" scoped>
.chat-message-list {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.message-list {
  flex: 1;
  overflow-y: auto;
  background-color: #f5f5f5;
  padding: 20px;
  border-radius: 8px;

  /** 自定义滚动条 */
  &::-webkit-scrollbar {
    width: 6px;
  }

  &::-webkit-scrollbar-track {
    background: #f5f5f5;
    border-radius: 3px;
  }

  &::-webkit-scrollbar-thumb {
    background: linear-gradient(180deg, #e0e0e0 0%, #bdbdbd 100%);
    border-radius: 3px;
    transition: background 0.3s;

    &:hover {
      background: linear-gradient(180deg, #bdbdbd 0%, #9e9e9e 100%);
    }
  }
}

/** 骨架屏 */
.message-skeleton {
  padding: 20px 0;
}

.skeleton-item {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  margin-bottom: 24px;

  &--user {
    flex-direction: row-reverse;
  }

  &--doctor {
    flex-direction: row;
  }
}

.skeleton-avatar {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: linear-gradient(90deg, #f2f2f2 25%, #e6e6e6 50%, #f2f2f2 75%);
  background-size: 200% 100%;
  animation: pulse 1.5s ease-in-out infinite;
  flex-shrink: 0;
}

.skeleton-bubble {
  max-width: 60%;
  height: 60px;
  border-radius: 12px;
  background: linear-gradient(90deg, #f2f2f2 25%, #e6e6e6 50%, #f2f2f2 75%);
  background-size: 200% 100%;
  animation: pulse 1.5s ease-in-out infinite;
}

@keyframes pulse {
  0% {
    background-position: 200% 0;
  }
  100% {
    background-position: -200% 0;
  }
}

/** 空状态 */
.message-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
}

/** 加载更多按钮 */
.load-more {
  display: flex;
  justify-content: center;
  padding: 20px 0;
}

.load-more-button {
  border: 1px dashed #409eff;
  background: transparent;
  color: #409eff;
  transition: all 0.3s;

  &:hover {
    background: #ecf5ff;
    border-color: #409eff;
  }
}
</style>
