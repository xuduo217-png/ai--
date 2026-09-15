<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { Search } from '@/components/Search'
import { ElTag, ElMessage, ElMessageBox } from 'element-plus'
import { Table } from '@/components/Table'
import { departmentApi, type Department } from '@/api-new/departments'
import { useTable } from '@/hooks/web/useTable'
import { reactive, ref, unref, computed, onMounted } from 'vue'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { BaseButton } from '@/components/Button'
import { Dialog } from '@/components/Dialog'
import DepartmentWrite from './components/DepartmentWrite.vue'
import { useI18n } from '@/hooks/web/useI18n'
import { useRoute, useRouter } from 'vue-router'

defineOptions({
  name: 'HospitalDepartmentManagement'
})

const { t } = useI18n()
const route = useRoute()
const router = useRouter()

// 从路由参数获取医院ID和名称
const hospitalId = computed(() => parseInt(route.params.id as string))
const hospitalName = computed(() => (route.query.hospitalName as string) || '未知医院')

// 页面标题
const pageTitle = computed(() => `${hospitalName.value} - 科室管理`)

// 搜索参数
const searchParams = ref<Record<string, any>>({})
const setSearchParams = (params: any) => {
  searchParams.value = params
  getList()
}

// 表格配置
const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const { currentPage, pageSize } = tableState
    const res = await departmentApi.getDepartmentListApi({
      hospitalId: unref(hospitalId), // 只查询当前医院的科室
      page: unref(currentPage),
      pageSize: unref(pageSize),
      ...unref(searchParams)
    })
    /**
     * 兼容数组直返和分页对象两种历史响应
     * 科室管理页只消费标准 list/total，避免页面直接与后端多版本结构耦合
     */
    const departmentPayload = res.data
    const departmentList = Array.isArray(departmentPayload)
      ? departmentPayload
      : departmentPayload?.data || departmentPayload?.list || []
    const totalCount = Array.isArray(departmentPayload)
      ? departmentPayload.length
      : departmentPayload?.pagination?.total ||
        departmentPayload?.meta?.total ||
        departmentPayload?.total ||
        res.pagination?.total ||
        0

    return {
      list: departmentList,
      total: totalCount
    }
  },
  fetchDelApi: async () => {
    // 删除操作在行内处理
    return true
  }
})

const { loading, dataList, total, currentPage, pageSize } = tableState
const { getList } = tableMethods

// CRUD Schema 配置
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
    type: 'index',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true }
  },
  {
    field: 'name',
    label: '科室名称',
    search: {
      component: 'Input'
    },
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入科室名称'
      },
      formItemProps: {
        required: true
      },
      colProps: { span: 24 }
    },
    table: {
      show: true
    }
  },
  {
    field: 'description',
    label: '科室描述',
    search: { hidden: true },
    table: {
      show: true,
      width: 300
    },
    form: {
      component: 'Input',
      componentProps: {
        type: 'textarea',
        rows: 3,
        placeholder: '请输入科室描述（可选）'
      },
      colProps: { span: 24 }
    }
  },
  {
    field: 'isActive',
    label: '状态',
    search: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '全部', value: '' },
          { label: '启用', value: true },
          { label: '禁用', value: false }
        ]
      }
    },
    form: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '启用', value: true },
          { label: '禁用', value: false }
        ]
      },
      value: true,
      colProps: { span: 24 }
    },
    table: {
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
    field: 'action',
    width: '200px',
    label: '操作',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: {
      slots: {
        default: (data: any) => {
          return (
            <>
              <BaseButton type="primary" onClick={() => handleEdit(data.row)}>
                编辑
              </BaseButton>
              <BaseButton type="danger" onClick={() => handleDelete(data.row)}>
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

// 对话框相关
const dialogVisible = ref(false)
const dialogTitle = ref('')
const currentRow = ref<Department | null>(null)
const writeRef = ref()
const saveLoading = ref(false)

/**
 * 打开新增对话框
 */
const handleAdd = () => {
  dialogTitle.value = '新增科室'
  currentRow.value = null
  dialogVisible.value = true
}

/**
 * 打开编辑对话框
 */
const handleEdit = (row: Department) => {
  dialogTitle.value = '编辑科室'
  currentRow.value = row
  dialogVisible.value = true
}

/**
 * 删除科室
 */
const handleDelete = async (row: Department) => {
  try {
    await ElMessageBox.confirm(`确定要删除科室"${row.name}"吗？`, '提示', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    })

    await departmentApi.deleteDepartmentApi(row.id)
    ElMessage.success('删除成功')
    getList()
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}

/**
 * 提交表单
 */
const save = async () => {
  const write = unref(writeRef)
  const formData = await write?.submit()
  if (formData) {
    saveLoading.value = true
    try {
      // 自动添加医院ID
      const dataWithHospitalId = {
        ...formData,
        hospitalId: unref(hospitalId)
      }

      // 根据 currentRow 判断是新增还是编辑
      if (currentRow.value?.id) {
        // 编辑模式
        await departmentApi.updateDepartmentApi(currentRow.value.id, dataWithHospitalId)
      } else {
        // 新增模式
        await departmentApi.createDepartmentApi(dataWithHospitalId)
      }

      dialogVisible.value = false
      getList()
      ElMessage.success('保存成功')
    } catch (error) {
      console.error('保存失败:', error)
      ElMessage.error('保存失败')
    } finally {
      saveLoading.value = false
    }
  }
}

/**
 * 返回医院列表
 */
const handleBack = () => {
  router.push('/hospitals/list')
}

// 组件挂载时加载数据
onMounted(() => {
  getList()
})
</script>

<template>
  <ContentWrap>
    <!-- 页面标题和返回按钮 -->
    <div class="mb-10px flex items-center justify-between">
      <div class="flex items-center gap-2">
        <BaseButton @click="handleBack"> 返回医院列表 </BaseButton>
        <span class="text-lg font-semibold">{{ pageTitle }}</span>
      </div>
      <BaseButton type="primary" @click="handleAdd">新增科室</BaseButton>
    </div>

    <!-- 搜索区域 -->
    <Search :schema="allSchemas.searchSchema" @search="setSearchParams" @reset="setSearchParams" />

    <!-- 表格 -->
    <Table
      v-model:pageSize="pageSize"
      v-model:currentPage="currentPage"
      :columns="allSchemas.tableColumns"
      :data="dataList"
      :loading="loading"
      :pagination="{
        total: total
      }"
      @register="tableRegister"
    />

    <!-- 新增/编辑对话框 -->
    <Dialog v-model="dialogVisible" :title="dialogTitle" width="600px">
      <DepartmentWrite
        ref="writeRef"
        :form-schema="allSchemas.formSchema"
        :current-row="currentRow"
        :hospital-id="hospitalId"
      />

      <template #footer>
        <BaseButton type="primary" :loading="saveLoading" @click="save">
          {{ t('exampleDemo.save') }}
        </BaseButton>
        <BaseButton @click="dialogVisible = false">{{ t('dialogDemo.close') }}</BaseButton>
      </template>
    </Dialog>
  </ContentWrap>
</template>

<style scoped lang="less">
.mb-10px {
  margin-bottom: 10px;
}

.flex {
  display: flex;
}

.items-center {
  align-items: center;
}

.justify-between {
  justify-content: space-between;
}

.gap-2 {
  gap: 0.5rem;
}

.text-lg {
  font-size: 1.125rem;
  line-height: 1.75rem;
}

.font-semibold {
  font-weight: 600;
}
</style>
