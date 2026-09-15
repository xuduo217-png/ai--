<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { Search } from '@/components/Search'
import { ElTag, ElMessage, ElMessageBox, ElTabs, ElTabPane, ElSelect, ElSwitch } from 'element-plus'
import { useTable } from '@/hooks/web/useTable'
import { ref, unref, computed, nextTick } from 'vue'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { BaseButton } from '@/components/Button'
import { Dialog } from '@/components/Dialog'
import { Form } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import { useRouter } from 'vue-router'
import { VueDraggable } from 'vue-draggable-plus'
import {
  getSelfCheckListsApi,
  createSelfCheckListApi,
  updateSelfCheckListApi,
  deleteSelfCheckListApi,
  updateSelfCheckListStatusApi,
  reorderSelfCheckListsApi,
  type SelfCheckList
} from '@/api-new/ai-self-check'
import { getPetCategoryTreeApi, type PetCategoryTreeNode } from '@/api-new/pet-categories'
import { formatToDateTime } from '@/utils/dateUtil'

defineOptions({
  name: 'SelfCheckLists'
})

const router = useRouter()

// 分类数据
const categoryTree = ref<PetCategoryTreeNode[]>([])
const firstLevelCategories = computed(() => {
  return categoryTree.value
    .filter((cat) => !cat.parentId)
    .map((cat) => ({ label: cat.name, value: cat.id }))
})

// 计算是否有筛选条件
const hasFilters = computed(() => {
  // 检查是否有用户输入的搜索条件
  return Object.values(searchParams.value).some((v) => v !== '' && v !== undefined)
})

const loadCategories = async () => {
  try {
    const res = await getPetCategoryTreeApi()
    categoryTree.value = res.data || []
  } catch (error) {
    console.error('加载分类数据失败:', error)
  }
}

// Tabs 状态
const activeTab = ref<'PUBLIC' | 'SPECIFIC'>('PUBLIC')
const categoryIdFilter = ref<number>()

// 对话框
const dialogVisible = ref(false)
const dialogTitle = ref('')
const currentRow = ref<SelfCheckList | null>(null)
const saveLoading = ref(false)

// 表单
const { formRegister, formMethods } = useForm()
const { setValues, getFormData, getElFormExpose } = formMethods
const formType = ref<'PUBLIC' | 'SPECIFIC'>('PUBLIC')

// 拖动排序状态
const isReordering = ref(false)
const originalOrder = ref<SelfCheckList[]>([])

// CRUD Schema
const crudSchemas: CrudSchema[] = [
  {
    field: 'title',
    label: '自查表标题',
    search: {
      component: 'Input',
      componentProps: { placeholder: '请输入标题' }
    },
    form: {
      component: 'Input',
      componentProps: { placeholder: '请输入自查表标题' },
      formItemProps: {
        rules: [{ required: true, message: '请输入自查表标题', trigger: 'blur' }]
      }
    }
  },
  {
    field: 'type',
    label: '类型',
    search: { hidden: true },
    form: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '公共项', value: 'PUBLIC' },
          { label: '特定项', value: 'SPECIFIC' }
        ],
        onChange: (value: 'PUBLIC' | 'SPECIFIC') => {
          formType.value = value
        }
      },
      formItemProps: {
        rules: [{ required: true, message: '请选择类型', trigger: 'change' }]
      }
    },
    table: {
      width: 120,
      slots: {
        default: (data: any) => {
          return data.row.type === 'PUBLIC' ? (
            <ElTag type="success">公共项</ElTag>
          ) : (
            <ElTag type="primary">{data.row.categoryName || '-'}</ElTag>
          )
        }
      }
    }
  },
  {
    field: 'categoryId',
    label: '关联分类',
    search: { hidden: true },
    form: {
      component: 'Select',
      componentProps: {
        options: firstLevelCategories,
        placeholder: '请选择一级分类（仅特定项需要）',
        disabled: computed(() => formType.value !== 'SPECIFIC')
      }
    },
    table: { hidden: true }
  },
  {
    field: 'questionCount',
    label: '问题数量',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      width: 100,
      slots: {
        default: (data: any) => <span>{data.row.questionCount || 0}</span>
      }
    }
  },
  {
    field: 'status',
    label: '状态',
    search: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '启用', value: 'ACTIVE' },
          { label: '禁用', value: 'INACTIVE' }
        ],
        placeholder: '请选择状态'
      }
    },
    form: { hidden: true },
    table: {
      width: 100,
      slots: {
        default: (data: any) => {
          return (
            <ElSwitch
              modelValue={data.row.status}
              activeValue="ACTIVE"
              inactiveValue="INACTIVE"
              onChange={(value: string) => handleStatusChange(data.row, value)}
            />
          )
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
      width: 180,
      slots: {
        default: (data: any) => {
          return data.row.createdAt ? formatToDateTime(data.row.createdAt) : '-'
        }
      }
    }
  },
  {
    field: 'action',
    label: '操作',
    width: 280,
    search: { hidden: true },
    form: { hidden: true },
    table: {
      fixed: 'right',
      slots: {
        default: (data: any) => {
          return (
            <>
              <BaseButton type="primary" link onClick={() => handleManageQuestions(data.row)}>
                问题管理
              </BaseButton>
              <BaseButton type="primary" link onClick={() => handleEdit(data.row)}>
                编辑
              </BaseButton>
              <BaseButton type="danger" link onClick={() => handleDelete(data.row)}>
                删除
              </BaseButton>
            </>
          )
        }
      }
    }
  }
]

