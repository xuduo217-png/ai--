<script setup lang="tsx">
import { ref, watch } from 'vue'
import { ElTag, ElTimeline, ElTimelineItem, ElEmpty, ElTabs, ElTabPane } from 'element-plus'
import { Dialog } from '@/components/Dialog'
import { BaseButton } from '@/components/Button'
import { petApi, type Pet, PetGenderLabel } from '@/api-new/pets'
import {
  getPetHealthAppointmentsApi,
  type HealthAppointment,
  HealthAppointmentType,
  HealthAppointmentTypeLabel,
  HealthAppointmentStatus,
  HealthAppointmentStatusLabel
} from '@/api-new/health-appointments'
import { ElMessage } from 'element-plus'
import { getImageUrl } from '@/utils/image'
import { extractPagedTableData } from '@/utils/pagination'

interface Props {
  petId: number | null
  modelValue: boolean
}

const props = defineProps<Props>()
const emit = defineEmits(['update:modelValue'])

// 宠物详情数据
const pet = ref<Pet | null>(null)
const loading = ref(false)
const activeTab = ref('basic')

// 预约记录
const appointments = ref<HealthAppointment[]>([])
const appointmentsLoading = ref(false)

/**
 * 计算年龄
 */
const calculateAge = (birthDate: string): string => {
  if (!birthDate) return '未知'
  const birth = new Date(birthDate)
  const today = new Date()
  const ageInDays = Math.floor((today.getTime() - birth.getTime()) / (1000 * 60 * 60 * 24))

  if (ageInDays < 30) {
    return `${ageInDays} 天`
  } else if (ageInDays < 365) {
    const months = Math.floor(ageInDays / 30)
    return `${months} 个月`
  } else {
    const years = Math.floor(ageInDays / 365)
    const months = Math.floor((ageInDays % 365) / 30)
    return months > 0 ? `${years} 岁 ${months} 个月` : `${years} 岁`
  }
}

/**
 * 获取宠物详情
 */
const fetchPetDetail = async () => {
  if (!props.petId) return

  loading.value = true
  try {
    const res = await petApi.getPetDetailApi(props.petId)
    pet.value = res.data
  } catch (error) {
    console.error('获取宠物详情失败:', error)
    ElMessage.error('获取宠物详情失败')
  } finally {
    loading.value = false
  }
}

/**
 * 获取预约记录
 */
const fetchAppointments = async () => {
  if (!props.petId) return

  appointmentsLoading.value = true
  try {
    const res = await getPetHealthAppointmentsApi(props.petId, {
      page: 1,
      pageSize: 50
    })
    const { list } = extractPagedTableData<HealthAppointment>(res)
    appointments.value = list
  } catch (error) {
    console.error('获取预约记录失败:', error)
    ElMessage.error('获取预约记录失败')
  } finally {
    appointmentsLoading.value = false
  }
}

/**
 * 时间线类型图标和颜色
 */
const getTimelineIcon = (type: HealthAppointmentType) => {
  const iconMap = {
    [HealthAppointmentType.VACCINE]: { icon: '💉', color: '#409EFF' },
    [HealthAppointmentType.DEWORMING]: { icon: '💊', color: '#67C23A' },
    [HealthAppointmentType.CHECKUP]: { icon: '🏥', color: '#E6A23C' }
  }
  return iconMap[type] || { icon: '📅', color: '#909399' }
}

/**
 * 时间线类型
 */
const getTimelineType = (status: HealthAppointmentStatus) => {
  if (status === HealthAppointmentStatus.CANCELLED) return 'info'
  return 'primary'
}

/**
 * 获取疫苗统计中的“上次接种”展示文案
 * 仅录入针数但没有日期时，改为提示资料不完整，避免误导运营人员。
 */
const getVaccineLastText = (pet: Pet): string => {
  if (pet.lastVaccineAt) {
    return pet.lastVaccineAt
  }

  if ((pet.vaccineCount || 0) > 0) {
    return '已录入针数，未记录时间'
  }

  return '无记录'
}

/**
 * 获取疫苗统计中的“下次接种”展示文案
 * 建档阶段不再手工填写下次时间，默认引导通过健康预约流程补全。
 */
const getVaccineNextText = (pet: Pet): string => {
  if (pet.nextVaccineAt) {
    return pet.nextVaccineAt
  }

  if ((pet.vaccineCount || 0) > 0) {
    return '待预约后更新'
  }

  return '未设置'
}

/**
 * 监听 petId 变化
 */
watch(
  () => props.petId,
  (newVal) => {
    if (newVal && props.modelValue) {
      fetchPetDetail()
      fetchAppointments()
    }
  },
  { immediate: true }
)

/**
 * 监听对话框打开
 */
watch(
  () => props.modelValue,
  (newVal) => {
    if (newVal && props.petId) {
      activeTab.value = 'basic'
      fetchPetDetail()
      fetchAppointments()
    }
  }
)

/**
 * 关闭对话框
 */
const handleClose = () => {
  emit('update:modelValue', false)
}
</script>

