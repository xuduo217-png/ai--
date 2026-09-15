<script setup lang="ts">
import { watch } from 'vue'
import { Form, FormSchema } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import type { HealthAppointment } from '@/api-new/health-appointments'
import { HealthAppointmentTypeLabel } from '@/api-new/health-appointments'

interface Props {
  appointment: HealthAppointment | null
}

const props = defineProps<Props>()

// 表单方法
const { formRegister, formMethods } = useForm()
const { setValues, getElFormExpose } = formMethods

// 表单配置
const formSchema: FormSchema[] = [
  {
    field: 'petName',
    label: '宠物名称',
    component: 'Input',
    componentProps: {
      disabled: true
    },
    colProps: { span: 12 }
  },
  {
    field: 'type',
    label: '预约类型',
    component: 'Input',
    componentProps: {
      disabled: true
    },
    colProps: { span: 12 }
  },
  {
    field: 'appointmentDate',
    label: '本次预约日期',
    component: 'Input',
    componentProps: {
      disabled: true
    },
    colProps: { span: 12 }
  },
  {
    field: 'timeSlot',
    label: '时间段',
    component: 'Input',
    componentProps: {
      disabled: true
    },
    colProps: { span: 12 }
  },
  {
    field: 'nextAppointmentDate',
    label: '下次预约日期',
    component: 'DatePicker',
    componentProps: {
      type: 'date',
      placeholder: '请选择下次预约日期',
      valueFormat: 'YYYY-MM-DD',
      style: { width: '100%' },
      clearable: true
    },
    formItemProps: {
      rules: [{ required: true, message: '请选择下次预约日期', trigger: 'change' }]
    },
    colProps: { span: 24 }
  },
  {
    field: 'operationContent',
    label: '本次操作内容',
    component: 'Input',
    componentProps: {
      type: 'textarea',
      rows: 3,
      placeholder: '请输入本次操作内容（如：接种疫苗、驱虫处理、体检项目等）'
    },
    colProps: { span: 24 }
  },
  {
    field: 'detailContent',
    label: '详情内容',
    component: 'Editor',
    componentProps: {
      placeholder: '请输入详情内容（支持富文本格式）'
    },
    colProps: { span: 24 }
  },
  {
    field: 'notes',
    label: '备注',
    component: 'Input',
    componentProps: {
      type: 'textarea',
      rows: 2,
      placeholder: '请输入备注（可选）'
    },
    colProps: { span: 24 }
  }
]

// 监听 appointment 变化，设置表单值
watch(
  () => props.appointment,
  (newVal) => {
    if (newVal) {
      setTimeout(() => {
        setValues({
          petName: newVal.pet?.name || '',
          type: HealthAppointmentTypeLabel[newVal.type],
          appointmentDate: newVal.appointmentDate,
          timeSlot: newVal.timeSlot,
          nextAppointmentDate: '',
          operationContent: newVal.operationContent || '',
          detailContent: newVal.detailContent || '',
          notes: newVal.notes || ''
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
  const data = await formMethods.getFormData()
  // 返回所有需要的字段
  return {
    nextAppointmentDate: data.nextAppointmentDate,
    operationContent: data.operationContent,
    detailContent: data.detailContent,
    notes: data.notes
  }
}

// 暴露方法给父组件
defineExpose({
  getFormData
})
</script>

<template>
  <Form :schema="formSchema" @register="formRegister" label-width="120px" />
</template>
