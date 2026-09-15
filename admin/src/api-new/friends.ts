/**
 * 好友模块 API
 */

import request from '@/axios'
import type { PaginatedResponse } from './types'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 后端部分好友管理接口会保留业务层的 `success + data` 结构。
 * 管理端页面统一期望直接从 `res.data` 读取最终业务数据，因此这里在 API 层做一次解包，
 * 避免页面层重复处理不同响应形态，减少再次出现统计页这类取值错误。
 */
interface FriendsBusinessPayload<T> {
  success: boolean
  data: T
}

/**
 * 统一解开好友模块的业务响应外壳。
 * 这样页面层可以稳定按照 `IResponse<T>` 使用，不需要关心后端是否保留了 `success` 字段。
 *
 * @param {IResponse<T | FriendsBusinessPayload<T>>} response - 原始响应对象
 * @returns {IResponse<T>} 解包后的响应对象
 */
const unwrapFriendsBusinessPayload = <T>(
  response: IResponse<T | FriendsBusinessPayload<T>>
): IResponse<T> => {
  const payload = response.data

  if (payload && typeof payload === 'object' && 'success' in payload && 'data' in payload) {
    return {
      ...response,
      data: (payload as FriendsBusinessPayload<T>).data
    } as IResponse<T>
  }

  return response as IResponse<T>
}

/**
 * 好友关系类型
 */
export interface Friendship {
  id: number
  userId: number
  friendId: number
  userName?: string
  userAvatar?: string
  friendName?: string
  friendAvatar?: string
  direction: 'sent' | 'received'
  remark?: string
  lastChatAt?: string
  createdAt: string
  updatedAt?: string
}

/**
 * 好友申请类型
 */
export interface FriendRequest {
  id: number
  requesterId: number
  receiverId: number
  requesterName?: string
  requesterAvatar?: string
  receiverName?: string
  receiverAvatar?: string
  message?: string
  status: 'pending' | 'accepted' | 'rejected' | 'expired'
  rejectionReason?: string
  expiresAt: string
  createdAt: string
  updatedAt?: string
}

/**
 * 好友消息类型
 */
export interface FriendMessage {
  id: number
  messageId: string
  conversationId: string
  senderId: number
  receiverId: number
  senderName?: string
  receiverName?: string
  messageType: 'text' | 'image' | 'voice' | 'video'
  content: string
  cloudFileUrl?: string
  isRead: boolean | number
  isRevoked: boolean | number
  revokedAt?: string
  createdAt: string
  updatedAt: string
}

/**
 * 统计数据类型
 */
export interface FriendsStatistics {
  totalFriendships: number
  todayNewFriendships: number
  activeUsers: number
  totalMessages: number
  todayMessages: number
  pendingRequests: number
  offlineQueueSize: number
  avgFriendsPerUser: number
  messageStatsByType: {
    text: number
    image: number
    voice: number
  }
  activeUserGrowth: Array<{
    date: string
    count: number
  }>
}

/**
 * 离线消息队列详情
 */
export interface OfflineQueueDetail {
  userId: number
  userName?: string
  messageCount: number
  oldestMessageTime?: string
  newestMessageTime?: string
}

/**
 * 离线消息队列状态
 */
export interface OfflineQueueStatus {
  totalUsers: number
  totalMessages: number
  queueDetails: OfflineQueueDetail[]
}

/**
 * 获取所有好友关系（分页）
 */
export const getFriendshipsApi = (params: {
  page?: number
  pageSize?: number
  userId?: number
  friendId?: number
}) => {
  return request.get<PaginatedResponse<Friendship>>({
    url: `${BASE_URL}/friends/admin/friendships`,
    params
  })
}

/**
 * 获取所有好友申请（分页）
 */
export const getFriendRequestsApi = (params: {
  page?: number
  pageSize?: number
  status?: 'pending' | 'accepted' | 'rejected' | 'expired'
}) => {
  return request.get<PaginatedResponse<FriendRequest>>({
    url: `${BASE_URL}/friends/admin/requests`,
    params
  })
}

/**
 * 获取所有消息记录（分页）
 */
export const getFriendMessagesApi = (params: {
  page?: number
  pageSize?: number
  conversationId?: string
  senderId?: number
  receiverId?: number
  messageType?: 'text' | 'image' | 'voice'
  startTime?: string
  endTime?: string
}) => {
  return request.get<PaginatedResponse<FriendMessage>>({
    url: `${BASE_URL}/friends/admin/messages`,
    params
  })
}

/**
 * 获取会话所有消息
 */
export const getConversationMessagesApi = (conversationId: string) => {
  return request
    .get<FriendMessage[] | FriendsBusinessPayload<FriendMessage[]>>({
      url: `${BASE_URL}/friends/admin/conversations/${conversationId}/messages`
    })
    .then((response) => unwrapFriendsBusinessPayload<FriendMessage[]>(response))
}

/**
 * 获取离线消息队列状态
 */
export const getOfflineQueueStatusApi = () => {
  return request
    .get<OfflineQueueStatus | FriendsBusinessPayload<OfflineQueueStatus>>({
      url: `${BASE_URL}/friends/admin/offline-queue`
    })
    .then((response) => unwrapFriendsBusinessPayload<OfflineQueueStatus>(response))
}

/**
 * 清空指定用户离线消息
 */
export const clearUserOfflineQueueApi = (userId: number) => {
  return request.delete({
    url: `${BASE_URL}/friends/admin/offline-queue/${userId}`
  })
}

/**
 * 获取统计数据
 */
export const getFriendsStatisticsApi = () => {
  return request
    .get<FriendsStatistics | FriendsBusinessPayload<FriendsStatistics>>({
      url: `${BASE_URL}/friends/admin/statistics`
    })
    .then((response) => unwrapFriendsBusinessPayload<FriendsStatistics>(response))
}

/**
 * 强制解除好友关系（管理员操作）
 */
export const forceDeleteFriendshipApi = (userId: number, friendId: number) => {
  return request.delete({
    url: `${BASE_URL}/friends/admin/friendships`,
    params: { userId, friendId }
  })
}
