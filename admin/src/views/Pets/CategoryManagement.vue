<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { ElMessage, ElMessageBox, ElInput } from 'element-plus'
import { Table, type TableColumn } from '@/components/Table'
import {
  getPetCategoryTreeApi,
  createPetCategoryApi,
  updatePetCategoryApi,
  deletePetCategoryApi,
  type PetCategoryTreeNode,
  type PetCategory
} from '@/api-new/pet-categories'
import { ref, reactive, onMounted, nextTick, computed } from 'vue'
import { BaseButton } from '@/components/Button'
import { Dialog } from '@/components/Dialog'
import { Form, FormSchema } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'

defineOptions({
  name: 'PetCategoryManagement'
})

// 表格数据
const loading = ref(false)
const tableData = ref<PetCategoryTreeNode[]>([])
const searchKeyword = ref('')

// 对话框相关
const dialogVisible = ref(false)
const dialogTitle = ref('新增分类')
const saveLoading = ref(false)
const editingRow = ref<PetCategory | null>(null)

// 表单相关
const { formRegister, formMethods } = useForm()
const { getElFormExpose, setValues, getFormData } = formMethods

// 一级分类列表（用于父级选择）
const firstLevelCategories = computed(() => {
  return tableData.value.filter((item) => !item.parentId)
})

// 表单配置
const formSchema = ref<FormSchema[]>([
  {
    field: 'name',
    label: '分类名称',
    component: 'Input',
    componentProps: {
      placeholder: '请输入分类名称',
      maxlength: 100,
      showWordLimit: true
    },
    formItemProps: {
      rules: [{ required: true, message: '请输入分类名称', trigger: 'blur' }]
    },
    colProps: { span: 24 }
  },
  {
    field: 'parentId',
    label: '父级分类',
    component: 'Select',
    componentProps: {
      placeholder: '请选择父级分类（不选则为一级分类）',
      options: computed(() => [
        { label: '无（一级分类）', value: null },
        ...firstLevelCategories.value.map((cat) => ({
          label: cat.name,
          value: cat.id
        }))
      ]),
      clearable: true
    },
    colProps: { span: 24 }
  },
  {
    field: 'sortOrder',
    label: '排序序号',
    component: 'InputNumber',
    componentProps: {
      min: 0,
      placeholder: '数字越小越靠前'
    },
    formItemProps: {
      rules: [{ required: true, message: '请输入排序序号', trigger: 'blur' }]
    },
    colProps: { span: 24 }
  }
])

