<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { Table } from '@/components/Table'
import { useTable } from '@/hooks/web/useTable'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { extractPagedTableData } from '@/utils/pagination'
import { computed, reactive, ref, unref } from 'vue'
import {
  ElButton,
  ElDatePicker,
  ElDescriptions,
  ElDescriptionsItem,
  ElDivider,
  ElDrawer,
  ElForm,
  ElFormItem,
  ElImage,
  ElInput,
  ElMessage,
  ElMessageBox,
  ElOption,
  ElSelect,
  ElSpace,
  ElTag
} from 'element-plus'
import {
  getModerationReportDetailApi,
  getModerationReportsApi,
  handleModerationReportActionApi,
  updateModerationReportStatusApi,
  type ModerationReportAction,
  type ModerationReportReason,
  type ModerationReportStatus,
  type ModerationReportTargetType,
  type QueryModerationReportsParams,
  type ReportTargetSnapshot,
  type UGCReport
} from '@/api-new/moderation'
import { getImageUrl } from '@/utils/image'

type ReportTargetType = ModerationReportTargetType
type ReportReason = ModerationReportReason
type ReportStatus = ModerationReportStatus
type ReportAction = ModerationReportAction

const TARGET_TYPE_OPTIONS: Array<{ label: string; value: ReportTargetType }> = [
  { label: '社区帖子', value: 'COMMUNITY_POST' },
  { label: '社区评论', value: 'COMMUNITY_COMMENT' },
  { label: '走失/领养信息', value: 'LOST_FOUND_RECORD' },
  { label: '走失/领养评论', value: 'LOST_FOUND_COMMENT' },
  { label: '活动评论', value: 'ACTIVITY_COMMENT' },
  { label: '活动投票选手', value: 'ACTIVITY_VOTE_OPTION' },
  { label: '二手商品', value: 'SECOND_HAND_PRODUCT' },
  { label: '好友聊天消息', value: 'CHAT_MESSAGE' },
  { label: '用户', value: 'USER' }
]

const REASON_OPTIONS: Array<{ label: string; value: ReportReason }> = [
  { label: '骚扰辱骂', value: 'HARASSMENT' },
  { label: '色情低俗', value: 'PORNOGRAPHY' },
  { label: '暴力血腥', value: 'VIOLENCE' },
  { label: '诈骗欺诈', value: 'FRAUD' },
  { label: '垃圾广告', value: 'SPAM' },
  { label: '违法违规', value: 'ILLEGAL' },
  { label: '虚假误导', value: 'MISINFORMATION' },
  { label: '其他问题', value: 'OTHER' }
]

const STATUS_OPTIONS: Array<{ label: string; value: ReportStatus }> = [
  { label: '待处理', value: 'PENDING' },
  { label: '处理中', value: 'PROCESSING' },
  { label: '已处理', value: 'RESOLVED' },
  { label: '已驳回', value: 'REJECTED' }
]

const ACTION_OPTIONS: Array<{ label: string; value: ReportAction; danger?: boolean }> = [
  { label: '标记无效', value: 'NONE' },
  { label: '移除/下架内容', value: 'CONTENT_REMOVED', danger: true },
  { label: '记录警告用户', value: 'USER_WARNED' },
  { label: '屏蔽用户', value: 'USER_BLOCKED', danger: true },
  { label: '禁用账号', value: 'ACCOUNT_DISABLED', danger: true }
]

const targetTypeLabelMap = Object.fromEntries(
  TARGET_TYPE_OPTIONS.map((item) => [item.value, item.label])
) as Record<ReportTargetType, string>

const reasonLabelMap = Object.fromEntries(
  REASON_OPTIONS.map((item) => [item.value, item.label])
) as Record<ReportReason, string>

const statusLabelMap = Object.fromEntries(
  STATUS_OPTIONS.map((item) => [item.value, item.label])
) as Record<ReportStatus, string>

const actionLabelMap = Object.fromEntries(
  ACTION_OPTIONS.map((item) => [item.value, item.label])
) as Record<ReportAction, string>

const filterForm = reactive<{
  status: ReportStatus | ''
  targetType: ReportTargetType | ''
  reason: ReportReason | ''
  dateRange: string[]
}>({
  status: '',
  targetType: '',
  reason: '',
  dateRange: []
})

const drawerVisible = ref(false)
const detailLoading = ref(false)
const currentReport = ref<UGCReport | null>(null)
const handlingRemark = ref('')
const statusDraft = ref<ReportStatus>('PROCESSING')

