<script setup lang="ts">
import { ref, onMounted, reactive } from 'vue'
import {
  ElTable,
  ElTableColumn,
  ElCard,
  ElButton,
  ElDialog,
  ElForm,
  ElFormItem,
  ElInput,
  ElMessage,
  ElTag,
  ElSpace
} from 'element-plus'
import { getSystemConfigsApi, updateSystemConfigApi } from '@/api-new/system-configs'
import type { SystemConfig } from '@/api-new/system-configs/types'
import { extractPagedTableData } from '@/utils/pagination'

// 配置列表数据
const configList = ref<SystemConfig[]>([])
const loading = ref(false)

// 编辑对话框
const editDialogVisible = ref(false)
const editForm = reactive({
  configKey: '',
  configValue: {} as Record<string, any>,
  description: ''
})
const editLoading = ref(false)

// 配置值 JSON 编辑器
const jsonEditorVisible = ref(false)
const jsonEditorValue = ref('')

/**
 * 加载配置列表
 */
const loadConfigList = async () => {
  try {
    loading.value = true
    const res = await getSystemConfigsApi({
      page: 1,
      pageSize: 100
    })

    const { list } = extractPagedTableData<SystemConfig>(res)
    configList.value = list
  } catch (error) {
    console.error('加载配置列表失败:', error)
    ElMessage.error('加载配置列表失败')
  } finally {
    loading.value = false
  }
}

/**
 * 打开编辑对话框
 */
const handleEdit = (row: SystemConfig) => {
  editForm.configKey = row.configKey
  editForm.configValue = { ...row.configValue }
  editForm.description = row.description
  editDialogVisible.value = true
}

/**
 * 保存配置
 */
const handleSave = async () => {
  try {
    editLoading.value = true

    await updateSystemConfigApi(editForm.configKey, {
      configValue: editForm.configValue,
      description: editForm.description
    })

    ElMessage.success('保存成功')
    editDialogVisible.value = false
    await loadConfigList()
  } catch (error) {
    console.error('保存配置失败:', error)
    ElMessage.error('保存失败，请稍后重试')
  } finally {
    editLoading.value = false
  }
}

/**
 * 打开 JSON 编辑器
 */
const openJsonEditor = () => {
  jsonEditorValue.value = JSON.stringify(editForm.configValue, null, 2)
  jsonEditorVisible.value = true
}

/**
 * 保存 JSON 编辑
 */
const saveJsonEditor = () => {
  try {
    const parsed = JSON.parse(jsonEditorValue.value)
    editForm.configValue = parsed
    jsonEditorVisible.value = false
    ElMessage.success('JSON 格式验证通过')
  } catch (error) {
    ElMessage.error('JSON 格式错误，请检查')
  }
}

/**
 * 格式化配置值显示
 */
const formatConfigValue = (value: Record<string, any>) => {
  return JSON.stringify(value, null, 2)
}

/**
 * 获取配置标识的标签类型
 */
const getTagType = (configKey: string) => {
  const keyMap: Record<string, any> = {
    contact_info: 'success',
    payment_config: 'warning',
    system_settings: 'info'
  }
  return keyMap[configKey] || ''
}

// 页面加载时获取配置列表
onMounted(() => {
  loadConfigList()
})
</script>

<template>
  <div class="config-management-container">
    <ElCard>
      <template #header>
        <div class="card-header">
          <span class="title">配置管理</span>
          <ElButton type="primary" @click="loadConfigList" :loading="loading"> 刷新 </ElButton>
        </div>
      </template>

      <ElTable :data="configList" v-loading="loading" stripe>
        <ElTableColumn prop="id" label="ID" width="80" />
        <ElTableColumn prop="configKey" label="配置标识" width="200">
          <template #default="{ row }">
            <ElTag :type="getTagType(row.configKey)">
              {{ row.configKey }}
            </ElTag>
          </template>
        </ElTableColumn>
        <ElTableColumn prop="description" label="配置说明" width="200" />
        <ElTableColumn label="配置值" min-width="300">
          <template #default="{ row }">
            <pre class="config-value-preview">{{ formatConfigValue(row.configValue) }}</pre>
          </template>
        </ElTableColumn>
        <ElTableColumn prop="updatedAt" label="更新时间" width="180" />
        <ElTableColumn label="操作" width="120" fixed="right">
          <template #default="{ row }">
            <ElButton type="primary" size="small" @click="handleEdit(row)"> 编辑 </ElButton>
          </template>
        </ElTableColumn>
      </ElTable>
    </ElCard>

    <!-- 编辑对话框 -->
    <ElDialog
      v-model="editDialogVisible"
      :title="`编辑配置: ${editForm.configKey}`"
      width="800px"
      :close-on-click-modal="false"
    >
      <ElForm :model="editForm" label-width="120px" v-loading="editLoading">
        <ElFormItem label="配置标识">
          <ElInput v-model="editForm.configKey" disabled />
        </ElFormItem>

        <ElFormItem label="配置说明">
          <ElInput v-model="editForm.description" placeholder="请输入配置说明" />
        </ElFormItem>

        <ElFormItem label="配置值">
          <ElSpace direction="vertical" style="width: 100%">
            <ElButton type="primary" plain @click="openJsonEditor"> 编辑 JSON </ElButton>
            <pre class="config-value-display">{{ formatConfigValue(editForm.configValue) }}</pre>
          </ElSpace>
        </ElFormItem>
      </ElForm>

      <template #footer>
        <ElButton @click="editDialogVisible = false">取消</ElButton>
        <ElButton type="primary" @click="handleSave" :loading="editLoading"> 保存 </ElButton>
      </template>
    </ElDialog>

    <!-- JSON 编辑器对话框 -->
    <ElDialog
      v-model="jsonEditorVisible"
      title="编辑配置值（JSON 格式）"
      width="600px"
      :close-on-click-modal="false"
    >
      <ElInput
        v-model="jsonEditorValue"
        type="textarea"
        :rows="15"
        placeholder="请输入 JSON 格式的配置值"
      />

      <template #footer>
        <ElButton @click="jsonEditorVisible = false">取消</ElButton>
        <ElButton type="primary" @click="saveJsonEditor"> 确定 </ElButton>
      </template>
    </ElDialog>
  </div>
</template>

<style scoped lang="scss">
.config-management-container {
  padding: 20px;

  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;

    .title {
      font-size: 16px;
      font-weight: 600;
    }
  }

  .config-value-preview {
    margin: 0;
    padding: 8px;
    background-color: var(--el-fill-color-light);
    border-radius: 4px;
    font-size: 12px;
    max-height: 120px;
    overflow: auto;
  }

  .config-value-display {
    margin: 0;
    padding: 12px;
    background-color: var(--el-fill-color-light);
    border-radius: 4px;
    font-size: 13px;
    max-height: 300px;
    overflow: auto;
  }
}
</style>