// 表格列配置
const columns = reactive<TableColumn[]>([
  {
    field: 'name',
    label: '分类名称',
    minWidth: 300
  },
  {
    field: 'parentId',
    label: '父级分类',
    width: 200,
    slots: {
      default: (data: any) => {
        const row = data.row as PetCategoryTreeNode
        // 如果是一级分类，显示"-"
        if (!row.parentId) {
          return <span>-</span>
        }
        // 查找父级分类名称
        const parent = findParentCategory(tableData.value, row.parentId)
        return <span>{parent?.name || '-'}</span>
      }
    }
  },
  {
    field: 'sortOrder',
    label: '排序',
    width: 120
  },
  {
    field: 'createdAt',
    label: '创建时间',
    width: 180,
    slots: {
      default: (data: any) => {
        return <span>{formatDateTime(data.row.createdAt)}</span>
      }
    }
  },
  {
    field: 'action',
    label: '操作',
    width: 200,
    slots: {
      default: (data: any) => {
        return (
          <>
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
])

/**
 * 递归查找父级分类
 */
const findParentCategory = (
  categories: PetCategoryTreeNode[],
  parentId: number
): PetCategoryTreeNode | null => {
  for (const category of categories) {
    if (category.id === parentId) {
      return category
    }
    if (category.children && category.children.length > 0) {
      const found = findParentCategory(category.children, parentId)
      if (found) return found
    }
  }
  return null
}

/**
 * 格式化日期时间
 */
const formatDateTime = (dateStr: string) => {
  if (!dateStr) return '-'
  const date = new Date(dateStr)
  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  })
}

/**
 * 递归过滤树形数据
 */
const filterTreeData = (data: PetCategoryTreeNode[], keyword: string): PetCategoryTreeNode[] => {
  const result: PetCategoryTreeNode[] = []
  for (const item of data) {
    // 检查当前节点是否匹配
    const isMatch = item.name.toLowerCase().includes(keyword.toLowerCase())
    // 递归过滤子节点
    const filteredChildren = item.children ? filterTreeData(item.children, keyword) : []

    // 如果当前节点匹配或有匹配的子节点，则保留
    if (isMatch || filteredChildren.length > 0) {
      result.push({
        ...item,
        children: filteredChildren.length > 0 ? filteredChildren : item.children
      })
    }
  }
  return result
}

/**
 * 加载数据
 */
const loadData = async () => {
  loading.value = true
  try {
    const res = await getPetCategoryTreeApi()
    tableData.value = res.data || []
  } catch (error) {
    console.error('加载分类列表失败:', error)
    ElMessage.error('加载失败，请稍后重试')
  } finally {
    loading.value = false
  }
}

/**
 * 打开新增对话框
 */
const handleAdd = () => {
  dialogTitle.value = '新增分类'
  editingRow.value = null
  dialogVisible.value = true

  nextTick(() => {
    setValues({
      name: '',
      parentId: null,
      sortOrder: 0
    })
  })
}

/**
 * 打开编辑对话框
 */
const handleEdit = (row: PetCategory) => {
  dialogTitle.value = '编辑分类'
  editingRow.value = row
  dialogVisible.value = true

  nextTick(() => {
    setValues({
      name: row.name,
      parentId: row.parentId,
      sortOrder: row.sortOrder
    })
  })
}

/**
 * 删除
 */
const handleDelete = async (row: PetCategory) => {
  // 计算子分类数量
  const childCount = countChildren(row)

  let confirmMessage = '确认要删除这个分类吗？'
  if (childCount > 0) {
    confirmMessage = `确认要删除这个分类及其 ${childCount} 个子分类吗？删除后无法恢复。`
  } else {
    confirmMessage = '确认要删除这个分类吗？删除后无法恢复。'
  }

  try {
    await ElMessageBox.confirm(confirmMessage, '提示', {
      type: 'warning',
      confirmButtonText: '确认删除',
      cancelButtonText: '取消'
    })

    await deletePetCategoryApi(row.id)
    ElMessage.success('删除成功')
    await loadData()
  } catch (error: any) {
    if (error !== 'cancel') {
      console.error('删除失败:', error)
      ElMessage.error('删除失败，请稍后重试')
    }
  }
}

/**
 * 计算子分类数量
 */
const countChildren = (row: PetCategoryTreeNode): number => {
  if (!row.children || row.children.length === 0) {
    return 0
  }
  let count = row.children.length
  for (const child of row.children) {
    count += countChildren(child)
  }
  return count
}

/**
 * 提交表单
 */
const handleSubmit = async () => {
  try {
    saveLoading.value = true

    // 表单验证
    const elForm = await getElFormExpose()
    const valid = await elForm?.validate()
    if (!valid) {
      ElMessage.error('请检查表单数据')
      return
    }

    // 获取表单数据
    const formData = await getFormData()

    // 构建提交数据
    const submitData = {
      name: formData.name || '',
      parentId: formData.parentId || null,
      sortOrder: Number(formData.sortOrder) || 0
    }

    const isEdit = !!editingRow.value
    if (isEdit && editingRow.value) {
      await updatePetCategoryApi(editingRow.value.id, submitData)
      ElMessage.success('更新成功')
    } else {
      await createPetCategoryApi(submitData)
      ElMessage.success('创建成功')
    }

    dialogVisible.value = false
    await loadData()
  } catch (error: any) {
    console.error('提交失败:', error)
    ElMessage.error('操作失败，请稍后重试')
  } finally {
    saveLoading.value = false
  }
}

/**
 * 关闭对话框
 */
const handleCancel = () => {
  dialogVisible.value = false
}

// 计算属性：过滤后的数据
const filteredTableData = computed(() => {
  if (!searchKeyword.value.trim()) {
    return tableData.value
  }
  return filterTreeData(tableData.value, searchKeyword.value)
})

// 页面加载时获取数据
onMounted(() => {
  loadData()
})
</script>

<template>
  <ContentWrap>
    <div class="app-container">
      <!-- 操作栏 -->
      <div class="mb-4 flex justify-between items-center">
        <div class="flex items-center gap-2">
          <h3 class="text-lg font-semibold">宠物类别列表</h3>
          <ElInput
            v-model="searchKeyword"
            placeholder="搜索分类名称"
            clearable
            style="width: 200px"
            class="ml-4"
          />
        </div>
        <BaseButton type="primary" @click="handleAdd"> 新增分类 </BaseButton>
      </div>

      <!-- 表格 -->
      <Table
        :columns="columns"
        :data="filteredTableData"
        :loading="loading"
        row-key="id"
        :tree-props="{ children: 'children', hasChildren: 'hasChildren' }"
        :default-expand-all="true"
      />

      <!-- 编辑对话框 -->
      <Dialog v-model="dialogVisible" :title="dialogTitle" width="600px">
        <Form :schema="formSchema" @register="formRegister" label-width="100px" />

        <template #footer>
          <BaseButton type="primary" :loading="saveLoading" @click="handleSubmit">
            保存
          </BaseButton>
          <BaseButton @click="handleCancel">取消</BaseButton>
        </template>
      </Dialog>
    </div>
  </ContentWrap>
</template>

<style scoped lang="scss">
.app-container {
  padding: 20px;
}
</style>