const { allSchemas } = useCrudSchemas(crudSchemas)

// 表格配置
const searchParams = ref<Record<string, any>>({})

const { tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    // 获取所有数据（不分页），以便拖动排序
    const res = await getSelfCheckListsApi({
      type: unref(activeTab),
      categoryId: unref(categoryIdFilter),
      pageSize: 1000, // 获取足够多的数据，避免分页限制
      ...unref(searchParams)
    })

    return {
      list: res.data || [],
      total: res.pagination?.total || res.data?.length || 0
    }
  }
})

const { dataList, loading } = tableState
const { getList } = tableMethods

// 事件处理
const handleAdd = () => {
  dialogTitle.value = `新增${activeTab.value === 'PUBLIC' ? '公共项' : '特定项'}`
  currentRow.value = null
  formType.value = activeTab.value
  dialogVisible.value = true

  nextTick(() => {
    setValues({
      title: '',
      type: activeTab.value,
      categoryId: undefined
    })
  })
}

const handleEdit = (row: SelfCheckList) => {
  dialogTitle.value = '编辑自查表'
  currentRow.value = row
  formType.value = row.type
  dialogVisible.value = true

  nextTick(() => {
    setValues({
      title: row.title,
      type: row.type,
      categoryId: row.categoryId
    })
  })
}

const handleDelete = async (row: SelfCheckList) => {
  try {
    await ElMessageBox.confirm(`确定要删除自查表"${row.title}"吗？`, '提示', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    })

    await deleteSelfCheckListApi(row.id)
    ElMessage.success('删除成功')
    getList()
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}

const handleStatusChange = async (row: SelfCheckList, value: string) => {
  try {
    await updateSelfCheckListStatusApi(row.id, value as any)
    ElMessage.success('状态更新成功')
  } catch (error) {
    ElMessage.error('状态更新失败')
  }
}

const handleManageQuestions = (row: SelfCheckList) => {
  router.push({
    name: 'SelfCheckQuestions',
    params: { id: row.id }
  })
}

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

    if (formData.type === 'SPECIFIC' && !formData.categoryId) {
      ElMessage.error('特定项必须选择关联的分类')
      return
    }

    const submitData = {
      title: formData.title,
      type: formData.type,
      categoryId: formData.type === 'SPECIFIC' ? formData.categoryId : null,
      status: 'ACTIVE'
    }

    if (currentRow.value?.id) {
      await updateSelfCheckListApi(currentRow.value.id, submitData)
      ElMessage.success('更新成功')
    } else {
      // 新增时需要设置 sortOrder
      await createSelfCheckListApi({ ...submitData, sortOrder: 0 })
      ElMessage.success('创建成功')
    }

    dialogVisible.value = false
    getList()
  } catch (error) {
    ElMessage.error('操作失败')
  } finally {
    saveLoading.value = false
  }
}

const handleTabChange = () => {
  categoryIdFilter.value = undefined
  searchParams.value = {}
  getList()
}

/**
 * 列表拖动结束处理
 */
const handleTableDragEnd = async () => {
  // 有筛选条件时禁用拖动
  if (hasFilters.value) {
    ElMessage.warning('请清除筛选后再拖动排序')
    await getList()
    return
  }

  // 只有一条数据时不需要排序
  if (dataList.value.length < 2) {
    return
  }

  // 防止重复请求
  if (isReordering.value) {
    return
  }

  isReordering.value = true
  // 保存原始数据用于错误恢复
  originalOrder.value = [...dataList.value]
  // 提取所有 ID（按新顺序）
  const listIds = dataList.value.map((item) => item.id)

  try {
    await reorderSelfCheckListsApi(listIds)
    ElMessage.success('排序已保存')
  } catch (error) {
    // 恢复原始顺序
    dataList.value = [...originalOrder.value]
    ElMessage.error('排序保存失败，已恢复原序')
  } finally {
    isReordering.value = false
  }
}

// 初始化
loadCategories()
</script>

