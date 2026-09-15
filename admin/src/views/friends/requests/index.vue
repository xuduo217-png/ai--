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
  </ContentWrap>
</template>

<script setup lang="tsx">
import { ref, unref } from 'vue'
import { ContentWrap } from '@/components/ContentWrap'
import { Search } from '@/components/Search'
import { Table, type TableColumn } from '@/components/Table'
import type { FormSchema } from '@/components/Form'
import { useTable } from '@/hooks/web/useTable'
import { ElButton, ElTag, ElMessage } from 'element-plus'
import { getFriendRequestsApi, type FriendRequest } from '@/api-new/friends'
import { formatDate } from '@/utils/dateUtil'
import { getImageUrl } from '@/utils/image'

/**
 * 搜索参数
 */
const searchParams = ref({
  status: undefined
})

/**
 * 搜索表单配置
 */
const searchSchema: FormSchema[] = [
  {
    field: 'status',
    label: '申请状态',
    component: 'Select',
    componentProps: {
      placeholder: '请选择申请状态',
      clearable: true,
      options: [
        { label: '待处理', value: 'pending' },
        { label: '已接受', value: 'accepted' },
        { label: '已拒绝', value: 'rejected' },
        { label: '已过期', value: 'expired' }
      ]
    }
  }
]

/**
 * 获取状态标签
 */
const getStatusTag = (
  status: FriendRequest['status']
): { type: 'warning' | 'success' | 'danger' | 'info'; text: string } => {
  const statusMap: Record<
    FriendRequest['status'],
    { type: 'warning' | 'success' | 'danger' | 'info'; text: string }
  > = {
    pending: { type: 'warning', text: '待处理' },
    accepted: { type: 'success', text: '已接受' },
    rejected: { type: 'danger', text: '已拒绝' },
    expired: { type: 'info', text: '已过期' }
  }
  return statusMap[status] || { type: 'info', text: '未知' }
}

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
    field: 'requesterId',
    label: '申请人ID',
    width: 100
  },
  {
    field: 'requesterAvatar',
    label: '申请人头像',
    width: 100,
    slots: {
      default: (data: any) => {
        return data.row.requesterAvatar ? (
          <img
            src={getImageUrl(data.row.requesterAvatar)}
            style={{ width: '50px', height: '50px', objectFit: 'cover', borderRadius: '50%' }}
            alt="申请人头像"
          />
        ) : (
          <span>-</span>
        )
      }
    }
  },
  {
    field: 'requesterName',
    label: '申请人昵称',
    width: 120
  },
  {
    field: 'receiverId',
    label: '接收人ID',
    width: 100
  },
  {
    field: 'receiverAvatar',
    label: '接收人头像',
    width: 100,
    slots: {
      default: (data: any) => {
        return data.row.receiverAvatar ? (
          <img
            src={getImageUrl(data.row.receiverAvatar)}
            style={{ width: '50px', height: '50px', objectFit: 'cover', borderRadius: '50%' }}
            alt="接收人头像"
          />
        ) : (
          <span>-</span>
        )
      }
    }
  },
  {
    field: 'receiverName',
    label: '接收人昵称',
    width: 120
  },
  {
    field: 'message',
    label: '申请附言',
    width: 200,
    slots: {
      default: (data: any) => {
        return <span>{data.row.message || '-'}</span>
      }
    }
  },
  {
    field: 'status',
    label: '申请状态',
    width: 120,
    slots: {
      default: (data: any) => {
        const statusInfo = getStatusTag(data.row.status)
        return <ElTag type={statusInfo.type}>{statusInfo.text}</ElTag>
      }
    }
  },
  {
    field: 'rejectionReason',
    label: '拒绝原因',
    width: 200,
    slots: {
      default: (data: any) => {
        return <span>{data.row.rejectionReason || '-'}</span>
      }
    }
  },
  {
    field: 'expiresAt',
    label: '过期时间',
    width: 180,
    slots: {
      default: (data: any) => {
        return <span>{formatDate(new Date(data.row.expiresAt))}</span>
      }
    }
  },
  {
    field: 'createdAt',
    label: '创建时间',
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
      const res = await getFriendRequestsApi({
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
      console.error('获取好友申请列表失败:', error)
      ElMessage.error('获取好友申请列表失败')
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
  searchParams.value = data
  getList()
}

/**
 * 重置搜索
 */
const handleReset = () => {
  searchParams.value = {
    status: undefined
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
