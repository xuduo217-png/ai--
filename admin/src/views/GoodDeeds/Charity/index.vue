<script setup lang="tsx">
import { computed, ref, unref, nextTick } from 'vue'
import { ElTag, ElMessage, ElMessageBox, ElDialog, ElTable, ElTableColumn } from 'element-plus'
import { Table } from '@/components/Table'
import { ContentWrap } from '@/components/ContentWrap'
import { Search } from '@/components/Search'
import { useTable } from '@/hooks/web/useTable'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { BaseButton } from '@/components/Button'
import { Dialog } from '@/components/Dialog'
import { Form } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import {
  type CharityArticle,
  type CharityFormData,
  type CharityItem,
  type CharityParticipant,
  type CharityParticipantType,
  getCharityListAdminApi,
  createCharityApi,
  updateCharityApi,
  deleteCharityApi,
  getParticipantsApi,
  publishCharityArticleApi,
  updateCharityArticleApi,
  getPublishedArticleApi,
  getCharityArticlesApi
} from '@/api-new/charity'
import { formatToDateTime } from '@/utils/dateUtil'
import { getImageUrl } from '@/utils/image'

defineOptions({
  name: 'Charity'
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
    const res = await getCharityListAdminApi({
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

// 对话框
const dialogVisible = ref(false)
const dialogTitle = ref('')
const currentRow = ref<CharityItem | null>(null)
const saveLoading = ref(false)
const currentParticipantType = ref<CharityParticipantType>('checkin')
const currentMallAutoDonation = ref(false)
const existingMallAutoDonationId = computed(
  () => unref(dataList).find((item) => item.isMallAutoDonation)?.id
)
const mallAutoDonationSwitchDisabled = computed(() => {
  const existingId = existingMallAutoDonationId.value
  return existingId !== undefined && existingId !== currentRow.value?.id
})

// 参与者对话框
const participantsDialogVisible = ref(false)
const participantsData = ref<CharityParticipant[]>([])
const participantsLoading = ref(false)
const participantsCharityType = ref<CharityParticipantType>('checkin')

// 文章发布对话框
const articleDialogVisible = ref(false)
const articleDialogCharityId = ref<number>(0)
const articleDialogArticleId = ref<number | null>(null) // 当前编辑的文章ID，null表示新建
const articleDialogTitle = ref('') // 对话框标题
const articleLoading = ref(false)

// 文章列表对话框
const articlesDialogVisible = ref(false)
const articlesData = ref<CharityArticle[]>([])
const articlesLoading = ref(false)

// 表单
const { formRegister, formMethods } = useForm()
const { setValues, getFormData, getElFormExpose } = formMethods

// 文章表单
const { formRegister: articleFormRegister, formMethods: articleFormMethods } = useForm()
const {
  setValues: setArticleValues,
  getFormData: getArticleFormData,
  getElFormExpose: getArticleElFormExpose
} = articleFormMethods

const handleParticipantTypeChange = (value: CharityParticipantType) => {
  currentParticipantType.value = value

  if (value !== 'donation' && currentMallAutoDonation.value) {
    currentMallAutoDonation.value = false
    setValues({ isMallAutoDonation: false })
  }

  if (value === 'donation') {
    setValues({
      targetCheckIns: 0
    })
    return
  }

  setValues({
    targetCheckIns:
      currentRow.value?.participantType === 'checkin' ? currentRow.value.targetCheckIns : 7
  })
}

const handleMallAutoDonationChange = (value: boolean) => {
  if (value && mallAutoDonationSwitchDisabled.value) {
    ElMessage.warning('商城公益活动只能有一个，请编辑现有活动')
    setValues({ isMallAutoDonation: false })
    return
  }

  currentMallAutoDonation.value = Boolean(value)
  if (value && currentParticipantType.value !== 'donation') {
    currentParticipantType.value = 'donation'
    setValues({
      participantType: 'donation',
      targetCheckIns: 0,
      startTime: undefined,
      endTime: undefined
    })
  } else if (value) {
    setValues({ startTime: undefined, endTime: undefined })
  }
}

/**
 * 规范化公益表单数据
 * 统一收口表单字段，避免宽泛的表单返回值直接泄漏到 API 层。
 */
const buildCharityPayload = (formData: Recordable<any>) => {
  const isMallAutoDonation = Boolean(formData.isMallAutoDonation)

  return {
    title: String(formData.title ?? '').trim(),
    description: String(formData.description ?? '').trim(),
    details: formData.details ? String(formData.details) : undefined,
    coverImage: formData.coverImage ? String(formData.coverImage) : undefined,
    startTime: isMallAutoDonation
      ? null
      : formData.startTime
        ? String(formData.startTime)
        : undefined,
    endTime: isMallAutoDonation ? null : formData.endTime ? String(formData.endTime) : undefined,
    targetCheckIns:
      formData.participantType === 'donation' ? 0 : Number(formData.targetCheckIns ?? 0),
    participantType:
      formData.participantType === 'task'
        ? 'task'
        : formData.participantType === 'donation'
          ? 'donation'
          : 'checkin',
    isMallAutoDonation,
    donationRate: isMallAutoDonation ? Number(formData.donationRate ?? 0) : 0,
    isPinned: Boolean(formData.isPinned),
    taskConfig: formData.taskConfig,
    status:
      formData.status === 'DRAFT' || formData.status === 'EXPIRED' || formData.status === 'ACTIVE'
        ? formData.status
        : undefined
  } satisfies CharityFormData
}

/**
 * 获取状态标签类型
 */
const getStatusType = (status: string) => {
  const map: Record<string, any> = {
    DRAFT: 'info',
    ACTIVE: 'success',
    EXPIRED: 'danger'
  }
  return map[status] || 'info'
}

/**
 * 获取状态文本
 */
const getStatusText = (status: string) => {
  const map: Record<string, string> = {
    DRAFT: '草稿',
    ACTIVE: '进行中',
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

/**
 * 获取参与类型文本
 */
const getParticipantTypeText = (type: string) => {
  const map: Record<string, string> = {
    checkin: '打卡',
    task: '任务完成',
    donation: '捐款'
  }
  return map[type] || type
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
    field: 'status',
    label: '状态',
    search: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '全部', value: '' },
          { label: '草稿', value: 'DRAFT' },
          { label: '进行中', value: 'ACTIVE' },
          { label: '已结束', value: 'EXPIRED' }
        ]
      }
    },
    form: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '草稿', value: 'DRAFT' },
          { label: '进行中', value: 'ACTIVE' }
        ]
      },
      colProps: {
        span: 12
      },
      formItemProps: {
        rules: [{ required: true, message: '请选择状态', trigger: 'change' }]
      }
    },
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
    field: 'keyword',
    label: '关键词',
    search: {
      component: 'Input',
      componentProps: {
        placeholder: '搜索公益名称'
      }
    },
    form: { hidden: true },
    table: {
      hidden: true
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
    label: '公益名称',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        type: 'textarea',
        rows: 2,
        placeholder: '请输入公益名称'
      },
      colProps: {
        span: 24
      },
      formItemProps: {
        rules: [{ required: true, message: '请输入公益名称', trigger: 'blur' }]
      }
    },
    table: {
      show: true
    }
  },
  {
    field: 'description',
    label: '公益描述',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        type: 'textarea',
        rows: 4,
        placeholder: '请输入公益描述'
      },
      colProps: {
        span: 24
      },
      formItemProps: {
        rules: [{ required: true, message: '请输入公益描述', trigger: 'blur' }]
      }
    },
    table: {
      hidden: true
    }
  },
  {
    field: 'coverImage',
    label: '封面图片',
    search: { hidden: true },
    form: {
      component: 'ImageUpload',
      componentProps: {
        directUpload: true,
        previewWidth: 240,
        previewHeight: 120,
        category: 'charity-cover',
        dialogTitle: '上传封面图片'
      },
      colProps: {
        span: 24
      },
      formItemProps: {
        rules: [{ required: true, message: '请上传封面图片', trigger: 'change' }]
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
    field: 'startTime',
    label: '开始时间',
    search: { hidden: true },
    form: {
      component: 'DatePicker',
      componentProps: {
        type: 'datetime',
        format: 'YYYY-MM-DD HH:mm:ss',
        valueFormat: 'YYYY-MM-DD HH:mm:ss',
        placeholder: '请选择开始时间'
      },
      colProps: {
        span: 12
      }
    },
    table: {
      show: true,
      width: 180,
      slots: {
        default: (data: any) => {
          return data.row.startTime ? formatToDateTime(data.row.startTime) : '-'
        }
      }
    }
  },
  {
    field: 'endTime',
    label: '结束时间',
    search: { hidden: true },
    form: {
      component: 'DatePicker',
      componentProps: {
        type: 'datetime',
        format: 'YYYY-MM-DD HH:mm:ss',
        valueFormat: 'YYYY-MM-DD HH:mm:ss',
        placeholder: '请选择结束时间'
      },
      colProps: {
        span: 12
      }
    },
    table: {
      show: true,
      width: 180,
      slots: {
        default: (data: any) => {
          return data.row.endTime ? formatToDateTime(data.row.endTime) : '-'
        }
      }
    }
  },
  {
    field: 'targetCheckIns',
    label: '目标打卡数',
    search: { hidden: true },
    form: {
      component: 'InputNumber',
      componentProps: {
        min: 1,
        placeholder: '请输入目标打卡数'
      },
      colProps: {
        span: 12
      },
      formItemProps: {
        rules: [{ required: true, message: '请输入目标打卡数', trigger: 'blur' }]
      }
    },
    table: {
      show: true,
      width: 120,
      slots: {
        default: (data: any) => {
          return data.row.participantType === 'donation' ? '-' : (data.row.targetCheckIns ?? '-')
        }
      }
    }
  },
  {
    field: 'completedCheckIns',
    label: '已打卡次数',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 120,
      slots: {
        default: (data: any) => {
          return data.row.participantType === 'donation' ? '-' : (data.row.completedCheckIns ?? 0)
        }
      }
    }
  },
  {
    field: 'donatedAmount',
    label: '已捐金额',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 120,
      slots: {
        default: (data: any) => {
          if (data.row.participantType !== 'donation') {
            return <span>-</span>
          }

          return <span>{`¥${Number(data.row.donatedAmount || 0).toFixed(2)}`}</span>
        }
      }
    }
  },
  {
    field: 'participantType',
    label: '参与类型',
    search: { hidden: true },
    form: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '打卡', value: 'checkin' },
          { label: '捐款', value: 'donation' }
        ],
        onChange: handleParticipantTypeChange
      },
      colProps: {
        span: 12
      },
      formItemProps: {
        rules: [{ required: true, message: '请选择参与类型', trigger: 'change' }]
      }
    },
    table: {
      show: true,
      width: 120,
      slots: {
        default: (data: any) => {
          return <span>{getParticipantTypeText(data.row.participantType)}</span>
        }
      }
    }
  },
  {
    field: 'isMallAutoDonation',
    label: '商城自动公益',
    search: { hidden: true },
    form: {
      component: 'Switch',
      componentProps: computed(() => ({
        activeText: '支付自动入账',
        inactiveText: mallAutoDonationSwitchDisabled.value ? '已有商城公益' : '主动参与',
        disabled: mallAutoDonationSwitchDisabled.value,
        onChange: handleMallAutoDonationChange
      })),
      colProps: { span: 12 }
    },
    table: {
      show: true,
      width: 130,
      slots: {
        default: (data: any) =>
          data.row.isMallAutoDonation ? <ElTag type="warning">商城自动</ElTag> : <span>-</span>
      }
    }
  },
  {
    field: 'donationRate',
    label: '自动公益比例',
    search: { hidden: true },
    form: {
      component: 'InputNumber',
      componentProps: {
        min: 0.01,
        max: 100,
        step: 0.01,
        precision: 2,
        placeholder: '例如 1.50，表示实付金额的 1.5%'
      },
      colProps: { span: 12 },
      formItemProps: {
        rules: [{ required: true, message: '请输入自动公益比例', trigger: 'blur' }]
      }
    },
    table: {
      show: true,
      width: 130,
      slots: {
        default: (data: any) =>
          data.row.isMallAutoDonation ? (
            `${Number(data.row.donationRate || 0).toFixed(2)}%`
          ) : (
            <span>-</span>
          )
      }
    }
  },
  {
    field: 'isPinned',
    label: '置顶展示',
    search: { hidden: true },
    form: {
      component: 'Switch',
      componentProps: { activeText: '置顶', inactiveText: '不置顶' },
      colProps: { span: 12 }
    },
    table: {
      show: true,
      width: 100,
      slots: {
        default: (data: any) =>
          data.row.isPinned ? <ElTag type="success">置顶</ElTag> : <span>-</span>
      }
    }
  },
  {
    field: 'participantCount',
    label: '参与人数',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 100
    }
  },
  {
    field: 'details',
    label: '公益详情',
    search: { hidden: true },
    form: {
      component: 'Editor',
      componentProps: {
        placeholder: '请输入公益详情（支持富文本）'
      },
      colProps: {
        span: 24
      },
      formItemProps: {
        rules: [{ required: false, message: '请输入公益详情', trigger: 'blur' }]
      }
    },
    table: {
      hidden: true
    }
  },
  {
    field: 'action',
    label: '操作',
    form: { hidden: true },
    search: { hidden: true },
    table: {
      show: true,
      width: 500,
      slots: {
        default: (data: any) => {
          const isDeleted = Boolean(data.row.deletedAt)
          return (
            <div style="display: flex; align-items: center; gap: 8px;">
              <span
                class="operation-text operation-text--success"
                onClick={() => handleViewParticipants(data.row)}
              >
                {data.row.participantType === 'donation' ? '公益流水' : '参与者'}
              </span>
              {!isDeleted && data.row.participantType !== 'donation' && (
                <span
                  class="operation-text operation-text--info"
                  onClick={() => handlePublishArticle(data.row)}
                >
                  发布文章
                </span>
              )}
              {data.row.participantType !== 'donation' && (
                <span
                  class="operation-text operation-text--info"
                  onClick={() => handleViewArticles(data.row)}
                >
                  文章列表
                </span>
              )}
              {!isDeleted && (
                <span
                  class="operation-text operation-text--primary"
                  onClick={() => handleEdit(data.row)}
                >
                  编辑
                </span>
              )}
              {!isDeleted && (
                <span
                  class="operation-text operation-text--danger"
                  onClick={() => handleDelete(data.row)}
                >
                  删除
                </span>
              )}
            </div>
          )
        }
      }
    }
  }
]

