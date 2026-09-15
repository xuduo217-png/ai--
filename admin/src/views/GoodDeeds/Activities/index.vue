<script setup lang="tsx">
import { computed, nextTick, ref, unref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  ElTag,
  ElMessage,
  ElMessageBox,
  ElButton,
  ElTable,
  ElTableColumn,
  ElInput,
  ElCard,
  ElDrawer,
  ElImage,
  ElEmpty,
  ElPagination,
  ElProgress,
  ElUpload,
  ElSwitch
} from 'element-plus'
import type { UploadFile } from 'element-plus'
import { Table } from '@/components/Table'
import { ContentWrap } from '@/components/ContentWrap'
import { Search } from '@/components/Search'
import { useTable } from '@/hooks/web/useTable'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { BaseButton } from '@/components/Button'
import { Dialog } from '@/components/Dialog'
import { Form } from '@/components/Form'
import { Icon } from '@/components/Icon'
import { useForm } from '@/hooks/web/useForm'
import {
  type ActivityFormData,
  type ActivityItem,
  type ActivityComment,
  type ActivityRegistration,
  type ActivityVoteOption,
  getActivityDetailAdminApi,
  getActivityListAdminApi,
  createActivityApi,
  updateActivityApi,
  deleteActivityApi,
  getActivityRegistrationsApi,
  getActivityCommentsAdminApi,
  deleteActivityCommentAdminApi
} from '@/api-new/activities'
import { getHospitalListApi } from '@/api-new/hospitals/hospital'
import type { Hospital } from '@/api-new/hospitals'
import { formatToDateTime } from '@/utils/dateUtil'
import { extractUploadPath, getImageUrl } from '@/utils/image'
import { ImageUpload } from '@/components/ImageUpload'
import { uploadVideoApi } from '@/api-new/upload'
import { createVideoViewer } from '@/components/VideoPlayer'
import {
  VIDEO_UPLOAD_ACCEPT,
  getUploadErrorMessage,
  getUploadMediaValidationError
} from '@/utils/upload'

defineOptions({
  name: 'Activities'
})

const route = useRoute()
const router = useRouter()

type HospitalOption = {
  id: number
  name: string
  logo?: string
  city?: string
  address?: string
  phone?: string
}

type ActivityVoteOptionEditor = ActivityVoteOption & {
  videoUploading?: boolean
  videoUploadProgress?: number
}

// 医院选择弹窗
const hospitalSelectDialogVisible = ref(false)
const selectedHospital = ref<HospitalOption | null>(null)
const hospitalSearchKeyword = ref('')
const hospitalList = ref<Hospital[]>([])
const hospitalLoading = ref(false)
const hospitalPagination = ref({
  page: 1,
  pageSize: 20,
  total: 0
})

const defaultSearchParams = {
  deleteStatus: 'active'
}

const normalizeSearchParams = (params: Record<string, any> = {}) => {
  return Object.fromEntries(
    Object.entries({
      ...defaultSearchParams,
      ...params
    }).filter(([, value]) => value !== '' && value !== undefined && value !== null)
  )
}

// 搜索参数
const searchParams = ref<Record<string, any>>({ ...defaultSearchParams })

// 设置搜索参数
const setSearchParams = (params: any) => {
  searchParams.value = normalizeSearchParams(params)
  currentPage.value = 1
  getList()
}

// 表格相关
const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const { pageSize, currentPage } = tableState
    const res = await getActivityListAdminApi({
      page: unref(currentPage),
      pageSize: unref(pageSize),
      ...unref(searchParams)
    })

    return {
      list: res.data || [],
      total: res.pagination?.total || 0
    }
  }
})

const { total, loading, dataList, pageSize, currentPage } = tableState
const { getList } = tableMethods

// 活动表单页面
const currentRow = ref<ActivityItem | null>(null)
const saveLoading = ref(false)
const formLoading = ref(false)
const isActivityFormPage = computed(
  () => route.name === 'ActivityCreate' || route.name === 'ActivityEdit'
)
const isActivityEditPage = computed(() => route.name === 'ActivityEdit')
const formPageTitle = computed(() => (isActivityEditPage.value ? '编辑活动' : '新增活动'))

// 报名列表对话框
const registrationsDialogVisible = ref(false)
const registrationsDialogTitle = ref('报名用户列表')
const registrationsTimeLabel = ref('报名时间')
const registrationsData = ref<ActivityRegistration[]>([])
const registrationsLoading = ref(false)
const registrationsTotal = ref(0)
const registrationsPage = ref(1)
const registrationsPageSize = ref(10)
const currentRegistrationsActivityId = ref<number | null>(null)
const currentRegistrationsVoteOptionId = ref<number | undefined>(undefined)

// 投票详情对话框
const voteDetailsDialogVisible = ref(false)
const voteDetailsDialogTitle = ref('投票详情')
const voteDetailsActivity = ref<ActivityItem | null>(null)
const voteDetailsOptions = ref<ActivityVoteOption[]>([])

// 评论抽屉
const commentsDrawerVisible = ref(false)
const commentsDrawerTitle = ref('评论列表')
const commentsData = ref<ActivityComment[]>([])
const commentsLoading = ref(false)
const commentsTotal = ref(0)
const commentsPage = ref(1)
const commentsPageSize = ref(10)
const currentCommentsActivity = ref<ActivityItem | null>(null)

// 当前表单中活动类型（控制字段显隐）
const currentFormActivityType = ref<'OFFLINE' | 'ONLINE'>('OFFLINE')
const voteOptions = ref<ActivityVoteOptionEditor[]>([])
const VOTE_OPTION_VIDEO_MAX_SIZE_MB = 100

// 表单
const { formRegister, formMethods } = useForm()
const { setValues, getFormData, getElFormExpose } = formMethods

/**
 * 规范化活动表单数据
 * 这里显式收口字段，避免 Form 组件返回的宽泛对象与 API 契约继续漂移。
 */
const buildActivityPayload = (formData: Recordable<any>): ActivityFormData => {
  const hospitalId = Number(formData.hospitalId ?? selectedHospital.value?.id)
  const activityType: 'OFFLINE' | 'ONLINE' = formData.activityType ?? 'OFFLINE'

  const base = {
    title: String(formData.title ?? '').trim(),
    startTime: String(formData.startTime ?? ''),
    endTime: String(formData.endTime ?? ''),
    summary: String(formData.summary ?? '').trim(),
    description: String(formData.description ?? '').trim(),
    coverImage: formData.coverImage ? String(formData.coverImage) : undefined,
    sharePosterImage: String(formData.sharePosterImage ?? '').trim(),
    sharePosterTitle: String(formData.sharePosterTitle ?? '').trim(),
    sharePosterDescription: String(formData.sharePosterDescription ?? '').trim(),
    showOnHome: Boolean(formData.showOnHome),
    hospitalId,
    activityType
  }

  if (activityType === 'OFFLINE') {
    return {
      ...base,
      location: String(formData.location ?? '').trim()
    }
  }

  return {
    ...base,
    voteOptions: voteOptions.value.map((option, index) => ({
      id: option.id,
      image: String(option.image ?? '').trim(),
      video: String(option.video ?? '').trim(),
      videoCover: String(option.videoCover ?? '').trim(),
      title: String(option.title ?? '').trim(),
      description: String(option.description ?? '').trim(),
      voteCount: Number(option.voteCount ?? 0),
      sortOrder: index,
      ownerUserId: option.ownerUserId ?? null
    }))
  }
}

