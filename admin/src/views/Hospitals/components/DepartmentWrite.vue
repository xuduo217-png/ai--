<script setup lang="tsx">
import { watch, reactive } from 'vue'
import { Form, FormSchema } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import { PropType } from 'vue'
import { useValidator } from '@/hooks/web/useValidator'
import { Department } from '@/api-new/departments'

const { required } = useValidator()

const props = defineProps({
  currentRow: {
    type: Object as PropType<Department | null>,
    default: () => null
  },
  formSchema: {
    type: Array as PropType<FormSchema[]>,
    default: () => []
  },
  hospitalId: {
    type: Number,
    required: true
  }
})

// 表单验证规则
const rules = reactive({
  name: [required()]
})

const { formRegister, formMethods } = useForm()
const { setValues, getFormData, getElFormExpose } = formMethods

/**
 * 设置表单字段值
 */
const setFieldValue = (field: string, value: any) => {
  setValues({ [field]: value })
}

// 监听 currentRow 变化
watch(
  () => props.currentRow,
  (currentRow) => {
    if (!currentRow) {
      // 新增模式，重置数据
      return
    }

    // 编辑模式，填充数据
    setValues(currentRow)
  },
  {
    deep: true,
    immediate: true
  }
)

/**
 * 提交表单
 */
const submit = async () => {
  const elForm = await getElFormExpose()
  const valid = await elForm?.validate()
  if (!valid) return null

  const formData = await getFormData()

  // 只提取允许提交的字段，排除 id、createdAt、updatedAt 等系统字段
  const { id, createdAt, updatedAt, ...allowedFields } = formData as any

  // 确保包含医院ID
  return {
    ...allowedFields,
    hospitalId: props.hospitalId
  }
}

// 暴露方法给父组件
defineExpose({
  submit,
  setFieldValue
})
</script>

<template>
  <Form :schema="formSchema" :rules="rules" @register="formRegister" />
</template>
