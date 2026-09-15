/**
 * 社区管理 API
 */

import request from '@/axios'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

// ========== 类型定义 ==========

/**
 * 帖子状态
 */
export type PostStatus = 'PENDING_REVIEW' | 'APPROVED' | 'REJECTED'

/**
 * 帖子对象
 */
export interface Post {
  id: number
  userId: number
  user?: {
    id: number
    nickname: string
    avatar: string
  }
  content: string
  images?: string[]
  video?: string
  videoCover?: string
  tags?: string[]
  likeCount: number
  commentCount: number
  viewCount: number
  isPinned: boolean
  isFeatured: boolean
  status: PostStatus
  rejectReason?: string
  detectedSensitiveWords?: string[]
  createdAt: string
  updatedAt: string
}

/**
 * 分页查询参数
 */
export interface PageParams {
  page: number
  pageSize: number
}

/**
 * 分页响应
 */
export interface PaginatedResponse<T> {
  data: T[]
  meta: {
    total: number
    page: number
    pageSize: number
  }
}

/**
 * 敏感词对象
 */
export interface SensitiveWord {
  id: number
  word: string
  severity: number // 1-低危, 2-中危, 3-高危
  replacement?: string
  category?: string
  isActive: boolean
  createdAt: string
  updatedAt: string
}

/**
 * 敏感词创建参数
 */
export interface CreateSensitiveWordDto {
  word: string
  severity: number
  replacement?: string
  category?: string
}

/**
 * 敏感词更新参数
 */
export interface UpdateSensitiveWordDto {
  word?: string
  severity?: number
  replacement?: string
  category?: string
  isActive?: boolean
}

/**
 * 批量导入敏感词参数
 */
export interface BatchImportSensitiveWordsDto {
  words: string[]
}

/**
 * 批量导入结果
 */
export interface BatchImportResult {
  created: number
  skipped: number
}

// ========== 帖子管理 API ==========

/**
 * 获取待审核列表
 */
export const getPendingReviewApi = (params: PageParams) => {
  return request.get<PaginatedResponse<Post>>({
    url: `${BASE_URL}/admin/community/posts/pending`,
    params
  })
}

/**
 * 获取已审核内容列表
 */
export const getReviewedPostsApi = (params: PageParams & { status?: PostStatus }) => {
  return request.get<PaginatedResponse<Post>>({
    url: `${BASE_URL}/admin/community/posts`,
    params
  })
}

/**
 * 审核通过
 */
export const approvePostApi = (id: number) => {
  return request.post({
    url: `${BASE_URL}/admin/community/posts/${id}/approve`
  })
}

/**
 * 审核拒绝
 */
export const rejectPostApi = (id: number, rejectReason: string) => {
  return request.post({
    url: `${BASE_URL}/admin/community/posts/${id}/reject`,
    data: { rejectReason }
  })
}

/**
 * 删除帖子（管理员专用）
 */
export const deletePostApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/admin/community/posts/${id}`
  })
}

/**
 * 置顶/取消置顶
 */
export const togglePinApi = (id: number) => {
  return request.put({
    url: `${BASE_URL}/admin/community/posts/${id}/pin`
  })
}

/**
 * 加精/取消加精
 */
export const toggleFeatureApi = (id: number) => {
  return request.put({
    url: `${BASE_URL}/admin/community/posts/${id}/feature`
  })
}

// ========== 敏感词管理 API ==========

/**
 * 获取敏感词列表
 */
export const getSensitiveWordsApi = () => {
  return request.get<SensitiveWord[]>({
    url: `${BASE_URL}/admin/community/sensitive-words`
  })
}

/**
 * 添加敏感词
 */
export const createSensitiveWordApi = (data: CreateSensitiveWordDto) => {
  return request.post<SensitiveWord>({
    url: `${BASE_URL}/admin/community/sensitive-words`,
    data
  })
}

/**
 * 更新敏感词
 */
export const updateSensitiveWordApi = (id: number, data: UpdateSensitiveWordDto) => {
  return request.put<SensitiveWord>({
    url: `${BASE_URL}/admin/community/sensitive-words/${id}`,
    data
  })
}

/**
 * 删除敏感词
 */
export const deleteSensitiveWordApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/admin/community/sensitive-words/${id}`
  })
}

/**
 * 批量导入敏感词
 */
export const batchImportSensitiveWordsApi = (data: BatchImportSensitiveWordsDto) => {
  return request.post<BatchImportResult>({
    url: `${BASE_URL}/admin/community/sensitive-words/batch`,
    data
  })
}