const createEmptyVoteOption = (): ActivityVoteOptionEditor => ({
  image: '',
  video: '',
  videoCover: '',
  title: '',
  description: '',
  voteCount: 0,
  sortOrder: voteOptions.value.length
})

const handleAddVoteOption = () => {
  voteOptions.value.push(createEmptyVoteOption())
}

const handleRemoveVoteOption = (index: number) => {
  voteOptions.value.splice(index, 1)
}

const validateVoteOptionVideoFile = (file?: File): file is File => {
  if (!file) return false

  const validationError = getUploadMediaValidationError(file, 'video')
  if (validationError) {
    ElMessage.error(validationError)
    return false
  }

  const maxSizeBytes = VOTE_OPTION_VIDEO_MAX_SIZE_MB * 1024 * 1024
  if (file.size > maxSizeBytes) {
    ElMessage.error(`视频大小不能超过 ${VOTE_OPTION_VIDEO_MAX_SIZE_MB}MB`)
    return false
  }

  return true
}

const handleVoteOptionVideoChange = async (
  row: ActivityVoteOptionEditor,
  uploadFile: UploadFile
) => {
  const file = uploadFile.raw
  if (!validateVoteOptionVideoFile(file)) return

  row.videoUploading = true
  row.videoUploadProgress = 0

  try {
    const formData = new FormData()
    formData.append('file', file, file.name)
    formData.append('category', 'activity-vote-option-video')

    const response = await uploadVideoApi(formData, {
      onUploadProgress: (progressEvent) => {
        if (progressEvent.total) {
          row.videoUploadProgress = Math.round((progressEvent.loaded / progressEvent.total) * 100)
        }
      }
    })

    const uploadedUrl = response.data?.url?.trim()
    if (!uploadedUrl) throw new Error('上传失败：服务器未返回视频地址')
    row.video = extractUploadPath(uploadedUrl) || uploadedUrl
    row.videoCover = extractUploadPath(response.data.thumbnail) || response.data.thumbnail || ''
    row.videoUploadProgress = 100
    ElMessage.success('视频上传成功')
  } catch (error) {
    console.error('选手视频上传失败:', error)
    if (error instanceof Error) {
      ElMessage.error(getUploadErrorMessage(error, '视频上传失败'))
    }
  } finally {
    row.videoUploading = false
    row.videoUploadProgress = 0
  }
}

const handlePreviewVoteOptionVideo = (row: ActivityVoteOption) => {
  if (!row.video) return

  createVideoViewer({
    url: getImageUrl(row.video)
  })
}

const handleRemoveVoteOptionVideo = (row: ActivityVoteOptionEditor) => {
  row.video = ''
  row.videoCover = ''
  ElMessage.success('视频已删除')
}

const renderVoteOptionsEditor = () => {
  return (
    <div class="vote-options-panel">
      <div class="vote-options-header">
        <div class="vote-options-tip">
          选手可稍后添加；已添加的选手需要填写标题，图片和视频至少上传一个。
        </div>
        <BaseButton type="primary" onClick={handleAddVoteOption}>
          新增选手
        </BaseButton>
      </div>

      <ElTable data={voteOptions.value} border>
        <ElTableColumn label="图片" width={280}>
          {{
            default: ({ row }: { row: ActivityVoteOption }) => (
              <div class="vote-option-image-cell" style={{ width: '260px' }}>
                <ImageUpload
                  modelValue={row.image}
                  {...{
                    'onUpdate:modelValue': (value: string) => {
                      row.image = value
                    }
                  }}
                  aspectRatio={1}
                  cropBoxWidth={320}
                  cropBoxHeight={320}
                  previewWidth={200}
                  previewHeight={120}
                  category="activity-vote-option"
                  placeholder="选手图片"
                  directUpload={true}
                />
              </div>
            )
          }}
        </ElTableColumn>
        <ElTableColumn label="视频" width={340}>
          {{
            default: ({ row }: { row: ActivityVoteOptionEditor }) => (
              <div class="vote-option-video-cell" style={{ width: '320px' }}>
                {row.video ? (
                  <div
                    class="vote-option-video-preview"
                    style={{
                      position: 'relative',
                      width: '100%',
                      height: '120px',
                      maxHeight: '120px',
                      overflow: 'hidden',
                      border: '1px dashed var(--el-border-color)',
                      borderRadius: '6px',
                      background: 'var(--el-fill-color-light)'
                    }}
                  >
                    <video
                      class="vote-option-video-thumb"
                      src={getImageUrl(row.video)}
                      poster={row.videoCover ? getImageUrl(row.videoCover) : undefined}
                      style={{
                        display: 'block',
                        width: '100%',
                        height: '100%',
                        objectFit: 'cover',
                        pointerEvents: 'none'
                      }}
                      preload="metadata"
                      muted
                      playsinline
                    />
                    <div
                      class="vote-option-video-mask"
                      style={{
                        position: 'absolute',
                        inset: 0,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        gap: '24px',
                        background: 'rgba(0, 0, 0, 0.6)',
                        color: '#fff',
                        transition: 'opacity 0.3s',
                        fontSize: '14px'
                      }}
                    >
                      <div
                        class="vote-option-video-mask-actions"
                        style={{
                          display: 'flex',
                          flexDirection: 'row',
                          alignItems: 'center',
                          justifyContent: 'center',
                          gap: '24px'
                        }}
                      >
                        <div
                          class="vote-option-video-action"
                          style={{
                            display: 'flex',
                            flexDirection: 'column',
                            alignItems: 'center',
                            gap: '4px',
                            cursor: 'pointer',
                            color: '#fff'
                          }}
                          onClick={() => handlePreviewVoteOptionVideo(row)}
                        >
                          <Icon icon="vi-ep:view" />
                          <span>预览</span>
                        </div>
                        <div
                          class="vote-option-video-action"
                          style={{
                            display: 'flex',
                            flexDirection: 'column',
                            alignItems: 'center',
                            gap: '4px',
                            cursor: 'pointer',
                            color: '#fff'
                          }}
                          onClick={() => handleRemoveVoteOptionVideo(row)}
                        >
                          <Icon icon="vi-ep:delete" class="delete-icon" />
                          <span>删除</span>
                        </div>
                      </div>
                      <ElUpload
                        action=""
                        accept={VIDEO_UPLOAD_ACCEPT}
                        autoUpload={false}
                        showFileList={false}
                        disabled={row.videoUploading}
                        onChange={(uploadFile: UploadFile) => {
                          void handleVoteOptionVideoChange(row, uploadFile)
                        }}
                      >
                        <div
                          class="vote-option-video-action"
                          style={{
                            display: 'flex',
                            flexDirection: 'column',
                            alignItems: 'center',
                            gap: '4px',
                            cursor: 'pointer',
                            color: '#fff'
                          }}
                        >
                          <Icon icon={row.videoUploading ? 'vi-ep:loading' : 'vi-ep:zoom-in'} />
                          <span>更换</span>
                        </div>
                      </ElUpload>
                    </div>
                    {row.videoUploading ? (
                      <ElProgress
                        class="vote-option-video-progress"
                        percentage={row.videoUploadProgress ?? 0}
                        showText={false}
                        strokeWidth={4}
                      />
                    ) : null}
                  </div>
                ) : (
                  <ElUpload
                    action=""
                    accept={VIDEO_UPLOAD_ACCEPT}
                    autoUpload={false}
                    showFileList={false}
                    disabled={row.videoUploading}
                    onChange={(uploadFile: UploadFile) => {
                      void handleVoteOptionVideoChange(row, uploadFile)
                    }}
                  >
                    <div class="vote-option-video-placeholder">
                      <span>{row.videoUploading ? '上传中...' : '上传视频'}</span>
                    </div>
                  </ElUpload>
                )}
                {row.videoUploading && !row.video ? (
                  <ElProgress
                    percentage={row.videoUploadProgress ?? 0}
                    showText={false}
                    strokeWidth={4}
                  />
                ) : null}
              </div>
            )
          }}
        </ElTableColumn>
        <ElTableColumn label="标题" minWidth={180}>
          {{
            default: ({ row }: { row: ActivityVoteOption }) => (
              <ElInput
                modelValue={row.title}
                {...{
                  'onUpdate:modelValue': (value: string) => {
                    row.title = value
                  }
                }}
                placeholder="请输入选手标题"
              />
            )
          }}
        </ElTableColumn>
        <ElTableColumn label="描述" minWidth={260}>
          {{
            default: ({ row }: { row: ActivityVoteOption }) => (
              <ElInput
                modelValue={row.description}
                {...{
                  'onUpdate:modelValue': (value: string) => {
                    row.description = value
                  }
                }}
                type="textarea"
                rows={3}
                placeholder="请输入选手描述"
              />
            )
          }}
        </ElTableColumn>
        <ElTableColumn label="操作" width={100}>
          {{
            default: ({ $index }: { $index: number }) => (
              <ElButton type="danger" link onClick={() => handleRemoveVoteOption($index)}>
                删除
              </ElButton>
            )
          }}
        </ElTableColumn>
      </ElTable>
    </div>
  )
}