const buildQueryParams = (): QueryModerationReportsParams => {
  return {
    status: filterForm.status || undefined,
    targetType: filterForm.targetType || undefined,
    reason: filterForm.reason || undefined,
    startTime: filterForm.dateRange?.[0],
    endTime: filterForm.dateRange?.[1]
  }
}

const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const { pageSize, currentPage } = tableState
    const res = await getModerationReportsApi({
      page: unref(currentPage),
      pageSize: unref(pageSize),
      ...buildQueryParams()
    })
    const normalized = extractPagedTableData<UGCReport>(res)

    return {
      list: normalized.list,
      total: normalized.total
    }
  }
})

const { total, loading, dataList, pageSize, currentPage } = tableState
const { getList } = tableMethods

const formatTime = (value?: string | null) => {
  if (!value) return '-'
  return new Date(value).toLocaleString('zh-CN')
}

const getUserName = (
  user?: { id: number; nickname?: string | null } | null,
  fallbackId?: number | null
) => {
  if (user?.nickname) return user.nickname
  if (user?.id) return `用户#${user.id}`
  if (fallbackId) return `用户#${fallbackId}`
  return '-'
}

const getStatusTagType = (status: ReportStatus) => {
  const map: Record<ReportStatus, 'primary' | 'success' | 'warning' | 'danger'> = {
    PENDING: 'warning',
    PROCESSING: 'primary',
    RESOLVED: 'success',
    REJECTED: 'danger'
  }

  return map[status]
}

const getActionTagType = (action: ReportAction) => {
  if (action === 'NONE') return 'info'
  if (action === 'CONTENT_REMOVED' || action === 'ACCOUNT_DISABLED') return 'danger'
  if (action === 'USER_BLOCKED') return 'warning'
  return 'success'
}

const reportSnapshot = computed<ReportTargetSnapshot | null>(() => {
  return currentReport.value?.targetSnapshot || null
})

const snapshotImages = computed(() => {
  return reportSnapshot.value?.images?.filter(Boolean) || []
})

const snapshotMetadataText = computed(() => {
  const metadata = reportSnapshot.value?.metadata
  return metadata ? JSON.stringify(metadata, null, 2) : ''
})

const refreshReportDetail = async (id: number) => {
  detailLoading.value = true
  try {
    const res = await getModerationReportDetailApi(id)
    currentReport.value = res.data
    statusDraft.value = res.data.status
  } finally {
    detailLoading.value = false
  }
}

const handleViewDetail = async (row: UGCReport) => {
  drawerVisible.value = true
  handlingRemark.value = row.handlingRemark || ''
  await refreshReportDetail(row.id)
}

const handleSearch = () => {
  currentPage.value = 1
  getList()
}

const handleReset = () => {
  filterForm.status = ''
  filterForm.targetType = ''
  filterForm.reason = ''
  filterForm.dateRange = []
  handleSearch()
}

const handleUpdateStatus = async () => {
  if (!currentReport.value) return

  try {
    await updateModerationReportStatusApi(currentReport.value.id, {
      status: statusDraft.value,
      remark: handlingRemark.value.trim() || undefined
    })
    ElMessage.success('状态已更新')
    await refreshReportDetail(currentReport.value.id)
    getList()
  } catch (error: any) {
    ElMessage.error(error?.message || '状态更新失败')
  }
}

const handleAction = async (action: ReportAction) => {
  if (!currentReport.value) return

  const actionLabel = actionLabelMap[action]
  const actionOption = ACTION_OPTIONS.find((item) => item.value === action)

  try {
    await ElMessageBox.confirm(`确认执行“${actionLabel}”？`, '处理举报', {
      type: actionOption?.danger ? 'warning' : 'info'
    })

    await handleModerationReportActionApi(currentReport.value.id, {
      action,
      remark: handlingRemark.value.trim() || undefined
    })
    ElMessage.success('处理动作已执行')
    await refreshReportDetail(currentReport.value.id)
    getList()
  } catch (error: any) {
    if (error === 'cancel' || error === 'close') return
    ElMessage.error(error?.message || '处理失败')
  }
}