<template>
  <ContentWrap>
    <el-tabs v-model="activeTab" @tab-change="handleTabChange" class="mb-4">
      <el-tab-pane label="公共项" name="PUBLIC" />
      <el-tab-pane name="SPECIFIC">
        <template #label>
          <span>特定项</span>
          <el-select
            v-model="categoryIdFilter"
            placeholder="筛选分类"
            clearable
            size="small"
            style="width: 150px; margin-left: 10px"
            @change="getList"
          >
            <el-option label="全部" value="" />
            <el-option
              v-for="cat in firstLevelCategories"
              :key="cat.value"
              :label="cat.label"
              :value="cat.value"
            />
          </el-select>
        </template>
      </el-tab-pane>
    </el-tabs>

    <Search
      :schema="allSchemas.searchSchema"
      @search="
        (params) => {
          searchParams = params
          getList()
        }
      "
      @reset="
        (params) => {
          searchParams = params
          getList()
        }
      "
    />

    <div class="mb-10px">
      <BaseButton type="primary" @click="handleAdd">
        新增{{ activeTab === 'PUBLIC' ? '公共项' : '特定项' }}
      </BaseButton>
    </div>

    <!-- 卡片列表（支持拖动排序） -->
    <div v-loading="loading" class="self-check-list">
      <VueDraggable
        v-model="dataList"
        @end="handleTableDragEnd"
        :animation="300"
        handle=".list-drag-handle"
        :disabled="isReordering || hasFilters"
      >
        <div v-for="(item, index) in dataList" :key="item.id" class="card-item">
          <div class="item-header">
            <div class="item-info">
              <span class="list-drag-handle"></span>
              <span class="sort-badge">{{ index + 1 }}</span>
              <span class="item-title">{{ item.title }}</span>
              <ElTag v-if="item.type === 'PUBLIC'" type="success" size="small">公共项</ElTag>
              <ElTag v-else type="primary" size="small">{{ item.categoryName || '-' }}</ElTag>
              <ElTag type="info" size="small">问题数: {{ item.questionCount || 0 }}</ElTag>
            </div>
            <div class="item-actions">
              <BaseButton type="primary" link @click="handleManageQuestions(item)">
                问题管理
              </BaseButton>
              <BaseButton type="primary" link @click="handleEdit(item)"> 编辑 </BaseButton>
              <BaseButton type="danger" link @click="handleDelete(item)"> 删除 </BaseButton>
            </div>
          </div>
          <div class="item-footer">
            <span class="footer-label">状态:</span>
            <ElSwitch
              :model-value="item.status"
              activeValue="ACTIVE"
              inactiveValue="INACTIVE"
              @change="(value: string) => handleStatusChange(item, value)"
            />
            <span class="footer-divider">|</span>
            <span class="footer-label">创建时间:</span>
            <span class="footer-text">{{
              item.createdAt ? formatToDateTime(item.createdAt) : '-'
            }}</span>
          </div>
        </div>
      </VueDraggable>

      <div v-if="!loading && dataList.length === 0" class="empty-state">
        <p>暂无数据</p>
      </div>
    </div>

    <Dialog v-model="dialogVisible" :title="dialogTitle" width="600px">
      <Form :schema="allSchemas.formSchema" @register="formRegister" label-width="100px" />

      <template #footer>
        <BaseButton type="primary" :loading="saveLoading" @click="handleSubmit"> 保存 </BaseButton>
        <BaseButton @click="dialogVisible = false">取消</BaseButton>
      </template>
    </Dialog>
  </ContentWrap>
</template>

<style scoped lang="less">
.mb-4 {
  margin-bottom: 16px;
}
.mb-10px {
  margin-bottom: 10px;
}

// 自查表列表容器样式
.self-check-list {
  min-height: 200px;
}

// 卡片项样式
.card-item {
  border: 1px solid #ebeef5;
  border-radius: 8px;
  margin-bottom: 16px;
  padding: 16px;
  background: #fff;
  transition: all 0.3s;

  &:hover {
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
    border-color: #c0c4cc;
  }

  // 拖动中的样式
  &.sortable-ghost {
    opacity: 0.5;
    background: #f5f7fa;
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
  }

  .item-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    padding-bottom: 12px;

    .item-info {
      display: flex;
      align-items: center;
      gap: 8px;
      flex-wrap: wrap;
      flex: 1;

      .item-title {
        font-size: 15px;
        font-weight: 500;
        color: #303133;
      }
    }

    .item-actions {
      display: flex;
      gap: 4px;
      align-items: center;
    }
  }

  .item-footer {
    display: flex;
    align-items: center;
    gap: 8px;
    padding-top: 12px;
    border-top: 1px solid #f0f0f0;
    font-size: 13px;
    color: #606266;

    .footer-label {
      color: #909399;
    }

    .footer-divider {
      color: #dcdfe6;
      margin: 0 8px;
    }

    .footer-text {
      color: #606266;
    }
  }
}

// 列表拖动手柄样式
.list-drag-handle {
  cursor: move;
  color: #c0c4cc;
  padding: 0 4px;
  margin-right: 8px;
  display: inline-flex;
  align-items: center;
  transition: color 0.3s;

  &:hover {
    color: #409eff;
  }

  &::before {
    content: '⋮⋮';
    font-size: 18px;
    letter-spacing: -2px;
  }
}

// 排序徽章样式
.sort-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: #fff;
  border-radius: 50%;
  font-size: 12px;
  font-weight: 600;
}

// 空状态样式
.empty-state {
  text-align: center;
  padding: 60px 0;
  color: #909399;
  font-size: 14px;
}

// 分页容器样式
.pagination-container {
  display: flex;
  justify-content: center;
  margin-top: 20px;
  padding: 20px 0;
}
</style>
