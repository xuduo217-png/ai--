<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { Table } from '@/components/Table'
import { ref, unref, reactive } from 'vue'
import {
  ElTag,
  ElMessage,
  ElMessageBox,
  ElDialog,
  ElSelect,
  ElOption,
  ElButton
} from 'element-plus'
import {
  getReviewedPostsApi,
  deletePostApi,
  togglePinApi,
  toggleFeatureApi,
  type Post,
  type PostStatus
} from '@/api/community'
import { useTable } from '@/hooks/web/useTable'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { BaseButton } from '@/components/Button'
import { getImageUrl } from '@/utils/image'
import { VideoPlayer } from '@/components/VideoPlayer'

/**
 * 解析发布者展示名称
 * 社区接口当前不保证返回 phone 字段，这里统一退化到昵称，避免模板和类型系统继续错位
 */
const getUserDisplayName = (user?: Post['user']) => {
  if (!user) return '未知用户'
  return user.nickname || `用户#${user.id}`
}

// 状态筛选
const statusFilter = ref<PostStatus | ''>('')

const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const { pageSize, currentPage } = tableState
    const res = await getReviewedPostsApi({
      page: unref(currentPage),
      pageSize: unref(pageSize),
      status: statusFilter.value || undefined
    })

    return {
      list: Array.isArray(res.data) ? res.data : [],
      total: res.meta?.total || 0
    }
  }
})
const { total, loading, dataList, pageSize, currentPage } = tableState
const { getList } = tableMethods

// 监听筛选条件变化
const handleStatusChange = () => {
  currentPage.value = 1
  getList()
}

// 详情弹窗
const detailDialogVisible = ref(false)
const currentPost = ref<Post | null>(null)

// CRUD Schema 定义
const crudSchemas = reactive<CrudSchema[]>([
  {
    field: 'index',
    label: '序号',
    type: 'index',
    width: 80,
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true }
  },
  {
    field: 'id',
    label: '帖子ID',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    width: 80
  },
  {
    field: 'user',
    label: '发布者',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    width: 180,
    slots: {
      default: (data: any) => {
        const user = data.row.user
        return user ? (
          <div style="display: flex; align-items: center;">
            <img
              src={getImageUrl(user.avatar)}
              style="width: 32px; height: 32px; border-radius: 50%; margin-right: 8px;"
            />
            <span>{getUserDisplayName(user)}</span>
          </div>
        ) : (
          <span>-</span>
        )
      }
    }
  },
  {
    field: 'content',
    label: '内容',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    slots: {
      default: (data: any) => {
        const content = data.row.content || ''
        return <span>{content.length > 50 ? content.substring(0, 50) + '...' : content}</span>
      }
    }
  },
  {
    field: 'images',
    label: '媒体',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    width: 80,
    slots: {
      default: (data: any) => {
        const { images, video } = data.row
        if (video) {
          return <ElTag type="warning">视频</ElTag>
        }
        if (images && images.length > 0) {
          return <ElTag type="info">{images.length}张图片</ElTag>
        }
        return <span>-</span>
      }
    }
  },
  {
    field: 'status',
    label: '状态',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    width: 100,
    slots: {
      default: (data: any) => {
        const status = data.row.status
        if (status === 'APPROVED') {
          return <ElTag type="success">已通过</ElTag>
        } else if (status === 'REJECTED') {
          return <ElTag type="danger">已拒绝</ElTag>
        }
        return <ElTag type="info">{status}</ElTag>
      }
    }
  },
  {
    field: 'rejectReason',
    label: '拒绝原因',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    slots: {
      default: (data: any) => {
        const reason = data.row.rejectReason
        return reason ? <span>{reason}</span> : <span>-</span>
      }
    }
  },
  {
    field: 'isPinned',
    label: '置顶',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    width: 80,
    slots: {
      default: (data: any) => {
        return data.row.isPinned ? <ElTag type="warning">已置顶</ElTag> : <span>-</span>
      }
    }
  },
  {
    field: 'isFeatured',
    label: '加精',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    width: 80,
    slots: {
      default: (data: any) => {
        return data.row.isFeatured ? <ElTag type="warning">已加精</ElTag> : <span>-</span>
      }
    }
  },
  {
    field: 'createdAt',
    label: '发布时间',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    width: 180,
    slots: {
      default: (data: any) => {
        const date = new Date(data.row.createdAt)
        return date.toLocaleString('zh-CN')
      }
    }
  },
  {
    field: 'action',
    label: '操作',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    width: 320,
    slots: {
      default: (data: any) => {
        return (
          <>
            <BaseButton type="primary" link onClick={() => handleViewDetail(data.row)}>
              查看
            </BaseButton>
            {data.row.status === 'APPROVED' && (
              <>
                <BaseButton type="warning" link onClick={() => handleTogglePin(data.row)}>
                  {data.row.isPinned ? '取消置顶' : '置顶'}
                </BaseButton>
                <BaseButton type="success" link onClick={() => handleToggleFeature(data.row)}>
                  {data.row.isFeatured ? '取消加精' : '加精'}
                </BaseButton>
              </>
            )}
            <BaseButton type="danger" link onClick={() => handleDelete(data.row.id)}>
              删除
            </BaseButton>
          </>
        )
      }
    }
  }
])
const { allSchemas } = useCrudSchemas(crudSchemas)

// 查看详情
const handleViewDetail = (post: Post) => {
  currentPost.value = post
  detailDialogVisible.value = true
}

// 置顶/取消置顶
const handleTogglePin = async (post: Post) => {
  try {
    const result = await togglePinApi(post.id)
    ElMessage.success(result.message || '操作成功')
    getList()
  } catch (error: any) {
    ElMessage.error(error.message || '操作失败')
  }
}

