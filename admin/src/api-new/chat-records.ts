/**
 * 聊天记录 API
 * 用于管理后台查询聊天会话和消息记录
 */

import request from '@/axios'
import type { PaginatedResponse } from './types'

// API 基础路径
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 聊天记录查询参数
 */
export interface ChatRecordsQueryParams {
  page?: number
  pageSize?: number
  hospitalId?: number
  departmentId?: number
  doctorId?: number
  userId?: number
  startDate?: string
  endDate?: string
  status?: string
}

/**
 * 会话记录
 */
export interface ChatSessionRecord {
  id: number
  conversationId: string
  userId: number
  userName: string
  userAvatar?: string // 用户头像（新增字段）
  doctorId: number
  doctorName: string
  doctorAvatar?: string // 医生头像（新增字段）
  hospitalId: number
  hospitalName: string
  departmentId: number
  departmentName: string
  status: string
  orderId?: number // 订单ID（用于筛选该订单的消息）
  serviceItemId: number // 收费项ID（原 packageId）
  serviceItemName: string // 收费项名称（原 packageName）
  serviceStartAt: string
  serviceEndAt: string
  messageCount: number
  createdAt: string
}

/**
 * 消息记录
 */
export interface ChatMessage {
  id: number
  conversationId: string
  senderId: number
  senderName: string
  senderAvatar?: string // 发送者头像（新增字段）
  receiverId: number
  receiverName: string
  content: string
  type: string
  isAutoReply: boolean
  isRevoked: boolean
  revokedAt?: string
  createdAt: string
}

/**
 * 获取聊天记录列表
 */
export const getChatRecordsApi = (params: ChatRecordsQueryParams) => {
  return request.get<PaginatedResponse<ChatSessionRecord>>({
    url: `${BASE_URL}/chat/sessions`,
    params
  })
}

/**
 * 获取会话消息详情
 * @param conversationId - 会话 ID
 * @param params - 查询参数
 * @param params.page - 页码
 * @param params.pageSize - 每页数量
 * @param params.orderId - 订单 ID（可选，如果提供则只返回该订单的消息）
 */
export const getChatMessagesApi = (
  conversationId: string,
  params?: { page?: number; pageSize?: number; orderId?: number }
) => {
  return request.get<PaginatedResponse<ChatMessage>>({
    url: `${BASE_URL}/chat/messages`,
    params: {
      conversationId,
      ...params
    }
  })
}

/**
 * 获取聊天统计数据
 */
export const getChatStatisticsApi = (params?: { startDate?: string; endDate?: string }) => {
  return request.get({
    url: `${BASE_URL}/chat/statistics`,
    params
  })
}
