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
import { ElButton, ElTag, ElMessage, ElMessageBox } from 'element-plus'
import { getFriendshipsApi, forceDeleteFriendshipApi, type Friendship } from '@/api-new/friends'
import { formatDate } from '@/utils/dateUtil'
import { getImageUrl } from '@/utils/image'

/**
 * 搜索参数
 */
const searchParams = ref({
  userId: undefined,
  friendId: undefined
})

/**
 * 搜索表单配置
 */
const searchSchema: FormSchema[] = [
  {
    field: 'userId',
    label: '用户ID',
    component: 'Input',
    componentProps: {
      placeholder: '请输入用户ID',
      clearable: true
    }
  },
  {
    field: 'friendId',
    label: '好友ID',
    component: 'Input',
    componentProps: {
      placeholder: '请输入好友ID',
      clearable: true
    }
  }
]

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
    field: 'userId',
    label: '用户ID',
    width: 100
  },
  {
    field: 'userAvatar',
    label: '用户头像',
    width: 100,
    slots: {
      default: (data: any) => {
        return data.row.userAvatar ? (
          <img
            src={getImageUrl(data.row.userAvatar)}
            style={{ width: '50px', height: '50px', objectFit: 'cover', borderRadius: '50%' }}
            alt="用户头像"
          />
        ) : (
          <span>-</span>
        )
      }
    }
  },
  {
    field: 'userName',
    label: '用户昵称',
    width: 120
  },
  {
    field: 'friendId',
    label: '好友ID',
    width: 100
  },
  {
    field: 'friendAvatar',
    label: '好友头像',
    width: 100,
    slots: {
      default: (data: any) => {
        return data.row.friendAvatar ? (
          <img
            src={getImageUrl(data.row.friendAvatar)}
            style={{ width: '50px', height: '50px', objectFit: 'cover', borderRadius: '50%' }}
            alt="好友头像"
          />
        ) : (
          <span>-</span>
        )
      }
    }
  },
  {
    field: 'friendName',
    label: '好友昵称',
    width: 120
  },
  {
    field: 'direction',
    label: '关系方向',
    width: 120,
    slots: {
      default: (data: any) => {
        return data.row.direction === 'sent' ? (
          <ElTag type="success">主动添加</ElTag>
        ) : (
          <ElTag type="info">被动添加</ElTag>
        )
      }
    }
  },
  {
    field: 'remark',
    label: '备注名',
    width: 120,
    slots: {
      default: (data: any) => {
        return <span>{data.row.remark || '-'}</span>
      }
    }
  },
  {
    field: 'lastChatAt',
    label: '最后聊天时间',
    width: 180,
    slots: {
      default: (data: any) => {
        return <span>{data.row.lastChatAt ? formatDate(new Date(data.row.lastChatAt)) : '-'}</span>
      }
    }
  },
  {
    field: 'createdAt',
    label: '添加时间',
    width: 180,
    slots: {
      default: (data: any) => {
        return <span>{formatDate(new Date(data.row.createdAt))}</span>
      }
    }
  },
  {
    field: 'action',
    label: '操作',
    width: 150,
    fixed: 'right',
    slots: {
      default: (data: any) => {
        return (
          <>
            <ElButton type="danger" size="small" onClick={() => handleDelete(data.row)}>
              解除关系
            </ElButton>
          </>
        )
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
      const res = await getFriendshipsApi({
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
      console.error('获取好友关系列表失败:', error)
      ElMessage.error('获取好友关系列表失败')
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
    userId: undefined,
    friendId: undefined
  }
  getList()
}

/**
 * 刷新列表
 */
const handleRefresh = () => {
  getList()
}

/**
 * 解除好友关系
 */
const handleDelete = async (row: Friendship) => {
  try {
    await ElMessageBox.confirm(
      `确定要强制解除用户 ${row.userName || row.userId} 和 ${row.friendName || row.friendId} 的好友关系吗？此操作不可恢复！`,
      '警告',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      }
    )

    await forceDeleteFriendshipApi(row.userId, row.friendId)
    ElMessage.success('解除好友关系成功')
    getList()
  } catch (error: any) {
    if (error !== 'cancel') {
      console.error('解除好友关系失败:', error)
      ElMessage.error(error.message || '解除好友关系失败')
    }
  }
}
</script>

<style scoped lang="less">
// 自定义样式
</style>
