<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { ElMessage, ElUpload, UploadFile, ElProgress } from 'element-plus'
import { ImageCropping } from '@/components/ImageCropping'
import { Dialog } from '@/components/Dialog'
import { BaseButton } from '@/components/Button'
import { uploadImageApi } from '@/api-new/upload'
import { extractUploadPath, getImageUrl } from '@/utils/image'
import {
  IMAGE_UPLOAD_ACCEPT,
  getUploadErrorMessage,
  getUploadMediaValidationError,
  toUploadError
} from '@/utils/upload'
import type { ImageUploadProps, ImageUploadEmits } from './types'

const props = withDefaults(defineProps<ImageUploadProps>(), {
  modelValue: '',
  cropBoxWidth: 200,
  cropBoxHeight: 200,
  aspectRatio: 1,
  dialogWidth: '800px',
  dialogTitle: '上传图片',
  maxSize: 5,
  accept: IMAGE_UPLOAD_ACCEPT,
  circle: false,
  previewWidth: 148,
  previewHeight: 148,
  placeholder: '点击上传图片',
  showSuccessMessage: true
})

const emit = defineEmits<ImageUploadEmits>()

const prefixCls = 'image-upload'

// 状态管理
const dialogVisible = ref(false)
const previewDialogVisible = ref(false)
const selectedImageUrl = ref('')
const cropperRef = ref<ComponentRef<typeof ImageCropping>>()
const directFileInputRef = ref<HTMLInputElement>()
const uploading = ref(false)
const uploadProgress = ref(0)
const errorMessage = ref('')

// 计算预览样式
const previewStyle = computed(() => ({
  width: props.previewWidth ? `${props.previewWidth}px` : '148px',
  height: props.previewHeight ? `${props.previewHeight}px` : '148px'
}))

const previewImageUrl = computed(() => getImageUrl(props.modelValue))

/**
 * 删除图片
 */
const handleRemove = (event: Event) => {
  event.stopPropagation() // 阻止事件冒泡，避免触发上传对话框
  emit('update:modelValue', '')
  ElMessage.success('图片已删除')
}

/**
 * 打开预览对话框
 */
const handlePreview = (event: Event) => {
  event.stopPropagation()
  previewDialogVisible.value = true
}

/**
 * 将 base64 字符串转换为 Blob 对象
 * @param base64 - base64 字符串
 * @returns Blob 对象
 */
const base64ToBlob = (base64: string): Blob => {
  const arr = base64.split(',')
  const mime = arr[0].match(/:(.*?);/)?.[1] || 'image/jpeg'
  const bstr = atob(arr[1])
  let n = bstr.length
  const u8arr = new Uint8Array(n)

  while (n--) {
    u8arr[n] = bstr.charCodeAt(n)
  }

  return new Blob([u8arr], { type: mime })
}

/**
 * 打开裁剪对话框
 */
const handleOpenDialog = () => {
  if (props.disabled) return

  if (props.directUpload) {
    openDirectFilePicker()
    return
  }

  dialogVisible.value = true
  selectedImageUrl.value = ''
  errorMessage.value = ''
  uploadProgress.value = 0

  // 如果已有图片，显示当前图片
  if (props.modelValue) {
    selectedImageUrl.value = previewImageUrl.value
  }

  emit('dialog-open')
}

/**
 * 打开直接上传文件选择器
 */
const openDirectFilePicker = (event?: Event) => {
  event?.stopPropagation()
  if (props.disabled || uploading.value) return

  errorMessage.value = ''
  uploadProgress.value = 0
  directFileInputRef.value?.click()
}

const validateImageFile = (file?: File): file is File => {
  if (!file) return false

  const validationError = getUploadMediaValidationError(file, 'image')
  if (validationError) {
    ElMessage.error(validationError)
    return false
  }

  const maxSizeBytes = props.maxSize * 1024 * 1024
  if (file.size > maxSizeBytes) {
    ElMessage.error(`图片大小不能超过 ${props.maxSize}MB`)
    return false
  }

  return true
}

