<script setup lang="tsx">
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox, ElTag } from 'element-plus'
import { h } from 'vue'
import { Table } from '@/components/Table'
import { BaseButton } from '@/components/Button'
import { Dialog } from '@/components/Dialog'
import {
  getDoctorServiceItemsApi,
  addServiceItemApi,
  updateServiceItemApi,
  deleteServiceItemApi,
  type DoctorServiceItem,
  type CreateServiceItemParams,
  type UpdateServiceItemParams
} from '@/api-new/doctors'
import ServiceItemFormDialog from './ServiceItemFormDialog.vue'

const props = defineProps<{
  doctorId: number
  doctorName: string
}>()

const emit = defineEmits<{
  close: []
  refresh: []
}>()

// 收费项列表
const serviceItems = ref<DoctorServiceItem[]>([])
const loading = ref(false)

// 编辑弹窗
const editDialogVisible = ref(false)
const currentEditItem = ref<DoctorServiceItem | null>(null)
const editMode = ref<'create' | 'update'>('create')
const formRef = ref()

/**
 * 加载收费项列表
 */
const loadServiceItems = async () => {
  loading.value = true
  try {
    const res = await getDoctorServiceItemsApi(props.doctorId)
    serviceItems.value = res.data || []
  } catch (error) {
    console.error('加载收费项失败:', error)
    ElMessage.error('加载收费项失败')
  } finally {
    loading.value = false
  }
}

/**
 * 添加收费项
 */
const handleAdd = () => {
  editMode.value = 'create'
  currentEditItem.value = null
  editDialogVisible.value = true
}

/**
 * 编辑收费项
 */
const handleEdit = (item: DoctorServiceItem) => {
  editMode.value = 'update'
  currentEditItem.value = item
  editDialogVisible.value = true
}

/**
 * 删除收费项
 */
const handleDelete = async (item: DoctorServiceItem) => {
  try {
    await ElMessageBox.confirm(`确定要删除收费项"${item.name}"吗？`, '提示', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    })

    await deleteServiceItemApi(props.doctorId, item.id)
    ElMessage.success('删除成功')
    loadServiceItems()
    emit('refresh')
  } catch (error) {
    if (error !== 'cancel') {
      console.error('删除失败:', error)
      ElMessage.error('删除失败')
    }
  }
}

/**
 * 保存收费项
 */
const handleSave = async (formData: CreateServiceItemParams | UpdateServiceItemParams) => {
  try {
    if (editMode.value === 'create') {
      await addServiceItemApi(props.doctorId, formData as CreateServiceItemParams)
      ElMessage.success('添加成功')
    } else {
      await updateServiceItemApi(
        props.doctorId,
        currentEditItem.value!.id,
        formData as UpdateServiceItemParams
      )
      ElMessage.success('更新成功')
    }

    editDialogVisible.value = false
    loadServiceItems()
    emit('refresh')
  } catch (error) {
    console.error('保存失败:', error)
    ElMessage.error('保存失败')
  }
}

/**
 * 切换启用状态
 */
const handleToggleActive = async (item: DoctorServiceItem) => {
  try {
    await updateServiceItemApi(props.doctorId, item.id, { isActive: !item.isActive })
    ElMessage.success('状态更新成功')
    loadServiceItems()
    emit('refresh')
  } catch (error) {
    console.error('状态更新失败:', error)
    ElMessage.error('状态更新失败')
  }
}

onMounted(() => {
  loadServiceItems()
})

// 暴露表单引用
defineExpose({
  formRef
})
</script>

<template>
  <div class="service-items-management">
    <!-- 操作按钮 -->
    <div class="mb-4 flex justify-between items-center">
      <div class="text-sm text-gray-600"> 共 {{ serviceItems.length }} 个收费项 </div>
      <BaseButton type="primary" @click="handleAdd"> 添加收费项 </BaseButton>
    </div>

    <!-- 收费项表格 -->
    <Table
      :columns="[
        {
          field: 'sortOrder',
          label: '排序',
          width: 60,
          slots: {
            default: (data: any) => h('span', {}, data.row.sortOrder + 1)
          }
        },
        {
          field: 'name',
          label: '服务名称',
          minWidth: 100
        },
        {
          field: 'duration',
          label: '时长',
          width: 100,
          slots: {
            default: (data: any) => h('span', {}, `${data.row.duration} 分钟`)
          }
        },
        {
          field: 'price',
          label: '价格',
          width: 100,
          slots: {
            default: (data: any) => h('span', { class: 'text-red-600 font-semibold' }, `¥${data.row.price}`)
          }
        },
        {
          field: 'description',
          label: '描述',
          minWidth: 160,
          slots: {
            default: (data: any) => h('span', { class: 'text-gray-500' }, data.row.description || '-')
          }
        },
        {
          field: 'isActive',
          label: '状态',
          width: 100,
          slots: {
            default: (data: any) => h(
              ElTag,
              {
                type: data.row.isActive ? 'success' : 'info',
                style: { cursor: 'pointer' },
                onClick: () => handleToggleActive(data.row)
              },
              () => data.row.isActive ? '启用' : '禁用'
            )
          }
        },
        {
          field: 'action',
          label: '操作',
          width: 180,
          slots: {
            default: (data: any) => [
              h(BaseButton, {
                type: 'primary',
                onClick: () => handleEdit(data.row)
              }, () => '编辑'),
              h(BaseButton, {
                type: 'danger',
                onClick: () => handleDelete(data.row)
              }, () => '删除')
            ]
          }
        }
      ]"
      :data="serviceItems"
      :loading="loading"
    />

    <!-- 新增/编辑弹窗 -->
    <Dialog
      v-model="editDialogVisible"
      :title="editMode === 'create' ? '添加收费项' : '编辑收费项'"
      width="600px"
    >
      <ServiceItemFormDialog
        v-if="editDialogVisible"
        ref="formRef"
        :current-item="currentEditItem"
        :mode="editMode"
        @submit="handleSave"
        @cancel="editDialogVisible = false"
      />

      <template #footer>
        <BaseButton type="primary" @click="formRef?.submit()"> 保存 </BaseButton>
        <BaseButton @click="editDialogVisible = false">取消</BaseButton>
      </template>
    </Dialog>
  </div>
</template>

<style scoped lang="less">
.service-items-management {
  .mb-4 {
    margin-bottom: 16px;
  }
  .flex {
    display: flex;
  }
  .justify-between {
    justify-content: space-between;
  }
  .items-center {
    align-items: center;
  }
  .text-sm {
    font-size: 14px;
  }
  .text-gray-600 {
    color: #6b7280;
  }
  .text-red-600 {
    color: #dc2626;
  }
  .text-gray-500 {
    color: #9ca3af;
  }
  .font-semibold {
    font-weight: 600;
  }
}
</style>
