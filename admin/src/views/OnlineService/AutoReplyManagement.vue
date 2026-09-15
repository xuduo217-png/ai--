<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { ElMessage, ElMessageBox, ElTag } from 'element-plus'
import { Table } from '@/components/Table'
import type { TableColumn } from '@/components/Table'
import {
  getAutoReplyListApi,
  createAutoReplyApi,
  updateAutoReplyApi,
  deleteAutoReplyApi,
  clearAutoReplyCacheApi,
  type AutoReply
} from '@/api-new/auto-reply'
import { ref, reactive, onMounted, nextTick } from 'vue'
import { BaseButton } from '@/components/Button'
import { Dialog } from '@/components/Dialog'
import { Form, FormSchema } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'

defineOptions({
  name: 'AutoReplyManagement'
})

// 表格数据
const loading = ref(false)
const dataList = ref<AutoReply[]>([])
const tableRef = ref<InstanceType<typeof Table>>()

// 对话框相关
const dialogVisible = ref(false)
const dialogTitle = ref('新增自动回复')
const saveLoading = ref(false)
const editingRow = ref<AutoReply | null>(null) // 保存当前编辑的行数据

// 表单相关
const { formRegister, formMethods } = useForm()
const { getElFormExpose, setValues, getFormData } = formMethods

// 表单配置
const formSchema = ref<FormSchema[]>([
  {
    field: 'content',
    label: '回复内容',
    component: 'Input',
    componentProps: {
      type: 'textarea',
      rows: 4,
      maxlength: 500,
      showWordLimit: true,
      placeholder: '请输入自动回复内容'
    },
    formItemProps: {
      rules: [{ required: true, message: '请输入回复内容', trigger: 'blur' }]
    }
  },
  {
    field: 'sortOrder',
    label: '排序序号',
    component: 'InputNumber',
    componentProps: {
      min: 1,
      placeholder: '请输入排序序号，数字越小越靠前'
    },
    formItemProps: {
      rules: [{ required: true, message: '请输入排序序号', trigger: 'blur' }]
    }
  },
  {
    field: 'isActive',
    label: '是否启用',
    component: 'Switch',
    componentProps: {
      activeText: '启用',
      inactiveText: '禁用'
    }
  }
])

// 表格列配置
const columns = reactive<TableColumn[]>([
  {
    field: 'index',
    label: '序号',
    type: 'index',
    width: 60
  },
  {
    field: 'content',
    label: '回复内容',
    minWidth: 300
  },
  {
    field: 'sortOrder',
    label: '排序',
    width: 80
  },
  {
    field: 'isActive',
    label: '状态',
    width: 80,
    slots: {
      default: (data: any) => {
        return data.row.isActive ? (
          <ElTag type="success">启用</ElTag>
        ) : (
          <ElTag type="info">禁用</ElTag>
        )
      }
    }
  },
  {
    field: 'action',
    label: '操作',
    width: 180,
    slots: {
      default: (data: any) => {
        return (
          <>
            <BaseButton type="primary" link onClick={() => handleEdit(data.row)}>
              编辑
            </BaseButton>
            <BaseButton
              type={data.row.isActive ? 'warning' : 'success'}
              link
              onClick={() => handleToggleStatus(data.row)}
            >
              {data.row.isActive ? '禁用' : '启用'}
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
 * 加载数据列表
 */
const loadData = async () => {
  loading.value = true
  try {
    const res = await getAutoReplyListApi()
    // axios 拦截器返回 response.data，直接使用
    dataList.value = res.data || []
  } catch (error) {
    console.error('加载自动回复列表失败:', error)
    ElMessage.error('加载失败，请稍后重试')
  } finally {
    loading.value = false
  }
}

/**
 * 打开新增对话框
 */
const handleAdd = () => {
  dialogTitle.value = '新增自动回复'
  editingRow.value = null
  dialogVisible.value = true

  // 等待对话框打开后再设置表单值
  nextTick(() => {
    setValues({
      content: '',
      sortOrder: dataList.value.length + 1,
      isActive: true
    })
  })
}

/**
 * 打开编辑对话框
 */
const handleEdit = (row: AutoReply) => {
  dialogTitle.value = '编辑自动回复'
  editingRow.value = row
  dialogVisible.value = true

  // 等待对话框打开后再设置表单值
  nextTick(() => {
    setValues({
      content: row.content,
      sortOrder: row.sortOrder,
      isActive: row.isActive
    })
  })
}

/**
 * 切换启用状态
 */
const handleToggleStatus = async (row: AutoReply) => {
  try {
    const action = row.isActive ? '禁用' : '启用'
    await ElMessageBox.confirm(`确认要${action}这条自动回复吗？`, '提示', {
      type: 'warning'
    })

    await updateAutoReplyApi(row.id, { isActive: !row.isActive })
    ElMessage.success(`${action}成功`)

    // 清空自动回复缓存，使更改立即生效
    try {
      await clearAutoReplyCacheApi()
      console.log('自动回复缓存已清空')
    } catch (cacheError) {
      console.warn('清空缓存失败，但不影响业务逻辑:', cacheError)
    }

    await loadData()
  } catch (error: any) {
    if (error !== 'cancel') {
      console.error('切换状态失败:', error)
      ElMessage.error('操作失败，请稍后重试')
    }
  }
}

/**
 * 删除
 */
const handleDelete = async (row: AutoReply) => {
  try {
    await ElMessageBox.confirm('确认要删除这条自动回复吗？删除后无法恢复。', '提示', {
      type: 'warning',
      confirmButtonText: '确认删除',
      cancelButtonText: '取消'
    })

    await deleteAutoReplyApi(row.id)
    ElMessage.success('删除成功')

    // 清空自动回复缓存，使更改立即生效
    try {
      await clearAutoReplyCacheApi()
      console.log('自动回复缓存已清空')
    } catch (cacheError) {
      console.warn('清空缓存失败，但不影响业务逻辑:', cacheError)
    }

    await loadData()
  } catch (error: any) {
    if (error !== 'cancel') {
      console.error('删除失败:', error)
      ElMessage.error('删除失败，请稍后重试')
    }
  }
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
      content: formData.content || '',
      sortOrder: Number(formData.sortOrder) || 1,
      isActive: formData.isActive !== undefined ? formData.isActive : true
    }

    const isEdit = !!editingRow.value
    if (isEdit && editingRow.value) {
      await updateAutoReplyApi(editingRow.value.id, submitData)
      ElMessage.success('更新成功')
    } else {
      await createAutoReplyApi(submitData)
      ElMessage.success('创建成功')
    }

    // 清空自动回复缓存，使更改立即生效
    try {
      await clearAutoReplyCacheApi()
      console.log('自动回复缓存已清空')
    } catch (cacheError) {
      console.warn('清空缓存失败，但不影响业务逻辑:', cacheError)
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
        <h3 class="text-lg font-semibold">自动回复列表</h3>
        <BaseButton type="primary" @click="handleAdd"> 新增自动回复 </BaseButton>
      </div>

      <!-- 表格 -->
      <Table ref="tableRef" :columns="columns" :data="dataList" :loading="loading" />

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
