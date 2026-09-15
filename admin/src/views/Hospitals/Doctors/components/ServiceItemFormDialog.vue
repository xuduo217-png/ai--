<script setup lang="ts">
import { watch, computed } from 'vue'
import { Form, FormSchema } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import { useValidator } from '@/hooks/web/useValidator'
import type {
  DoctorServiceItem,
  CreateServiceItemParams,
  UpdateServiceItemParams
} from '@/api-new/doctors'

const props = defineProps<{
  currentItem: DoctorServiceItem | null
  mode: 'create' | 'update'
}>()

const emit = defineEmits<{
  submit: [data: CreateServiceItemParams | UpdateServiceItemParams]
  cancel: []
}>()

const { required } = useValidator()

// 表单 Schema
const formSchema = computed<FormSchema[]>(() => [
  {
    field: 'name',
    label: '服务名称',
    component: 'Input',
    componentProps: {
      placeholder: '请输入服务名称（如：图文咨询）'
    },
    formItemProps: {
      required: true
    },
    colProps: { span: 24 }
  },
  {
    field: 'duration',
    label: '服务时长（分钟）',
    component: 'InputNumber',
    componentProps: {
      placeholder: '请输入服务时长',
      min: 1,
      max: 1440
    },
    formItemProps: {
      required: true
    },
    colProps: { span: 12 }
  },
  {
    field: 'price',
    label: '服务价格（元）',
    component: 'InputNumber',
    componentProps: {
      placeholder: '请输入服务价格',
      min: 0,
      precision: 2,
      step: 10
    },
    formItemProps: {
      required: true
    },
    colProps: { span: 12 }
  },
  {
    field: 'description',
    label: '服务描述',
    component: 'Input',
    componentProps: {
      type: 'textarea',
      rows: 3,
      placeholder: '请输入服务描述（可选）'
    },
    colProps: { span: 24 }
  },
  {
    field: 'isActive',
    label: '是否启用',
    component: 'Switch',
    componentProps: {
      activeText: '启用',
      inactiveText: '禁用'
    },
    value: true,
    colProps: { span: 24 }
  }
])

// 验证规则
const rules = computed(() => ({
  name: [required()],
  duration: [required()],
  price: [required()]
}))

const { formRegister, formMethods } = useForm()
const { setValues, getFormData, getElFormExpose } = formMethods

/**
 * 提交表单
 */
const submit = async () => {
  const elForm = await getElFormExpose()
  const valid = await elForm?.validate().catch((err) => {
    console.log(err)
  })
  if (valid) {
    const formData = await getFormData()

    // 清理数据，只保留需要的字段，并确保类型正确
    const cleanedData: CreateServiceItemParams | UpdateServiceItemParams = {
      name: formData.name,
      duration: Number(formData.duration),
      price: Number(formData.price),
      description: formData.description || undefined,
      isActive: formData.isActive ?? true
    }

    emit('submit', cleanedData)
  }
}

// 监听当前项变化，自动填充表单
watch(
  () => props.currentItem,
  (currentItem) => {
    if (currentItem && props.mode === 'update') {
      setValues(currentItem)
    } else {
      setValues({
        name: '',
        duration: 30,
        price: 0,
        description: '',
        isActive: true
      })
    }
  },
  {
    immediate: true
  }
)

defineExpose({
  submit
})
</script>

<template>
  <Form :rules="rules" @register="formRegister" :schema="formSchema" />
</template>
