<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { getImageUrl } from '@/utils/image'
import { ElMessage, ElMessageBox, ElTag } from 'element-plus'
import { ref, onMounted } from 'vue'
import { BaseButton } from '@/components/Button'
import { useRouter, useRoute } from 'vue-router'
import { VueDraggable } from 'vue-draggable-plus'
import {
  getSelfCheckQuestionsApi,
  deleteQuestionApi,
  reorderQuestionsApi,
  type SelfCheckQuestion
} from '@/api-new/ai-self-check'
import { getSelfCheckListDetailApi, type SelfCheckList } from '@/api-new/ai-self-check'

defineOptions({
  name: 'SelfCheckQuestions'
})

const router = useRouter()
const route = useRoute()

const listId = ref<number>(Number(route.params.id))
const listDetail = ref<SelfCheckList | null>(null)
const questions = ref<SelfCheckQuestion[]>([])
const loading = ref(false)

// 拖动排序状态
const isReordering = ref(false)
const originalQuestions = ref<SelfCheckQuestion[]>([])

const loadListDetail = async () => {
  try {
    const res = await getSelfCheckListDetailApi(listId.value)
    listDetail.value = res.data
  } catch (error) {
    console.error('加载详情失败:', error)
  }
}

const loadQuestions = async () => {
  loading.value = true
  try {
    const res = await getSelfCheckQuestionsApi(listId.value)
    questions.value = res.data || []
  } catch (error) {
    ElMessage.error('加载问题失败')
  } finally {
    loading.value = false
  }
}

/**
 * 跳转到新增问题页面
 */
const handleAddQuestion = () => {
  router.push({
    name: 'SelfCheckQuestionCreate',
    params: { id: listId.value }
  })
}

/**
 * 跳转到编辑问题页面
 */
const handleEditQuestion = (question: SelfCheckQuestion) => {
  router.push({
    name: 'SelfCheckQuestionEdit',
    params: {
      id: listId.value,
      questionId: question.id
    }
  })
}

const handleDeleteQuestion = async (question: SelfCheckQuestion) => {
  try {
    await ElMessageBox.confirm(`确定要删除问题"${question.questionText}"吗？`, '提示', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    })

    await deleteQuestionApi(question.id)
    ElMessage.success('删除成功')
    loadQuestions()
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}

const handleBack = () => {
  router.push({ name: 'SelfCheckLists' })
}

/**
 * 问题列表拖动结束处理
 */
const handleQuestionDragEnd = async () => {
  // 只有一条数据时不需要排序
  if (questions.value.length < 2) {
    return
  }

  // 防止重复请求
  if (isReordering.value) {
    return
  }

  isReordering.value = true
  // 保存原始数据用于错误恢复
  originalQuestions.value = [...questions.value]
  // 提取所有问题 ID（按新顺序）
  const questionIds = questions.value.map((q) => q.id)

  try {
    await reorderQuestionsApi(questionIds)
    ElMessage.success('排序已保存')
  } catch (error) {
    // 恢复原始顺序
    questions.value = [...originalQuestions.value]
    ElMessage.error('排序保存失败，已恢复原序')
  } finally {
    isReordering.value = false
  }
}

/**
 * 对选项进行排序
 */
const sortOptions = (options: any[]) => {
  if (!options) return []
  return [...options].sort((a, b) => a.sortOrder - b.sortOrder)
}

onMounted(() => {
  loadListDetail()
  loadQuestions()
})
</script>

