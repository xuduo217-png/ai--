<script setup lang="tsx">
import { ref, onMounted, reactive, computed, nextTick, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { Form } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import { useValidator } from '@/hooks/web/useValidator'
import { ElMessage } from 'element-plus'
import { Loading } from '@element-plus/icons-vue'
import { BaseButton } from '@/components/Button'
import { ContentWrap } from '@/components/ContentWrap'
import { getAidGuideCategoryListApi, getGuideDetailApi } from '@/api-new/aid-guides'
import type { AidCategory } from '@/api-new/aid-guides'
import { extractUploadPath, getImageUrl } from '@/utils/image'
import type { FormSchema } from '@/components/Form'

defineOptions({
  name: 'AidGuideCreate'
})

const { required } = useValidator()
const router = useRouter()
const route = useRoute()

// 获取路由参数中的指南 ID
const articleId = computed(() => route.query.id as string | undefined)
const isEditMode = computed(() => !!articleId.value)
const pageTitle = computed(() => (isEditMode.value ? '编辑指南' : '新建指南'))

// 表单配置
const formSchema = ref<FormSchema[]>([])

// 获取分类列表
const categoryOptions = ref<{ label: string; value: number }[]>([])
const loadCategories = async () => {
  try {
    const res = await getAidGuideCategoryListApi({
      page: 1,
      pageSize: 100
    })
    categoryOptions.value = (res.data || [])
      .filter((item: AidCategory) => item.isActive)
      .map((item: AidCategory) => ({
        label: item.name,
        value: item.id
      }))
  } catch (error) {
    console.error('获取分类列表失败', error)
  }
}

onMounted(async () => {
  await loadCategories()

  // 初始化表单配置
  formSchema.value = [
    {
      field: 'title',
      label: '指南标题',
      component: 'Input',
      componentProps: {
        placeholder: '请输入指南标题'
      },
      colProps: {
        span: 24
      },
      formItemProps: {
        rules: [{ required: true, message: '请输入指南标题' }]
      }
    },
    // {
    //   field: 'summary',
    //   label: '指南摘要',
    //   component: 'Input',
    //   componentProps: {
    //     type: 'textarea',
    //     rows: 3,
    //     placeholder: '请输入指南摘要（用于列表展示）'
    //   },
    //   colProps: {
    //     span: 24
    //   },
    //   rules: [{ required: true, message: '请输入指南摘要' }]
    // },
    {
      field: 'icon',
      label: '指南图标',
      component: 'ImageUpload',
      componentProps: {
        placeholder: '点击上传指南图标',
        aspectRatio: 1,
        cropBoxWidth: 200,
        cropBoxHeight: 200,
        category: 'aid-guide-icon',
        circle: false,
        previewWidth: 120,
        previewHeight: 120
      },
      colProps: {
        span: 24
      }
    },
    {
      field: 'categoryId',
      label: '所属分类',
      component: 'Select',
      componentProps: {
        options: categoryOptions,
        placeholder: '请选择分类'
      },
      colProps: {
        span: 12
      },
      formItemProps: {
        rules: [{ required: true, message: '请选择分类' }]
      }
    },
    {
      field: 'status',
      label: '指南状态',
      component: 'Select',
      componentProps: {
        options: [
          { label: '草稿', value: 'DRAFT' },
          { label: '已发布', value: 'PUBLISHED' }
        ],
        placeholder: '请选择状态'
      },
      colProps: {
        span: 12
      },
      formItemProps: {
        rules: [{ required: true, message: '请选择状态' }]
      }
    },
    {
      field: 'content',
      label: '指南内容',
      component: 'Editor',
      componentProps: {
        placeholder: '请输入指南内容'
      },
      colProps: {
        span: 24
      },
      formItemProps: {
        rules: [{ required: true, message: '请输入指南内容' }]
      }
    }
  ]

  // 如果是编辑模式，加载指南详情
  if (isEditMode.value) {
    await loadArticleDetail()
  } else {
    // 新增模式下设置默认值
    await nextTick()
    setValues({
      status: 'DRAFT'
    })
  }
})

// 表单验证规则
const rules = reactive({
  title: [required({ message: '请输入指南标题', trigger: 'blur' })],
  categoryId: [required({ message: '请选择分类', trigger: 'change' })],
  status: [required({ message: '请选择状态', trigger: 'change' })],
  content: [required({ message: '请输入指南内容', trigger: 'blur' })]
})

const { formRegister, formMethods } = useForm()
const { setValues, getFormData, getElFormExpose } = formMethods

// 加载指南详情（编辑模式）
const loading = ref(false)
const articleData = ref<any>(null) // 保存指南数据

const loadArticleDetail = async () => {
  if (!isEditMode.value) return

  try {
    loading.value = true
    const res = await getGuideDetailApi(Number(articleId.value))
    articleData.value = res.data
    console.log('加载到的指南数据:', articleData.value)
    loading.value = false
  } catch (error) {
    console.error('加载指南详情失败', error)
    ElMessage.error('加载指南详情失败')
    router.push('/aid-guides/list')
    loading.value = false
  }
}

// 监听 articleData，当数据加载完成后设置到表单
watch(
  articleData,
  async (newData) => {
    if (!newData) return

    console.log('watch 触发，准备设置表单数据...')

    // 等待表单完全渲染
    await nextTick()
    await nextTick()

    try {
      // 使用 getImageUrl 统一处理指南图标 URL，便于上传组件正确预览。
      const iconUrl = getImageUrl(newData.icon)

      console.log('处理后的指南图标 URL:', iconUrl)

      await setValues({
        title: newData.title,
        summary: newData.summary,
        content: newData.content,
        icon: iconUrl,
        categoryId: newData.categoryId,
        status: newData.status
      })

      console.log('表单数据已设置')

      // 验证
      const formData = await getFormData()
      console.log('当前表单值:', formData)
    } catch (error) {
      console.error('设置表单数据失败:', error)
    }
  },
  { immediate: false }
)

// 提交表单
const handleSubmit = async () => {
  const elForm = await getElFormExpose()
  const valid = await elForm?.validate().catch((err: any) => {
    console.log(err)
  })

  if (!valid) {
    return
  }

  const formData = await getFormData()

  // 处理图标 URL：上传组件预览使用完整地址，提交时收敛为 /uploads 相对路径。
  const iconUrl = extractUploadPath(formData.icon)

  // 构建提交数据（只提交后端 DTO 支持的字段）
  const submitData = {
    title: formData.title,
    icon: iconUrl,
    content: formData.content,
    categoryId: formData.categoryId,
    status: formData.status,
    sortOrder: formData.sortOrder || 0
  }

  try {
    const { createGuideApi, updateGuideApi } = await import('@/api-new/aid-guides')

    if (isEditMode.value) {
      // 编辑模式：调用更新接口
      await updateGuideApi(Number(articleId.value), submitData)
      ElMessage.success('指南更新成功')
    } else {
      // 新增模式：调用创建接口
      await createGuideApi(submitData)
      ElMessage.success('指南创建成功')
    }

    router.push('/aid-guides/list')
  } catch (error) {
    console.error(isEditMode.value ? '更新失败' : '创建失败', error)
    ElMessage.error(isEditMode.value ? '更新失败' : '创建失败')
  }
}

// 返回列表
const handleBack = () => {
  router.push('/aid-guides/list')
}
</script>

<template>
  <ContentWrap>
    <div class="article-create-page">
      <div class="page-header">
        <h2 class="page-title">{{ pageTitle }}</h2>
      </div>

      <div v-if="loading" class="loading-container">
        <Loading class="is-loading" />
        <span>加载中...</span>
      </div>

      <div v-else class="form-container">
        <Form :rules="rules" :schema="formSchema" @register="formRegister" />
      </div>

      <div class="form-actions">
        <BaseButton @click="handleBack"> 返回列表 </BaseButton>
        <BaseButton type="primary" @click="handleSubmit">
          {{ isEditMode ? '更新指南' : '保存指南' }}
        </BaseButton>
      </div>
    </div>
  </ContentWrap>
</template>

<style scoped lang="scss">
.article-create-page {
  padding: 20px;
}

.page-header {
  margin-bottom: 24px;
  padding-bottom: 16px;
  border-bottom: 1px solid var(--el-border-color);
}

.page-title {
  font-size: 20px;
  font-weight: 600;
  color: var(--el-text-color-primary);
  margin: 0;
}

.loading-container {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  padding: 60px 24px;
  background: var(--el-bg-color);
  border-radius: 4px;
  margin-bottom: 24px;
  color: var(--el-text-color-secondary);
  font-size: 14px;
}

.form-container {
  background: var(--el-bg-color);
  padding: 24px;
  border-radius: 4px;
  margin-bottom: 24px;
}

.form-actions {
  display: flex;
  justify-content: center;
  gap: 12px;
  padding: 24px;
  background: var(--el-bg-color);
  border-radius: 4px;
}
</style>