<template>
  <Dialog
    :model-value="modelValue"
    @update:model-value="handleClose"
    title="宠物详情"
    width="1000px"
    :append-to-body="true"
  >
    <div v-if="loading" class="loading-container">加载中...</div>

    <div v-else-if="pet">
      <ElTabs v-model="activeTab">
        <!-- Tab 1：基本信息 -->
        <ElTabPane label="基本信息" name="basic">
          <div class="detail-section">
            <div class="pet-header">
              <img
                v-if="pet.avatar"
                :src="getImageUrl(pet.avatar)"
                class="pet-avatar"
                alt="宠物头像"
              />
              <div v-else class="pet-avatar-placeholder">{{ pet.name[0] }}</div>

              <div class="pet-basic-info">
                <h3>{{ pet.name }}</h3>
                <div class="info-tags">
                  <ElTag type="primary">{{ PetGenderLabel[pet.gender] }}</ElTag>
                  <ElTag v-if="pet.category" type="success">{{ pet.category.name }}</ElTag>
                  <ElTag v-if="pet.subCategory" type="info">{{ pet.subCategory.name }}</ElTag>
                  <ElTag :type="pet.isNeutered ? 'success' : 'warning'">
                    {{ pet.isNeutered ? '已绝育' : '未绝育' }}
                  </ElTag>
                </div>
              </div>
            </div>

            <div class="info-grid">
              <div class="info-item">
                <label>出生日期</label>
                <span>{{ pet.birthDate || '-' }}</span>
              </div>
              <div class="info-item">
                <label>年龄</label>
                <span>{{ calculateAge(pet.birthDate || '') }}</span>
              </div>
              <div class="info-item">
                <label>体重</label>
                <span>{{ pet.weight ? `${pet.weight} kg` : '-' }}</span>
              </div>
            </div>

            <div v-if="pet.tags && pet.tags.length > 0" class="tags-section">
              <label>标签</label>
              <div class="tags-list">
                <ElTag v-for="(tag, index) in pet.tags" :key="index" type="info" size="small">
                  {{ tag }}
                </ElTag>
              </div>
            </div>

            <div class="info-meta">
              <div>创建时间：{{ pet.createdAt }}</div>
              <div>更新时间：{{ pet.updatedAt }}</div>
            </div>
          </div>
        </ElTabPane>

        <!-- Tab 2：主人信息 -->
        <ElTabPane label="主人信息" name="owner">
          <div v-if="pet.owner" class="detail-section">
            <div class="owner-header">
              <img
                v-if="pet.owner.avatar"
                :src="getImageUrl(pet.owner.avatar)"
                class="owner-avatar"
                alt="主人头像"
              />
              <div v-else class="owner-avatar-placeholder">{{ pet.owner.username[0] }}</div>

              <div class="owner-basic-info">
                <h3>{{ pet.owner.username }}</h3>
              </div>
            </div>

            <div class="info-grid">
              <div class="info-item">
                <label>手机号</label>
                <span>{{ pet.owner.phone }}</span>
              </div>
            </div>
          </div>
          <ElEmpty v-else description="暂无主人信息" />
        </ElTabPane>

        <!-- Tab 3：健康统计 -->
        <ElTabPane label="健康统计" name="health">
          <div class="detail-section">
            <div class="health-stats-grid">
              <div class="stat-card">
                <div class="stat-icon">💉</div>
                <div class="stat-content">
                  <div class="stat-label">疫苗接种</div>
                  <div class="stat-value">{{ pet.vaccineCount || 0 }} 针</div>
                  <div class="stat-meta">
                    <div>上次：{{ getVaccineLastText(pet) }}</div>
                    <div>下次：{{ getVaccineNextText(pet) }}</div>
                  </div>
                </div>
              </div>

              <div class="stat-card">
                <div class="stat-icon">💊</div>
                <div class="stat-content">
                  <div class="stat-label">驱虫记录</div>
                  <div class="stat-value">{{ pet.dewormingCount || 0 }} 次</div>
                  <div class="stat-meta">
                    <div>上次：{{ pet.lastDewormingAt || '无记录' }}</div>
                    <div>下次：{{ pet.nextDewormingAt || '未设置' }}</div>
                  </div>
                </div>
              </div>

              <div class="stat-card">
                <div class="stat-icon">🏥</div>
                <div class="stat-content">
                  <div class="stat-label">体检记录</div>
                  <div class="stat-value">{{ pet.checkupCount || 0 }} 次</div>
                  <div class="stat-meta">
                    <div>上次：{{ pet.lastCheckupAt || '无记录' }}</div>
                    <div>下次：{{ pet.nextCheckupAt || '未设置' }}</div>
                  </div>
                </div>
              </div>

              <div class="stat-card">
                <div class="stat-icon">📅</div>
                <div class="stat-content">
                  <div class="stat-label">预约统计</div>
                  <div class="stat-value">{{ pet.appointmentCount || 0 }} 次</div>
                  <div class="stat-meta">
                    <div>最后预约：{{ pet.lastAppointmentAt || '无记录' }}</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </ElTabPane>

        <!-- Tab 4：预约记录 -->
        <ElTabPane label="预约记录" name="appointments">
          <div v-if="appointmentsLoading" class="loading-container">加载中...</div>

          <div v-else-if="appointments.length > 0" class="detail-section">
            <ElTimeline>
              <ElTimelineItem
                v-for="appointment in appointments"
                :key="appointment.id"
                :type="getTimelineType(appointment.status)"
                :icon="getTimelineIcon(appointment.type).icon"
                :color="getTimelineIcon(appointment.type).color"
                :size="'large'"
              >
                <div class="timeline-content">
                  <div class="timeline-header">
                    <span class="timeline-title">
                      {{ HealthAppointmentTypeLabel[appointment.type] }}
                    </span>
                    <ElTag
                      :type="appointment.status === 'cancelled' ? 'info' : 'success'"
                      size="small"
                    >
                      {{ HealthAppointmentStatusLabel[appointment.status] }}
                    </ElTag>
                  </div>
                  <div class="timeline-time">
                    {{ appointment.appointmentDate }} {{ appointment.timeSlot }}
                  </div>
                  <div v-if="appointment.operationContent" class="timeline-operation">
                    操作内容：{{ appointment.operationContent }}
                  </div>
                  <div v-if="appointment.notes" class="timeline-notes">
                    备注：{{ appointment.notes }}
                  </div>
                </div>
              </ElTimelineItem>
            </ElTimeline>
          </div>

          <ElEmpty v-else description="暂无预约记录" />
        </ElTabPane>
      </ElTabs>
    </div>

    <template #footer>
      <BaseButton @click="handleClose">关闭</BaseButton>
    </template>
  </Dialog>