const resetVoteOptions = (options?: ActivityVoteOption[]) => {
  voteOptions.value =
    options && options.length > 0
      ? options.map((option, index) => ({
          id: option.id,
          activityId: option.activityId,
          image: option.image ?? '',
          video: option.video ?? '',
          videoCover: option.videoCover ?? '',
          title: option.title ?? '',
          description: option.description ?? '',
          voteCount: Number(option.voteCount ?? 0),
          sortOrder: option.sortOrder ?? index,
          ownerUserId: option.ownerUserId ?? null
        }))
      : []
}

/**
 * 加载医院列表
 */
const loadHospitalList = async () => {
  try {
    hospitalLoading.value = true
    const res = await getHospitalListApi({
      page: hospitalPagination.value.page,
      pageSize: hospitalPagination.value.pageSize,
      name: hospitalSearchKeyword.value || undefined
    })

    hospitalList.value = res.data || []
    hospitalPagination.value.total = res.pagination?.total || 0
  } catch (error) {
    console.error('加载医院列表失败:', error)
    ElMessage.error('加载医院列表失败')
  } finally {
    hospitalLoading.value = false
  }
}

/**
 * 医院列表分页变化
 */
const handleHospitalPageChange = (page: number) => {
  hospitalPagination.value.page = page
  loadHospitalList()
}

/**
 * 打开医院选择弹窗
 */
const openHospitalSelectDialog = () => {
  hospitalSearchKeyword.value = ''
  hospitalPagination.value.page = 1
  loadHospitalList()
  hospitalSelectDialogVisible.value = true
}

/**
 * 选择医院
 */
const handleSelectHospital = (hospital: any) => {
  selectedHospital.value = hospital
  hospitalSelectDialogVisible.value = false

  // 更新表单中的医院ID
  setValues({
    hospitalId: hospital.id
  })
}

/**
 * 清除选择的医院
 */
const handleClearHospital = () => {
  selectedHospital.value = null
  selectedHospitalText.value = '请选择医院'
  setValues({
    hospitalId: undefined
  })
}

/**
 * 搜索医院
 */
const handleHospitalSearch = () => {
  hospitalPagination.value.page = 1
  loadHospitalList()
}

// 当前选中的医院显示文本
const selectedHospitalText = ref('请选择医院')

// 监听医院选择变化，更新显示文本
watch(
  selectedHospital,
  (newHospital) => {
    if (newHospital) {
      selectedHospitalText.value = newHospital.name
    } else {
      selectedHospitalText.value = '请选择医院'
    }
  },
  { immediate: true }
)

/**
 * 获取状态标签类型
 */
const getStatusType = (status: string) => {
  const map: Record<string, any> = {
    UPCOMING: 'info',
    ONGOING: 'success',
    EXPIRED: 'danger'
  }
  return map[status] || 'info'
}

/**
 * 获取状态文本
 */
const getStatusText = (status: string) => {
  const map: Record<string, string> = {
    UPCOMING: '未开始',
    ONGOING: '进行中',
    EXPIRED: '已结束'
  }
  return map[status] || status
}

/**
 * 获取删除状态标签
 */
const getDeleteStatusTag = (deletedAt?: string | null) => {
  return deletedAt ? <ElTag type="danger">已删除</ElTag> : <ElTag type="success">未删除</ElTag>
}

const handleShowOnHomeChange = async (row: ActivityItem, value: boolean) => {
  const previousValue = Boolean(row.showOnHome)
  row.showOnHome = value

  try {
    await updateActivityApi(row.id, { showOnHome: value })
    ElMessage.success(value ? '已展示到首页' : '已取消首页展示')
  } catch (error: any) {
    row.showOnHome = previousValue
    console.error('更新首页展示状态失败:', error)
    ElMessage.error(error.message || '更新首页展示状态失败')
  }
}

/**
 * 格式化时间戳为日期字符串
 */