// 加精/取消加精
const handleToggleFeature = async (post: Post) => {
  try {
    const result = await toggleFeatureApi(post.id)
    ElMessage.success(result.message || '操作成功')
    getList()
  } catch (error: any) {
    ElMessage.error(error.message || '操作失败')
  }
}

// 删除
const handleDelete = async (id: number) => {
  try {
    await ElMessageBox.confirm('确认删除该帖子？此操作不可恢复。', '操作确认', {
      type: 'warning'
    })
    await deletePostApi(id)
    ElMessage.success('删除成功')
    getList()
  } catch (error) {
    // 用户取消操作
  }
}
</script>

<template>
  <ContentWrap>
    <div class="mb-4 flex items-center justify-between">
      <div class="flex items-center">
        <span class="mr-2 text-sm text-gray-600">状态筛选：</span>
        <ElSelect
          v-model="statusFilter"
          placeholder="全部状态"
          style="width: 150px"
          @change="handleStatusChange"
          clearable
        >
          <ElOption label="已通过" value="APPROVED" />
          <ElOption label="已拒绝" value="REJECTED" />
        </ElSelect>
      </div>
    </div>

    <Table
      v-model:pageSize="pageSize"
      v-model:currentPage="currentPage"
      :columns="allSchemas.tableColumns"
      :data="dataList"
      :loading="loading"
      :pagination="{
        total: total
      }"
      @register="tableRegister"
    />

    <!-- 详情弹窗 -->
    <ElDialog v-model="detailDialogVisible" title="帖子详情" width="820px" destroy-on-close>
      <div v-if="currentPost" class="post-detail">
        <!-- 发布者信息 -->
        <div class="detail-section">
          <div class="detail-label">发布者</div>
          <div class="detail-content">
            <img :src="getImageUrl(currentPost.user?.avatar)" class="user-avatar" />
            <span>{{ getUserDisplayName(currentPost.user) }}</span>
          </div>
        </div>

        <!-- 帖子内容 -->
        <div class="detail-section">
          <div class="detail-label">内容</div>
          <div class="detail-content">{{ currentPost.content }}</div>
        </div>

        <!-- 图片 -->
        <div v-if="currentPost.images && currentPost.images.length > 0" class="detail-section">
          <div class="detail-label">图片</div>
          <div class="detail-content">
            <img
              v-for="(url, index) in currentPost.images"
              :key="index"
              :src="getImageUrl(url)"
              class="post-image"
            />
          </div>
        </div>

        <!-- 视频 -->
        <div v-if="currentPost.video" class="detail-section">
          <div class="detail-label">视频</div>
          <div class="detail-content">
            <div class="post-video-player">
              <VideoPlayer :url="getImageUrl(currentPost.video)" />
            </div>
          </div>
        </div>

        <!-- 标签 -->
        <div v-if="currentPost.tags && currentPost.tags.length > 0" class="detail-section">
          <div class="detail-label">标签</div>
          <div class="detail-content">
            <ElTag v-for="(tag, index) in currentPost.tags" :key="index" style="margin-right: 8px">
              {{ tag }}
            </ElTag>
          </div>
        </div>

        <!-- 状态 -->
        <div class="detail-section">
          <div class="detail-label">状态</div>
          <div class="detail-content">
            <ElTag v-if="currentPost.status === 'APPROVED'" type="success">已通过</ElTag>
            <ElTag v-else-if="currentPost.status === 'REJECTED'" type="danger">已拒绝</ElTag>
          </div>
        </div>

        <!-- 拒绝原因 -->
        <div v-if="currentPost.rejectReason" class="detail-section">
          <div class="detail-label">拒绝原因</div>
          <div class="detail-content">{{ currentPost.rejectReason }}</div>
        </div>

        <!-- 统计数据 -->
        <div class="detail-section">
          <div class="detail-label">统计数据</div>
          <div class="detail-content">
            <span class="mr-4">点赞：{{ currentPost.likeCount }}</span>
            <span class="mr-4">评论：{{ currentPost.commentCount }}</span>
            <span>浏览：{{ currentPost.viewCount }}</span>
          </div>
        </div>

        <!-- 发布时间 -->
        <div class="detail-section">
          <div class="detail-label">发布时间</div>
          <div class="detail-content">
            {{ new Date(currentPost.createdAt).toLocaleString('zh-CN') }}
          </div>
        </div>
      </div>

      <template #footer>
        <ElButton @click="detailDialogVisible = false">关闭</ElButton>
      </template>
    </ElDialog>
  </ContentWrap>
</template>

<style scoped lang="scss">
.mb-4 {
  margin-bottom: 16px;
}

.mr-2 {
  margin-right: 8px;
}

.mr-4 {
  margin-right: 16px;
}

.post-detail {
  .detail-section {
    margin-bottom: 20px;

    .detail-label {
      font-size: 14px;
      font-weight: 600;
      color: #606266;
      margin-bottom: 8px;
    }

    .detail-content {
      font-size: 14px;
      color: #303133;
      line-height: 1.6;
    }

    .user-avatar {
      width: 40px;
      height: 40px;
      border-radius: 50%;
      margin-right: 12px;
      vertical-align: middle;
    }

    .post-image {
      width: 120px;
      height: 120px;
      object-fit: cover;
      border-radius: 8px;
      margin-right: 8px;
      margin-bottom: 8px;
    }

    .post-video-player {
      width: 100%;
      max-width: 100%;
      overflow: hidden;
      border-radius: 8px;
    }

    .post-video-player:deep(.xgplayer) {
      width: 100% !important;
      max-width: 100% !important;
    }
  }
}
</style>