</template>

<style scoped lang="less">
.loading-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 200px;
  color: #909399;
}

.detail-section {
  padding: 20px;
}

.pet-header {
  display: flex;
  align-items: center;
  gap: 20px;
  margin-bottom: 24px;

  .pet-avatar {
    width: 120px;
    height: 120px;
    border-radius: 50%;
    object-fit: cover;
    border: 4px solid #f0f0f0;
  }

  .pet-avatar-placeholder {
    width: 120px;
    height: 120px;
    border-radius: 50%;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 48px;
    color: white;
    font-weight: bold;
  }

  .pet-basic-info {
    flex: 1;

    h3 {
      font-size: 28px;
      margin: 0 0 12px 0;
      color: #303133;
    }

    .info-tags {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
    }
  }
}

.info-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 20px;
  margin-bottom: 24px;

  .info-item {
    display: flex;
    flex-direction: column;
    gap: 8px;

    label {
      font-size: 14px;
      color: #909399;
    }

    span {
      font-size: 16px;
      color: #303133;
      font-weight: 500;
    }
  }
}

.tags-section {
  margin-bottom: 24px;

  label {
    font-size: 14px;
    color: #909399;
    display: block;
    margin-bottom: 8px;
  }

  .tags-list {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }
}

.info-meta {
  padding-top: 20px;
  border-top: 1px solid #f0f0f0;
  font-size: 14px;
  color: #909399;
  display: flex;
  gap: 24px;
}

.owner-header {
  display: flex;
  align-items: center;
  gap: 20px;
  margin-bottom: 24px;

  .owner-avatar {
    width: 80px;
    height: 80px;
    border-radius: 50%;
    object-fit: cover;
  }

  .owner-avatar-placeholder {
    width: 80px;
    height: 80px;
    border-radius: 50%;
    background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 32px;
    color: white;
    font-weight: bold;
  }

  .owner-basic-info {
    h3 {
      font-size: 24px;
      margin: 0;
      color: #303133;
    }
  }
}

.health-stats-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 20px;

  .stat-card {
    display: flex;
    gap: 16px;
    padding: 20px;
    background: #f5f7fa;
    border-radius: 8px;
    transition: all 0.3s;

    &:hover {
      background: #e9ecef;
      transform: translateY(-2px);
    }

    .stat-icon {
      font-size: 48px;
      width: 60px;
      height: 60px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: white;
      border-radius: 50%;
    }

    .stat-content {
      flex: 1;

      .stat-label {
        font-size: 14px;
        color: #909399;
        margin-bottom: 4px;
      }

      .stat-value {
        font-size: 24px;
        font-weight: bold;
        color: #303133;
        margin-bottom: 8px;
      }

      .stat-meta {
        font-size: 12px;
        color: #909399;
        line-height: 1.6;
      }
    }
  }
}

.timeline-content {
  padding: 8px 0;

  .timeline-header {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 8px;

    .timeline-title {
      font-size: 16px;
      font-weight: bold;
      color: #303133;
    }
  }

  .timeline-time {
    font-size: 14px;
    color: #606266;
    margin-bottom: 4px;
  }

  .timeline-operation {
    font-size: 13px;
    color: #409eff;
    margin-top: 4px;
    padding: 4px 8px;
    background: #ecf5ff;
    border-radius: 4px;
    display: inline-block;
  }

  .timeline-notes {
    font-size: 13px;
    color: #909399;
    margin-top: 4px;
  }
}
</style>