const crudSchemas = reactive<CrudSchema[]>([
  {
    field: 'id',
    label: 'ID',
    search: { hidden: true },
    form: { hidden: true },
    table: { show: true, width: 80 }
  },
  {
    field: 'targetType',
    label: '目标类型',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 150,
      slots: {
        default: (data: any) => {
          const value = data.row.targetType as ReportTargetType
          return <ElTag>{targetTypeLabelMap[value] || value}</ElTag>
        }
      }
    }
  },
  {
    field: 'reason',
    label: '举报原因',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 130,
      slots: {
        default: (data: any) => {
          const value = data.row.reason as ReportReason
          return <ElTag type="danger">{reasonLabelMap[value] || value}</ElTag>
        }
      }
    }
  },
  {
    field: 'reporter',
    label: '举报人',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 140,
      slots: {
        default: (data: any) => {
          return <span>{getUserName(data.row.reporter, data.row.reporterId)}</span>
        }
      }
    }
  },
  {
    field: 'targetUser',
    label: '被举报用户',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 150,
      slots: {
        default: (data: any) => {
          return <span>{getUserName(data.row.targetUser, data.row.targetUserId)}</span>
        }
      }
    }
  },
  {
    field: 'status',
    label: '状态',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 160,
      slots: {
        default: (data: any) => {
          const status = data.row.status as ReportStatus
          return (
            <ElSpace>
              <ElTag type={getStatusTagType(status)}>{statusLabelMap[status]}</ElTag>
              {data.row.isOverdue ? <ElTag type="danger">超24小时</ElTag> : null}
            </ElSpace>
          )
        }
      }
    }
  },
  {
    field: 'action',
    label: '处理动作',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 140,
      slots: {
        default: (data: any) => {
          const action = data.row.action as ReportAction
          return <ElTag type={getActionTagType(action)}>{actionLabelMap[action] || action}</ElTag>
        }
      }
    }
  },
  {
    field: 'createdAt',
    label: '创建时间',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 180,
      slots: {
        default: (data: any) => <span>{formatTime(data.row.createdAt)}</span>
      }
    }
  },
  {
    field: 'handledAt',
    label: '处理时间',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 180,
      slots: {
        default: (data: any) => <span>{formatTime(data.row.handledAt)}</span>
      }
    }
  },
  {
    field: 'operation',
    label: '操作',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 120,
      fixed: 'right',
      slots: {
        default: (data: any) => {
          return (
            <ElButton type="primary" link onClick={() => handleViewDetail(data.row)}>
              详情
            </ElButton>
          )
        }
      }
    }
  }
])

const { allSchemas } = useCrudSchemas(crudSchemas)
</script>