const formatTimestamp = (timestamp: number) => {
  if (!timestamp) return ''
  const date = new Date(timestamp * 1000)
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

const formatCommentTime = (value?: string) => {
  if (!value) return '-'
  return formatToDateTime(value)
}

/**
 * 报名时间由后端 bigint 字段返回时可能是数字字符串，先转为毫秒时间戳再格式化。
 */
const formatRegistrationTime = (value?: number | string) => {
  if (value === undefined || value === null || value === '') return '-'
  const timestamp = Number(value)
  return Number.isFinite(timestamp) ? formatToDateTime(timestamp) : '-'
}

// CRUD Schema 定义
const crudSchemas: CrudSchema[] = [
  {
    field: 'index',
    label: '序号',
    form: { hidden: true },
    search: { hidden: true },
    table: { type: 'index', width: 60 }
  },
  {
    field: 'hospitalId',
    label: '所属医院',
    search: {
      component: 'Input',
      componentProps: {
        placeholder: '输入医院名称搜索'
      }
    },
    form: {
      component: 'Input',
      componentProps: {},
      formItemProps: {
        slots: {
          default: () => {
            return (
              <div style="display: flex; flex-direction: column; gap: 12px; width: 100%;">
                {/* 选择按钮区域 */}
                <div style="display: flex; gap: 8px; align-items: center;">
                  <div style="flex: 1; cursor: pointer;" onClick={openHospitalSelectDialog}>
                    <ElInput
                      model-value={selectedHospitalText.value}
                      placeholder="请选择医院"
                      readonly
                      style="width: 100%;"
                    >
                      {{
                        append: () => (
                          <BaseButton onClick={openHospitalSelectDialog}>选择医院</BaseButton>
                        )
                      }}
                    </ElInput>
                  </div>
                  {selectedHospital.value && (
                    <BaseButton type="danger" onClick={handleClearHospital}>
                      清除
                    </BaseButton>
                  )}
                </div>
                {/* 已选医院预览 */}
                {selectedHospital.value && (
                  <div style="padding: 12px; border: 1px solid #e4e7ed; border-radius: 4px; display: flex; gap: 12px; align-items: center;">
                    <ElImage
                      src={getImageUrl(selectedHospital.value.logo)}
                      style={{
                        width: '80px',
                        height: '80px',
                        borderRadius: '4px',
                        objectFit: 'cover'
                      }}
                      fit="cover"
                    />
                    <div style={{ flex: 1, lineHeight: 1.6 }}>
                      <div style={{ fontWeight: 'bold', fontSize: '16px', marginBottom: '4px' }}>
                        {selectedHospital.value.name}
                      </div>
                      <div style={{ fontSize: '13px', color: '#606266', marginBottom: '4px' }}>
                        📍 {selectedHospital.value.city || '-'}{' '}
                        {selectedHospital.value.address || ''}
                      </div>
                      <div style={{ fontSize: '13px', color: '#909399' }}>
                        联系电话: {selectedHospital.value.phone || '-'}
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )
          }
        }
      },
      colProps: {
        span: 24
      }
    },
    table: {
      show: true,
      width: 200,
      slots: {
        default: (data: any) => {
          return <span>{data.row.hospitalName || '-'}</span>
        }
      }
    }
  },
  {
    field: 'startDate',
    label: '开始日期',
    search: {
      component: 'DatePicker',
      componentProps: {
        type: 'date',
        format: 'YYYY-MM-DD',
        valueFormat: 'YYYY-MM-DD',
        placeholder: '选择开始日期'
      }
    },
    form: { hidden: true },
    table: { hidden: true }
  },
  {
    field: 'status',
    label: '活动状态',
    search: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '全部', value: '' },
          { label: '未开始', value: 'UPCOMING' },
          { label: '进行中', value: 'ONGOING' },
          { label: '已结束', value: 'EXPIRED' }
        ]
      }
    },
    form: { hidden: true },
    table: {
      show: true,
      width: 100,
      slots: {
        default: (data: any) => {
          return (
            <ElTag type={getStatusType(data.row.status)}>{getStatusText(data.row.status)}</ElTag>
          )
        }
      }
    }
  },
  {
    field: 'deleteStatus',
    label: '删除状态',
    search: {
      component: 'Select',
      value: defaultSearchParams.deleteStatus,
      componentProps: {
        options: [
          { label: '未删除', value: 'active' },
          { label: '已删除', value: 'deleted' },
          { label: '全部', value: 'all' }
        ]
      }
    },
    form: { hidden: true },
    table: {
      show: true,
      width: 100,
      slots: {
        default: (data: any) => {
          return getDeleteStatusTag(data.row.deletedAt)
        }
      }
    }
  },
  {
    field: 'title',
    label: '活动名称',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入活动名称'
      },
      colProps: {
        span: 24
      },
      formItemProps: {
        rules: [{ required: true, message: '请输入活动名称', trigger: 'blur' }]
      }
    },
    table: {
      show: true
    }
  },
  {
    field: 'startTime',
    label: '开始日期',
    search: { hidden: true },
    form: {
      component: 'DatePicker',
      componentProps: {
        type: 'date',
        format: 'YYYY-MM-DD',
        valueFormat: 'YYYY-MM-DD',
        placeholder: '请选择开始日期'
      },
      colProps: {
        span: 12
      },
      formItemProps: {
        rules: [{ required: true, message: '请选择开始日期', trigger: 'change' }]
      }
    },
    table: {
      show: true,
      width: 120,
      slots: {
        default: (data: any) => {
          return <span>{formatTimestamp(data.row.startTime)}</span>
        }
      }
    }
  },
  {
    field: 'endTime',
    label: '结束日期',
    search: { hidden: true },
    form: {
      component: 'DatePicker',
      componentProps: {
        type: 'date',
        format: 'YYYY-MM-DD',
        valueFormat: 'YYYY-MM-DD',
        placeholder: '请选择结束日期'
      },
      colProps: {
        span: 12
      },
      formItemProps: {
        rules: [{ required: true, message: '请选择结束日期', trigger: 'change' }]
      }
    },
    table: {
      show: true,
      width: 120,
      slots: {
        default: (data: any) => {
          return <span>{formatTimestamp(data.row.endTime)}</span>
        }
      }
    }
  },
  {
    field: 'coverImage',
    label: '封面图',
    search: { hidden: true },
    form: {
      component: 'ImageUpload',
      componentProps: {
        directUpload: true,
        previewWidth: 240,
        previewHeight: 120,
        category: 'activity-cover',
        dialogTitle: '上传活动封面图',
        placeholder: '点击上传封面图'
      },
      colProps: {
        span: 24
      },
      formItemProps: {
        rules: [{ required: true, message: '请上传封面图', trigger: 'change' }]
      }
    },
    table: {
      show: true,
      width: 120,
      slots: {
        default: (data: any) => {
          return data.row.coverImage ? (
            <img
              src={getImageUrl(data.row.coverImage)}
              style={{ width: '80px', height: '45px', objectFit: 'cover', borderRadius: '4px' }}
              alt="封面"
            />
          ) : (
            <span>-</span>
          )
        }
      }
    }
  },
  {
    field: 'sharePosterImage',
    label: '分享海报',
    search: { hidden: true },
    form: {
      component: 'ImageUpload',
      componentProps: {
        aspectRatio: 9 / 16,
        cropBoxWidth: 360,
        cropBoxHeight: 640,
        category: 'activity-share-poster',
        dialogTitle: '上传分享海报',
        placeholder: '点击上传分享海报',
        previewWidth: 126,
        previewHeight: 224
      },
      colProps: {
        span: 24
      }
    },
    table: {
      hidden: true
    }
  },
  {
    field: 'sharePosterTitle',
    label: '海报提示标题',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入海报提示标题',
        maxlength: 10,
        showWordLimit: true
      },
      colProps: {
        span: 12
      }
    },
    table: {
      hidden: true
    }
  },
  {
    field: 'sharePosterDescription',
    label: '海报提示信息',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入海报提示信息',
        maxlength: 30,
        showWordLimit: true
      },
      colProps: {
        span: 12
      }
    },
    table: {
      hidden: true
    }
  },
  {
    field: 'activityType',
    label: '活动类型',
    search: { hidden: true },
    form: {
      component: 'RadioGroup',
      componentProps: {
        options: [
          { label: '线下活动', value: 'OFFLINE' },
          { label: '线上投票', value: 'ONLINE' }
        ],
        onChange: (val: 'OFFLINE' | 'ONLINE') => {
          currentFormActivityType.value = val
        }
      },
      colProps: { span: 24 },
      formItemProps: {
        rules: [{ required: true, message: '请选择活动类型', trigger: 'change' }]
      }
    },
    table: {
      show: true,
      width: 100,
      slots: {
        default: (data: any) => {
          const isOnline = data.row.activityType === 'ONLINE'
          return (
            <ElTag type={isOnline ? 'success' : 'info'}>{isOnline ? '线上投票' : '线下活动'}</ElTag>
          )
        }
      }
    }
  },
  {
    field: 'showOnHome',
    label: '展示到首页',
    search: { hidden: true },
    form: {
      component: 'RadioGroup',
      componentProps: {
        options: [
          { label: '是', value: true },
          { label: '否', value: false }
        ]
      },
      colProps: { span: 24 }
    },
    table: {
      show: true,
      width: 120,
      slots: {
        default: (data: any) => {
          return (
            <ElSwitch
              modelValue={Boolean(data.row.showOnHome)}
              disabled={Boolean(data.row.deletedAt)}
              onChange={(value: boolean) => handleShowOnHomeChange(data.row, Boolean(value))}
            />
          )
        }
      }
    }
  },
  {
    field: 'location',
    label: '活动地点',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入活动地点'
      },
      colProps: { span: 24 }
    },
    table: {
      show: true,
      width: 180,
      slots: {
        default: (data: any) => {
          return (
            <span>{data.row.location || (data.row.activityType === 'ONLINE' ? '---' : '-')}</span>
          )
        }
      }
    }
  },
  {
    field: 'summary',
    label: '活动简介',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        type: 'textarea',
        rows: 3,
        placeholder: '请输入活动简介'
      },
      colProps: {
        span: 24
      },
      formItemProps: {
        rules: [{ required: true, message: '请输入活动简介', trigger: 'blur' }]
      }
    },
    table: {
      hidden: true
    }
  },
  {
    field: 'voteOptionsEditor',
    label: '选手列表',
    search: { hidden: true },
    form: {
      formItemProps: {
        slots: {
          default: renderVoteOptionsEditor
        }
      },
      colProps: {
        span: 24
      }
    },
    table: {
      hidden: true
    }
  },
  {
    field: 'description',
    label: '活动详情',
    search: { hidden: true },
    form: {
      component: 'Editor',
      componentProps: {
        placeholder: '请输入活动详情'
      },
      colProps: {
        span: 24
      },
      formItemProps: {
        rules: [{ required: true, message: '请输入活动详情', trigger: 'blur' }]
      }
    },
    table: {
      hidden: true
    }
  },
  {
    field: 'registrationCount',
    label: '报名/票数',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 110,
      slots: {
        default: (data: any) => {
          const count = data.row.registrationCount ?? 0
          return data.row.activityType === 'ONLINE' ? `${count} 票` : `${count} 人`
        }
      }
    }
  },
  {
    field: 'commentCount',
    label: '评论数量',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 100,
      slots: {
        default: (data: any) => {
          return data.row.activityType === 'ONLINE' ? (
            <ElTag type="info">{data.row.commentCount ?? 0}</ElTag>
          ) : (
            <span>-</span>
          )
        }
      }
    }
  },
  {
    field: 'action',
    label: '操作',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 310,
      slots: {
        default: (data: any) => {
          const isOnline = data.row.activityType === 'ONLINE'
          const isDeleted = Boolean(data.row.deletedAt)
          return (
            <>
              {!isDeleted && (
                <ElButton type="primary" link onClick={() => handleEdit(data.row)}>
                  编辑
                </ElButton>
              )}
              {isOnline ? (
                <ElButton type="primary" link onClick={() => handleViewVotes(data.row)}>
                  投票详情
                </ElButton>
              ) : (
                <ElButton type="primary" link onClick={() => handleViewRegistrations(data.row)}>
                  查看报名
                </ElButton>
              )}
              {isOnline && (
                <ElButton type="primary" link onClick={() => handleViewComments(data.row)}>
                  查看评论
                </ElButton>
              )}
              {!isDeleted && (
                <ElButton type="danger" link onClick={() => handleDelete(data.row)}>
                  删除
                </ElButton>
              )}
            </>
          )
        }
      }
    }
  }
]

