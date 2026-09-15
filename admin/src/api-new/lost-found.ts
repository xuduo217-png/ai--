/**
 * 走失招领管理 API
 */

import request from '@/axios'
import type { PaginatedResponse } from './types'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 信息类型
 */
export type LostFoundRecordType = 'LOST' | 'ADOPTION'

/**
 * 宠物信息
 */
export interface PetInfo {
  id: number
  name: string
  avatar?: string
  category?: {
    id: number
    name: string
  }
  subCategory?: {
    id: number
    name: string
  }
}

/**
 * 发布者信息
 */
export interface PublisherInfo {
  id: number
  username: string
  phone?: string
  avatar?: string
}

/**
 * 走失信息
 */
export interface LostFound {
  id: number
  petId: number | null
  pet: PetInfo | null
  petName?: string
  petCategory?: string
  petBreed?: string
  publisherId: number
  publisher: PublisherInfo
  publisherType: 'USER' | 'ADMIN'
  recordType: LostFoundRecordType
  contactName: string
  contactPhone: string
  description: string
  images?: string[]
  video?: string | null
  videoCover?: string | null
  isPinned: boolean
  isFound: boolean
  foundAt?: string
  createdAt: string
  updatedAt: string
}

/**
 * 查询参数
 */
export interface LostFoundQueryParams {
  page?: number
  pageSize?: number
  recordType?: LostFoundRecordType
  isFound?: boolean
  isPinned?: boolean
  petId?: number
  publisherId?: number
  keyword?: string
}

/**
 * 创建参数
 */
export interface LostFoundCreateParams {
  petId?: number | null
  petName?: string
  petCategory?: string
  petBreed?: string
  recordType?: LostFoundRecordType
  contactName: string
  contactPhone: string
  description: string
  images?: string[]
  video?: string
  videoCover?: string
}

/**
 * 更新参数
 */
export interface LostFoundUpdateParams {
  petId?: number | null
  petName?: string
  petCategory?: string
  petBreed?: string
  recordType?: LostFoundRecordType
  contactName?: string
  contactPhone?: string
  description?: string
  images?: string[]
  video?: string
  videoCover?: string
}

/**
 * 获取走失信息列表（支持分页和筛选）
 */
export const getLostFoundListApi = (params: LostFoundQueryParams) => {
  return request.get<PaginatedResponse<LostFound>>({
    url: `${BASE_URL}/lost-found`,
    params
  })
}

/**
 * 获取走失信息详情
 */
export const getLostFoundDetailApi = (id: number) => {
  return request.get<LostFound>({
    url: `${BASE_URL}/lost-found/${id}`
  })
}

/**
 * 创建走失信息（管理员可用）
 */
export const createLostFoundApi = (data: LostFoundCreateParams) => {
  return request.post<LostFound>({
    url: `${BASE_URL}/lost-found`,
    data
  })
}

/**
 * 更新走失信息
 */
export const updateLostFoundApi = (id: number, data: LostFoundUpdateParams) => {
  return request.put<LostFound>({
    url: `${BASE_URL}/lost-found/${id}`,
    data
  })
}

/**
 * 设置/取消置顶（管理员专用）
 */
export const toggleLostFoundPinApi = (id: number) => {
  return request.patch<LostFound>({
    url: `${BASE_URL}/lost-found/${id}/pin`
  })
}

/**
 * 标记已找回
 */
export const markLostFoundAsFoundApi = (id: number) => {
  return request.patch<LostFound>({
    url: `${BASE_URL}/lost-found/${id}/found`
  })
}

/**
 * 删除走失信息
 */
export const deleteLostFoundApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/lost-found/${id}`
  })
}
