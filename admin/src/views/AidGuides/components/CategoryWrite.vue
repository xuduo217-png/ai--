<script setup lang="tsx">
import { watch, reactive } from 'vue'
import { Form } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import { PropType } from 'vue'
import { useValidator } from '@/hooks/web/useValidator'
import type { AidCategory } from '@/api-new/aid-guides'
import { getImageUrl } from '@/utils/image'

const { required } = useValidator()

const props = defineProps({
  currentRow: {
    type: Object as PropType<AidCategory | null>,
    default: () => null
  },
  formSchema: {
    type: Array as PropType<any[]>,
    default: () => []
  }
})

// 表单验证规则
const rules = reactive({
  name: [required({ message: '请输入分类名称', trigger: 'blur' })]
})

const { formRegister, formMethods } = useForm()
const { setValues, getFormData, getElFormExpose } = formMethods

// 监听 currentRow 变化
watch(
  () => props.currentRow,
  (currentRow) => {
    if (!currentRow) {
      // 新增模式，设置默认值
      setValues({
        isActive: true,
        sortOrder: 0
      })
      return
    }

    // 编辑模式，填充数据
    // 使用 getImageUrl 统一处理 icon URL
    const displayData = {
      ...currentRow,
      icon: getImageUrl(currentRow.icon)
    }

    setValues(displayData)
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
  const valid = await elForm?.validate().catch((err: any) => {
    console.log(err)
  })

  if (!valid) {
    throw new Error('表单验证失败')
  }

  const formData = await getFormData()

  // 处理 icon 字段：将完整 URL 转换为相对路径
  let iconUrl = formData.icon
  if (iconUrl && iconUrl.startsWith('http')) {
    try {
      const urlObj = new URL(iconUrl)
      iconUrl = urlObj.pathname
    } catch (e) {
      // 如果 URL 解析失败，保持原样
      console.warn('URL 解析失败:', iconUrl)
    }
  }

  // 构建提交数据
  const submitData: any = {
    name: formData.name,
    icon: iconUrl,
    sortOrder: formData.sortOrder,
    isActive: formData.isActive
  }

  return submitData
}

defineExpose({
  submit
})
</script>

<template>
  <div class="category-form">
    <Form :rules="rules" @register="formRegister" :schema="formSchema" />
  </div>
</template>

<style scoped lang="scss">
.category-form {
  padding: 0;
}

// 优化表单项间距
:deep(.el-form-item) {
  margin-bottom: 18px;
}
</style>