const appendUploadMeta = (formData: FormData) => {
  if (props.category) {
    formData.append('category', props.category)
  }
  if (props.description) {
    formData.append('description', props.description)
  }
  if (props.tags) {
    formData.append('tags', props.tags)
  }
}

/**
 * 直接上传原图
 */
const uploadDirectFile = async (file: File) => {
  uploading.value = true
  errorMessage.value = ''
  uploadProgress.value = 0

  try {
    const formData = new FormData()
    formData.append('file', file, file.name)
    appendUploadMeta(formData)

    const response = await uploadImageApi(formData, {
      onUploadProgress: (progressEvent) => {
        if (progressEvent.total) {
          uploadProgress.value = Math.round((progressEvent.loaded / progressEvent.total) * 100)
          emit('progress', uploadProgress.value)
        }
      }
    })

    const normalizedUploadPath = extractUploadPath(response.data.url) || response.data.url
    const normalizedResponse = {
      ...response.data,
      url: normalizedUploadPath
    }

    emit('update:modelValue', normalizedUploadPath)
    emit('success', normalizedResponse)
    emit('progress', 100)

    if (props.showSuccessMessage) {
      ElMessage.success('图片上传成功')
    }
  } catch (error) {
    errorMessage.value = getUploadErrorMessage(error, '图片上传失败')
    emit('error', toUploadError(error, '图片上传失败'))
    if (error instanceof Error) ElMessage.error(errorMessage.value)
  } finally {
    uploading.value = false
    uploadProgress.value = 0
  }
}

const handleDirectFileChange = async (event: Event) => {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''

  if (!validateImageFile(file)) return

  await uploadDirectFile(file)
}

/**
 * 文件选择处理
 */
const uploadChange = (uploadFile: UploadFile) => {
  errorMessage.value = ''
  if (!validateImageFile(uploadFile.raw)) return

  // 获取图片的访问地址
  const url = URL.createObjectURL(uploadFile.raw)
  selectedImageUrl.value = url
}

/**
 * 执行上传操作
 */
const handleUpload = async () => {
  // 获取裁剪后的 base64 图片
  const base64 = cropperRef.value?.cropperExpose?.getCroppedCanvas()?.toDataURL()

  if (!base64) {
    errorMessage.value = '无法获取裁剪后的图片'
    return
  }

  uploading.value = true
  errorMessage.value = ''
  uploadProgress.value = 0

  try {
    // 将 base64 转换为 Blob
    const blob = base64ToBlob(base64)

    // 创建 FormData
    const formData = new FormData()
    formData.append('file', blob, `crop-${Date.now()}.jpg`)
    appendUploadMeta(formData)

    // 调用上传 API
    const response = await uploadImageApi(formData, {
      onUploadProgress: (progressEvent) => {
        if (progressEvent.total) {
          uploadProgress.value = Math.round((progressEvent.loaded / progressEvent.total) * 100)
          emit('progress', uploadProgress.value)
        }
      }
    })

    const normalizedUploadPath = extractUploadPath(response.data.url) || response.data.url
    const normalizedResponse = {
      ...response.data,
      url: normalizedUploadPath
    }

    // 上传成功
    emit('update:modelValue', normalizedUploadPath)
    emit('success', normalizedResponse)
    emit('progress', 100)

    if (props.showSuccessMessage) {
      ElMessage.success('图片上传成功')
    }

    dialogVisible.value = false
  } catch (error) {
    errorMessage.value = getUploadErrorMessage(error, '图片上传失败')
    emit('error', toUploadError(error, '图片上传失败'))
    if (error instanceof Error) ElMessage.error(errorMessage.value)
  } finally {
    uploading.value = false
  }
}

/**
 * 取消上传
 */
