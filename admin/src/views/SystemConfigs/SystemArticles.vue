<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox, ElRadioGroup, ElRadioButton, ElButton } from 'element-plus'
import { Editor } from '@/components/Editor'
import { getSystemArticleByTypeApi, updateSystemArticleApi } from '@/api-new/system-articles'
import { ArticleType, ArticleTypeLabels } from '@/api-new/system-articles'

// 当前选中的文章类型
const currentType = ref<ArticleType>(ArticleType.ABOUT_US)
const originalType = ref<ArticleType>(ArticleType.ABOUT_US)

// 文章内容
const content = ref('')
const originalContent = ref('')

// 加载和保存状态
const loading = ref(false)
const saving = ref(false)

// 最后更新时间
const lastUpdateTime = ref('')

/**
 * 加载文章内容
 */
const loadArticle = async (type: ArticleType) => {
  try {
    loading.value = true
    const res = await getSystemArticleByTypeApi(type)

    if (res.data) {
      // 文章存在，加载内容
      content.value = res.data.content || ''
      originalContent.value = res.data.content || ''
      lastUpdateTime.value = res.data.updatedAt
        ? formatUpdateTime(new Date(res.data.updatedAt))
        : ''
    } else {
      // 文章不存在，清空内容
      content.value = ''
      originalContent.value = ''
      lastUpdateTime.value = ''
    }
  } catch (error) {
    console.error('加载文章失败:', error)
    ElMessage.error('加载文章失败，请稍后重试')
  } finally {
    loading.value = false
  }
}

/**
 * 格式化更新时间
 */
const formatUpdateTime = (date: Date): string => {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  const hours = String(date.getHours()).padStart(2, '0')
  const minutes = String(date.getMinutes()).padStart(2, '0')
  return `${year}-${month}-${day} ${hours}:${minutes}`
}

/**
 * 检查未保存的修改
 */
const checkUnsavedChanges = async (): Promise<boolean> => {
  if (content.value !== originalContent.value) {
    try {
      await ElMessageBox.confirm(
        '当前文章有未保存的修改，切换类型将丢失这些修改。是否保存？',
        '提示',
        {
          confirmButtonText: '保存',
          cancelButtonText: '不保存',
          distinguishCancelAndClose: true,
          type: 'warning'
        }
      )
      // 用户点击"保存"
      await handleSave()
      return true
    } catch (action: any) {
      if (action === 'cancel') {
        // 用户点击"不保存"
        return true
      } else {
        // 用户点击关闭按钮，取消切换
        return false
      }
    }
  }
  return true
}

/**
 * 类型切换处理
 */
const handleTypeChange = async (type: ArticleType) => {
  // 检查未保存的修改
  const canSwitch = await checkUnsavedChanges()
  if (!canSwitch) {
    // 恢复原来的选择
    currentType.value = originalType.value
    return
  }

  originalType.value = type
  await loadArticle(type)
}

/**
 * 保存文章
 */
const handleSave = async () => {
  // 验证内容不为空
  if (!content.value || content.value.trim() === '' || content.value.trim() === '<p></p>') {
    ElMessage.warning('文章内容不能为空')
    return
  }

  try {
    saving.value = true
    await updateSystemArticleApi(currentType.value, content.value)

    // 更新原始内容
    originalContent.value = content.value

    // 重新加载以获取更新时间
    await loadArticle(currentType.value)

    ElMessage.success('保存成功')
  } catch (error) {
    console.error('保存失败:', error)
    ElMessage.error('保存失败，请稍后重试')
  } finally {
    saving.value = false
  }
}

// 组件挂载时加载默认文章
onMounted(() => {
  loadArticle(currentType.value)
})
</script>

<template>
  <div class="system-articles-container">
    <!-- 类型选择和保存按钮 -->
    <div class="type-selector">
      <span class="label">文章类型：</span>
      <el-radio-group v-model="currentType" @change="handleTypeChange">
        <el-radio-button :value="ArticleType.ABOUT_US">
          {{ ArticleTypeLabels[ArticleType.ABOUT_US] }}
        </el-radio-button>
        <el-radio-button :value="ArticleType.PRIVACY">
          {{ ArticleTypeLabels[ArticleType.PRIVACY] }}
        </el-radio-button>
        <el-radio-button :value="ArticleType.USER_AGREEMENT">
          {{ ArticleTypeLabels[ArticleType.USER_AGREEMENT] }}
        </el-radio-button>
      </el-radio-group>
      <el-button type="primary" :loading="saving" @click="handleSave" class="save-button">
        保存
      </el-button>
    </div>

    <!-- 富文本编辑器 -->
    <div v-loading="loading" class="editor-wrapper">
      <Editor v-model="content" height="70vh" />
    </div>

    <!-- 底部更新时间 -->
    <div v-if="lastUpdateTime" class="footer-bar">
      <span class="update-time">最后更新: {{ lastUpdateTime }}</span>
    </div>
  </div>
</template>

<style lang="less" scoped>
.system-articles-container {
  padding: 20px;
  background: #fff;
  border-radius: 4px;

  .type-selector {
    margin-bottom: 20px;
    display: flex;
    align-items: center;
    gap: 16px;

    .label {
      font-size: 14px;
      color: #606266;
      font-weight: 500;
      white-space: nowrap;
    }

    .save-button {
      margin-left: auto;
    }
  }

  .editor-wrapper {
    min-height: 600px;
    margin-bottom: 20px;
  }

  .footer-bar {
    display: flex;
    justify-content: flex-end;
    padding-top: 16px;
    border-top: 1px solid #ebeef5;

    .update-time {
      font-size: 12px;
      color: #909399;
    }
  }
}
</style>
