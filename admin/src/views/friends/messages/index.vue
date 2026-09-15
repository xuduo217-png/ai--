<template>
  <ContentWrap>
    <Search :schema="searchSchema" @search="handleSearch" @reset="handleReset" />

    <div class="mb-10px">
      <ElButton type="primary" @click="handleRefresh">
        <Icon icon="ep:refresh" class="mr-5px" />
        刷新
      </ElButton>
    </div>

    <Table
      v-model:current-page="currentPage"
      v-model:page-size="pageSize"
      :columns="columns"
      :data="dataList"
      :loading="loading"
      :pagination="{
        total: total || 0
      }"
      @register="tableRegister"
    />

    <!-- 图片预览对话框 -->
    <ElDialog v-model="imagePreviewVisible" title="图片预览" width="600px">
      <div style="text-align: center">
        <img :src="previewImageUrl" style="max-width: 100%; max-height: 500px" alt="图片预览" />
      </div>
    </ElDialog>
  </ContentWrap>
</template>

<script setup lang="tsx">
import { ref, unref } from 'vue'
import { ContentWrap } from '@/components/ContentWrap'
import { Search } from '@/components/Search'
import { Table, type TableColumn } from '@/components/Table'
import type { FormSchema } from '@/components/Form'
import { useTable } from '@/hooks/web/useTable'
import { ElButton, ElTag, ElMessage, ElDialog } from 'element-plus'
import { getFriendMessagesApi, type FriendMessage } from '@/api-new/friends'
import { formatDate } from '@/utils/dateUtil'
import { getImageUrl } from '@/utils/image'

/**
 * 搜索参数
 */
const searchParams = ref({
  conversationId: undefined,
  senderId: undefined,
  receiverId: undefined,
  messageType: undefined,
  startTime: undefined,
  endTime: undefined
})

/**
 * 图片预览
 */
const imagePreviewVisible = ref(false)
const previewImageUrl = ref('')

/**
 * 搜索表单配置
 */
const searchSchema: FormSchema[] = [
  {
    field: 'conversationId',
    label: '会话ID',
    component: 'Input',
    componentProps: {
      placeholder: '请输入会话ID',
      clearable: true
    }
  },
  {
    field: 'senderId',
    label: '发送人ID',
    component: 'Input',
    componentProps: {
      placeholder: '请输入发送人ID',
      clearable: true
    }
  },
  {
    field: 'receiverId',
    label: '接收人ID',
    component: 'Input',
    componentProps: {
      placeholder: '请输入接收人ID',
      clearable: true
    }
  },
  {
    field: 'messageType',
    label: '消息类型',
    component: 'Select',
    componentProps: {
      placeholder: '请选择消息类型',
      clearable: true,
      options: [
        { label: '文字消息', value: 'text' },
        { label: '图片消息', value: 'image' },
        { label: '语音消息', value: 'voice' },
        { label: '视频消息', value: 'video' }
      ]
    }
  },
  {
    field: 'timeRange',
    label: '时间范围',
    component: 'DatePicker',
    componentProps: {
      type: 'daterange',
      valueFormat: 'YYYY-MM-DD HH:mm:ss',
      format: 'YYYY-MM-DD HH:mm:ss',
      clearable: true,
      startPlaceholder: '开始时间',
      endPlaceholder: '结束时间'
    }
  }
]

/**
 * 获取消息类型标签
 */
const getMessageTypeTag = (
  type: FriendMessage['messageType']
): { type: 'primary' | 'success' | 'warning' | 'info'; text: string } => {
  const typeMap: Record<
    FriendMessage['messageType'],
    { type: 'primary' | 'success' | 'warning'; text: string }
  > = {
    text: { type: 'primary', text: '文字' },
    image: { type: 'success', text: '图片' },
    voice: { type: 'warning', text: '语音' },
    video: { type: 'warning', text: '视频' }
  }
  return typeMap[type] || { type: 'info', text: '未知' }
}

/**
 * 预览图片
 */
const handlePreviewImage = (url: string) => {
  previewImageUrl.value = getImageUrl(url)
  imagePreviewVisible.value = true
}

/**
 * 安全解析消息 JSON
 */
const safeParseContent = (content: string): Record<string, any> | null => {
  if (!content) {
    return null
  }

  try {
    const parsed = JSON.parse(content)
    if (parsed && typeof parsed === 'object') {
      return parsed
    }
  } catch {
    // 忽略解析错误
  }

  return null
}

/**
 * 获取媒体 URL（兼容 content.url 与 cloudFileUrl）
 */
const getMediaUrl = (row: FriendMessage): string => {
  const parsedContent = safeParseContent(row.content)
  const rawUrl = parsedContent?.url || row.cloudFileUrl || ''

  if (!rawUrl) {
    return ''
  }

  // 本地 file:// 或 content:// 地址在 admin 端不可访问
  if (rawUrl.startsWith('file://') || rawUrl.startsWith('content://')) {
    return ''
  }

  return getImageUrl(rawUrl)
}

/**
 * 渲染消息内容
 */