const handleCancel = () => {
  if (uploading.value) {
    ElMessage.warning('上传中，请稍候...')
    return
  }

  dialogVisible.value = false
  emit('dialog-close')
}

// 监听对话框关闭
watch(dialogVisible, (val) => {
  if (!val) {
    emit('dialog-close')
  }
})
</script>

<template>
  <div :class="prefixCls">
    <!-- 图片预览区域 -->
    <div class="image-upload-wrapper">
      <div
        v-if="modelValue"
        class="preview-image-container"
        :class="{ 'is-circle': circle }"
        :style="previewStyle"
      >
        <img :src="previewImageUrl" alt="预览图" class="preview-image" />
        <div class="preview-mask">
          <div class="mask-actions">
            <div class="action-item" @click="handlePreview">
              <Icon icon="vi-ep:view" />
              <span>预览</span>
            </div>
            <!-- <div class="action-item" @click="handleOpenDialog">
              <Icon icon="vi-ep:zoom-in" />
              <span>更换</span>
            </div> -->
            <div class="action-item" @click="handleRemove">
              <Icon icon="vi-ep:delete" class="delete-icon" />
              <span>删除</span>
            </div>
          </div>
        </div>
      </div>

      <!-- 占位符 -->
      <div
        v-else
        class="upload-placeholder"
        :style="previewStyle"
        :class="{ 'is-disabled': disabled }"
        @click="handleOpenDialog"
      >
        <Icon
          :icon="uploading && directUpload ? 'vi-ep:loading' : 'vi-ep:plus'"
          class="placeholder-icon"
        />
        <span class="placeholder-text">{{ placeholder }}</span>
      </div>
    </div>

    <input
      v-if="directUpload"
      ref="directFileInputRef"
      class="direct-file-input"
      type="file"
      :accept="accept"
      @change="handleDirectFileChange"
    />

    <!-- 裁剪对话框 -->
    <Dialog v-model="dialogVisible" :title="dialogTitle" :width="dialogWidth">
      <div class="image-upload-dialog">
        <!-- 文件选择 -->
        <div v-if="!selectedImageUrl" class="upload-section">
          <ElUpload
            action=""
            :accept="accept"
            :auto-upload="false"
            :show-file-list="false"
            :on-change="uploadChange"
            drag
          >
            <div class="upload-dragger">
              <Icon icon="vi-ep:upload-filled" class="upload-icon" />
              <div class="upload-text">点击或拖拽文件到此处上传</div>
              <div class="upload-hint">支持 JPG、PNG、GIF 等格式，不超过 {{ maxSize }}MB</div>
            </div>
          </ElUpload>
        </div>

        <!-- 裁剪组件 -->
        <div v-else class="cropper-section">
          <ImageCropping
            ref="cropperRef"
            :image-url="selectedImageUrl"
            :aspect-ratio="aspectRatio"
            :crop-box-width="cropBoxWidth"
            :crop-box-height="cropBoxHeight"
            :box-width="650"
            :box-height="400"
            :show-result="false"
            :show-actions="true"
          />
        </div>

        <!-- 错误提示 -->
        <div v-if="errorMessage" class="error-message">
          <Icon icon="vi-ep:circle-close-filled" class="error-icon" />
          <span>{{ errorMessage }}</span>
        </div>

        <!-- 上传进度 -->
        <div v-if="uploading" class="upload-progress">
          <ElProgress
            :percentage="uploadProgress"
            :status="errorMessage ? 'exception' : undefined"
          />
        </div>
      </div>

      <!-- 底部按钮 -->
      <template #footer>
        <div class="dialog-footer">
          <BaseButton @click="handleCancel">取消</BaseButton>
          <BaseButton
            v-if="selectedImageUrl"
            type="primary"
            :loading="uploading"
            :disabled="uploading"
            @click="handleUpload"
          >
            {{ uploading ? '上传中...' : '确定上传' }}
          </BaseButton>
        </div>
      </template>
    </Dialog>

    <!-- 图片预览对话框 -->
    <Dialog v-model="previewDialogVisible" title="图片预览" width="800px">
      <div class="image-preview-container">
        <img :src="previewImageUrl" alt="预览图" class="preview-full-image" />
      </div>
      <template #footer>
        <div class="dialog-footer">
          <BaseButton type="primary" @click="previewDialogVisible = false">关闭</BaseButton>
        </div>
      </template>
    </Dialog>
  </div>