const { allSchemas } = useCrudSchemas(crudSchemas)

const locationFormSchema = allSchemas.formSchema.find((item) => item.field === 'location')
const voteOptionsFormSchema = allSchemas.formSchema.find(
  (item) => item.field === 'voteOptionsEditor'
)

watch(
  currentFormActivityType,
  (activityType) => {
    if (locationFormSchema) {
      locationFormSchema.remove = activityType === 'ONLINE'
    }
    if (voteOptionsFormSchema) {
      voteOptionsFormSchema.remove = activityType !== 'ONLINE'
    }
  },
  { immediate: true }
)

const setActivityFormValues = async (values: Record<string, any>) => {
  await nextTick()
  setValues(values)
}

const resetActivityForm = async () => {
  currentRow.value = null
  selectedHospital.value = null
  selectedHospitalText.value = '请选择医院'
  currentFormActivityType.value = 'OFFLINE'
  resetVoteOptions()

  await setActivityFormValues({
    title: '',
    startTime: '',
    endTime: '',
    location: '',
    summary: '',
    description: '',
    coverImage: '',
    sharePosterImage: '',
    sharePosterTitle: '',
    sharePosterDescription: '',
    hospitalId: undefined,
    activityType: 'OFFLINE',
    showOnHome: false
  })
}

const fillActivityForm = async (activity: ActivityItem) => {
  currentRow.value = activity

  // 使用完整的医院数据（如果有的话）
  if (activity.hospitalData) {
    selectedHospital.value = activity.hospitalData
  } else {
    // 降级处理：如果没有完整数据，至少设置 id 和 name
    selectedHospital.value = { id: activity.hospitalId, name: activity.hospitalName || '' }
  }

  currentFormActivityType.value = activity.activityType ?? 'OFFLINE'
  resetVoteOptions(activity.voteOptions)

  await setActivityFormValues({
    title: activity.title,
    startTime: formatTimestamp(activity.startTime),
    endTime: formatTimestamp(activity.endTime),
    location: activity.location ?? '',
    summary: activity.summary,
    description: activity.description,
    coverImage: activity.coverImage ?? '',
    sharePosterImage: activity.sharePosterImage ?? '',
    sharePosterTitle: activity.sharePosterTitle ?? '',
    sharePosterDescription: activity.sharePosterDescription ?? '',
    hospitalId: activity.hospitalId,
    activityType: activity.activityType ?? 'OFFLINE',
    showOnHome: Boolean(activity.showOnHome)
  })
}

