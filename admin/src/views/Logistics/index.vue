<script setup lang="ts">
import { ref, onMounted } from 'vue'
import {
  ElMessage,
  ElMessageBox,
  ElCard,
  ElTable,
  ElTableColumn,
  ElTag,
  ElButton,
  ElDialog,
  ElForm,
  ElFormItem,
  ElInput,
  ElSwitch
} from 'element-plus'
import {
  getLogisticsListApi,
  createLogisticsApi,
  updateLogisticsApi,
  deleteLogisticsApi,
  toggleLogisticsApi
} from '@/api-new/logistics'
import type { Logistics, LogisticsForm } from '@/api-new/types'

const tableData = ref<Logistics[]>([])
const loading = ref(false)

// 表单对话框
const dialogVisible = ref(false)
const dialogTitle = ref('新增物流公司')
const editingId = ref<number | null>(null) // 存储正在编辑的 ID
const formData = ref<LogisticsForm>({
  name: '',
  code: '',
  isEnabled: true
})

/**
 * 获取物流列表
 */
const fetchList = async () => {
  loading.value = true
  try {
    const { data } = await getLogisticsListApi()
    tableData.value = data
  } catch (error) {
    ElMessage.error('获取物流列表失败')
  } finally {
    loading.value = false
  }
}

/**
 * 新增
 */
const handleAdd = () => {
  dialogTitle.value = '新增物流公司'
  editingId.value = null
  formData.value = {
    name: '',
    code: '',
    isEnabled: true
  }
  dialogVisible.value = true
}

/**
 * 编辑
 */
const handleEdit = (row: Logistics) => {
  dialogTitle.value = '编辑物流公司'
  editingId.value = row.id
  formData.value = {
    name: row.name,
    code: row.code,
    isEnabled: row.isEnabled
  }
  dialogVisible.value = true
}

/**
 * 删除
 */
const handleDelete = async (id: number) => {
  try {
    await ElMessageBox.confirm('确认删除该物流公司吗？', '删除确认', {
      type: 'warning',
      confirmButtonText: '确认',
      cancelButtonText: '取消'
    })
    await deleteLogisticsApi(id)
    ElMessage.success('删除成功')
    await fetchList()
  } catch (error: any) {
    if (error !== 'cancel') {
      ElMessage.error(error.response?.data?.message || '删除失败')
    }
  }
}

/**
 * 切换启用状态
 */
const handleToggle = async (row: Logistics) => {
  try {
    await toggleLogisticsApi(row.id)
    ElMessage.success(`${row.isEnabled ? '禁用' : '启用'}成功`)
    await fetchList()
  } catch (error) {
    ElMessage.error('操作失败')
  }
}

/**
 * 提交表单
 */
const handleSubmit = async () => {
  // 表单验证
  if (!formData.value.name || !formData.value.name.trim()) {
    ElMessage.warning('请输入物流公司名称')
    return
  }
  if (!formData.value.code || !formData.value.code.trim()) {
    ElMessage.warning('请输入物流编码')
    return
  }
  if (!/^[A-Z0-9]{2,10}$/.test(formData.value.code)) {
    ElMessage.warning('物流编码为2-10位大写字母或数字')
    return
  }

  try {
    if (editingId.value) {
      await updateLogisticsApi(editingId.value, formData.value)
      ElMessage.success('更新成功')
    } else {
      await createLogisticsApi(formData.value)
      ElMessage.success('创建成功')
    }
    dialogVisible.value = false
    await fetchList()
  } catch (error: any) {
    ElMessage.error(error.response?.data?.message || '操作失败')
  }
}

onMounted(() => {
  fetchList()
})
</script>

<template>
  <div class="logistics-management">
    <el-card>
      <template #header>
        <el-button type="primary" @click="handleAdd">+ 新增物流公司</el-button>
      </template>

      <el-table :data="tableData" v-loading="loading" border stripe>
        <el-table-column prop="name" label="物流公司名称" />
        <el-table-column prop="code" label="物流编码" width="120" />
        <el-table-column prop="isEnabled" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.isEnabled ? 'success' : 'info'">
              {{ row.isEnabled ? '启用' : '禁用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="创建时间" width="240" />
        <el-table-column label="操作" width="250" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" size="small" @click="handleEdit(row)">编辑</el-button>
            <el-button
              :type="row.isEnabled ? 'warning' : 'success'"
              size="small"
              @click="handleToggle(row)"
            >
              {{ row.isEnabled ? '禁用' : '启用' }}
            </el-button>
            <el-button type="danger" size="small" @click="handleDelete(row.id)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 表单对话框 -->
    <el-dialog v-model="dialogVisible" :title="dialogTitle" width="500px">
      <el-form :model="formData" label-width="120px">
        <el-form-item label="物流公司名称" required>
          <el-input
            v-model="formData.name"
            placeholder="请输入物流公司名称"
            maxlength="100"
            show-word-limit
          />
        </el-form-item>
        <el-form-item label="物流编码" required>
          <el-input
            v-model="formData.code"
            placeholder="如：SF、YTO、ZTO"
            maxlength="10"
            :disabled="!!editingId"
          />
          <div style="color: #999; font-size: 12px; margin-top: 4px">2-10位大写字母或数字</div>
        </el-form-item>
        <el-form-item label="状态">
          <el-switch v-model="formData.isEnabled" active-text="启用" inactive-text="禁用" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSubmit">确认</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped lang="scss">
.logistics-management {
  padding: 16px;
}
</style>
