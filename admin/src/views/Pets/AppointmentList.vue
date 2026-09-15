<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { Search } from '@/components/Search'
import { ElTag, ElMessage, ElMessageBox } from 'element-plus'
import { Table } from '@/components/Table'
import {
  getHealthAppointmentListApi,
  updateHealthAppointmentStatusApi,
  completeHealthAppointmentApi,
  cancelHealthAppointmentApi,
  type HealthAppointment,
  HealthAppointmentType,
  HealthAppointmentTypeLabel,
  HealthAppointmentStatus,
  HealthAppointmentStatusLabel
} from '@/api-new/health-appointments'
import { PetGenderLabel } from '@/api-new/pets'
import { useTable } from '@/hooks/web/useTable'
import { ref, unref, reactive } from 'vue'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { BaseButton } from '@/components/Button'
import { Dialog } from '@/components/Dialog'
import AppointmentConfirm from './components/AppointmentConfirm.vue'
import AppointmentComplete from './components/AppointmentComplete.vue'
import { getImageUrl } from '@/utils/image'
import { extractPagedTableData } from '@/utils/pagination'

defineOptions({
  name: 'AppointmentList'
})

// 预约类型标签映射
const getTypeTagColor = (type: HealthAppointmentType) => {
  const colorMap: Record<HealthAppointmentType, 'primary' | 'success' | 'warning'> = {
    [HealthAppointmentType.VACCINE]: 'primary',
    [HealthAppointmentType.DEWORMING]: 'success',
    [HealthAppointmentType.CHECKUP]: 'warning'
  }
  return colorMap[type] || 'info'
}

// 预约状态标签映射
const getStatusTagColor = (status: HealthAppointmentStatus) => {
  const colorMap: Record<HealthAppointmentStatus, 'warning' | 'success' | 'info' | 'danger'> = {
    [HealthAppointmentStatus.PENDING]: 'warning',
    [HealthAppointmentStatus.CONFIRMED]: 'success',
    [HealthAppointmentStatus.COMPLETED]: 'info',
    [HealthAppointmentStatus.CANCELLED]: 'danger'
  }
  return colorMap[status] || 'info'
}

/**
 * 计算宠物年龄
 */
const calculateAge = (birthDate: string): string => {
  if (!birthDate) return '未知'
  const birth = new Date(birthDate)
  const today = new Date()
  const ageInDays = Math.floor((today.getTime() - birth.getTime()) / (1000 * 60 * 60 * 24))

  if (ageInDays < 30) {
    return `${ageInDays}天`
  } else if (ageInDays < 365) {
    const months = Math.floor(ageInDays / 30)
    return `${months}个月`
  } else {
    const years = Math.floor(ageInDays / 365)
    const months = Math.floor((ageInDays % 365) / 30)
    return months > 0 ? `${years}岁${months}个月` : `${years}岁`
  }
}

// 搜索参数
const searchParams = ref<Record<string, any>>({})
const setSearchParams = (params: any) => {
  searchParams.value = params
  getList()
}

// 对话框相关
const confirmDialogVisible = ref(false)
const completeDialogVisible = ref(false)
const viewDialogVisible = ref(false)
const currentRow = ref<HealthAppointment | null>(null)
const confirmRef = ref()
const completeRef = ref()

