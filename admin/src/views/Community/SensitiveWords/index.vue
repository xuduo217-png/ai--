<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { Table } from '@/components/Table'
import { ref, reactive } from 'vue'
import {
  ElTag,
  ElMessage,
  ElMessageBox,
  ElDialog,
  ElButton,
  ElInput,
  ElSelect,
  ElOption,
  ElForm,
  ElFormItem,
  ElSwitch
} from 'element-plus'
import {
  getSensitiveWordsApi,
  createSensitiveWordApi,
  updateSensitiveWordApi,
  deleteSensitiveWordApi,
  batchImportSensitiveWordsApi,
  type SensitiveWord
} from '@/api-new'
import { useTable } from '@/hooks/web/useTable'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { BaseButton } from '@/components/Button'

const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const res = await getSensitiveWordsApi({})
    return {
      list: res.data || [],
      total: res.data?.length || 0
    }
  }
})
const { loading, dataList } = tableState
const { getList } = tableMethods

// 表单弹窗
const formDialogVisible = ref(false)
const formDialogTitle = ref('')
const formSaving = ref(false)
const currentWord = ref<SensitiveWord | null>(null)
const formData = ref({
  word: '',
  severity: 2,
  replacement: '',
  category: '',
  isActive: true
})

// 批量导入弹窗
const importDialogVisible = ref(false)
const importText = ref('')
const importSaving = ref(false)

// 敏感词等级选项
const severityOptions = [
  { label: '低危（仅标记）', value: 1 },
  { label: '中危（替换词）', value: 2 },
  { label: '高危（直接拒绝）', value: 3 }
]

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
    field: 'word',
    label: '敏感词',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入敏感词'
      }
    }
  },
  {
    field: 'severity',
    label: '等级',
    search: { hidden: true },
    form: {
      component: 'Select',
      componentProps: {
        placeholder: '请选择等级',
        options: severityOptions
      }
    },
    table: {
      width: 120,
      slots: {
        default: (data: any) => {
          const map: Record<number, { text: string; type: any }> = {
            1: { text: '低危', type: 'info' },
            2: { text: '中危', type: 'warning' },
            3: { text: '高危', type: 'danger' }
          }
          const info = map[data.row.severity] || { text: '未知', type: 'info' }
          return <ElTag type={info.type}>{info.text}</ElTag>
        }
      }
    }
  },
  {
    field: 'replacement',
    label: '替换词',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入替换词（仅中危需要）'
      }
    }
  },
  {
    field: 'category',
    label: '分类',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入分类（选填）'
      }
    },
    table: {
      slots: {
        default: (data: any) => {
          return data.row.category || <span style="color: #909399;">-</span>
        }
      }
    }
  },
  {
    field: 'isActive',
    label: '状态',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: {
      width: 100,
      slots: {
        default: (data: any) => {
          const isActive = Boolean(data.row.isActive)
          return isActive ? <ElTag type="success">启用</ElTag> : <ElTag type="info">禁用</ElTag>
        }
      }
    }
  },
  {
    field: 'action',
    label: '操作',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: {
      width: 180,
      slots: {
        default: (data: any) => {
          return (
            <>
              <BaseButton type="primary" link onClick={() => handleEdit(data.row)}>
                编辑
              </BaseButton>
              <BaseButton type="danger" link onClick={() => handleDelete(data.row.id)}>
                删除
              </BaseButton>
            </>
          )
        }
      }
    }
  }
])
const { allSchemas } = useCrudSchemas(crudSchemas)

// 打开新增弹窗
const handleAdd = () => {
  formDialogTitle.value = '添加敏感词'
  currentWord.value = null
  formData.value = {
    word: '',
    severity: 2,
    replacement: '',
    category: '',
    isActive: true
  }
  formDialogVisible.value = true
}

// 打开编辑弹窗
const handleEdit = (word: SensitiveWord) => {
  formDialogTitle.value = '编辑敏感词'
  currentWord.value = word
  formData.value = {
    word: word.word,
    severity: word.severity,
    replacement: word.replacement || '',
    category: word.category || '',
    isActive: word.isActive !== false
  }
  formDialogVisible.value = true
}

