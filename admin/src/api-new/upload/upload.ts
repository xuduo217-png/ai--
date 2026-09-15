/**
 * 文件上传 API
 */
import request from '@/axios'
import type { UploadResponse } from './types'
import { getImageUrl } from '@/utils/image'
import { assertSupportedUploadFile } from '@/utils/upload'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 上传图片
 * @param data - FormData 对象，包含 file 字段
 * @param config - 请求配置（可包含 onUploadProgress 进度回调）
 * @returns Promise<UploadResponse>
 */
export const uploadImageApi = async (
  data: FormData,
  config?: {
    onUploadProgress?: (progressEvent: any) => void
  }
) => {
  assertSupportedUploadFile(data, 'image')
  const response = await request.post<UploadResponse>({
    url: `${BASE_URL}/upload/image`,
    data,
    headers: {
      'Content-Type': 'multipart/form-data'
    },
    onUploadProgress: config?.onUploadProgress
  })

  // 如果返回的 URL 是相对路径，使用 getImageUrl 拼接完整的服务器地址
  const uploadedUrl = response.data?.url?.trim()
  if (!uploadedUrl) throw new Error('上传失败：服务器未返回图片地址')
  response.data.url = getImageUrl(uploadedUrl)

  return response
}

/**
 * 上传视频
 * @param data - FormData 对象，包含 file 字段
 * @param config - 请求配置（可包含 onUploadProgress 进度回调）
 * @returns Promise<UploadResponse>
 */
export const uploadVideoApi = async (
  data: FormData,
  config?: {
    onUploadProgress?: (progressEvent: any) => void
  }
) => {
  assertSupportedUploadFile(data, 'video')
  const response = await request.post<UploadResponse>({
    url: `${BASE_URL}/upload/file`,
    data,
    headers: {
      'Content-Type': 'multipart/form-data'
    },
    onUploadProgress: config?.onUploadProgress
  })

  // 如果返回的 URL 是相对路径，使用 getImageUrl 拼接完整的服务器地址
  const uploadedUrl = response.data?.url?.trim()
  if (!uploadedUrl) throw new Error('上传失败：服务器未返回视频地址')
  response.data.url = getImageUrl(uploadedUrl)

  return response
}
