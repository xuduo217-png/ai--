<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { ElMessage, ElTag, ElInput } from 'element-plus'
import { ref, onMounted, computed, nextTick } from 'vue'
import { BaseButton } from '@/components/Button'
import { useRouter, useRoute } from 'vue-router'
import { ImageUpload } from '@/components/ImageUpload'
import { Form, FormSchema } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import { VueDraggable } from 'vue-draggable-plus'
import {
  getSelfCheckListDetailApi,
  getSelfCheckQuestionsApi,
  createQuestionApi,
  updateQuestionApi,
  reorderQuestionOptionsApi,
  type SelfCheckList,
  type QuestionType
} from '@/api-new/ai-self-check'

defineOptions({
  name: 'SelfCheckQuestionEdit'
})

const router = useRouter()
const route = useRoute()

const listId = ref<number>(Number(route.params.id))
const questionId = ref<number>(Number(route.params.questionId))
const isEdit = computed(() => !!questionId.value)

const listDetail = ref<SelfCheckList | null>(null)
const loading = ref(false)
const saveLoading = ref(false)
const questionType = ref<QuestionType>('SINGLE')
const editingOptions = ref<any[]>([])

type SelectableQuestionType = Exclude<QuestionType, 'TEXT'>

// Admin 端只允许维护选择题，TEXT 仅用于兼容历史数据展示。
const questionTypeOptions: Array<{ label: string; value: SelectableQuestionType }> = [
  { label: '单选', value: 'SINGLE' },
  { label: '多选', value: 'MULTIPLE' }
]

// 选项拖动排序状态
const isReorderingOptions = ref(false)
const originalOptions = ref<any[]>([])

const { formRegister, formMethods } = useForm()
const { setValues, getFormData, getElFormExpose } = formMethods

// 表单配置
const questionFormSchema: FormSchema[] = [
  {
    field: 'questionText',
    label: '问题描述',
    component: 'Input',
    componentProps: {
      type: 'textarea',
      rows: 4,
      placeholder: '请输入问题描述'
    },
    formItemProps: {
      rules: [{ required: true, message: '请输入问题描述', trigger: 'blur' }]
    },
    colProps: { span: 24 }
  },
  {
    field: 'questionType',
    label: '问题类型',
    component: 'Select',
    componentProps: {
      options: questionTypeOptions,
      onChange: (value: SelectableQuestionType) => {
        questionType.value = value
      }
    },
    formItemProps: {
      rules: [{ required: true, message: '请选择问题类型', trigger: 'change' }]
    },
    colProps: { span: 12 }
  },
  {
    field: 'required',
    label: '是否必填',
    component: 'Switch',
    componentProps: {
      activeText: '必填',
      inactiveText: '选填'
    },
    colProps: { span: 12 }
  }
]

// 加载数据
const loadListDetail = async () => {
  try {
    const res = await getSelfCheckListDetailApi(listId.value)
    listDetail.value = res.data
  } catch (error) {
    ElMessage.error('加载详情失败')
  }
}

const loadQuestionDetail = async () => {
  if (!isEdit.value) return

  loading.value = true
  try {
    const res = await getSelfCheckQuestionsApi(listId.value)
    const question = res.data.find((q) => q.id === questionId.value)

    if (question) {
      questionType.value = question.questionType
      editingOptions.value = (question.options || []).map((opt) => ({
        id: opt.id,
        optionText: opt.optionText,
        optionImage: opt.optionImage,
        sortOrder: opt.sortOrder
      }))

      await nextTick()
      setValues({
        questionText: question.questionText,
        questionType: question.questionType,
        required: question.required
      })
    } else {
      ElMessage.error('问题不存在')
      router.back()
    }
  } catch (error) {
    ElMessage.error('加载问题失败')
    router.back()
  } finally {
    loading.value = false
  }
}

// 添加选项
const handleAddOption = () => {
  editingOptions.value.push({
    optionText: '',
    optionImage: null,
    sortOrder: editingOptions.value.length
  })
}