// 保存
const handleSave = async () => {
  if (!formData.value.word.trim()) {
    ElMessage.warning('请输入敏感词')
    return
  }

  formSaving.value = true
  try {
    if (currentWord.value) {
      await updateSensitiveWordApi({ id: currentWord.value.id, data: formData.value })
      ElMessage.success('更新成功')
    } else {
      // 新增
      await createSensitiveWordApi(formData.value)
      ElMessage.success('添加成功')
    }
    formDialogVisible.value = false
    getList()
  } catch (error: any) {
    ElMessage.error(error.message || '操作失败')
  } finally {
    formSaving.value = false
  }
}

// 删除
const handleDelete = async (id: number) => {
  try {
    await ElMessageBox.confirm('确认删除该敏感词？', '操作确认', {
      type: 'warning'
    })
    await deleteSensitiveWordApi({ id })
    ElMessage.success('删除成功')
    getList()
  } catch (error: any) {
    if (error !== 'cancel' && error !== 'close') {
      ElMessage.error(error?.message || '删除失败')
    }
  }
}

// 打开批量导入弹窗
const handleImport = () => {
  importText.value = ''
  importDialogVisible.value = true
}

// 批量导入
const handleBatchImport = async () => {
  const lines = importText.value
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length > 0)

  if (lines.length === 0) {
    ElMessage.warning('请输入敏感词（每行一个）')
    return
  }

  if (lines.length > 1000) {
    ElMessage.warning('一次最多导入 1000 个敏感词')
    return
  }

  importSaving.value = true
  try {
    const result = await batchImportSensitiveWordsApi({ words: lines })
    ElMessage.success(`成功导入 ${result.data.created} 个敏感词，跳过 ${result.data.skipped} 个`)
    importDialogVisible.value = false
    getList()
  } catch (error: any) {
    ElMessage.error(error.message || '导入失败')
  } finally {
    importSaving.value = false
  }
}
</script>

<template>
  <ContentWrap>
    <div class="mb-4">
      <BaseButton type="primary" @click="handleAdd">添加敏感词</BaseButton>
      <BaseButton type="success" @click="handleImport">批量导入</BaseButton>
    </div>

    <Table
      :columns="allSchemas.tableColumns"
      :data="dataList"
      :loading="loading"
      @register="tableRegister"
    />

    <!-- 表单弹窗 -->
    <ElDialog v-model="formDialogVisible" :title="formDialogTitle" width="500px" destroy-on-close>
      <ElForm label-width="100px">
        <ElFormItem label="敏感词" required>
          <ElInput
            v-model="formData.word"
            placeholder="请输入敏感词"
            maxlength="50"
            show-word-limit
          />
        </ElFormItem>
        <ElFormItem label="等级" required>
          <ElSelect v-model="formData.severity" placeholder="请选择等级" style="width: 100%">
            <ElOption
              v-for="option in severityOptions"
              :key="option.value"
              :label="option.label"
              :value="option.value"
            />
          </ElSelect>
        </ElFormItem>
        <ElFormItem label="替换词">
          <ElInput
            v-model="formData.replacement"
            placeholder="中危等级可设置替换词"
            maxlength="50"
          />
          <div class="text-xs text-gray-500 mt-1"> 仅中危等级有效，将敏感词替换为该内容 </div>
        </ElFormItem>
        <ElFormItem label="分类">
          <ElInput
            v-model="formData.category"
            placeholder="选填，如：政治、色情等"
            maxlength="20"
          />
        </ElFormItem>
        <ElFormItem label="启用状态">
          <ElSwitch v-model="formData.isActive" inline-prompt active-text="启" inactive-text="停" />
        </ElFormItem>
      </ElForm>
      <template #footer>
        <ElButton @click="formDialogVisible = false">取消</ElButton>
        <ElButton type="primary" :loading="formSaving" @click="handleSave">保存</ElButton>
      </template>
    </ElDialog>

    <!-- 批量导入弹窗 -->
    <ElDialog v-model="importDialogVisible" title="批量导入敏感词" width="500px" destroy-on-close>
      <ElInput
        v-model="importText"
        type="textarea"
        :rows="10"
        placeholder="请输入敏感词，每行一个&#10;例如：&#10;敏感词1&#10;敏感词2&#10;敏感词3"
      />
      <div class="text-xs text-gray-500 mt-2"> 一次最多导入 1000 个敏感词，默认为低危等级 </div>
      <template #footer>
        <ElButton @click="importDialogVisible = false">取消</ElButton>
        <ElButton type="primary" :loading="importSaving" @click="handleBatchImport">导入</ElButton>
      </template>
    </ElDialog>
  </ContentWrap>
</template>

<style scoped lang="scss">
.mb-4 {
  margin-bottom: 16px;
}
</style>
