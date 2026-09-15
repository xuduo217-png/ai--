<template>
  <Dialog
    v-model="dialogVisible"
    title="聊天记录详情"
    :fullscreen="false"
    :max-height="'80vh'"
    @close="handleClose"
  >
    <div class="dialog-content">
      <!-- 会话信息卡片 -->
      <SessionInfoCard v-if="sessionInfo" :session-info="sessionInfo" />

      <!-- 聊天消息列表 -->
      <ChatMessageList
        ref="messageListRef"
        :messages="messageList"
        :current-user-id="currentUserId"
        :is-loading="isLoading"
        :has-more="hasMore"
        :is-loading-more="isLoadingMore"
        @load-more="handleLoadMore"
      />
    </div>
  </Dialog>
</template>

<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue'
import { ElMessage } from 'element-plus'
import { Dialog } from '@/components/Dialog'
import SessionInfoCard from './SessionInfoCard.vue'
import ChatMessageList from './ChatMessageList.vue'
import {
  getChatMessagesApi,
  type ChatSessionRecord,
  type ChatMessage
} from '@/api-new/chat-records'
import { extractPagedTableData } from '@/utils/pagination'

/**
 * 聊天记录详情对话框组件
 * 微信风格聊天 UI
 */
interface Props {
  /** 模型值（控制对话框显示） */
  modelValue: boolean
  /** 会话记录 */
  sessionInfo: ChatSessionRecord | null
}

interface Emits {
  (e: 'update:modelValue', value: boolean): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

/** 对话框显示状态 */
const dialogVisible = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
})

/** 消息列表 */
const messageList = ref<ChatMessage[]>([])
const isLoading = ref(false)
const isLoadingMore = ref(false)

/** 分页信息 */
const pagination = ref({
  page: 1,
  pageSize: 50,
  total: 0
})

/** 消息列表组件引用 */
const messageListRef = ref()

/** 当前用户ID（用于判断消息方向） */
const currentUserId = computed(() => props.sessionInfo?.userId || 0)

/** 是否还有更多消息 */
const hasMore = computed(
  () => pagination.value.page * pagination.value.pageSize < pagination.value.total
)

/**
 * 加载消息列表
 */
const loadMessages = async (page = 1) => {
  if (!props.sessionInfo) return

  isLoading.value = page === 1
  isLoadingMore.value = page > 1

  try {
    const res = await getChatMessagesApi(props.sessionInfo.conversationId, {
      page,
      pageSize: pagination.value.pageSize,
      orderId: props.sessionInfo.orderId // 传递订单ID以筛选该订单的消息
    })
    const { list: messages, total: totalCount } = extractPagedTableData<ChatMessage>(res)

    if (page === 1) {
      messageList.value = messages
    } else {
      // 追加消息（新消息在前）
      messageList.value = [...messages, ...messageList.value]
    }

    pagination.value.page = page
    pagination.value.total = totalCount

    // 首次加载后滚动到底部
    if (page === 1) {
      nextTick(() => {
        messageListRef.value?.scrollToBottom()
      })
    }
  } catch (error) {
    console.error('加载消息失败:', error)
    ElMessage.error('加载消息失败')
  } finally {
    isLoading.value = false
    isLoadingMore.value = false
  }
}

/**
 * 加载更多消息
 */
const handleLoadMore = () => {
  loadMessages(pagination.value.page + 1)
}

/**
 * 关闭对话框
 */
const handleClose = () => {
  dialogVisible.value = false
  // 重置状态
  messageList.value = []
  pagination.value.page = 1
  pagination.value.total = 0
}

/**
 * 监听对话框打开，加载消息
 */
watch(
  () => props.modelValue,
  (newVal) => {
    if (newVal && props.sessionInfo) {
      loadMessages(1)
    }
  }
)
</script>

<script lang="ts">
export default {
  name: 'ChatDetailDialog'
}
</script>

<style lang="less" scoped>
.dialog-content {
  display: flex;
  flex-direction: column;
  height: 100%;
  max-height: 80vh;
}
</style>
