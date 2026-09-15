<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { Table } from '@/components/Table'
import { ref, unref, reactive } from 'vue'
import { ElTag, ElMessage, ElMessageBox, ElDialog, ElButton, ElInput } from 'element-plus'
import { getPendingReviewApi, approvePostApi, rejectPostApi, type Post } from '@/api/community'
import { useTable } from '@/hooks/web/useTable'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { BaseButton } from '@/components/Button'
import { getImageUrl } from '@/utils/image'
import { VideoPlayer } from '@/components/VideoPlayer'

/**
 * 解析发布者展示名称
 * 社区后台当前类型只保证 nickname 存在，因此优先展示昵称，避免继续依赖未声明的 phone 字段
 */
const getUserDisplayName = (user?: Post['user']) => {
  if (!user) return '未知用户'
  return user.nickname || `用户#${user.id}`
}

const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const { pageSize, currentPage } = tableState
    const res = await getPendingReviewApi({
      page: unref(currentPage),
      pageSize: unref(pageSize)
    })

    return {
      list: Array.isArray(res.data) ? res.data : [],
      total: res.meta?.total || 0
    }
  }
})
const { total, loading, dataList, pageSize, currentPage } = tableState
const { getList } = tableMethods

// 详情弹窗
const detailDialogVisible = ref(false)
const currentPost = ref<Post | null>(null)

// 拒绝原因弹窗
const rejectDialogVisible = ref(false)
const rejectPostId = ref<number | null>(null)
const rejectReason = ref('')

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
        // 只显示文本内容的前50个字符
        const content = data.row.content || ''
        return <span>{content.length > 50 ? content.substring(0, 50) + '...' : content}</span>
      }
    }
  },
  {
    field: 'images',
    label: '图片/视频',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    width: 150,
    slots: {
      default: (data: any) => {
        const { images, video } = data.row
        if (video) {
          return <ElTag type="warning">视频</ElTag>
        }
        if (images && images.length > 0) {
          return (
            <span>
              {images.slice(0, 3).map((url: string, i: number) => (
                <img
                  key={i}
                  src={getImageUrl(url)}
                  style="width: 40px; height: 40px; object-fit: cover; border-radius: 4px; margin-right: 4px;"
                />
              ))}
              {images.length > 3 && <span>...</span>}
            </span>
          )
        }
        return <span>-</span>
      }
    }
  },
  {
    field: 'tags',
    label: '标签',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    width: 150,
    slots: {
      default: (data: any) => {
        const tags = data.row.tags
        if (!tags || tags.length === 0) {
          return <span>-</span>
        }
        return (
          <span>
            {tags.slice(0, 3).map((tag: string, i: number) => (
              <ElTag key={i} size="small" style="margin-right: 4px;">
                {tag}
              </ElTag>
            ))}
            {tags.length > 3 && <span>+{tags.length - 3}</span>}
          </span>
        )
      }
    }
  },
  {
    field: 'detectedSensitiveWords',
    label: '敏感词标记',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    width: 120,
    slots: {
      default: (data: any) => {
        const words = data.row.detectedSensitiveWords
        if (words && words.length > 0) {
          return <ElTag type="danger">检测到敏感词</ElTag>
        }
        return <span>-</span>
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
    width: 280,
    slots: {
      default: (data: any) => {
        return (
          <>
            <BaseButton type="primary" link onClick={() => handleViewDetail(data.row)}>
              查看
            </BaseButton>
            <BaseButton type="success" link onClick={() => handleApprove(data.row.id)}>
              通过
            </BaseButton>
            <BaseButton type="danger" link onClick={() => handleReject(data.row.id)}>
              拒绝
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

// 审核通过
const handleApprove = async (id: number) => {
  try {
    await ElMessageBox.confirm('确认审核通过该帖子？', '操作确认', {
      type: 'warning'
    })
    await approvePostApi(id)
    ElMessage.success('审核通过')
    getList()
  } catch (error) {
    // 用户取消操作
  }
}

// 审核拒绝 - 打开输入框
const handleReject = (id: number) => {
  rejectPostId.value = id
  rejectReason.value = ''
  rejectDialogVisible.value = true
}

// 确认拒绝
const handleConfirmReject = async () => {
  if (!rejectReason.value.trim()) {
    ElMessage.warning('请输入拒绝原因')
    return
  }
  try {
    await rejectPostApi(rejectPostId.value!, rejectReason.value)
    ElMessage.success('已拒绝')
    rejectDialogVisible.value = false
    getList()
  } catch (error) {
    ElMessage.error('操作失败')
  }
}
</script>

<template>
  <ContentWrap>
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

        <!-- 敏感词标记 -->
        <div
          v-if="currentPost.detectedSensitiveWords && currentPost.detectedSensitiveWords.length > 0"
          class="detail-section"
        >
          <div class="detail-label">敏感词标记</div>
          <div class="detail-content">
            <ElTag type="danger" effect="dark">
              检测到 {{ currentPost.detectedSensitiveWords.length }} 个敏感词
            </ElTag>
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

    <!-- 拒绝原因弹窗 -->
    <ElDialog v-model="rejectDialogVisible" title="拒绝原因" width="400px" destroy-on-close>
      <ElInput
        v-model="rejectReason"
        type="textarea"
        :rows="4"
        placeholder="请输入拒绝原因（必填）"
        maxlength="500"
        show-word-limit
      />
      <template #footer>
        <ElButton @click="rejectDialogVisible = false">取消</ElButton>
        <ElButton type="primary" @click="handleConfirmReject">确认拒绝</ElButton>
      </template>
    </ElDialog>
  </ContentWrap>
</template>

<style scoped lang="scss">
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
