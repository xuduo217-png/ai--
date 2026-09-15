<script setup lang="tsx">
import { ref, onMounted, reactive, computed, nextTick, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { Form } from '@/components/Form'
import type { FormSchema } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import { useValidator } from '@/hooks/web/useValidator'
import { ElMessage } from 'element-plus'
import { Loading } from '@element-plus/icons-vue'
import { BaseButton } from '@/components/Button'
import { ContentWrap } from '@/components/ContentWrap'
import { getAllHealthCategoriesApi, getArticleDetailApi } from '@/api-new/health-articles'
import type { HealthCategory } from '@/api-new/health-articles'
import { getImageUrl } from '@/utils/image'
import { extractPagedTableData } from '@/utils/pagination'

defineOptions({
  name: 'HealthArticleCreate'
})

const { required } = useValidator()
const router = useRouter()
const route = useRoute()

// 获取路由参数中的文章 ID
const articleId = computed(() => route.query.id as string | undefined)
const isEditMode = computed(() => !!articleId.value)
const pageTitle = computed(() => (isEditMode.value ? '编辑文章' : '新建文章'))

// 表单配置
const formSchema = ref<FormSchema[]>([])

// 获取分类列表
const categoryOptions = ref<any[]>([])
const loadCategories = async () => {
  try {
    const res = await getAllHealthCategoriesApi({
      page: 1,
      pageSize: 100
    })
    const { list: categories } = extractPagedTableData<HealthCategory>(res)
    categoryOptions.value = categories
      .filter((item: HealthCategory) => item.isActive)
      .map((item: HealthCategory) => ({
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
      label: '文章标题',
      component: 'Input',
      componentProps: {
        placeholder: '请输入文章标题'
      },
      colProps: {
        span: 24
      }
    },
    {
      field: 'summary',
      label: '文章摘要',
      component: 'Input',
      componentProps: {
        type: 'textarea',
        rows: 3,
        placeholder: '请输入文章摘要（用于列表展示）'
      },
      colProps: {
        span: 24
      }
    },
    {
      field: 'coverImage',
      label: '封面图片',
      component: 'ImageUpload',
      componentProps: {
        placeholder: '点击上传封面图片',
        aspectRatio: 16 / 9,
        cropBoxWidth: 640,
        cropBoxHeight: 360,
        category: 'health-article-cover',
        circle: false,
        previewWidth: 300,
        previewHeight: 169
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
      }
    },
    {
      field: 'status',
      label: '文章状态',
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
      }
    },
    {
      field: 'content',
      label: '文章内容',
      component: 'Editor',
      componentProps: {
        placeholder: '请输入文章内容'
      },
      colProps: {
        span: 24
      }
    }
  ]

  // 如果是编辑模式，加载文章详情
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
  title: [required({ message: '请输入文章标题', trigger: 'blur' })],
  summary: [required({ message: '请输入文章摘要', trigger: 'blur' })],
  categoryId: [required({ message: '请选择分类', trigger: 'change' })],
  status: [required({ message: '请选择状态', trigger: 'change' })],
  content: [required({ message: '请输入文章内容', trigger: 'blur' })]
})

const { formRegister, formMethods } = useForm()
const { setValues, getFormData, getElFormExpose } = formMethods

// 加载文章详情（编辑模式）
const loading = ref(false)
const articleData = ref<any>(null) // 保存文章数据

const loadArticleDetail = async () => {
  if (!isEditMode.value) return

  try {
    loading.value = true
    const res = await getArticleDetailApi(Number(articleId.value))
    articleData.value = res.data
    console.log('加载到的文章数据:', articleData.value)
    loading.value = false
  } catch (error) {
    console.error('加载文章详情失败', error)
    ElMessage.error('加载文章详情失败')
    router.push('/health-articles/list')
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
      // 使用 getImageUrl 统一处理封面图片 URL
      const coverImageUrl = getImageUrl(newData.coverImage)

      console.log('处理后的封面图片 URL:', coverImageUrl)

      await setValues({
        title: newData.title,
        summary: newData.summary,
        content: newData.content,
        coverImage: coverImageUrl,
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

  // 处理封面图片 URL
  let coverImageUrl = formData.coverImage
  if (coverImageUrl && coverImageUrl.startsWith('http')) {
    try {
      const urlObj = new URL(coverImageUrl)
      coverImageUrl = urlObj.pathname
    } catch (e) {
      console.warn('URL 解析失败:', coverImageUrl)
    }
  }

  // 构建提交数据
  const submitData = {
    title: formData.title,
    summary: formData.summary,
    content: formData.content,
    coverImage: coverImageUrl,
    categoryId: formData.categoryId,
    status: formData.status
  }

  try {
    const { createArticleApi, updateArticleApi } = await import('@/api-new/health-articles')

    if (isEditMode.value) {
      // 编辑模式：调用更新接口
      await updateArticleApi(Number(articleId.value), submitData)
      ElMessage.success('文章更新成功')
    } else {
      // 新增模式：调用创建接口
      await createArticleApi(submitData)
      ElMessage.success('文章创建成功')
    }

    router.push('/health-articles/list')
  } catch (error) {
    console.error(isEditMode.value ? '更新失败' : '创建失败', error)
    ElMessage.error(isEditMode.value ? '更新失败' : '创建失败')
  }
}

// 返回列表
const handleBack = () => {
  router.push('/health-articles/list')
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
          {{ isEditMode ? '更新文章' : '保存文章' }}
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
