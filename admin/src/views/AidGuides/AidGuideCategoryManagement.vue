<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { Dialog } from '@/components/Dialog'
import { Table } from '@/components/Table'
import { Plus } from '@element-plus/icons-vue'
import { ref, unref, reactive, onMounted } from 'vue'
import { ElTag, ElMessage, ElMessageBox } from 'element-plus'
import {
  getAidGuideCategoryListApi,
  deleteAidGuideCategoryApi,
  createAidGuideCategoryApi,
  updateAidGuideCategoryApi,
  type AidCategory
} from '@/api-new/aid-guides'
import { useTable } from '@/hooks/web/useTable'
import { Search } from '@/components/Search'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { BaseButton } from '@/components/Button'
import { getImageUrl } from '@/utils/image'
import Write from './components/CategoryWrite.vue'

defineOptions({
  name: 'AidCategoryManagement'
})

// 搜索参数
const searchParams = ref<Record<string, any>>({})
const setSearchParams = (params: any) => {
  searchParams.value = params
  getList()
}

// 表格配置
const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const { pageSize, currentPage } = tableState
    const res = await getAidGuideCategoryListApi({
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

// 页面加载时获取数据
onMounted(() => {
  getList()
})

// 弹窗相关状态
const dialogVisible = ref(false)
const dialogTitle = ref('')
const currentRow = ref<AidCategory | null>(null)
const writeRef = ref()
const saveLoading = ref(false)

// CRUD Schema 定义
const crudSchemas = reactive<CrudSchema[]>([
  {
    field: 'selection',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: { type: 'selection' }
  },
  {
    field: 'index',
    label: '序号',
    form: { hidden: true },
    search: { hidden: true },
    detail: { hidden: true },
    table: { type: 'index' }
  },
  {
    field: 'icon',
    label: '分类图标',
    search: { hidden: true },
    form: {
      component: 'ImageUpload',
      componentProps: {
        placeholder: '点击上传分类图标',
        aspectRatio: 1,
        cropBoxWidth: 200,
        cropBoxHeight: 200,
        category: 'aid-guide-category-icon',
        circle: false,
        previewWidth: 100,
        previewHeight: 100
      },
      colProps: { span: 24 }
    },
    table: {
      show: true,
      width: 100,
      slots: {
        default: (data: any) => {
          return data.row.icon ? (
            <img
              src={getImageUrl(data.row.icon)}
              style={{ width: '50px', height: '50px', objectFit: 'cover', borderRadius: '4px' }}
              alt="图标"
            />
          ) : (
            <span>-</span>
          )
        }
      }
    }
  },
  {
    field: 'name',
    label: '分类名称',
    search: {
      component: 'Input'
    },
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入分类名称'
      }
    },
    table: {
      show: true
    }
  },
  {
    field: 'sortOrder',
    label: '排序权重',
    search: { hidden: true },
    form: {
      component: 'InputNumber',
      componentProps: {
        placeholder: '数字越小越靠前',
        min: 0
      }
    },
    table: {
      show: true,
      width: 100
    }
  },
  {
    field: 'isActive',
    label: '状态',
    search: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '启用', value: true },
          { label: '禁用', value: false }
        ]
      }
    },
    form: {
      component: 'Switch',
      componentProps: {
        activeText: '启用',
        inactiveText: '禁用'
      }
    },
    table: {
      show: true,
      width: 100,
      slots: {
        default: (data: any) => {
          return data.row.isActive ? (
            <ElTag type="success">启用</ElTag>
          ) : (
            <ElTag type="danger">禁用</ElTag>
          )
        }
      }
    }
  },
  {
    field: 'articleCount',
    label: '指南数量',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 100
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
        default: (data: any) => {
          return new Date(data.row.createdAt).toLocaleString('zh-CN')
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
  }
])

const { allSchemas } = useCrudSchemas(crudSchemas)

// 操作方法
const handleAdd = () => {
  dialogTitle.value = '新增分类'
  currentRow.value = null
  dialogVisible.value = true
}

const handleEdit = (row: AidCategory) => {
  dialogTitle.value = '编辑分类'
  currentRow.value = row
  dialogVisible.value = true
}

const handleDelete = async (row: AidCategory) => {
  try {
    await ElMessageBox.confirm(`确定要删除分类"${row.name}"吗？`, '提示', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    })

    await deleteAidGuideCategoryApi(row.id)
    ElMessage.success('删除成功')
    getList()
  } catch (error) {
    if (error !== 'cancel') {
      console.error('删除失败', error)
      ElMessage.error('删除失败')
    }
  }
}

const handleSave = async () => {
  const write = writeRef.value
  if (!write) return

  try {
    saveLoading.value = true
    const formData = await write.submit()

    if (currentRow.value) {
      await updateAidGuideCategoryApi(currentRow.value.id, formData)
      ElMessage.success('更新成功')
    } else {
      await createAidGuideCategoryApi(formData)
      ElMessage.success('创建成功')
    }

    dialogVisible.value = false
    getList()
  } catch (error) {
    console.error('保存失败', error)
    ElMessage.error('保存失败')
  } finally {
    saveLoading.value = false
  }
}
</script>

<template>
  <ContentWrap>
    <!-- 搜索区域 -->
    <Search
      :schema="allSchemas.searchSchema"
      @search="setSearchParams"
      @reset="setSearchParams({})"
    />

    <!-- 操作按钮 -->
    <div class="mb-10px flex items-center justify-between">
      <span class="text-info">共 {{ total }} 个分类</span>
      <BaseButton type="primary" :icon="Plus" @click="handleAdd"> 新增分类 </BaseButton>
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

    <!-- 新增/编辑弹窗 -->
    <Dialog v-model="dialogVisible" :title="dialogTitle" width="800px">
      <div v-if="dialogVisible" class="dialog-content">
        <Write ref="writeRef" :form-schema="allSchemas.formSchema" :current-row="currentRow" />
      </div>

      <template #footer>
        <BaseButton type="primary" :loading="saveLoading" @click="handleSave"> 保存 </BaseButton>
        <BaseButton @click="dialogVisible = false">取消</BaseButton>
      </template>
    </Dialog>
  </ContentWrap>
</template>

<style scoped>
.dialog-content {
  padding: 20px;
}

.text-info {
  color: var(--el-text-color-secondary);
  font-size: 14px;
}
</style>
