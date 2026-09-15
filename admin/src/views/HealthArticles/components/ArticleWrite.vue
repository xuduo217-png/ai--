<script setup lang="tsx">
import { watch, reactive } from 'vue'
import { Form } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import { useValidator } from '@/hooks/web/useValidator'
import { PropType } from 'vue'
import type { HealthArticle } from '@/api-new/health-articles'
import { getImageUrl } from '@/utils/image'

const { required } = useValidator()

const props = defineProps({
  currentRow: {
    type: Object as PropType<HealthArticle | null>,
    default: () => null
  },
  formSchema: {
    type: Array as PropType<any[]>,
    default: () => []
  }
})

// 表单验证规则
const rules = reactive({
  title: [required({ message: '请输入文章标题', trigger: 'blur' })],
  summary: [required({ message: '请输入文章摘要', trigger: 'blur' })],
  categoryId: [required({ message: '请选择分类', trigger: 'change' })],
  status: [required({ message: '请选择状态', trigger: 'change' })],
  content: [required({ message: '请输入文章内容', trigger: 'blur' })]
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
        status: 'DRAFT'
      })
      return
    }

    // 编辑模式，填充数据
    // 使用 getImageUrl 统一处理 coverImage URL
    const displayData = {
      ...currentRow,
      coverImage: getImageUrl(currentRow.coverImage)
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

  // 处理 coverImage 字段：将完整 URL 转换为相对路径
  let coverImageUrl = formData.coverImage
  if (coverImageUrl && coverImageUrl.startsWith('http')) {
    try {
      const urlObj = new URL(coverImageUrl)
      coverImageUrl = urlObj.pathname
    } catch (e) {
      // 如果 URL 解析失败，保持原样
      console.warn('URL 解析失败:', coverImageUrl)
    }
  }

  // 构建提交数据
  const submitData: any = {
    title: formData.title,
    summary: formData.summary,
    content: formData.content,
    coverImage: coverImageUrl,
    categoryId: formData.categoryId,
    status: formData.status
  }

  return submitData
}

defineExpose({
  submit
})
</script>

<template>
  <div class="article-form">
    <Form :rules="rules" @register="formRegister" :schema="formSchema" />
  </div>
</template>

<style scoped lang="scss">
.article-form {
  padding: 0;
}

// 优化表单项间距
:deep(.el-form-item) {
  margin-bottom: 18px;
}
</style>
