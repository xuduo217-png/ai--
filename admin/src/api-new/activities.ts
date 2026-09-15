/**
 * 活动管理 API（Admin 端）
 */

import request from '@/axios'
import type { Hospital } from './hospitals'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 活动状态
 */
export type ActivityStatus = 'UPCOMING' | 'ONGOING' | 'EXPIRED'

/**
 * 删除状态筛选
 */
export type ActivityDeleteStatus = 'active' | 'deleted' | 'all'

/**
 * 活动类型：线下（OFFLINE）/ 线上投票（ONLINE）
 */
export type ActivityType = 'OFFLINE' | 'ONLINE'

/**
 * 活动列表/详情项
 */
export interface ActivityItem {
  id: number
  title: string
  startTime: number
  endTime: number
  location: string
  summary: string
  description: string
  coverImage?: string
  sharePosterImage?: string
  sharePosterTitle?: string
  sharePosterDescription?: string
  showOnHome?: boolean
  hospitalId: number
  activityType: ActivityType
  voteOptions?: ActivityVoteOption[]
  registrationCount?: number
  commentCount?: number
  status?: ActivityStatus
  deletedAt?: string | null
  hospitalName?: string
  hospitalData?: Pick<Hospital, 'id' | 'name' | 'logo' | 'city' | 'address' | 'phone'>
  hospital?: Pick<Hospital, 'id' | 'name' | 'logo' | 'city' | 'address' | 'phone'>
  isRegistered?: boolean
  canRegister?: boolean
  createdAt: number
  updatedAt: number
}

/**
 * 线上投票选手
 */
export interface ActivityVoteOption {
  id?: number
  activityId?: number
  image: string
  video?: string
  videoCover?: string
  title: string
  description?: string
  voteCount?: number
  sortOrder?: number
  ownerUserId?: number | null
}

/**
 * 活动表单数据
 */
export interface ActivityFormData {
  title: string
  startTime: string
  endTime: string
  location?: string
  summary: string
  description: string
  coverImage?: string
  sharePosterImage?: string
  sharePosterTitle?: string
  sharePosterDescription?: string
  showOnHome?: boolean
  hospitalId: number
  activityType: ActivityType
  voteOptions?: ActivityVoteOption[]
}

/**
 * 活动报名记录
 */
export interface ActivityRegistration {
  id: number
  activityId: number
  userId: number
  phone: string
  voteOptionId?: number
  // MySQL bigint values may be serialized as numeric strings by the API.
  registeredAt: number | string
  userName?: string
  userAvatar?: string
}

/**
 * 活动评论
 */
export interface ActivityComment {
  id: number
  activityId: number
  userId: number
  content: string
  parentId?: number | null
  likeCount: number
  createdAt: string
  user?: {
    id: number
    nickname: string
    avatar?: string | null
  }
  replies?: ActivityComment[]
}

/**
 * 获取活动列表（管理员）
 */
export const getActivityListAdminApi = (params?: {
  hospitalId?: number
  startDate?: string
  status?: ActivityStatus
  deleteStatus?: ActivityDeleteStatus
  showOnHome?: boolean
  keyword?: string
  page?: number
  pageSize?: number
}) => {
  return request.get<ActivityItem[]>({
    url: `${BASE_URL}/activities/admin/list`,
    params
  })
}

/**
 * 获取活动详情
 */
export const getActivityDetailAdminApi = (id: number) => {
  return request
    .get<ActivityItem>({
      // 后端当前未提供 /activities/admin/:id，管理端回显复用现有详情接口以规避 404。
      url: `${BASE_URL}/activities/app/${id}`
    })
    .then((response) => {
      const activity = response.data

      if (activity?.hospital && !activity.hospitalData) {
        activity.hospitalData = {
          id: activity.hospital.id,
          name: activity.hospital.name,
          logo: activity.hospital.logo,
          city: activity.hospital.city,
          address: activity.hospital.address,
          phone: activity.hospital.phone
        }
      }

      if (activity?.hospital && !activity.hospitalName) {
        activity.hospitalName = activity.hospital.name
      }

      return response
    })
}

/**
 * 创建活动
 */
export const createActivityApi = (data: ActivityFormData) => {
  return request.post({
    url: `${BASE_URL}/activities/admin`,
    data
  })
}

/**
 * 更新活动
 */
export const updateActivityApi = (id: number, data: Partial<ActivityFormData>) => {
  return request.put({
    url: `${BASE_URL}/activities/admin/${id}`,
    data
  })
}

/**
 * 删除活动
 */
export const deleteActivityApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/activities/admin/${id}`
  })
}

/**
 * 获取活动的报名用户列表（管理员）
 */
export const getActivityRegistrationsApi = (
  id: number,
  params?: {
    page?: number
    pageSize?: number
    voteOptionId?: number
  }
) => {
  return request.get<ActivityRegistration[]>({
    url: `${BASE_URL}/activities/admin/${id}/registrations`,
    params
  })
}

/**
 * 获取活动评论列表（管理员）
 */
export const getActivityCommentsAdminApi = (
  id: number,
  params?: {
    page?: number
    pageSize?: number
  }
) => {
  return request.get<ActivityComment[]>({
    url: `${BASE_URL}/activities/admin/${id}/comments`,
    params
  })
}

/**
 * 删除活动评论（管理员）
 */
export const deleteActivityCommentAdminApi = (commentId: number) => {
  return request.delete<{ deletedCount: number }>({
    url: `${BASE_URL}/activities/admin/comments/${commentId}`
  })
}

/**
 * 获取活动参与者列表（管理员，线下为报名，线上为投票）
 */
export const getActivityParticipantsApi = (
  id: number,
  params?: {
    page?: number
    pageSize?: number
    voteOptionId?: number
  }
) => {
  return request.get<ActivityRegistration[]>({
    url: `${BASE_URL}/activities/admin/${id}/registrations`,
    params
  })
}

/**
 * 兼容旧名称：线上活动旧的“打卡记录”入口，现在统一返回参与者列表
 */
export const getActivityCheckInsApi = (
  id: number,
  params?: {
    page?: number
    pageSize?: number
  }
) => {
  return getActivityParticipantsApi(id, params)
}
