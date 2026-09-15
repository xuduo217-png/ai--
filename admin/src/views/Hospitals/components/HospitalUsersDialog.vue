<script setup lang="tsx">
import { ref, computed, watch, reactive } from 'vue'
import {
  ElMessage,
  ElMessageBox,
  ElTabPane,
  ElTabs,
  ElForm,
  ElFormItem,
  ElInput,
  ElSwitch
} from 'element-plus'
import type { FormRules } from 'element-plus'
import { Table } from '@/components/Table'
import { useTable } from '@/hooks/web/useTable'
import { Dialog } from '@/components/Dialog'
import { BaseButton } from '@/components/Button'
import { Search } from '@/components/Search'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { getUserList, createUser, updateUser, deleteUser, UserRole } from '@/api-new/users'
import type { CreateUserRequest, UpdateUserRequest, User } from '@/api-new/users'

/**
 * 医院用户管理对话框
 * 用于管理医院的管理员和员工
 */

interface Props {
  modelValue: boolean
  hospitalId: number
  hospitalName: string
}

interface Emits {
  (e: 'update:modelValue', value: boolean): void
  (e: 'refresh'): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

// 当前激活的 Tab
const activeTab = ref<'admin' | 'staff'>('admin')

// 对话框显示状态
const dialogVisible = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
})