// 生成所有 schemas
const { allSchemas } = useCrudSchemas(crudSchemas)
const dialogFormSchema = computed(() => {
  return allSchemas.formSchema.filter((schema) => {
    if (
      currentMallAutoDonation.value &&
      (schema.field === 'startTime' || schema.field === 'endTime')
    ) {
      return false
    }

    if (schema.field === 'targetCheckIns' && currentParticipantType.value === 'donation') {
      return false
    }

    if (schema.field === 'donationRate' && !currentMallAutoDonation.value) {
      return false
    }

    return true
  })
})

/**
 * 新增公益
 */
const handleAdd = () => {
  dialogTitle.value = '新增公益'
  currentRow.value = null
  currentParticipantType.value = 'checkin'
  currentMallAutoDonation.value = false
  dialogVisible.value = true

  nextTick(() => {
    setValues({
      status: 'ACTIVE',
      title: '',
      description: '',
      details: '',
      coverImage: '',
      startTime: undefined,
      endTime: undefined,
      targetCheckIns: 7,
      participantType: 'checkin',
      isMallAutoDonation: false,
      donationRate: 0,
      isPinned: false
    })
  })
}

/**
 * 编辑公益
 */
const handleEdit = (row: any) => {
  dialogTitle.value = '编辑公益'
  currentRow.value = row
  currentParticipantType.value = row.participantType === 'donation' ? 'donation' : 'checkin'
  currentMallAutoDonation.value = Boolean(row.isMallAutoDonation)
  dialogVisible.value = true

  nextTick(() => {
    setValues({
      status: row.status,
      title: row.title,
      description: row.description,
      details: row.details || '',
      coverImage: getImageUrl(row.coverImage), // 将相对路径转换为完整 URL
      startTime: row.isMallAutoDonation ? undefined : row.startTime,
      endTime: row.isMallAutoDonation ? undefined : row.endTime,
      targetCheckIns: row.participantType === 'donation' ? 0 : row.targetCheckIns,
      participantType: row.participantType,
      isMallAutoDonation: Boolean(row.isMallAutoDonation),
      donationRate: row.donationRate || 0,
      isPinned: Boolean(row.isPinned)
    })
  })
}

