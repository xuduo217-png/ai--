<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { Dialog } from '@/components/Dialog'
import { Table } from '@/components/Table'
import { computed, ref, unref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import {
  ElTag,
  ElSwitch,
  ElMessage,
  ElMessageBox,
  ElTabs,
  ElTabPane,
  ElDescriptions,
  ElDescriptionsItem,
  ElInput,
  ElInputNumber
} from 'element-plus'
import {
  getUserList,
  updateUser,
  deleteUser,
  createUser,
  resetUserPassword,
  adjustUserBalance,
  UserRole
} from '@/api-new/users'
import type {
  User,
  CreateUserRequest,
  UpdateUserRequest,
  ResetUserPasswordRequest,
  AdjustUserBalanceType
} from '@/api-new/users'
import { useTable } from '@/hooks/web/useTable'
import { Search } from '@/components/Search'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { BaseButton } from '@/components/Button'
import { UserRoleLabel } from '@/api-new/users'
import UserFormDialog from './components/UserFormDialog.vue'
import WalletDetailList from './components/WalletDetailList.vue'
import {
  buildAdjustUserBalancePayload,
  buildResetUserPasswordPayload,
  getUserDialogFormSchema,
  normalizeBalanceAdjustAmount
} from './userList.helpers'

const router = useRouter()

const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    // 使用服务端分页，固定只查询普通用户
    const { pageSize, currentPage } = tableState
    const res = await getUserList({
      page: unref(currentPage),
      pageSize: unref(pageSize),
      role: UserRole.USER, // 固定只查询普通用户
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

// 搜索参数
const searchParams = ref<Record<string, any>>({})
const setSearchParams = (params: any) => {
  currentPage.value = 1
  searchParams.value = params
  getList()
}

// 弹窗相关状态
const dialogVisible = ref(false)
const dialogTitle = ref('')
const currentRow = ref<User | null>(null)
const writeRef = ref()
const saveLoading = ref(false)
const resetPasswordLoadingUserId = ref<number | null>(null)
const balanceDialogVisible = ref(false)
const balanceDialogUser = ref<User | null>(null)
const balanceSubmitAction = ref<AdjustUserBalanceType | null>(null)
const walletDetailListRefreshKey = ref(0)
const balanceForm = reactive({
  amount: undefined as number | undefined,
  remark: ''
})

// 详情弹窗相关状态
const detailDialogVisible = ref(false)
const detailUser = ref<User | null>(null)
const activeTab = ref('basic')

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
    field: 'username',
    label: '用户名',
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入用户名'
      },
      colProps: {
        span: 12
      }
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
      colProps: {
        span: 12
      }
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
      colProps: {
        span: 12
      }
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
      colProps: {
        span: 12
      }
    },
    search: { hidden: true }
  },
  {
    field: 'role',
    label: '角色',
    form: {
      component: 'Select',
      componentProps: {
        placeholder: '普通用户',
        disabled: true, // 禁用角色选择，固定为普通用户
        options: [{ label: UserRoleLabel.USER, value: 'USER' }]
      },
      colProps: {
        span: 12
      }
    },
    search: { hidden: true }, // 隐藏角色筛选
    table: {
      slots: {
        default: () => {
          return <ElTag>{UserRoleLabel.USER}</ElTag>
        }
      }
    }
  },
  {
    field: 'isActive',
    label: '状态',
    form: {
      component: 'Select',
      value: true, // 默认启用
      componentProps: {
        options: [
          { label: '启用', value: true },
          { label: '禁用', value: false }
        ]
      },
      colProps: { span: 12 }
    },
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
    table: {
      slots: {
        default: (data: any) => {
          const row = data.row as User
          return (
            <ElSwitch
              modelValue={row.isActive}
              onChange={(val: boolean) => handleStatusChange(row, val)}
            />
          )
        }
      }
    }
  },
  {
    field: 'verified',
    label: '已认证',
    search: { hidden: true },
    form: { hidden: true }, // 隐藏表单项
    table: {
      hidden: true // 普通用户列表不显示认证状态
    }
  },
  {
    field: 'hospital.name',
    label: '所属医院',
    search: { hidden: true },
    form: { hidden: true }, // 普通用户表单不显示医院选择
    table: {
      hidden: true // 普通用户列表不显示医院信息
    }
  },
  {
    field: 'createdAt',
    label: '注册时间',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      slots: {
        default: (data: any) => {
          const row = data.row as User
          return new Date(row.createdAt).toLocaleString('zh-CN')
        }
      }
    }
  },
  {
    field: 'lastLoginAt',
    label: '最后登录',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      slots: {
        default: (data: any) => {
          const row = data.row as User
          return row.lastLoginAt ? new Date(row.lastLoginAt).toLocaleString('zh-CN') : '-'
        }
      }
    }
  },
  {
    field: 'balance',
    label: '可用余额',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      width: 120,
      slots: {
        default: (data: any) => {
          const row = data.row as User
          return `¥${Number(row.balance || 0).toFixed(2)}`
        }
      }
    }
  },
  {
    field: 'pendingBalance',
    label: '待审核余额',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      width: 130,
      slots: {
        default: (data: any) => {
          const row = data.row as User
          return `¥${Number(row.pendingBalance || 0).toFixed(2)}`
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
      width: 640,
      slots: {
        default: (data: any) => {
          const row = data.row as User
          return (
            <>
              <BaseButton type="default" onClick={() => handleViewDetail(row)}>
                详情
              </BaseButton>
              <BaseButton type="success" onClick={() => handleViewWalletTransactions(row)}>
                钱包流水
              </BaseButton>
              <BaseButton type="warning" onClick={() => handleOpenBalanceDialog(row)}>
                余额操作
              </BaseButton>
              <BaseButton type="primary" onClick={() => handleEdit(row)}>
                编辑
              </BaseButton>
              <BaseButton
                type="warning"
                loading={resetPasswordLoadingUserId.value === row.id}
                onClick={() => handleResetPassword(row)}
              >
                重置密码
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
])

const { allSchemas } = useCrudSchemas(crudSchemas)
const dialogFormSchema = computed(() =>
  getUserDialogFormSchema(allSchemas.formSchema, Boolean(currentRow.value?.id))
)

/**
 * 新增用户
 */
const handleAdd = () => {
  dialogTitle.value = '新增用户'
  currentRow.value = null
  dialogVisible.value = true
}

/**
 * 编辑用户
 */
const handleEdit = (row: User) => {
  dialogTitle.value = '编辑用户'
  currentRow.value = row
  dialogVisible.value = true
}

/**
 * 查看用户详情（包括钱包明细）
 */
const handleViewDetail = async (row: User) => {
  detailUser.value = row
  detailDialogVisible.value = true
}

/**
 * 跳转到钱包流水并自动筛选当前用户
 */
const handleViewWalletTransactions = (row: User) => {
  router.push({
    name: 'WalletTransactions',
    query: { userId: String(row.id) }
  })
}

/**
 * 管理员重置用户密码
 */
const handleResetPassword = async (row: User) => {
  try {
    const { value } = await ElMessageBox.prompt(
      `请输入用户 "${row.username || row.phone}" 的新密码（至少 6 位）`,
      '重置密码',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        inputType: 'password',
        inputPlaceholder: '请输入新密码',
        inputPattern: /^.{6,}$/,
        inputErrorMessage: '密码至少 6 位',
        closeOnClickModal: false
      }
    )

    const password = value?.trim()
    if (!password) {
      ElMessage.warning('请输入新密码')
      return
    }
    if (password.length < 6) {
      ElMessage.warning('密码至少 6 位')
      return
    }

    resetPasswordLoadingUserId.value = row.id
    const payload: ResetUserPasswordRequest = {
      id: row.id,
      ...buildResetUserPasswordPayload(password)
    }

    await resetUserPassword(payload)
    ElMessage.success('密码重置成功')
  } catch (error) {
    if (error !== 'cancel') {
      console.error('重置密码失败:', error)
      ElMessage.error('重置密码失败')
    }
  } finally {
    resetPasswordLoadingUserId.value = null
  }
}

/**
 * 管理员调整用户余额
 */
const handleOpenBalanceDialog = (row: User) => {
  balanceDialogUser.value = row
  balanceDialogVisible.value = true
  balanceForm.amount = undefined
  balanceForm.remark = ''
}

const handleCloseBalanceDialog = () => {
  balanceDialogVisible.value = false
  balanceDialogUser.value = null
  balanceForm.amount = undefined
  balanceForm.remark = ''
}

const handleAdjustBalance = async (type: AdjustUserBalanceType) => {
  const row = balanceDialogUser.value
  if (!row) {
    return
  }

  const actionLabel = type === 'increase' ? '增加' : '减少'

  try {
    if (balanceForm.amount === undefined || balanceForm.amount === null) {
      ElMessage.warning('请输入调整金额')
      return
    }

    const amount = normalizeBalanceAdjustAmount(String(balanceForm.amount))
    if (!Number.isFinite(amount) || amount <= 0) {
      ElMessage.warning('调整金额必须大于 0')
      return
    }

    balanceSubmitAction.value = type
    await adjustUserBalance(row.id, buildAdjustUserBalancePayload(type, amount, balanceForm.remark))
    ElMessage.success(`${actionLabel}余额成功`)

    if (detailUser.value?.id === row.id) {
      const balance = Number(detailUser.value.balance || 0)
      detailUser.value = {
        ...detailUser.value,
        balance:
          type === 'increase'
            ? Number((balance + amount).toFixed(2))
            : Number((balance - amount).toFixed(2))
      }
      walletDetailListRefreshKey.value += 1
    }

    balanceSubmitAction.value = null
    handleCloseBalanceDialog()
    getList()
  } catch (error) {
    console.error(`${actionLabel}余额失败:`, error)
    ElMessage.error(`${actionLabel}余额失败`)
  } finally {
    balanceSubmitAction.value = null
  }
}

/**
 * 保存用户（新增或编辑）
 */
const handleSave = async (formData: any) => {
  saveLoading.value = true
  try {
    if (currentRow.value?.id) {
      // 编辑模式 - 固定角色为 USER
      const updateData: UpdateUserRequest = {
        username: formData.username,
        email: formData.email,
        phone: formData.phone,
        isActive: formData.isActive,
        role: UserRole.USER // 固定为普通用户
      }
      await updateUser(currentRow.value.id, updateData)
      ElMessage.success('更新成功')
    } else {
      // 新增模式 - 固定角色为 USER
      const createData: CreateUserRequest = {
        username: formData.username,
        password: formData.password,
        email: formData.email,
        phone: formData.phone,
        role: UserRole.USER // 固定为普通用户
      }
      await createUser(createData)
      ElMessage.success('创建成功')
    }

    dialogVisible.value = false
    currentPage.value = 1
    getList()
  } catch (error) {
    console.error('保存失败:', error)
    ElMessage.error('保存失败')
  } finally {
    saveLoading.value = false
  }
}

/**
 * 处理用户状态变更
 */
const handleStatusChange = async (row: User, value: boolean) => {
  try {
    await updateUser(row.id, { isActive: value })
    ElMessage.success('状态更新成功')
    getList()
  } catch (error) {
    ElMessage.error('状态更新失败')
  }
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
    getList()
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}
</script>

<template>
  <ContentWrap>
    <!-- 搜索区域 -->
    <Search :schema="allSchemas.searchSchema" @reset="setSearchParams" @search="setSearchParams" />

    <!-- 操作按钮 -->
    <div class="mb-10px">
      <BaseButton type="primary" @click="handleAdd">新增用户</BaseButton>
    </div>

    <!-- 表格区域 -->
    <Table
      v-model:current-page="currentPage"
      v-model:page-size="pageSize"
      :columns="allSchemas.tableColumns"
      :data="dataList"
      :loading="loading"
      @register="tableRegister"
      :pagination="{
        total: total || 0
      }"
    />
  </ContentWrap>

  <!-- 新增/编辑弹窗 -->
  <Dialog v-model="dialogVisible" :title="dialogTitle" width="800px">
    <div v-if="dialogVisible" class="dialog-content">
      <UserFormDialog
        ref="writeRef"
        :form-schema="dialogFormSchema"
        :current-row="currentRow"
        @submit="handleSave"
      />
    </div>

    <template #footer>
      <BaseButton type="primary" :loading="saveLoading" @click="writeRef?.submit()">
        保存
      </BaseButton>
      <BaseButton @click="dialogVisible = false">取消</BaseButton>
    </template>
  </Dialog>

  <Dialog v-model="balanceDialogVisible" title="余额操作" width="520px">
    <div v-if="balanceDialogVisible && balanceDialogUser" class="balance-dialog">
      <div class="balance-summary">
        <div class="balance-summary__label">当前用户</div>
        <div class="balance-summary__value">
          {{ balanceDialogUser.username || balanceDialogUser.phone }}
        </div>
        <div class="balance-summary__label">当前可用余额</div>
        <div class="balance-summary__amount">
          ¥{{ Number(balanceDialogUser.balance || 0).toFixed(2) }}
        </div>
      </div>

      <div class="balance-form-item">
        <div class="balance-form-item__label">调整金额</div>
        <ElInputNumber
          v-model="balanceForm.amount"
          :min="0.01"
          :max="99999999"
          :precision="2"
          :step="1"
          controls-position="right"
          class="balance-input"
          placeholder="请输入金额"
        />
      </div>

      <div class="balance-form-item">
        <div class="balance-form-item__label">操作备注</div>
        <ElInput
          v-model="balanceForm.remark"
          type="textarea"
          :rows="4"
          maxlength="200"
          show-word-limit
          placeholder="选填，不填时会使用系统默认备注"
        />
      </div>
    </div>

    <template #footer>
      <BaseButton
        type="success"
        :loading="balanceSubmitAction === 'increase'"
        @click="handleAdjustBalance('increase')"
      >
        增加余额
      </BaseButton>
      <BaseButton
        type="danger"
        :loading="balanceSubmitAction === 'decrease'"
        @click="handleAdjustBalance('decrease')"
      >
        减少余额
      </BaseButton>
      <BaseButton :disabled="Boolean(balanceSubmitAction)" @click="handleCloseBalanceDialog">
        取消
      </BaseButton>
    </template>
  </Dialog>

  <!-- 用户详情弹窗 -->
  <Dialog v-model="detailDialogVisible" title="用户详情" width="900px">
    <div v-if="detailDialogVisible && detailUser" class="dialog-content">
      <el-tabs v-model="activeTab">
        <el-tab-pane label="基本信息" name="basic">
          <el-descriptions :column="2" border>
            <el-descriptions-item label="用户名">
              {{ detailUser.username || '-' }}
            </el-descriptions-item>
            <el-descriptions-item label="手机号">
              {{ detailUser.phone }}
            </el-descriptions-item>
            <el-descriptions-item label="邮箱">
              {{ detailUser.email || '-' }}
            </el-descriptions-item>
            <el-descriptions-item label="角色">
              {{ UserRoleLabel[detailUser.role] }}
            </el-descriptions-item>
            <el-descriptions-item label="状态">
              <ElTag :type="detailUser.isActive ? 'success' : 'danger'">
                {{ detailUser.isActive ? '启用' : '禁用' }}
              </ElTag>
            </el-descriptions-item>
            <el-descriptions-item label="可用余额">
              <span style="font-size: 18px; font-weight: 600; color: #10b981">
                ¥{{ Number(detailUser.balance || 0).toFixed(2) }}
              </span>
            </el-descriptions-item>
            <el-descriptions-item label="待审核余额">
              <span style="font-size: 18px; font-weight: 600; color: #f59e0b">
                ¥{{ Number(detailUser.pendingBalance || 0).toFixed(2) }}
              </span>
            </el-descriptions-item>
            <el-descriptions-item label="注册时间">
              {{ new Date(detailUser.createdAt).toLocaleString('zh-CN') }}
            </el-descriptions-item>
            <el-descriptions-item label="最后登录" :span="2">
              {{
                detailUser.lastLoginAt
                  ? new Date(detailUser.lastLoginAt).toLocaleString('zh-CN')
                  : '-'
              }}
            </el-descriptions-item>
          </el-descriptions>
        </el-tab-pane>
        <el-tab-pane label="钱包明细" name="wallet">
          <WalletDetailList
            :key="`${detailUser.id}-${walletDetailListRefreshKey}`"
            :user-id="detailUser.id"
          />
        </el-tab-pane>
      </el-tabs>
    </div>

    <template #footer>
      <BaseButton @click="detailDialogVisible = false">关闭</BaseButton>
    </template>
  </Dialog>
</template>

<style scoped>
.dialog-content {
  padding: 0;
}

.balance-dialog {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.balance-summary {
  padding: 16px;
  border-radius: 8px;
  background: #f8fafc;
}

.balance-summary__label {
  font-size: 13px;
  color: #64748b;
}

.balance-summary__value {
  margin-top: 4px;
  font-size: 16px;
  font-weight: 600;
  color: #1f2937;
}

.balance-summary__amount {
  margin-top: 4px;
  font-size: 28px;
  font-weight: 700;
  color: #10b981;
}

.balance-form-item {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.balance-form-item__label {
  font-size: 14px;
  font-weight: 500;
  color: #1f2937;
}

.balance-input {
  width: 100%;
}
</style>