// 表格配置
const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const { currentPage, pageSize } = tableState
    const res = await getHealthAppointmentListApi({
      page: unref(currentPage),
      pageSize: unref(pageSize),
      ...unref(searchParams)
    })

    return extractPagedTableData<HealthAppointment>(res)
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
    field: 'petName',
    label: '宠物名称',
    search: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入宠物名称'
      }
    },
    table: { hidden: true }
  },
  {
    field: 'ownerPhone',
    label: '主人手机号',
    search: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入主人手机号'
      }
    },
    table: { hidden: true }
  },
  {
    field: 'type',
    label: '预约类型',
    search: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '全部', value: '' },
          { label: '疫苗接种', value: HealthAppointmentType.VACCINE },
          { label: '驱虫', value: HealthAppointmentType.DEWORMING },
          { label: '体检', value: HealthAppointmentType.CHECKUP }
        ]
      }
    },
    table: {
      show: true,
      width: 120,
      slots: {
        default: (data: any) => {
          return (
            <ElTag type={getTypeTagColor(data.row.type)}>
              {HealthAppointmentTypeLabel[data.row.type]}
            </ElTag>
          )
        }
      }
    }
  },
  {
    field: 'status',
    label: '预约状态',
    search: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '全部', value: '' },
          { label: '待确认', value: HealthAppointmentStatus.PENDING },
          { label: '已确认', value: HealthAppointmentStatus.CONFIRMED },
          { label: '已完成', value: HealthAppointmentStatus.COMPLETED },
          { label: '已取消', value: HealthAppointmentStatus.CANCELLED }
        ]
      }
    },
    table: {
      show: true,
      width: 120,
      slots: {
        default: (data: any) => {
          return (
            <ElTag type={getStatusTagColor(data.row.status)}>
              {HealthAppointmentStatusLabel[data.row.status]}
            </ElTag>
          )
        }
      }
    }
  },
  {
    field: 'pet',
    label: '宠物信息',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 280,
      slots: {
        default: (data: any) => {
          const pet = data.row.pet
          if (!pet) return <span>-</span>
          return (
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              {pet.avatar && (
                <img
                  src={getImageUrl(pet.avatar)}
                  style={{ width: '40px', height: '40px', borderRadius: '50%', objectFit: 'cover' }}
                  alt="头像"
                />
              )}
              <div style={{ flex: 1 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <span style={{ fontWeight: 'bold', fontSize: '14px' }}>{pet.name}</span>
                  <ElTag size="small" type={pet.gender === 1 ? 'primary' : 'danger'}>
                    {PetGenderLabel[pet.gender]}
                  </ElTag>
                </div>
                <div style={{ fontSize: '12px', color: '#909399', marginTop: '2px' }}>
                  {pet.category?.name} {pet.subCategory?.name ? `- ${pet.subCategory.name}` : ''}
                </div>
                <div style={{ fontSize: '12px', color: '#909399', marginTop: '2px' }}>
                  {calculateAge(pet.birthDate || '')} ·{' '}
                  {pet.weight ? `${pet.weight}kg` : '体重未知'}
                </div>
              </div>
            </div>
          )
        }
      }
    }
  },
  {
    field: 'user',
    label: '主人信息',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      slots: {
        default: (data: any) => {
          const user = data.row.user
          if (!user) return <span>-</span>
          return (
            <div>
              <div>{user.username}</div>
              <div style={{ fontSize: '12px', color: '#909399' }}>{user.phone}</div>
            </div>
          )
        }
      }
    }
  },
  {
    field: 'appointmentDate',
    label: '预约日期',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true
    }
  },
  {
    field: 'timeSlot',
    label: '时间段',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true
    }
  },
  {
    field: 'action',
    width: '240px',
    label: '操作',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: {
      fixed: 'right',
      slots: {
        default: (data: any) => {
          const row = data.row
          const status = row.status

          return (
            <>
              {status === HealthAppointmentStatus.PENDING && (
                <>
                  <BaseButton type="primary" onClick={() => handleConfirm(row)}>
                    确认
                  </BaseButton>
                  <BaseButton type="danger" onClick={() => handleCancel(row)}>
                    取消
                  </BaseButton>
                </>
              )}
              {status === HealthAppointmentStatus.CONFIRMED && (
                <>
                  <BaseButton type="success" onClick={() => handleComplete(row)}>
                    完成
                  </BaseButton>
                  <BaseButton type="danger" onClick={() => handleCancel(row)}>
                    取消
                  </BaseButton>
                </>
              )}
              {status === HealthAppointmentStatus.COMPLETED && (
                <BaseButton type="info" onClick={() => handleView(row)}>
                  查看
                </BaseButton>
              )}
            </>
          )
        }
      }
    }
  }
])

const { allSchemas } = useCrudSchemas(crudSchemas)

/**
 * 确认预约
 */
const handleConfirm = (row: HealthAppointment) => {
  currentRow.value = row
  confirmDialogVisible.value = true
}

/**
 * 完成预约
 */
const handleComplete = (row: HealthAppointment) => {
  currentRow.value = row
  completeDialogVisible.value = true
}

/**
 * 取消预约
 */
const handleCancel = async (row: HealthAppointment) => {
  try {
    await ElMessageBox.confirm(`确定要取消该预约吗？`, '提示', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    })

    await cancelHealthAppointmentApi(row.id)
    ElMessage.success('取消成功')
    getList()
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('取消失败')
    }
  }
}

/**
 * 查看详情
 */
const handleView = (row: HealthAppointment) => {
  currentRow.value = row
  viewDialogVisible.value = true
}

/**
 * 确认预约提交
 */
const handleConfirmSubmit = async () => {
  try {
    const confirm = unref(confirmRef)
    if (!confirm) return

    const formData = await confirm.getFormData()
    if (!formData) return

    await updateHealthAppointmentStatusApi(currentRow.value!.id, {
      status: HealthAppointmentStatus.CONFIRMED,
      doctorId: formData.doctorId
    })

    ElMessage.success('确认成功')
    confirmDialogVisible.value = false
    getList()
  } catch (error) {
    ElMessage.error('确认失败')
  }
}

/**
 * 完成预约提交
 */