<template>
  <ContentWrap>
    <ElForm :model="filterForm" inline class="report-filter-form">
      <ElFormItem label="状态">
        <ElSelect v-model="filterForm.status" clearable placeholder="全部状态" style="width: 140px">
          <ElOption
            v-for="item in STATUS_OPTIONS"
            :key="item.value"
            :label="item.label"
            :value="item.value"
          />
        </ElSelect>
      </ElFormItem>
      <ElFormItem label="目标">
        <ElSelect
          v-model="filterForm.targetType"
          clearable
          placeholder="全部目标"
          style="width: 170px"
        >
          <ElOption
            v-for="item in TARGET_TYPE_OPTIONS"
            :key="item.value"
            :label="item.label"
            :value="item.value"
          />
        </ElSelect>
      </ElFormItem>
      <ElFormItem label="原因">
        <ElSelect v-model="filterForm.reason" clearable placeholder="全部原因" style="width: 150px">
          <ElOption
            v-for="item in REASON_OPTIONS"
            :key="item.value"
            :label="item.label"
            :value="item.value"
          />
        </ElSelect>
      </ElFormItem>
      <ElFormItem label="时间">
        <ElDatePicker
          v-model="filterForm.dateRange"
          type="datetimerange"
          value-format="YYYY-MM-DD HH:mm:ss"
          start-placeholder="开始时间"
          end-placeholder="结束时间"
          style="width: 360px"
        />
      </ElFormItem>
      <ElFormItem>
        <ElButton type="primary" @click="handleSearch">查询</ElButton>
        <ElButton @click="handleReset">重置</ElButton>
      </ElFormItem>
    </ElForm>

    <Table
      v-model:pageSize="pageSize"
      v-model:currentPage="currentPage"
      :columns="allSchemas.tableColumns"
      :data="dataList"
      :loading="loading"
      :pagination="{ total }"
      @register="tableRegister"
    />

    <ElDrawer v-model="drawerVisible" title="举报详情" size="44%">
      <div v-if="currentReport" v-loading="detailLoading" class="report-detail">
        <ElDescriptions :column="2" border>
          <ElDescriptionsItem label="举报ID">{{ currentReport.id }}</ElDescriptionsItem>
          <ElDescriptionsItem label="状态">
            <ElTag :type="getStatusTagType(currentReport.status)">
              {{ statusLabelMap[currentReport.status] }}
            </ElTag>
            <ElTag v-if="currentReport.isOverdue" type="danger" class="ml-8">超24小时</ElTag>
          </ElDescriptionsItem>
          <ElDescriptionsItem label="目标类型">
            {{ targetTypeLabelMap[currentReport.targetType] }}
          </ElDescriptionsItem>
          <ElDescriptionsItem label="目标ID">{{ currentReport.targetId }}</ElDescriptionsItem>
          <ElDescriptionsItem label="举报原因">
            {{ reasonLabelMap[currentReport.reason] }}
          </ElDescriptionsItem>
          <ElDescriptionsItem label="处理动作">
            {{ actionLabelMap[currentReport.action] }}
          </ElDescriptionsItem>
          <ElDescriptionsItem label="举报人">
            {{ getUserName(currentReport.reporter, currentReport.reporterId) }}
          </ElDescriptionsItem>
          <ElDescriptionsItem label="被举报用户">
            {{ getUserName(currentReport.targetUser, currentReport.targetUserId) }}
          </ElDescriptionsItem>
          <ElDescriptionsItem label="创建时间">
            {{ formatTime(currentReport.createdAt) }}
          </ElDescriptionsItem>
          <ElDescriptionsItem label="处理时间">
            {{ formatTime(currentReport.handledAt) }}
          </ElDescriptionsItem>
          <ElDescriptionsItem label="处理人">
            {{ getUserName(currentReport.handler, currentReport.handledBy) }}
          </ElDescriptionsItem>
        </ElDescriptions>

        <ElDivider>举报说明</ElDivider>
        <p class="detail-text">{{ currentReport.description || '用户未填写补充说明' }}</p>

        <ElDivider>目标快照</ElDivider>
        <ElDescriptions :column="1" border>
          <ElDescriptionsItem label="标题">{{ reportSnapshot?.title || '-' }}</ElDescriptionsItem>
          <ElDescriptionsItem label="摘要">{{ reportSnapshot?.summary || '-' }}</ElDescriptionsItem>
          <ElDescriptionsItem label="作者">
            {{ getUserName(reportSnapshot?.author, reportSnapshot?.author?.id) }}
          </ElDescriptionsItem>
        </ElDescriptions>

        <div v-if="snapshotImages.length" class="snapshot-images">
          <ElImage
            v-for="image in snapshotImages"
            :key="image"
            :src="getImageUrl(image)"
            :preview-src-list="snapshotImages.map((item) => getImageUrl(item))"
            fit="cover"
            class="snapshot-image"
          />
        </div>

        <pre v-if="snapshotMetadataText" class="metadata-block">{{ snapshotMetadataText }}</pre>

        <ElDivider>处理备注</ElDivider>
        <ElInput
          v-model="handlingRemark"
          type="textarea"
          :rows="3"
          maxlength="500"
          show-word-limit
          placeholder="填写处理说明，便于后续审计"
        />

        <div class="status-row">
          <ElSelect v-model="statusDraft" style="width: 160px">
            <ElOption
              v-for="item in STATUS_OPTIONS"
              :key="item.value"
              :label="item.label"
              :value="item.value"
            />
          </ElSelect>
          <ElButton type="primary" @click="handleUpdateStatus">更新状态</ElButton>
        </div>

        <ElDivider>处理动作</ElDivider>
        <ElSpace wrap>
          <ElButton
            v-for="item in ACTION_OPTIONS"
            :key="item.value"
            :type="item.danger ? 'danger' : 'primary'"
            plain
            @click="handleAction(item.value)"
          >
            {{ item.label }}
          </ElButton>
        </ElSpace>
      </div>
    </ElDrawer>
  </ContentWrap>
</template>

<style scoped lang="less">
.report-filter-form {
  margin-bottom: 12px;
}

.report-detail {
  padding-right: 8px;
}

.detail-text {
  margin: 0;
  color: #374151;
  line-height: 1.7;
  white-space: pre-wrap;
}

.snapshot-images {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-top: 12px;
}

.snapshot-image {
  width: 96px;
  height: 96px;
  border-radius: 6px;
  overflow: hidden;
}

.metadata-block {
  margin-top: 12px;
  padding: 12px;
  border-radius: 6px;
  background: #f8fafc;
  color: #334155;
  white-space: pre-wrap;
}

.status-row {
  display: flex;
  gap: 12px;
  align-items: center;
  margin-top: 12px;
}

.ml-8 {
  margin-left: 8px;
}
</style>