const loadActivityForm = async () => {
  if (!isActivityFormPage.value) {
    return
  }

  if (!isActivityEditPage.value) {
    await resetActivityForm()
    return
  }

  const activityId = Number(route.params.id)
  if (!activityId) {
    ElMessage.error('活动 ID 无效')
    router.replace({ name: 'ActivitiesList' })
    return
  }

  try {
    formLoading.value = true
    const res = await getActivityDetailAdminApi(activityId)
    await fillActivityForm(res.data)
  } catch (error: any) {
    console.error('加载活动详情失败:', error)
    ElMessage.error(error.message || '加载活动详情失败')
    router.replace({ name: 'ActivitiesList' })
  } finally {
    formLoading.value = false
  }
}

watch(
  () => route.fullPath,
  () => {
    loadActivityForm()
  },
  { immediate: true }
)

/**
 * 跳转新增活动页面
 */
const handleAdd = () => {
  router.push({ name: 'ActivityCreate' })
}

/**
 * 跳转编辑活动页面
 */
const handleEdit = (row: ActivityItem) => {
  router.push({
    name: 'ActivityEdit',
    params: {
      id: row.id
    }
  })
}

const handleCancelForm = () => {
  router.push({ name: 'ActivitiesList' })
}

/**
 * 删除活动
 */
const handleDelete = async (row: any) => {
  try {
    await ElMessageBox.confirm(`确定要删除活动"${row.title}"吗？`, '提示', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    })

    await deleteActivityApi(row.id)
    ElMessage.success('删除成功')
    getList()
  } catch (error: any) {
    if (error !== 'cancel') {
      console.error('删除失败:', error)
      ElMessage.error(error.message || '删除失败')
    }
  }
}

/**
 * 加载参与者列表
 */
const loadRegistrations = async (activityId: number) => {
  try {
    registrationsLoading.value = true
    const res = await getActivityRegistrationsApi(activityId, {
      page: registrationsPage.value,
      pageSize: registrationsPageSize.value,
      voteOptionId: currentRegistrationsVoteOptionId.value
    })
    registrationsData.value = res.data || []
    registrationsTotal.value = res.pagination?.total || 0
  } catch (error) {
    console.error('加载参与者列表失败:', error)
    ElMessage.error('加载参与者列表失败')
  } finally {
    registrationsLoading.value = false
  }
}

/**
 * 参与者列表分页改变
 */
const handleRegistrationsPageChange = (page: number) => {
  registrationsPage.value = page
  if (currentRegistrationsActivityId.value) {
    loadRegistrations(currentRegistrationsActivityId.value)
  }
}

/**
 * 参与者对话框关闭
 */
const handleRegistrationsDialogClose = () => {
  registrationsDialogVisible.value = false
  currentRegistrationsActivityId.value = null
  currentRegistrationsVoteOptionId.value = undefined
  registrationsData.value = []
}

/**
 * 打开参与者对话框
 */
const openParticipantDialog = async (
  row: any,
  mode: 'registration' | 'vote',
  option?: ActivityVoteOption
) => {
  currentRegistrationsActivityId.value = row.id
  currentRegistrationsVoteOptionId.value = option?.id
  registrationsPage.value = 1
  registrationsDialogTitle.value =
    mode === 'vote' ? `投票人列表${option?.title ? ` - ${option.title}` : ''}` : '报名用户列表'
  registrationsTimeLabel.value = mode === 'vote' ? '投票时间' : '报名时间'
  registrationsDialogVisible.value = true
  await loadRegistrations(row.id)
}

/**
 * 查看报名详情
 */
const handleViewRegistrations = async (row: any) => {
  await openParticipantDialog(row, 'registration')
}

/**
 * 查看投票详情（线上活动）
 */
const handleViewVotes = async (row: any) => {
  voteDetailsActivity.value = row
  voteDetailsDialogTitle.value = `投票详情 - ${row.title}`
  voteDetailsOptions.value = [...(row.voteOptions ?? [])].sort((left, right) => {
    const voteCountDiff = Number(right.voteCount ?? 0) - Number(left.voteCount ?? 0)
    if (voteCountDiff !== 0) return voteCountDiff

    const sortDiff = Number(left.sortOrder ?? 0) - Number(right.sortOrder ?? 0)
    if (sortDiff !== 0) return sortDiff
    return Number(left.id ?? 0) - Number(right.id ?? 0)
  })
  voteDetailsDialogVisible.value = true
}

/**
 * 查看选手投票人列表
 */
const handleViewVoteOptionParticipants = async (option: ActivityVoteOption) => {
  if (!voteDetailsActivity.value) {
    return
  }

  await openParticipantDialog(voteDetailsActivity.value, 'vote', option)
}

/**
 * 加载评论列表
 */
const loadComments = async () => {
  if (!currentCommentsActivity.value) {
    return
  }

  try {
    commentsLoading.value = true
    const res = await getActivityCommentsAdminApi(currentCommentsActivity.value.id, {
      page: commentsPage.value,
      pageSize: commentsPageSize.value
    })
    commentsData.value = res.data || []
    commentsTotal.value = res.pagination?.total || 0
  } catch (error: any) {
    console.error('加载评论列表失败:', error)
    ElMessage.error(error.message || '加载评论列表失败')
  } finally {
    commentsLoading.value = false
  }
}

/**
 * 打开评论抽屉
 */
const handleViewComments = async (row: ActivityItem) => {
  currentCommentsActivity.value = row
  commentsDrawerTitle.value = `评论列表 - ${row.title}`
  commentsPage.value = 1
  commentsData.value = []
  commentsDrawerVisible.value = true
  await loadComments()
}

/**
 * 评论列表分页变化
 */
const handleCommentsPageChange = (page: number) => {
  commentsPage.value = page
  loadComments()
}

/**
 * 关闭评论抽屉
 */
const handleCommentsDrawerClose = () => {
  commentsDrawerVisible.value = false
  currentCommentsActivity.value = null
  commentsData.value = []
  commentsTotal.value = 0
  commentsPage.value = 1
}

/**
 * 删除评论
 */
const handleDeleteComment = async (comment: ActivityComment) => {
  try {
    await ElMessageBox.confirm(
      '确定要删除该评论吗？删除后这条评论及其下方回复将不再在 App 端展示。',
      '删除评论',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      }
    )

    await deleteActivityCommentAdminApi(comment.id)
    ElMessage.success('删除成功')
    await loadComments()
    if (commentsData.value.length === 0 && commentsPage.value > 1 && commentsTotal.value > 0) {
      commentsPage.value -= 1
      await loadComments()
    }
    await getList()
  } catch (error: any) {
    if (error !== 'cancel') {
      console.error('删除评论失败:', error)
      ElMessage.error(error.message || '删除评论失败')
    }
  }
}

/**
 * 提交表单
 */