/**
 * 删除公益
 */
const handleDelete = async (row: any) => {
  try {
    await ElMessageBox.confirm('确定删除该公益吗？', '提示', {
      type: 'warning'
    })

    await deleteCharityApi(row.id)
    ElMessage.success('删除成功')
    getList()
  } catch (error) {
    // 取消删除
  }
}

/**
 * 提取图片相对路径
 * 将完整 URL 转换为相对路径，如 http://xxx.com/uploads/abc.jpg -> /uploads/abc.jpg
 * 如果已经是相对路径，则原样返回
 */
const extractImagePath = (url: string | undefined): string | undefined => {
  if (!url) return undefined

  // 如果已经是相对路径，直接返回
  if (url.startsWith('/uploads/')) {
    return url
  }

  // 尝试从完整 URL 中提取相对路径
  try {
    const urlObj = new URL(url)
    const pathname = urlObj.pathname
    // 如果路径以 /uploads/ 开头，返回该路径
    if (pathname.startsWith('/uploads/')) {
      return pathname
    }
  } catch (e) {
    // URL 解析失败，可能是相对路径，直接返回
  }

  return url
}

/**
 * 提交表单
 */
const handleSubmit = async () => {
  try {
    saveLoading.value = true

    const elForm = await getElFormExpose()
    const valid = await elForm?.validate()
    if (!valid) {
      ElMessage.error('请检查表单数据')
      return
    }

    const formData = await getFormData()
    const payload = buildCharityPayload(formData)

    // 处理 coverImage：将完整 URL 转换为相对路径
    if (payload.coverImage) {
      payload.coverImage = extractImagePath(payload.coverImage)
    }

    if (currentRow.value?.id) {
      await updateCharityApi(currentRow.value.id, payload)
      ElMessage.success('更新成功')
    } else {
      await createCharityApi(payload)
      ElMessage.success('创建成功')
    }

    dialogVisible.value = false
    getList()
  } catch (error: any) {
    ElMessage.error(error?.response?.data?.message || '操作失败，请稍后重试')
  } finally {
    saveLoading.value = false
  }
}