</template>

<style scoped lang="less">
.image-upload {
  // 预览容器
  .image-upload-wrapper {
    display: inline-block;
    vertical-align: top;
  }

  // 预览图片容器
  .preview-image-container {
    position: relative;
    overflow: hidden;
    background-color: var(--el-fill-color-light);
    border: 1px solid var(--el-border-color);
    border-radius: 4px;
    transition: border-color 0.3s;
    cursor: pointer;

    &.is-circle {
      border-radius: 50%;
    }

    &:hover {
      .preview-mask {
        opacity: 1;
      }
    }
  }

  // 预览图片
  .preview-image {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }

  // 遮罩层
  .preview-mask {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-color: rgba(0, 0, 0, 0.6);
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    color: #fff;
    opacity: 0;
    transition: opacity 0.3s;
    font-size: 14px;

    .mask-actions {
      display: flex;
      flex-direction: row;
      align-items: center;
      justify-content: center;
      gap: 24px;

      .action-item {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 4px;
        cursor: pointer;

        .iconify {
          font-size: 20px;
          transition: transform 0.2s;

          &:hover {
            transform: scale(1.2);
          }

          &.delete-icon {
            color: #f56c6c;
          }
        }

        span {
          font-size: 12px;
          cursor: pointer;
        }

        &:hover {
          opacity: 0.8;
        }
      }
    }
  }

  // 占位符
  .upload-placeholder {
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    background-color: var(--el-fill-color-lighter);
    border: 1px dashed var(--el-border-color);
    border-radius: 4px;
    color: var(--el-text-color-secondary);
    transition: all 0.3s;
    cursor: pointer;

    &:not(.is-disabled):hover {
      border-color: var(--el-color-primary);
      color: var(--el-color-primary);
    }

    &.is-disabled {
      cursor: not-allowed;
      opacity: 0.6;
    }
  }

  .placeholder-icon {
    font-size: 32px;
    margin-bottom: 8px;
  }

  .placeholder-text {
    font-size: 13px;
    text-align: center;
  }

  .direct-file-input {
    display: none;
  }

  // 对话框内容
  .image-upload-dialog {
    min-height: 400px;

    .upload-section {
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 400px;

      .upload-dragger {
        text-align: center;
        padding: 40px;

        .upload-icon {
          font-size: 67px;
          color: var(--el-text-color-placeholder);
          margin-bottom: 16px;
        }

        .upload-text {
          font-size: 14px;
          color: var(--el-text-color-regular);
          margin-bottom: 8px;
        }

        .upload-hint {
          font-size: 12px;
          color: var(--el-text-color-placeholder);
        }
      }
    }

    .cropper-section {
      display: flex;
      justify-content: center;
    }

    .error-message {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-top: 16px;
      padding: 8px 12px;
      background-color: var(--el-color-error-light-9);
      border: 1px solid var(--el-color-error-light-7);
      border-radius: 4px;
      color: var(--el-color-error);

      .error-icon {
        font-size: 16px;
      }
    }

    .upload-progress {
      margin-top: 16px;
    }
  }

  // 对话框底部
  .dialog-footer {
    display: flex;
    justify-content: flex-end;
    gap: 12px;
  }

  // 图片预览对话框
  .image-preview-container {
    display: flex;
    justify-content: center;
    align-items: center;
    padding: 20px;
    min-height: 400px;

    .preview-full-image {
      max-width: 100%;
      max-height: 600px;
      object-fit: contain;
      border-radius: 4px;
    }
  }
}
</style>