// CRUD Schema 定义
const crudSchemas: CrudSchema[] = [
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
    field: 'username',
    label: '用户名',
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入用户名'
      },
      colProps: { span: 12 }
    },
    search: {
      component: 'Input'
    }
  },
  {
    field: 'phone',
    label: '手机号',
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入手机号'
      },
      colProps: { span: 12 }
    },
    search: {
      component: 'Input'
    }
  },
  {
    field: 'password',
    label: '密码',
    form: {
      component: 'Input',
      componentProps: {
        type: 'password',
        showPassword: true,
        placeholder: '请输入密码'
      },
      colProps: { span: 12 }
    },
    search: { hidden: true },
    table: { hidden: true }
  },
  {
    field: 'email',
    label: '邮箱',
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入邮箱'
      },
      colProps: { span: 12 }
    },
    search: { hidden: true }
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
      }
    },
    table: {
      slots: {
        default: (data: any) => {
          const row = data.row as User
          return (
            <span class={row.isActive ? 'text-green-600' : 'text-red-600'}>
              {row.isActive ? '启用' : '禁用'}
            </span>
          )
        }
      }
    }
  },
  {
    field: 'action',
    label: '操作',
    form: { hidden: true },
    detail: { hidden: true },
    search: { hidden: true },
    table: {
      width: 180,
      slots: {
        default: (data: any) => {
          const row = data.row as User
          return (
            <>
              <BaseButton type="primary" onClick={() => handleEdit(row)}>
                编辑
              </BaseButton>
              <BaseButton type="danger" onClick={() => handleDelete(row)}>
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

// 弹窗相关状态
const formDialogVisible = ref(false)
const formDialogTitle = ref('')
const currentRow = ref<User | null>(null)
const saveLoading = ref(false)

// 表单数据和验证规则
const formData = reactive({
  username: '',
  phone: '',
  email: '',
  password: '',
  isActive: true
})

const formRules = reactive<FormRules<typeof formData>>({
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  phone: [
    { required: true, message: '请输入手机号', trigger: 'blur' },
    { pattern: /^1[3-9]\d{9}$/, message: '手机号格式不正确', trigger: 'blur' }
  ],
  email: [
    { required: true, message: '请输入邮箱', trigger: 'blur' },
    { type: 'email' as const, message: '邮箱格式不正确', trigger: 'blur' }
  ],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }]
})

const formRef = ref()

/**
 * 规范化可选字符串字段
 * whitelist 恢复后，空字符串会继续参与 DTO 校验；这里统一转成 undefined。
 */
const normalizeOptionalString = (value: unknown): string | undefined => {
  if (typeof value !== 'string') return undefined
  const trimmedValue = value.trim()
  return trimmedValue ? trimmedValue : undefined
}

/**
 * 构建用户创建载荷
 * 仅提交 DTO 允许的字段，避免 whitelist 开启后出现运行时漂移。
 */
const buildCreateUserPayload = (role: UserRole): CreateUserRequest => {
  return {
    username: String(formData.username).trim(),
    password: String(formData.password).trim(),
    email: normalizeOptionalString(formData.email),
    phone: String(formData.phone).trim(),
    role,
    hospitalId: props.hospitalId
  }
}

/**
 * 构建用户更新载荷
 * 更新接口不接收 hospitalId，因此这里不向后端透传。
 */
const buildUpdateUserPayload = (): UpdateUserRequest => {
  return {
    username: String(formData.username).trim(),
    email: normalizeOptionalString(formData.email),
    phone: String(formData.phone).trim(),
    isActive: formData.isActive
  }
}

/**
 * 重置表单
 */
const resetForm = () => {
  formData.username = ''
  formData.phone = ''
  formData.email = ''
  formData.password = ''
  formData.isActive = true
  formRef.value?.clearValidate()
}

// 搜索参数
const searchParams = ref<Record<string, any>>({})
const setSearchParams = (params: any) => {
  searchParams.value = params
  if (activeTab.value === 'admin') {
    getAdminList()
  } else {
    getStaffList()
  }
}

/**
 * 管理员列表表格配置
 */
const adminTable = useTable({
  fetchDataApi: async () => {
    const res = await getUserList({
      page: 1,
      pageSize: 100, // 管理员通常不会很多，直接加载全部
      role: UserRole.HOSPITAL_ADMIN,
      hospitalId: props.hospitalId,
      ...searchParams.value
    })
    return {
      list: res.data || [],
      total: res.pagination?.total || 0
    }
  }
})

const {
  tableRegister: adminTableRegister,
  tableState: adminTableState,
  tableMethods: adminTableMethods
} = adminTable
const { dataList: adminList, loading: adminLoading, total: adminTotal } = adminTableState
const { getList: getAdminList } = adminTableMethods

/**
 * 员工列表表格配置
 */
const staffTable = useTable({
  fetchDataApi: async () => {
    const res = await getUserList({
      page: staffTableState.currentPage.value,
      pageSize: staffTableState.pageSize.value,
      role: UserRole.STAFF,
      hospitalId: props.hospitalId,
      ...searchParams.value
    })
    return {
      list: res.data || [],
      total: res.pagination?.total || 0
    }
  }
})

const {
  tableRegister: staffTableRegister,
  tableState: staffTableState,
  tableMethods: staffTableMethods
} = staffTable
const {
  dataList: staffList,
  loading: staffLoading,
  currentPage: staffCurrentPage,
  pageSize: staffPageSize,
  total: staffTotal
} = staffTableState
const { getList: getStaffList } = staffTableMethods

/**
 * 监听对话框打开，加载数据
 */
watch(
  () => props.modelValue,
  (val) => {
    if (val) {
      activeTab.value = 'admin'
      getAdminList()
      getStaffList()
    }
  }
)

/**
 * 新增用户
 */
const handleAdd = () => {
  resetForm()
  formDialogTitle.value = activeTab.value === 'admin' ? '新增管理员' : '新增员工'
  currentRow.value = null
  formDialogVisible.value = true
}

/**
 * 编辑用户
 */
const handleEdit = (row: User) => {
  resetForm()
  formData.username = row.username
  formData.phone = row.phone
  formData.email = row.email || ''
  formData.isActive = row.isActive
  formData.password = '' // 编辑时不显示密码
  formDialogTitle.value = '编辑用户'
  currentRow.value = row
  formDialogVisible.value = true
}

/**
 * 保存用户
 */
const handleSave = async () => {
  if (!formRef.value) return

  await formRef.value.validate(async (valid: boolean) => {
    if (!valid) return

    saveLoading.value = true
    try {
      // 根据当前 Tab 确定角色
      const role = activeTab.value === 'admin' ? UserRole.HOSPITAL_ADMIN : UserRole.STAFF

      if (currentRow.value?.id) {
        // 编辑模式
        await updateUser(currentRow.value.id, buildUpdateUserPayload())
        ElMessage.success('更新成功')
      } else {
        // 新增模式
        await createUser(buildCreateUserPayload(role))
        ElMessage.success('创建成功')
      }

      formDialogVisible.value = false
      getAdminList()
      getStaffList()
      emit('refresh')
    } catch (error) {
      console.error('保存失败:', error)
      ElMessage.error('保存失败')
    } finally {
      saveLoading.value = false
    }
  })
}

/**
 * 删除用户
 */
const handleDelete = async (row: User) => {
  try {
    await ElMessageBox.confirm(
      `确定要删除用户 "${row.username || row.phone}" 吗？此操作不可恢复。`,
      '警告',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      }
    )

    await deleteUser(row.id)
    ElMessage.success('删除成功')
    getAdminList()
    getStaffList()
    emit('refresh')
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}
</script>

<template>
  <Dialog
    v-model="dialogVisible"
    :title="`${hospitalName} - 用户管理`"
    width="90%"
    max-height="80vh"
  >
    <ElTabs v-model="activeTab" class="mt-10px">
      <!-- 管理员列表 -->
      <ElTabPane label="医院管理员" name="admin">
        <div class="mb-10px flex justify-between">
          <span class="text-sm text-gray-500">
            管理该医院的管理员账户，可以管理系统内的员工和业务数据
          </span>
          <BaseButton type="primary" @click="handleAdd">新增管理员</BaseButton>
        </div>

        <Search
          :schema="allSchemas.searchSchema"
          @reset="setSearchParams"
          @search="setSearchParams"
        />

        <Table
          :columns="allSchemas.tableColumns"
          :data="adminList"
          :loading="adminLoading"
          :pagination="{ total: adminTotal }"
          @register="adminTableRegister"
        />
      </ElTabPane>

      <!-- 员工列表 -->
      <ElTabPane label="员工" name="staff">
        <div class="mb-10px flex justify-between">
          <span class="text-sm text-gray-500">
            管理该医院的员工账户，员工可以处理日常业务操作
          </span>
          <BaseButton type="primary" @click="handleAdd">新增员工</BaseButton>
        </div>

        <Search
          :schema="allSchemas.searchSchema"
          @reset="setSearchParams"
          @search="setSearchParams"
        />

        <Table
          v-model:current-page="staffCurrentPage"
          v-model:page-size="staffPageSize"
          :columns="allSchemas.tableColumns"
          :data="staffList"
          :loading="staffLoading"
          :pagination="{ total: staffTotal }"
          @register="staffTableRegister"
        />
      </ElTabPane>
    </ElTabs>

    <!-- 用户表单对话框 -->
    <Dialog v-model="formDialogVisible" :title="formDialogTitle" width="600px">
      <ElForm
        v-if="formDialogVisible"
        ref="formRef"
        :model="formData"
        :rules="formRules"
        label-width="100px"
        class="dialog-content"
      >
        <ElFormItem label="用户名" prop="username">
          <ElInput v-model="formData.username" placeholder="请输入用户名" />
        </ElFormItem>

        <ElFormItem label="手机号" prop="phone">
          <ElInput v-model="formData.phone" placeholder="请输入手机号" />
        </ElFormItem>

        <ElFormItem label="邮箱" prop="email">
          <ElInput v-model="formData.email" placeholder="请输入邮箱" />
        </ElFormItem>

        <ElFormItem v-if="!currentRow" label="密码" prop="password">
          <ElInput
            v-model="formData.password"
            type="password"
            show-password
            placeholder="请输入密码"
          />
        </ElFormItem>

        <ElFormItem label="状态">
          <ElSwitch v-model="formData.isActive" active-text="启用" inactive-text="禁用" />
        </ElFormItem>
      </ElForm>

      <template #footer>
        <BaseButton type="primary" :loading="saveLoading" @click="handleSave"> 保存 </BaseButton>
        <BaseButton @click="formDialogVisible = false">取消</BaseButton>
      </template>
    </Dialog>
  </Dialog>
</template>

<style scoped>
.mb-10px {
  margin-bottom: 10px;
}
.mt-10px {
  margin-top: 10px;
}
.dialog-content {
  padding: 20px;
}
</style>
