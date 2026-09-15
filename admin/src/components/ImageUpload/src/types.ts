/**
 * ImageUpload 组件类型定义
 */

import type { UploadResponse } from '@/api-new/upload'

/**
 * 组件 Props 属性
 */
export interface ImageUploadProps {
  /** 绑定的图片 URL（支持 v-model） */
  modelValue?: string
  /** 裁剪框宽度（像素） */
  cropBoxWidth?: number
  /** 裁剪框高度（像素） */
  cropBoxHeight?: number
  /** 裁剪比例（如 1 表示 1:1，16/9 表示 16:9） */
  aspectRatio?: number
  /** 对话框宽度 */
  dialogWidth?: string | number
  /** 对话框标题 */
  dialogTitle?: string
  /** 最大文件大小（MB，默认 5MB） */
  maxSize?: number
  /** 允许的图片格式 */
  accept?: string
  /** 文件分类（用于后端分类管理） */
  category?: string
  /** 文件描述（用于后端记录） */
  description?: string
  /** 文件标签（用于后端管理） */
  tags?: string
  /** 是否禁用 */
  disabled?: boolean
  /** 是否圆形预览 */
  circle?: boolean
  /** 预览图片宽度 */
  previewWidth?: number
  /** 预览图片高度 */
  previewHeight?: number
  /** 占位文本 */
  placeholder?: string
  /** 是否显示上传成功提示 */
  showSuccessMessage?: boolean
  /** 是否直接选择并上传原图，不打开裁剪弹窗 */
  directUpload?: boolean
}

/**
 * 组件 Events 事件
 */
export interface ImageUploadEmits {
  /** 更新 modelValue */
  'update:modelValue': [value: string]
  /** 上传成功 */
  success: [response: UploadResponse]
  /** 上传失败 */
  error: [error: Error]
  /** 上传进度变化 */
  progress: [percent: number]
  /** 裁剪对话框打开 */
  'dialog-open': []
  /** 裁剪对话框关闭 */
  'dialog-close': []
}
