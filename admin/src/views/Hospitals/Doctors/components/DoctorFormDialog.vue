<script setup lang="ts">
import { Form, FormSchema } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import { PropType, watch, computed, ref } from 'vue'
import type {
  Doctor,
  CreateDoctorParams,
  UpdateDoctorParams,
  CreateServiceItemParams
} from '@/api-new/doctors'
import { useValidator } from '@/hooks/web/useValidator'
import ServiceItemsInput from './ServiceItemsInput.vue'

const { required } = useValidator()

const props = defineProps({
  currentRow: {
    type: Object as PropType<Doctor | null>,
    default: () => null
  },
  formSchema: {
    type: Array as PropType<FormSchema[]>,
    default: () => []
  }
})

const emit = defineEmits<{
  submit: [data: CreateDoctorParams | UpdateDoctorParams]
}>()

// 是否为编辑模式
const isEdit = computed(() => !!props.currentRow?.id)

// 收费项数据（仅新建时使用）
const serviceItems = ref<CreateServiceItemParams[]>([])

// 表单验证规则
const rules = computed(() => ({
  username: [required()],
  password: isEdit.value ? [] : [required()],
  phone: [required()],
  name: [required()],
  specialty: [required()],
  hospitalId: [required()],
  departmentId: [required()]
}))

const { formRegister, formMethods } = useForm()
const { setValues, getFormData, getElFormExpose } = formMethods

/**
 * 设置表单字段值
 * 用于父组件更新特定字段
 */
const setFieldValue = (field: string, value: any) => {
  setValues({ [field]: value })
}

// 提交表单
const submit = async () => {
  const elForm = await getElFormExpose()
  const valid = await elForm?.validate().catch((err) => {
    console.log(err)
  })
  if (valid) {
    const formData = await getFormData()

    // 如果是新建模式，添加收费项数据
    if (!isEdit.value) {
      ;(formData as any).serviceItems = serviceItems.value
    }

    emit('submit', formData)
  }
}

// 监听当前行数据变化，自动填充表单
watch(
  () => props.currentRow,
  (currentRow) => {
    if (!currentRow) {
      // 新建模式时，重置收费项
      serviceItems.value = [{ name: '', duration: 30, price: 0, isActive: true }]
    } else {
      setValues(currentRow)
    }
  },
  {
    deep: true,
    immediate: true
  }
)

defineExpose({
  submit,
  setFieldValue
})
</script>

<template>
  <Form :rules="rules" @register="formRegister" :schema="formSchema" />

  <!-- 收费项配置（仅新建时显示） -->
  <div v-if="!isEdit" class="mt-20px">
    <div class="font-semibold mb-10px">收费项配置（必填）</div>
    <ServiceItemsInput v-model="serviceItems" />
  </div>
</template>

<style scoped lang="less">
.mt-20px {
  margin-top: 20px;
}

.mb-10px {
  margin-bottom: 10px;
}

.font-semibold {
  font-weight: 600;
}
</style>