const handleCompleteSubmit = async () => {
  try {
    const complete = unref(completeRef)
    if (!complete) return

    const formData = await complete.getFormData()
    if (!formData) return

    await completeHealthAppointmentApi(currentRow.value!.id, formData)

    ElMessage.success('完成成功')
    completeDialogVisible.value = false
    getList()
  } catch (error) {
    ElMessage.error('完成失败')
  }
}
</script>

<template>
  <ContentWrap>
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
        total
      }"
      @register="tableRegister"
    />

    <!-- 确认预约对话框 -->
    <Dialog v-model="confirmDialogVisible" title="确认预约" width="600px" max-height="650px">
      <AppointmentConfirm v-if="confirmDialogVisible" ref="confirmRef" :appointment="currentRow" />
      <template #footer>
        <BaseButton type="primary" @click="handleConfirmSubmit">确认</BaseButton>
        <BaseButton @click="confirmDialogVisible = false">取消</BaseButton>
      </template>
    </Dialog>

    <!-- 完成预约对话框 -->
    <Dialog v-model="completeDialogVisible" title="完成预约" width="1000px" max-height="650px">
      <AppointmentComplete
        v-if="completeDialogVisible"
        ref="completeRef"
        :appointment="currentRow"
      />
      <template #footer>
        <BaseButton type="primary" @click="handleCompleteSubmit">完成</BaseButton>
        <BaseButton @click="completeDialogVisible = false">取消</BaseButton>
      </template>
    </Dialog>

    <!-- 查看详情对话框 -->
    <Dialog v-model="viewDialogVisible" title="预约详情" width="800px" max-height="650px">
      <div v-if="currentRow" class="appointment-detail">
        <div class="detail-row">
          <span class="detail-label">预约医院：</span>
          <span class="detail-value">{{ currentRow.hospital?.name || '未知' }}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">宠物信息：</span>
          <span class="detail-value"
            >{{ currentRow.pet?.name }}（{{ currentRow.pet?.category?.name
            }}{{
              currentRow.pet?.subCategory?.name ? ` - ${currentRow.pet.subCategory.name}` : ''
            }}）</span
          >
        </div>
        <div class="detail-row">
          <span class="detail-label">主人信息：</span>
          <span class="detail-value"
            >{{ currentRow.user?.username }} - {{ currentRow.user?.phone }}</span
          >
        </div>
        <div v-if="currentRow.doctor" class="detail-row">
          <span class="detail-label">操作医生：</span>
          <span class="detail-value"
            >{{ currentRow.doctor?.name }} - {{ currentRow.doctor?.phone }}</span
          >
        </div>
        <div class="detail-row">
          <span class="detail-label">预约类型：</span>
          <ElTag type="primary" v-if="currentRow.type === 'vaccine'">疫苗接种</ElTag>
          <ElTag type="success" v-else-if="currentRow.type === 'deworming'">驱虫</ElTag>
          <ElTag type="warning" v-else>体检</ElTag>
        </div>
        <div class="detail-row">
          <span class="detail-label">预约状态：</span>
          <ElTag type="warning" v-if="currentRow.status === 'pending'">待确认</ElTag>
          <ElTag type="success" v-else-if="currentRow.status === 'confirmed'">已确认</ElTag>
          <ElTag type="info" v-else-if="currentRow.status === 'completed'">已完成</ElTag>
          <ElTag type="danger" v-else>已取消</ElTag>
        </div>
        <div class="detail-row">
          <span class="detail-label">预约日期：</span>
          <span class="detail-value">{{ currentRow.appointmentDate }}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">时间段：</span>
          <span class="detail-value">{{ currentRow.timeSlot }}</span>
        </div>
        <div v-if="currentRow.notes" class="detail-row">
          <span class="detail-label">备注：</span>
          <span class="detail-value">{{ currentRow.notes }}</span>
        </div>
        <div v-if="currentRow.operationContent" class="detail-row">
          <span class="detail-label">本次操作内容：</span>
          <span class="detail-value">{{ currentRow.operationContent }}</span>
        </div>
        <div v-if="currentRow.detailContent" class="detail-row" style="align-items: flex-start">
          <span class="detail-label">详情内容：</span>
          <div class="detail-value" v-html="currentRow.detailContent"></div>
        </div>
        <div class="detail-row">
          <span class="detail-label">创建时间：</span>
          <span class="detail-value">{{ currentRow.createdAt }}</span>
        </div>
      </div>
      <template #footer>
        <BaseButton @click="viewDialogVisible = false">关闭</BaseButton>
      </template>
    </Dialog>
  </ContentWrap>
</template>

<style scoped lang="less">
.appointment-detail {
  padding: 20px;

  .detail-row {
    display: flex;
    margin-bottom: 16px;
    align-items: center;

    &:last-child {
      margin-bottom: 0;
    }

    .detail-label {
      font-weight: bold;
      color: #303133;
      width: 100px;
      flex-shrink: 0;
    }

    .detail-value {
      color: #606266;
      flex: 1;
    }
  }
}
</style>
