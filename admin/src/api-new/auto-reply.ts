/**
 * 自动回复管理 API
 */

import request from '@/axios'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 自动回复类型定义
 */
export interface AutoReply {
  id: number
  content: string
  sortOrder: number
  isActive: boolean
  createdAt: string
  updatedAt: string
}

/**
 * 创建自动回复参数
 */
export interface CreateAutoReplyParams {
  content: string
  sortOrder: number
  isActive?: boolean
}

/**
 * 更新自动回复参数
 */
export interface UpdateAutoReplyParams {
  content?: string
  sortOrder?: number
  isActive?: boolean
}

/**
 * 获取自动回复列表
 */
export const getAutoReplyListApi = () => {
  return request.get<AutoReply[]>({
    url: `${BASE_URL}/chat/auto-replies`
  })
}

/**
 * 创建自动回复
 */
export const createAutoReplyApi = (data: CreateAutoReplyParams) => {
  return request.post<AutoReply>({
    url: `${BASE_URL}/chat/auto-replies`,
    data
  })
}

/**
 * 更新自动回复
 */
export const updateAutoReplyApi = (id: number, data: UpdateAutoReplyParams) => {
  return request.put<AutoReply>({
    url: `${BASE_URL}/chat/auto-replies/${id}`,
    data
  })
}

/**
 * 删除自动回复
 */
export const deleteAutoReplyApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/chat/auto-replies/${id}`
  })
}

/**
 * 清空自动回复缓存
 * 修改自动回复配置后调用此接口使更改立即生效
 */
export const clearAutoReplyCacheApi = () => {
  return request.post<{
    deleted: number
    details: string
  }>({
    url: `${BASE_URL}/chat/auto-replies/clear-cache`
  })
}