<template>
  <ContentWrap>
    <div class="mb-4 flex justify-between items-center">
      <div class="flex items-center gap-2">
        <BaseButton @click="handleBack">← 返回</BaseButton>
        <h3 class="text-lg font-semibold"> {{ listDetail?.title || '自查表' }} - 问题管理 </h3>
        <ElTag v-if="listDetail" :type="listDetail.type === 'PUBLIC' ? 'success' : 'primary'">
          {{ listDetail.type === 'PUBLIC' ? '公共项' : listDetail.categoryName }}
        </ElTag>
      </div>
      <BaseButton type="primary" @click="handleAddQuestion"> 新增问题 </BaseButton>
    </div>

    <div v-loading="loading" class="question-list">
      <!-- 用 VueDraggable 包裹问题列表 -->
      <VueDraggable
        v-model="questions"
        @end="handleQuestionDragEnd"
        :animation="300"
        handle=".question-drag-handle"
        :disabled="isReordering"
      >
        <div v-for="(question, index) in questions" :key="question.id" class="question-item">
          <div class="question-header">
            <div class="question-info">
              <!-- 添加拖动手柄 -->
              <span class="question-drag-handle"></span>
              <ElTag
                :type="
                  question.questionType === 'SINGLE'
                    ? 'primary'
                    : question.questionType === 'MULTIPLE'
                      ? 'success'
                      : 'warning'
                "
                size="small"
              >
                {{
                  question.questionType === 'SINGLE'
                    ? '单选'
                    : question.questionType === 'MULTIPLE'
                      ? '多选'
                      : '填空'
                }}
              </ElTag>
              <span class="sort-badge">{{ index + 1 }}</span>
              <span class="question-text">{{ question.questionText }}</span>
              <ElTag v-if="question.required" type="danger" size="small">必填</ElTag>
            </div>
            <div class="question-actions">
              <BaseButton type="primary" link @click="handleEditQuestion(question)"
                >编辑</BaseButton
              >
              <BaseButton type="danger" link @click="handleDeleteQuestion(question)"
                >删除</BaseButton
              >
            </div>
          </div>

          <!-- 填空题显示提示 -->
          <div v-if="question.questionType === 'TEXT'" class="question-body">
            <div class="text-hint">
              <span class="hint-icon">📝</span>
              <span class="hint-text">用户需要填写文本回答</span>
            </div>
          </div>

          <!-- 选择题显示选项 -->
          <div v-else class="question-body">
            <div class="options-list">
              <div
                v-if="!question.options || question.options.length === 0"
                class="empty-options-hint"
              >
                暂无选项
              </div>
              <div v-else>
                <div
                  v-for="option in sortOptions(question.options)"
                  :key="option.id"
                  class="option-item"
                >
                  <div class="option-header">
                    <span class="option-badge">{{ option.sortOrder + 1 }}</span>
                    <span class="option-text">{{ option.optionText }}</span>
                  </div>
                  <div v-if="option.optionImage" class="option-image">
                    <img :src="getImageUrl(option.optionImage)" alt="选项图片" />
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </VueDraggable>

      <div v-if="!loading && questions.length === 0" class="empty-state">
        <p>暂无问题，点击右上角"新增问题"添加</p>
      </div>
    </div>
  </ContentWrap>
</template>

<style scoped lang="less">
.mb-4 {
  margin-bottom: 16px;
}

// 问题拖动手柄样式
.question-drag-handle {
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
    font-size: 18px;
    letter-spacing: -2px;
  }
}

.question-item {
  border: 1px solid #ebeef5;
  border-radius: 8px;
  margin-bottom: 16px;
  padding: 16px;
  background: #fff;
  transition: all 0.3s;

  &:hover {
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
    border-color: #c0c4cc;
  }

  // 拖动中的问题卡片
  &.sortable-ghost {
    opacity: 0.5;
    background: #f5f7fa;
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
  }

  .question-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    padding-bottom: 12px;

    .question-info {
      display: flex;
      align-items: center;
      gap: 8px;
      flex-wrap: wrap;
      flex: 1;

      .sort-badge {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 24px;
        height: 24px;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: #fff;
        border-radius: 50%;
        font-size: 12px;
        font-weight: 600;
      }

      .question-text {
        font-size: 15px;
        font-weight: 500;
        color: #303133;
      }
    }
  }

  .question-body {
    margin-top: 12px;
    padding-top: 12px;
    border-top: 1px solid #f0f0f0;

    .text-hint {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 12px 16px;
      background: #f5f7fa;
      border-radius: 6px;
      color: #606266;
      font-size: 13px;

      .hint-icon {
        font-size: 18px;
      }

      .hint-text {
        flex: 1;
      }
    }

    .options-list {
      display: flex;
      flex-direction: column;
      gap: 12px;

      .empty-options-hint {
        text-align: center;
        padding: 20px;
        color: #909399;
        font-size: 13px;
        background: #f5f7fa;
        border-radius: 6px;
      }

      .option-item {
        display: flex;
        flex-direction: column;
        gap: 8px;
        padding: 12px;
        background: #fafafa;
        border-radius: 6px;
        border: 1px solid #ebeef5;

        .option-header {
          display: flex;
          align-items: center;
          gap: 10px;

          .option-badge {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            min-width: 20px;
            height: 20px;
            padding: 0 6px;
            background: #e1e6f0;
            color: #5a6c7d;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
          }

          .option-text {
            flex: 1;
            font-size: 14px;
            color: #606266;
          }
        }

        .option-image {
          margin-top: 4px;

          img {
            max-width: 200px;
            max-height: 120px;
            border-radius: 4px;
            object-fit: cover;
            border: 1px solid #ebeef5;
          }
        }
      }
    }
  }
}

.empty-state {
  text-align: center;
  padding: 60px 0;
  color: #909399;
  font-size: 14px;
}
</style>