const handleSubmit = async () => {
  try {
    saveLoading.value = true

    // 验证是否选择了医院
    if (!selectedHospital.value) {
      ElMessage.error('请选择医院')
      saveLoading.value = false
      return
    }

    // 表单验证
    const elForm = await getElFormExpose()
    const valid = await elForm?.validate()
    if (!valid) {
      ElMessage.error('请检查表单数据')
      return
    }

    // 获取表单数据
    const formData = await getFormData()
    const payload = buildActivityPayload(formData)

    // 验证时间
    if (payload.startTime && payload.endTime) {
      const startDate = new Date(payload.startTime)
      const endDate = new Date(payload.endTime)
      if (startDate > endDate) {
        ElMessage.error('开始时间不能晚于结束时间')
        return
      }
    }

    // 线下活动必须填写地点
    if (payload.activityType === 'OFFLINE' && !payload.location?.trim()) {
      ElMessage.error('线下活动必须填写活动地点')
      return
    }

    if (payload.activityType === 'ONLINE') {
      const validVoteOptions = (payload.voteOptions ?? []).filter(
        (option) => option.image || option.video || option.title || option.description
      )

      const invalidVoteOption = validVoteOptions.find(
        (option) => (!option.image && !option.video) || !option.title
      )
      if (invalidVoteOption) {
        ElMessage.error('请完善选手标题，并至少上传图片或视频')
        return
      }

      payload.voteOptions = validVoteOptions
    }

    if (currentRow.value) {
      // 编辑
      await updateActivityApi(currentRow.value.id, payload)
      ElMessage.success('更新成功')
    } else {
      // 新增
      await createActivityApi(payload)
      ElMessage.success('创建成功')
    }

    await router.push({ name: 'ActivitiesList' })
    nextTick(() => {
      getList()
    })
  } catch (error: any) {
    console.error('提交失败:', error)
    ElMessage.error(error.message || '操作失败')
  } finally {
    saveLoading.value = false
  }
}
</script>

