<script setup lang="ts">
import { Form, FormSchema } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import { PropType, watch, reactive } from 'vue'
import type { FormRules } from 'element-plus'
import type { User, CreateUserRequest, UpdateUserRequest } from '@/api-new/users'
import { useValidator } from '@/hooks/web/useValidator'

const { required } = useValidator()

const props = defineProps({
  currentRow: {
    type: Object as PropType<User | null>,
    default: () => null
  },
  formSchema: {
    type: Array as PropType<FormSchema[]>,
    default: () => []
  }
})

const emit = defineEmits<{
  submit: [data: CreateUserRequest | UpdateUserRequest]
}>()

// 表单验证规则
const rules: FormRules = reactive({
  phone: [required()],
  password: []
  // role 已固定为 USER，不需要验证
})

// 监听是否为编辑模式，动态更新密码验证规则
watch(
  () => props.currentRow?.id,
  (isEdit) => {
    if (isEdit) {
      rules.password = []
    } else {
      rules.password = [required()]
    }
  },
  { immediate: true }
)

const { formRegister, formMethods } = useForm()
const { setValues, getFormData, getElFormExpose } = formMethods

// 提交表单
const submit = async () => {
  const elForm = await getElFormExpose()
  const valid = await elForm?.validate().catch((err) => {
    console.log(err)
  })
  if (valid) {
    const formData = await getFormData()
    emit('submit', formData)
  }
}

// 监听当前行数据变化，自动填充表单
watch(
  () => props.currentRow,
  (currentRow) => {
    if (!currentRow) return
    setValues(currentRow)
  },
  {
    deep: true,
    immediate: true
  }
)

defineExpose({
  submit
})
</script>

<template>
  <div class="user-form-dialog">
    <Form :rules="rules" @register="formRegister" :schema="formSchema" />
  </div>
</template>

<style scoped lang="scss">
.user-form-dialog {
  padding: 0;
}

// 优化表单项间距
:deep(.el-form-item) {
  margin-bottom: 18px;
}
</style>
