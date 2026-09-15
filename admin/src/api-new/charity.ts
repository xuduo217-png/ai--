/**
 * 公益管理 API（Admin 端）
 */

import request from '@/axios'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 公益状态
 */
export type CharityStatus = 'DRAFT' | 'ACTIVE' | 'EXPIRED'

/**
 * 删除状态筛选
 */
export type CharityDeleteStatus = 'active' | 'deleted' | 'all'

/**
 * 公益参与类型
 */
export type CharityParticipantType = 'checkin' | 'task' | 'donation'

/**
 * 公益列表/详情项
 */
export interface CharityItem {
  id: number
  title: string
  description: string
  details?: string
  coverImage?: string
  startTime?: string | null
  endTime?: string | null
  targetCheckIns: number
  completedCheckIns?: number
  donatedAmount?: number
  participantType: CharityParticipantType
  isMallAutoDonation?: boolean
  donationRate?: number
  isPinned?: boolean
  taskConfig?: Record<string, any>
  status: CharityStatus
  deletedAt?: string | null
  participantCount?: number
  totalCheckIns?: number
  userCheckInCount?: number
  hasCheckedToday?: boolean
  createdAt: string
  updatedAt: string
}

/**
 * 公益表单数据
 */
export interface CharityFormData {
  title: string
  description: string
  details?: string
  coverImage?: string
  startTime?: string | null
  endTime?: string | null
  targetCheckIns: number
  participantType: CharityParticipantType
  taskConfig?: Record<string, any>
  status?: CharityStatus
  isMallAutoDonation?: boolean
  donationRate?: number
  isPinned?: boolean
}

/**
 * 公益参与者统计项
 */
export interface CharityParticipant {
  userId: number
  userName: string
  userAvatar?: string | null
  checkInCount?: number
  donationAmount?: number
  firstCheckInTime?: string
  lastCheckInTime?: string
  donationSource?: 'manual' | 'mall_order'
  donationEntryType?: 'credit' | 'reversal'
  orderId?: number | null
  orderNo?: string | null
  donationBaseAmount?: number | null
  donationRate?: number | null
  checkInTime?: string
  createdAt?: string
  sourceReference?: string | null
}

/**
 * 公益文章
 */
export interface CharityArticle {
  id: number
  charityId: number
  title: string
  content: string
  publisherId: number
  targetUserIds?: number[]
  sendNotification: boolean
  isPublished: boolean
  createdAt: string
}

/**
 * 公益文章表单
 */
export interface CharityArticleFormData {
  title: string
  content: string
  sendNotification?: boolean
  targetUserIds?: number[]
}

/**
 * 获取公益列表（管理员）
 */
export const getCharityListAdminApi = (params?: {
  status?: string
  deleteStatus?: CharityDeleteStatus
  keyword?: string
  page?: number
  pageSize?: number
}) => {
  return request.get<CharityItem[]>({
    url: `${BASE_URL}/charity/admin/list`,
    params
  })
}

/**
 * 获取公益详情
 */
export const getCharityDetailAdminApi = (id: number) => {
  return request.get<CharityItem>({
    // 后端当前未提供 /charity/admin/:id，管理端复用现有详情接口以规避 404。
    url: `${BASE_URL}/charity/${id}`
  })
}

/**
 * 创建公益
 */
export const createCharityApi = (data: CharityFormData) => {
  return request.post({
    url: `${BASE_URL}/charity/admin`,
    data
  })
}

/**
 * 更新公益
 */
export const updateCharityApi = (id: number, data: Partial<CharityFormData>) => {
  return request.put({
    url: `${BASE_URL}/charity/admin/${id}`,
    data
  })
}

/**
 * 删除公益
 */
export const deleteCharityApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/charity/admin/${id}`
  })
}

/**
 * 获取公益统计数据
 */
export const getCharityStatsApi = (charityId: number) => {
  return request.get({
    url: `${BASE_URL}/charity/admin/${charityId}/stats`
  })
}

/**
 * 获取参与者列表
 */
export const getParticipantsApi = (
  charityId: number,
  params?: {
    page?: number
    pageSize?: number
  }
) => {
  return request.get<CharityParticipant[]>({
    url: `${BASE_URL}/charity/admin/${charityId}/participants`,
    params
  })
}

/**
 * 发布文章给参与者
 * 规则：
 * 1. 公益必须已结束（状态为 EXPIRED）
 * 2. 每个公益只能发布一篇文章
 */
export const publishCharityArticleApi = (charityId: number, data: CharityArticleFormData) => {
  return request.post({
    url: `${BASE_URL}/charity/admin/${charityId}/article`,
    data
  })
}

/**
 * 更新公益文章
 * 只能编辑已发布的文章
 */
export const updateCharityArticleApi = (
  charityId: number,
  articleId: number,
  data: Partial<CharityArticleFormData>
) => {
  return request.put({
    url: `${BASE_URL}/charity/admin/${charityId}/article/${articleId}`,
    data
  })
}

/**
 * 获取公益已发布的文章（用于编辑）
 */
export const getPublishedArticleApi = (charityId: number) => {
  return request.get<CharityArticle | null>({
    url: `${BASE_URL}/charity/admin/${charityId}/article`
  })
}

/**
 * 获取公益文章列表（管理员）
 */
export const getCharityArticlesApi = (charityId: number) => {
  return request.get<CharityArticle[]>({
    url: `${BASE_URL}/charity/admin/${charityId}/articles`
  })
}