<template>
  <ContentWrap v-if="isActivityFormPage">
    <div class="mb-4 flex justify-between items-center">
      <div class="flex items-center gap-2">
        <BaseButton @click="handleCancelForm">返回</BaseButton>
        <h2 class="form-title">{{ formPageTitle }}</h2>
      </div>
      <div class="flex items-center gap-2">
        <BaseButton @click="handleCancelForm">取消</BaseButton>
        <BaseButton type="primary" :loading="saveLoading" @click="handleSubmit">保存</BaseButton>
      </div>
    </div>

    <div v-loading="formLoading">
      <Form :schema="allSchemas.formSchema" @register="formRegister" label-width="100px" />
    </div>
  </ContentWrap>

  <ContentWrap v-else>
    <!-- 搜索区域 -->
    <Search :schema="allSchemas.searchSchema" @search="setSearchParams" @reset="setSearchParams" />

    <!-- 操作按钮 -->
    <div class="mb-4 flex justify-end">
      <BaseButton type="primary" @click="handleAdd">新增活动</BaseButton>
    </div>

    <!-- 表格 -->
    <Table
      v-model:pageSize="pageSize"
      v-model:currentPage="currentPage"
      :columns="allSchemas.tableColumns"
      :data="dataList"
      :loading="loading"
      :pagination="{
        total
      }"
      @register="tableRegister"
    />
  </ContentWrap>

  <!-- 医院选择弹窗 -->
  <Dialog v-model="hospitalSelectDialogVisible" title="选择医院" width="1400px">
    <!-- 搜索栏 -->
    <div style="margin-bottom: 16px; display: flex; gap: 8px">
      <ElInput
        v-model="hospitalSearchKeyword"
        placeholder="输入医院名称搜索"
        clearable
        style="flex: 1"
        @keyup.enter="handleHospitalSearch"
      >
        <template #append>
          <BaseButton @click="handleHospitalSearch">搜索</BaseButton>
        </template>
      </ElInput>
    </div>

    <!-- 医院列表 -->
    <div v-loading="hospitalLoading">
      <div style="display: flex; flex-wrap: wrap; gap: 12px">
        <div v-for="hospital in hospitalList" :key="hospital.id" style="width: calc(25% - 9px)">
          <ElCard
            :body-style="{ padding: '16px' }"
            shadow="hover"
            style="cursor: pointer; height: 100%"
            :class="{ 'is-selected': selectedHospital?.id === hospital.id }"
            @click="handleSelectHospital(hospital)"
          >
            <div style="display: flex; flex-direction: column; gap: 8px">
              <!-- 医院图片 -->
              <ElImage
                v-if="hospital.logo"
                :src="getImageUrl(hospital.logo)"
                style="width: 100%; height: 140px; border-radius: 4px; object-fit: cover"
                fit="cover"
              />
              <div
                v-else
                style="
                  width: 100%;
                  height: 140px;
                  border-radius: 4px;
                  object-fit: cover;
                  background: #f5f7fa;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  font-size: 48px;
                  color: #9ca3af;
                "
              >
                <span>🏥</span>
              </div>

              <!-- 医院信息 -->
              <div style="flex: 1">
                <div
                  style="
                    font-weight: 600;
                    font-size: 16px;
                    margin-bottom: 8px;
                    color: #1f2937;
                    white-space: nowrap;
                    overflow: hidden;
                    text-overflow: ellipsis;
                  "
                >
                  {{ hospital.name }}
                </div>

                <div style="font-size: 13px; color: #6b7280; margin-bottom: 4px">
                  <span>📍 {{ hospital.city || '-' }}</span>
                  <span v-if="hospital.address" style="margin-left: 8px">
                    {{ hospital.address }}
                  </span>
                </div>

                <div style="font-size: 13px; color: #9ca3af">
                  联系电话: {{ hospital.phone || '-' }}
                </div>
              </div>
            </div>
          </ElCard>
        </div>
      </div>

      <!-- 空状态 -->
      <ElEmpty v-if="!hospitalLoading && hospitalList.length === 0" description="暂无医院数据" />

      <!-- 分页 -->
      <div
        v-if="hospitalPagination.total > 0"
        style="margin-top: 16px; display: flex; justify-content: center"
      >
        <el-pagination
          :current-page="hospitalPagination.page"
          :page-size="hospitalPagination.pageSize"
          :total="hospitalPagination.total"
          layout="total, prev, pager, next"
          @current-change="handleHospitalPageChange"
        />
      </div>
    </div>

    <template #footer>
      <BaseButton @click="hospitalSelectDialogVisible = false">取消</BaseButton>
    </template>
  </Dialog>

  <!-- 投票详情对话框 -->
  <Dialog v-model="voteDetailsDialogVisible" :title="voteDetailsDialogTitle" width="1000px">
    <el-table :data="voteDetailsOptions" stripe border>
      <el-table-column label="图片" width="120">
        <template #default="{ row }">
          <ElImage
            v-if="row.image"
            :src="getImageUrl(row.image)"
            style="width: 72px; height: 72px; border-radius: 6px; object-fit: cover"
            fit="cover"
            :preview-src-list="[getImageUrl(row.image)]"
            preview-teleported
          />
          <span v-else>-</span>
        </template>
      </el-table-column>
      <el-table-column label="视频" width="120">
        <template #default="{ row }">
          <el-button
            v-if="row.video"
            type="primary"
            link
            @click="handlePreviewVoteOptionVideo(row)"
          >
            预览
          </el-button>
          <span v-else>-</span>
        </template>
      </el-table-column>
      <el-table-column prop="title" label="选手标题" min-width="160" />
      <el-table-column prop="description" label="描述" min-width="240" show-overflow-tooltip />
      <el-table-column label="票数" width="100">
        <template #default="{ row }">
          {{ row.voteCount || 0 }}
        </template>
      </el-table-column>
      <el-table-column label="操作" width="100">
        <template #default="{ row }">
          <el-button
            type="primary"
            link
            :disabled="!row.id"
            @click="handleViewVoteOptionParticipants(row)"
          >
            详情
          </el-button>
        </template>
      </el-table-column>
    </el-table>

    <ElEmpty v-if="voteDetailsOptions.length === 0" description="暂无选手数据" />

    <template #footer>
      <BaseButton @click="voteDetailsDialogVisible = false">关闭</BaseButton>
    </template>
  </Dialog>

  <!-- 报名列表对话框 -->
  <Dialog v-model="registrationsDialogVisible" :title="registrationsDialogTitle" width="800px">
    <el-table v-loading="registrationsLoading" :data="registrationsData" stripe>
      <el-table-column prop="userName" label="用户" width="150" />
      <el-table-column prop="phone" label="联系电话" width="130" />
      <el-table-column prop="registeredAt" :label="registrationsTimeLabel">
        <template #default="{ row }">
          {{ formatRegistrationTime(row.registeredAt) }}
        </template>
      </el-table-column>
    </el-table>
    <div class="mt-4 flex justify-end">
      <el-pagination
        v-model:current-page="registrationsPage"
        :page-size="registrationsPageSize"
        :total="registrationsTotal"
        layout="total, prev, pager, next"
        @current-change="handleRegistrationsPageChange"
      />
    </div>
    <template #footer>
      <BaseButton @click="handleRegistrationsDialogClose">关闭</BaseButton>
    </template>
  </Dialog>

  <!-- 活动评论抽屉 -->
  <ElDrawer
    v-model="commentsDrawerVisible"
    :title="commentsDrawerTitle"
    size="50%"
    direction="rtl"
    destroy-on-close
    @closed="handleCommentsDrawerClose"
  >
    <div class="comments-drawer">
      <el-table v-loading="commentsLoading" :data="commentsData" row-key="id" stripe border>
        <el-table-column label="用户" width="150">
          <template #default="{ row }">
            <div class="comment-user-cell">
              <ElImage
                v-if="row.user?.avatar"
                :src="getImageUrl(row.user.avatar)"
                class="comment-user-avatar"
                fit="cover"
              />
              <div v-else class="comment-user-avatar comment-user-avatar-empty">-</div>
              <span>{{ row.user?.nickname || `用户${row.userId}` }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="评论内容" min-width="260">
          <template #default="{ row }">
            <div class="comment-content">
              <div>{{ row.content }}</div>
              <div v-if="row.replies?.length" class="comment-replies">
                <div v-for="reply in row.replies" :key="reply.id" class="comment-reply-item">
                  <span class="comment-reply-user">
                    {{ reply.user?.nickname || `用户${reply.userId}` }}：
                  </span>
                  <span>{{ reply.content }}</span>
                </div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="评论时间" width="170">
          <template #default="{ row }">
            {{ formatCommentTime(row.createdAt) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="90" fixed="right">
          <template #default="{ row }">
            <el-button type="danger" link @click="handleDeleteComment(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <ElEmpty v-if="!commentsLoading && commentsData.length === 0" description="暂无评论" />

      <div class="comments-pagination">
        <el-pagination
          v-model:current-page="commentsPage"
          :page-size="commentsPageSize"
          :total="commentsTotal"
          layout="total, prev, pager, next"
          @current-change="handleCommentsPageChange"
        />
      </div>
    </div>
  </ElDrawer>
</template>

<style lang="less" scoped>
.mb-4 {
  margin-bottom: 1rem;
}

.flex {
  display: flex;
}

.justify-end {
  justify-content: flex-end;
}

.justify-between {
  justify-content: space-between;
}

.items-center {
  align-items: center;
}

.gap-2 {
  gap: 8px;
}

.mt-4 {
  margin-top: 1rem;
}

.form-title {
  margin: 0;
  font-size: 20px;
  font-weight: 600;
}

.is-selected {
  border: 2px solid var(--el-color-primary);
}

.vote-options-panel {
  margin-top: 20px;
  padding: 16px;
  border: 1px solid var(--el-border-color);
  border-radius: 6px;
  background: var(--el-fill-color-lighter);
}

.vote-options-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 16px;
}

.vote-options-tip {
  font-size: 13px;
  color: var(--el-text-color-secondary);
}

.vote-option-image-cell {
  width: 260px;
}

.vote-option-image-cell :deep(.image-upload),
.vote-option-image-cell :deep(.image-upload-wrapper),
.vote-option-image-cell :deep(.preview-image-container),
.vote-option-image-cell :deep(.upload-placeholder) {
  width: 100% !important;
  height: 120px !important;
  max-height: 120px;
}

.vote-option-image-cell :deep(.preview-image) {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.vote-option-video-cell {
  width: 320px;
}

.vote-option-video-preview,
.vote-option-video-placeholder {
  position: relative;
  width: 100%;
  height: 120px;
  max-height: 120px;
  overflow: hidden;
  border: 1px dashed var(--el-border-color);
  border-radius: 6px;
  background: var(--el-fill-color-light);
}

.vote-option-video-preview:hover .vote-option-video-mask {
  opacity: 1;
}

.vote-option-video-mask {
  opacity: 0;
}

.vote-option-video-action:hover {
  opacity: 0.8;
}

.vote-option-video-action :deep(.iconify) {
  font-size: 20px;
  transition: transform 0.2s;
}

.vote-option-video-action:hover :deep(.iconify) {
  transform: scale(1.2);
}

.vote-option-video-action :deep(.delete-icon) {
  color: #f56c6c;
}

.vote-option-video-action span {
  font-size: 12px;
  cursor: pointer;
}

.vote-option-video-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  font-size: 13px;
  color: var(--el-text-color-secondary);
}

.vote-option-video-progress {
  position: absolute;
  right: 8px;
  bottom: 8px;
  left: 8px;
}

.comments-drawer {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.comment-user-cell {
  display: flex;
  align-items: center;
  gap: 8px;
}

.comment-user-avatar {
  width: 32px;
  height: 32px;
  flex: 0 0 32px;
  border-radius: 50%;
  overflow: hidden;
  background: var(--el-fill-color-light);
}

.comment-user-avatar-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--el-text-color-placeholder);
  font-size: 12px;
}

.comment-content {
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-word;
}

.comment-replies {
  margin-top: 8px;
  padding: 8px 10px;
  border-radius: 6px;
  background: var(--el-fill-color-lighter);
}

.comment-reply-item + .comment-reply-item {
  margin-top: 6px;
}

.comment-reply-user {
  color: var(--el-color-primary);
  font-weight: 600;
}

.comments-pagination {
  display: flex;
  justify-content: flex-end;
  margin-top: 16px;
}
</style>
