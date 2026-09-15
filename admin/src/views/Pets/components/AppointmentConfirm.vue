<script setup lang="ts">
import { ref, watch, computed } from 'vue'
import { Form, FormSchema } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import type { HealthAppointment } from '@/api-new/health-appointments'
import { HealthAppointmentTypeLabel } from '@/api-new/health-appointments'
import { getHospitalDoctorsApi, type Doctor } from '@/api-new/doctors'

interface Props {
  appointment: HealthAppointment | null
}

const props = defineProps<Props>()

// 表单方法
const { formRegister, formMethods } = useForm()
const { setValues, getElFormExpose } = formMethods

// 医生列表
const doctorList = ref<Doctor[]>([])
const loadingDoctor = ref(false)

// 表单数据
const formData = ref({
  appointmentDate: '',
  timeSlot: '',
  doctorId: null as number | null
})

/**
 * 加载医院医生列表
 */
const loadHospitalDoctors = async (hospitalId: number) => {
  if (!hospitalId) return

  try {
    loadingDoctor.value = true
    const res = await getHospitalDoctorsApi(hospitalId)
    doctorList.value = res.data || []
  } catch (error) {
    console.error('加载医生列表失败:', error)
    doctorList.value = []
  } finally {
    loadingDoctor.value = false
  }
}

// 监听 appointment 变化，设置表单值
watch(
  () => props.appointment,
  (newVal) => {
    if (newVal) {
      formData.value = {
        appointmentDate: newVal.appointmentDate,
        timeSlot: newVal.timeSlot,
        doctorId: null
      }

      // 加载医院医生列表
      if (newVal.hospitalId) {
        loadHospitalDoctors(newVal.hospitalId)
      }
    }
  },
  { immediate: true }
)

// 表单配置
const formSchema = computed<FormSchema[]>(() => [
  {
    field: 'hospitalInfo',
    label: '预约医院',
    component: 'Input',
    componentProps: {
      disabled: true,
      placeholder: ''
    },
    colProps: { span: 24 }
  },
  {
    field: 'petInfo',
    label: '宠物信息',
    component: 'Input',
    componentProps: {
      disabled: true,
      placeholder: ''
    },
    colProps: { span: 24 }
  },
  {
    field: 'ownerInfo',
    label: '主人信息',
    component: 'Input',
    componentProps: {
      disabled: true,
      placeholder: ''
    },
    colProps: { span: 24 }
  },
  {
    field: 'type',
    label: '预约类型',
    component: 'Input',
    componentProps: {
      disabled: true
    },
    colProps: { span: 24 }
  },
  {
    field: 'doctorId',
    label: '选择医生',
    component: 'Select',
    componentProps: {
      options: (doctorList.value || []).map((doctor) => ({
        label: `${doctor.name}${doctor.phone ? ` - ${doctor.phone}` : ''}`,
        value: doctor.id
      })),
      placeholder: '请选择医生',
      loading: loadingDoctor.value
    },
    formItemProps: {
      rules: [{ required: true, message: '请选择医生', trigger: 'change' }]
    },
    colProps: { span: 24 }
  },
  {
    field: 'appointmentDate',
    label: '预约日期',
    component: 'DatePicker',
    componentProps: {
      type: 'date',
      placeholder: '请选择预约日期',
      valueFormat: 'YYYY-MM-DD',
      style: { width: '100%' }
    },
    formItemProps: {
      rules: [{ required: true, message: '请选择预约日期', trigger: 'change' }]
    },
    colProps: { span: 24 }
  },
  {
    field: 'timeSlot',
    label: '时间段',
    component: 'Select',
    componentProps: {
      options: [
        { label: '09:00-10:00', value: '09:00-10:00' },
        { label: '10:00-11:00', value: '10:00-11:00' },
        { label: '11:00-12:00', value: '11:00-12:00' },
        { label: '13:00-14:00', value: '13:00-14:00' },
        { label: '14:00-15:00', value: '14:00-15:00' },
        { label: '15:00-16:00', value: '15:00-16:00' },
        { label: '16:00-17:00', value: '16:00-17:00' },
        { label: '17:00-18:00', value: '17:00-18:00' }
      ],
      placeholder: '请选择时间段'
    },
    formItemProps: {
      rules: [{ required: true, message: '请选择时间段', trigger: 'change' }]
    },
    colProps: { span: 24 }
  }
])

// 初始化表单值
watch(
  () => props.appointment,
  (newVal) => {
    if (newVal) {
      setTimeout(() => {
        setValues({
          hospitalInfo: newVal.hospital?.name || '未知',
          petInfo: `${newVal.pet?.name}（${newVal.pet?.category?.name}）`,
          ownerInfo: `${newVal.user?.username} - ${newVal.user?.phone}`,
          type: HealthAppointmentTypeLabel[newVal.type],
          doctorId: null, // 医生需要重新选择
          appointmentDate: newVal.appointmentDate,
          timeSlot: newVal.timeSlot
        })
      }, 100)
    }
  },
  { immediate: true }
)

/**
 * 获取表单数据（包装方法，先验证再返回数据）
 */
const getFormData = async () => {
  const elForm = await getElFormExpose()
  const valid = await elForm?.validate()
  if (!valid) return null

  // 调用 formMethods 的 getFormData 方法获取实际数据
  return await formMethods.getFormData()
}

// 暴露方法给父组件
defineExpose({
  getFormData
})
</script>

<template>
  <Form :schema="formSchema" @register="formRegister" label-width="100px" />
</template>