/**
 * 查看参与者
 */
const handleViewParticipants = async (row: any) => {
  try {
    participantsLoading.value = true
    participantsDialogVisible.value = true
    participantsCharityType.value = row.participantType === 'donation' ? 'donation' : 'checkin'

    const res = await getParticipantsApi(row.id, { page: 1, pageSize: 100 })
    participantsData.value = res.data || []
  } catch (error) {
    ElMessage.error('获取参与者列表失败')
  } finally {
    participantsLoading.value = false
  }
}

/**
 * 发布/编辑文章
 * 规则：
 * 1. 公益必须已结束（状态为 EXPIRED）
 * 2. 每个公益只能发布一篇文章，发布后只能编辑
 */
const handlePublishArticle = async (row: any) => {
  if (row.participantType === 'donation') {
    ElMessage.warning('捐款类型公益不支持发布文章')
    return
  }

  // 1. 检查公益状态
  if (row.status !== 'EXPIRED') {
    ElMessage.warning('只有已结束的公益才能发布文章')
    return
  }

  articleDialogCharityId.value = row.id
  articleDialogVisible.value = true

  try {
    // 2. 检查是否已有文章
    const res = await getPublishedArticleApi(row.id)
    const existingArticle = res.data

    if (existingArticle) {
      // 已有文章，进入编辑模式
      articleDialogArticleId.value = existingArticle.id
      articleDialogTitle.value = '编辑文章'

      nextTick(() => {
        setArticleValues({
          title: existingArticle.title,
          content: existingArticle.content,
          sendNotification: existingArticle.sendNotification
        })
      })
    } else {
      // 无文章，进入创建模式
      articleDialogArticleId.value = null
      articleDialogTitle.value = '发布文章'

      nextTick(() => {
        setArticleValues({
          title: '',
          content: '',
          sendNotification: true
        })
      })
    }
  } catch (error) {
    // 没有文章，进入创建模式
    articleDialogArticleId.value = null
    articleDialogTitle.value = '发布文章'

    nextTick(() => {
      setArticleValues({
        title: '',
        content: '',
        sendNotification: true
      })
    })
  }
}