// 删除选项
const handleDeleteOption = (index: number) => {
  editingOptions.value.splice(index, 1)
  editingOptions.value.forEach((opt, i) => {
    opt.sortOrder = i
  })
}

/**
 * 选项拖动结束处理
 */
const handleOptionDragEnd = async () => {
  // 只有一条数据时不需要排序
  if (editingOptions.value.length < 2) {
    return
  }

  // 防止重复请求
  if (isReorderingOptions.value) {
    return
  }

  isReorderingOptions.value = true
  // 保存原始数据用于错误恢复
  originalOptions.value = [...editingOptions.value]

  // 提取所有选项的 ID（已存在的选项）
  const optionIds = editingOptions.value.filter((opt) => opt.id).map((opt) => opt.id)

  if (optionIds.length > 0 && isEdit.value) {
    try {
      // 如果是编辑模式，调用 API 更新排序
      await reorderQuestionOptionsApi(questionId.value, optionIds)
      ElMessage.success('排序已保存')
    } catch (error) {
      // 恢复原始顺序
      editingOptions.value = [...originalOptions.value]
      ElMessage.error('排序保存失败，已恢复原序')
    }
  } else {
    // 新增模式，只更新前端显示
    ElMessage.success('排序已更新（保存时生效）')
  }

  // 重新分配 sortOrder
  editingOptions.value.forEach((opt, i) => {
    opt.sortOrder = i
  })

  isReorderingOptions.value = false
}

// 保存
const handleSubmit = async () => {
  try {
    saveLoading.value = true

    const elForm = await getElFormExpose()
    const valid = await elForm?.validate()
    if (!valid) {
      ElMessage.error('请检查表单数据')
      return
    }

    const formData = await getFormData()

    if (formData.questionType === 'TEXT') {
      ElMessage.error('Admin 端不再支持填空题，请改为单选或多选')
      return
    }

    if (editingOptions.value.length === 0) {
      ElMessage.error('选择题至少需要一个选项')
      return
    }

    // 准备提交数据，过滤掉选项的 id 字段（后端不允许提交 id）
    const submitData: any = {
      questionText: formData.questionText,
      questionType: formData.questionType,
      required: Boolean(formData.required),
      options: editingOptions.value.map(({ id, ...opt }) => opt)
    }

    if (isEdit.value) {
      await updateQuestionApi(questionId.value, submitData)
      ElMessage.success('更新成功')
    } else {
      submitData.listId = listId.value
      submitData.sortOrder = 0 // 新增时默认为 0，可以通过拖动调整
      await createQuestionApi(submitData)
      ElMessage.success('创建成功')
    }

    // 返回问题列表页面
    router.back()
  } catch (error) {
    ElMessage.error('操作失败')
  } finally {
    saveLoading.value = false
  }
}

// 取消
const handleCancel = () => {
  router.back()
}

// 初始化
onMounted(() => {
  loadListDetail()
  loadQuestionDetail()
})
</script>