const renderMessageContent = (row: FriendMessage) => {
  if (row.messageType === 'text') {
    // 文字消息直接显示
    return <span>{row.content}</span>
  } else if (row.messageType === 'image') {
    // 图片消息显示缩略图
    const imageUrl = getMediaUrl(row)
    if (imageUrl) {
      return (
        <img
          src={imageUrl}
          style={{
            width: '80px',
            height: '80px',
            objectFit: 'cover',
            cursor: 'pointer',
            borderRadius: '4px'
          }}
          alt="图片消息"
          onClick={() => handlePreviewImage(imageUrl)}
        />
      )
    }

    return <span style={{ color: '#999' }}>[图片地址无效]</span>
  } else if (row.messageType === 'voice') {
    const voiceData = safeParseContent(row.content)
    const duration = voiceData?.duration ? `${voiceData.duration}秒` : '未知时长'
    const voiceUrl = getMediaUrl(row)

    if (!voiceUrl) {
      return <span style={{ color: '#999' }}>[语音地址无效，无法播放（{duration}）]</span>
    }

    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
        <audio controls preload="none" src={voiceUrl} style={{ width: '240px' }} />
        <span style={{ fontSize: '12px', color: '#666' }}>时长：{duration}</span>
      </div>
    )
  }
  return <span>-</span>
}

const isRevokedMessage = (row: FriendMessage) => Number(row.isRevoked) === 1

/**
 * 表格列配置
 */
const columns: TableColumn[] = [
  {
    field: 'id',
    label: 'ID',
    width: 80
  },
  {
    field: 'messageId',
    label: '消息ID',
    width: 280,
    slots: {
      default: (data: any) => {
        return (
          <span style={{ fontSize: '12px', fontFamily: 'monospace' }}>{data.row.messageId}</span>
        )
      }
    }
  },
  {
    field: 'conversationId',
    label: '会话ID',
    width: 120
  },
  {
    field: 'senderId',
    label: '发送人ID',
    width: 100
  },
  {
    field: 'senderName',
    label: '发送人',
    width: 120
  },
  {
    field: 'receiverId',
    label: '接收人ID',
    width: 100
  },
  {
    field: 'receiverName',
    label: '接收人',
    width: 120
  },
  {
    field: 'messageType',
    label: '消息类型',
    width: 100,
    slots: {
      default: (data: any) => {
        const typeInfo = getMessageTypeTag(data.row.messageType)
        return <ElTag type={typeInfo.type}>{typeInfo.text}</ElTag>
      }
    }
  },
  {
    field: 'content',
    label: '消息内容',
    width: 340,
    slots: {
      default: (data: any) => {
        return renderMessageContent(data.row)
      }
    }
  },
  {
    field: 'isRevoked',
    label: '撤回状态',
    width: 130,
    slots: {
      default: (data: any) => {
        const row = data.row as FriendMessage
        return isRevokedMessage(row) ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
            <ElTag type="danger" effect="dark">
              已撤回
            </ElTag>
            {row.revokedAt ? (
              <span style={{ color: '#909399', fontSize: '12px' }}>
                {formatDate(new Date(row.revokedAt))}
              </span>
            ) : null}
          </div>
        ) : (
          <ElTag type="info">未撤回</ElTag>
        )
      }
    }
  },
  {
    field: 'isRead',
    label: '已读状态',
    width: 100,
    slots: {
      default: (data: any) => {
        return Number(data.row.isRead) === 1 ? (
          <ElTag type="success">已读</ElTag>
        ) : (
          <ElTag type="info">未读</ElTag>
        )
      }
    }
  },
  {
    field: 'createdAt',
    label: '发送时间',
    width: 180,
    slots: {
      default: (data: any) => {
        return <span>{formatDate(new Date(data.row.createdAt))}</span>
      }
    }
  }
]

/**
 * 表格实例
 */
const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const { pageSize, currentPage } = tableState
    try {
      const res = await getFriendMessagesApi({
        page: unref(currentPage),
        pageSize: unref(pageSize),
        ...unref(searchParams)
      })

      // 确保返回的是数组
      const list = Array.isArray(res.data) ? res.data : []
      const total = res.pagination?.total || 0

      return {
        list,
        total
      }
    } catch (error) {
      console.error('获取消息记录列表失败:', error)
      ElMessage.error('获取消息记录列表失败')
      return {
        list: [],
        total: 0
      }
    }
  }
})
const { total, loading, dataList, pageSize, currentPage } = tableState
const { getList } = tableMethods

/**
 * 搜索
 */
const handleSearch = (data: any) => {
  const { timeRange, ...rest } = data
  searchParams.value = {
    ...rest,
    startTime: Array.isArray(timeRange) ? timeRange[0] : undefined,
    endTime: Array.isArray(timeRange) ? timeRange[1] : undefined
  }
  getList()
}

/**
 * 重置搜索
 */
const handleReset = () => {
  searchParams.value = {
    conversationId: undefined,
    senderId: undefined,
    receiverId: undefined,
    messageType: undefined,
    startTime: undefined,
    endTime: undefined
  }
  getList()
}

/**
 * 刷新列表
 */
const handleRefresh = () => {
  getList()
}
</script>

<style scoped lang="less">
// 自定义样式
</style>