/**
 * 提交文章（创建或更新）
 */
const handleArticleSubmit = async () => {
  try {
    articleLoading.value = true

    const elForm = await getArticleElFormExpose()
    const valid = await elForm?.validate()
    if (!valid) {
      ElMessage.error('请检查表单数据')
      return
    }

    const formData = await getArticleFormData()

    if (articleDialogArticleId.value) {
      // 编辑已有文章
      await updateCharityArticleApi(articleDialogCharityId.value, articleDialogArticleId.value, {
        title: formData.title,
        content: formData.content,
        sendNotification: formData.sendNotification
      })
      ElMessage.success('文章更新成功')
    } else {
      // 创建新文章
      await publishCharityArticleApi(articleDialogCharityId.value, {
        title: formData.title,
        content: formData.content,
        sendNotification: formData.sendNotification
      })
      ElMessage.success('文章发布成功')
    }

    articleDialogVisible.value = false
  } catch (error: any) {
    // 解析错误信息
    const errorMsg = error?.response?.data?.message || '操作失败，请稍后重试'
    ElMessage.error(errorMsg)
  } finally {
    articleLoading.value = false
  }
}

/**
 * 查看文章列表
 */
const handleViewArticles = async (row: any) => {
  if (row.participantType === 'donation') {
    ElMessage.warning('捐款类型公益没有文章列表')
    return
  }

  try {
    articlesLoading.value = true
    articlesDialogVisible.value = true

    const res = await getCharityArticlesApi(row.id)
    articlesData.value = res.data || []
  } catch (error) {
    ElMessage.error('获取文章列表失败')
  } finally {
    articlesLoading.value = false
  }
}
</script>