<template>
  <ContentWrap>
    <div v-loading="loading" class="mb-4 flex justify-between items-center">
      <div class="flex items-center gap-2">
        <BaseButton @click="handleCancel">← 返回</BaseButton>
        <h3 class="text-lg font-semibold">
          {{ isEdit ? '编辑问题' : '新增问题' }}
        </h3>
        <ElTag v-if="listDetail" :type="listDetail.type === 'PUBLIC' ? 'success' : 'primary'">
          {{ listDetail.type === 'PUBLIC' ? '公共项' : listDetail.categoryName }}
        </ElTag>
        <span class="text-gray-500">- {{ listDetail?.title || '自查表' }}</span>
      </div>
      <BaseButton type="primary" :loading="saveLoading" @click="handleSubmit"> 保存 </BaseButton>
    </div>

    <div class="question-form-container">
      <Form :schema="questionFormSchema" @register="formRegister" label-width="120px" />

      <!-- 选项部分（仅选择题显示） -->
      <div v-if="questionType !== 'TEXT'" class="options-section">
        <div class="section-header">
          <h4>选项列表</h4>
          <BaseButton type="primary" size="small" @click="handleAddOption"> 添加选项 </BaseButton>
        </div>

        <div v-if="editingOptions.length === 0" class="empty-options">
          <p>暂无选项，点击"添加选项"添加</p>
        </div>

        <!-- 用 VueDraggable 包裹选项列表 -->
        <VueDraggable
          v-else
          v-model="editingOptions"
          @end="handleOptionDragEnd"
          :animation="300"
          handle=".option-drag-handle"
          :disabled="isReorderingOptions"
        >
          <div
            v-for="(option, index) in editingOptions"
            :key="option.id || index"
            class="option-item"
          >
            <div class="option-header">
              <!-- 添加拖动手柄 -->
              <span class="option-drag-handle"></span>
              <span class="option-number">选项 {{ index + 1 }}</span>
              <BaseButton type="danger" link @click="handleDeleteOption(index)"> 删除 </BaseButton>
            </div>
            <div class="option-content">
              <ElInput
                v-model="option.optionText"
                placeholder="请输入选项描述"
                class="option-input"
              />
              <ImageUpload
                v-model="option.optionImage"
                :aspect-ratio="Number.NaN"
                category="self-check-option"
                dialog-title="上传表现图片"
              />
            </div>
          </div>
        </VueDraggable>

        <div class="options-hint">
          <p>💡 提示：拖动左侧手柄可调整选项顺序</p>
        </div>
      </div>

      <!-- 填空题提示 -->
      <div v-else class="text-hint-section">
        <ElTag type="warning" size="large">填空题</ElTag>
        <p class="mt-2 text-gray-500 text-sm">用户需要填写文本回答，无需设置选项</p>
      </div>
    </div>
  </ContentWrap>
</template>

<style scoped lang="less">
.mb-4 {
  margin-bottom: 16px;
}

// 选项拖动手柄样式
.option-drag-handle {
  cursor: move;
  color: #c0c4cc;
  padding: 0 4px;
  margin-right: 8px;
  display: inline-flex;
  align-items: center;
  transition: color 0.3s;

  &:hover {
    color: #409eff;
  }

  &::before {
    content: '⋮⋮';
    font-size: 16px;
    letter-spacing: -2px;
  }
}

.question-form-container {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
}

.options-section {
  margin-top: 30px;
  padding-top: 20px;
  border-top: 1px solid #ebeef5;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;

  h4 {
    margin: 0;
    font-size: 16px;
    font-weight: 500;
  }
}

.empty-options {
  text-align: center;
  padding: 40px 0;
  color: #909399;
  font-size: 14px;
  background: #f5f7fa;
  border-radius: 6px;
}

.options-list {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.option-item {
  border: 1px solid #ebeef5;
  border-radius: 6px;
  padding: 16px;
  background: #fff;
  transition: all 0.3s;

  &:hover {
    border-color: #c0c4cc;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  }

  // 拖动中的样式
  &.sortable-ghost {
    opacity: 0.5;
    background: #f5f7fa;
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
  }

  .option-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 12px;
    font-size: 14px;
    font-weight: 500;

    .option-number {
      display: inline-flex;
      align-items: center;
      padding: 4px 12px;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: #fff;
      border-radius: 4px;
      font-size: 13px;
    }
  }

  .option-content {
    display: flex;
    gap: 12px;

    .option-input {
      flex: 1;
    }
  }
}

.options-hint {
  margin-top: 16px;
  padding: 12px;
  background: #ecf5ff;
  border: 1px solid #b3d8ff;
  border-radius: 4px;
  color: #409eff;
  font-size: 13px;

  p {
    margin: 0;
  }
}

.text-hint-section {
  margin-top: 30px;
  padding: 20px;
  text-align: center;
  background: #f5f7fa;
  border-radius: 6px;
}
</style>