<template>
  <ContentWrap>
    <!-- 搜索区域 -->
    <Search :schema="allSchemas.searchSchema" @search="setSearchParams" @reset="setSearchParams" />

    <!-- 操作按钮 -->
    <div class="mb-10px">
      <BaseButton type="primary" @click="handleAdd"> 新增公益 </BaseButton>
    </div>

    <!-- 表格 -->
    <Table
      v-model:pageSize="pageSize"
      v-model:currentPage="currentPage"
      :columns="allSchemas.tableColumns"
      :data="dataList"
      :loading="loading"
      :pagination="{ total }"
      @register="tableRegister"
    />
  </ContentWrap>

  <!-- 创建/编辑对话框 -->
  <Dialog
    v-model="dialogVisible"
    :title="dialogTitle"
    width="1200px"
    :max-height="900"
    fullscreen
    class="charity-dialog"
  >
    <Form :schema="dialogFormSchema" @register="formRegister" label-width="120px" />

    <template #footer>
      <BaseButton type="primary" :loading="saveLoading" @click="handleSubmit"> 保存 </BaseButton>
      <BaseButton @click="dialogVisible = false">取消</BaseButton>
    </template>
  </Dialog>

  <!-- 参与者对话框 -->
  <ElDialog
    v-model="participantsDialogVisible"
    :title="participantsCharityType === 'donation' ? '公益流水' : '参与者列表'"
    width="1100px"
  >
    <div v-loading="participantsLoading">
      <ElTable :data="participantsData" border max-height="500">
        <ElTableColumn prop="userId" label="用户ID" width="100" />
        <ElTableColumn prop="userName" label="用户昵称" width="150" />
        <ElTableColumn prop="userAvatar" label="用户头像" width="100">
          <template #default="{ row }">
            <img
              v-if="row.userAvatar"
              :src="getImageUrl(row.userAvatar)"
              style="width: 50px; height: 50px; object-fit: cover; border-radius: 50%"
              alt="头像"
            />
            <span v-else>-</span>
          </template>
        </ElTableColumn>
        <ElTableColumn
          v-if="participantsCharityType !== 'donation'"
          prop="checkInCount"
          label="签到次数"
          width="100"
        />
        <ElTableColumn
          v-if="participantsCharityType === 'donation'"
          prop="donationEntryType"
          label="流水类型"
          width="110"
        >
          <template #default="{ row }">
            <ElTag :type="row.donationEntryType === 'reversal' ? 'danger' : 'success'">
              {{ row.donationEntryType === 'reversal' ? '退款冲销' : '公益入账' }}
            </ElTag>
          </template>
        </ElTableColumn>
        <ElTableColumn
          v-if="participantsCharityType === 'donation'"
          prop="orderNo"
          label="订单号"
          min-width="180"
        />
        <ElTableColumn
          v-if="participantsCharityType === 'donation'"
          prop="donationBaseAmount"
          label="实付/退款基数"
          width="140"
        >
          <template #default="{ row }">
            {{
              row.donationBaseAmount == null ? '-' : `¥${Number(row.donationBaseAmount).toFixed(2)}`
            }}
          </template>
        </ElTableColumn>
        <ElTableColumn
          v-if="participantsCharityType === 'donation'"
          prop="donationRate"
          label="比例"
          width="90"
        >
          <template #default="{ row }">{{
            row.donationRate == null ? '-' : `${Number(row.donationRate).toFixed(2)}%`
          }}</template>
        </ElTableColumn>
        <ElTableColumn
          v-if="participantsCharityType === 'donation'"
          prop="donationAmount"
          label="公益金额"
          width="120"
        >
          <template #default="{ row }">
            <span :style="{ color: row.donationEntryType === 'reversal' ? '#f56c6c' : '#67c23a' }">
              {{
                `${row.donationEntryType === 'reversal' ? '-' : '+'}¥${Math.abs(Number(row.donationAmount || 0)).toFixed(2)}`
              }}
            </span>
          </template>
        </ElTableColumn>
        <ElTableColumn
          v-if="participantsCharityType === 'donation'"
          prop="checkInTime"
          label="发生时间"
          width="180"
        >
          <template #default="{ row }">{{
            row.checkInTime ? formatToDateTime(row.checkInTime) : '-'
          }}</template>
        </ElTableColumn>
        <ElTableColumn
          v-if="participantsCharityType !== 'donation'"
          prop="firstCheckInTime"
          label="首次签到时间"
          width="180"
        >
          <template #default="{ row }">
            {{ row.firstCheckInTime ? formatToDateTime(row.firstCheckInTime) : '-' }}
          </template>
        </ElTableColumn>
        <ElTableColumn
          v-if="participantsCharityType !== 'donation'"
          prop="lastCheckInTime"
          label="最后签到时间"
          width="180"
        >
          <template #default="{ row }">
            {{ row.lastCheckInTime ? formatToDateTime(row.lastCheckInTime) : '-' }}
          </template>
        </ElTableColumn>
      </ElTable>
    </div>
  </ElDialog>

  <!-- 发布/编辑文章对话框 -->
  <ElDialog
    v-model="articleDialogVisible"
    :title="articleDialogTitle"
    width="1200px"
    :max-height="900"
  >
    <Form
      :schema="[
        {
          field: 'title',
          label: '文章标题',
          component: 'Input',
          componentProps: {
            placeholder: '请输入文章标题'
          },
          colProps: { span: 24 },
          formItemProps: {
            rules: [{ required: true, message: '请输入文章标题', trigger: 'blur' }]
          }
        },
        {
          field: 'content',
          label: '文章内容',
          component: 'Editor',
          componentProps: {
            placeholder: '请输入文章内容'
          },
          colProps: { span: 24 },
          formItemProps: {
            rules: [{ required: true, message: '请输入文章内容', trigger: 'blur' }]
          }
        },
        {
          field: 'sendNotification',
          label: '发送通知',
          component: 'Switch',
          componentProps: {
            activeText: '是',
            inactiveText: '否'
          },
          colProps: { span: 24 }
        }
      ]"
      @register="articleFormRegister"
      label-width="100px"
    />

    <template #footer>
      <BaseButton type="primary" :loading="articleLoading" @click="handleArticleSubmit">
        {{ articleDialogArticleId ? '保存' : '发布' }}
      </BaseButton>
      <BaseButton @click="articleDialogVisible = false">取消</BaseButton>
    </template>
  </ElDialog>

  <!-- 文章列表对话框 -->
  <ElDialog v-model="articlesDialogVisible" title="文章列表" width="800px">
    <div v-loading="articlesLoading">
      <ElTable :data="articlesData" border max-height="500">
        <ElTableColumn prop="id" label="文章ID" width="80" />
        <ElTableColumn prop="title" label="标题" width="200" />
        <ElTableColumn prop="content" label="内容" show-overflow-tooltip />
        <ElTableColumn prop="publisherId" label="发布者ID" width="100" />
        <ElTableColumn prop="isPublished" label="发布状态" width="100">
          <template #default="{ row }">
            <ElTag :type="row.isPublished ? 'success' : 'info'">
              {{ row.isPublished ? '已发布' : '草稿' }}
            </ElTag>
          </template>
        </ElTableColumn>
        <ElTableColumn prop="createdAt" label="发布时间" width="180">
          <template #default="{ row }">
            {{ row.createdAt ? formatToDateTime(row.createdAt) : '-' }}
          </template>
        </ElTableColumn>
      </ElTable>
    </div>
  </ElDialog>
</template>

<style scoped lang="scss">
.mb-10px {
  margin-bottom: 10px;
}

:deep(.operation-text) {
  cursor: pointer;
  font-size: 14px;
  line-height: 1;

  &:hover {
    opacity: 0.8;
  }
}

:deep(.operation-text--primary) {
  color: var(--el-color-primary);
}

:deep(.operation-text--success) {
  color: var(--el-color-success);
}

:deep(.operation-text--info) {
  color: var(--el-color-info);
}

:deep(.operation-text--danger) {
  color: var(--el-color-danger);
}
</style>
