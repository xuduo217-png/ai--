/**
 * UGC 举报处理 API
 */

import request from '@/axios'

const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

export type ModerationReportTargetType =
  | 'COMMUNITY_POST'
  | 'COMMUNITY_COMMENT'
  | 'LOST_FOUND_RECORD'
  | 'LOST_FOUND_COMMENT'
  | 'ACTIVITY_COMMENT'
  | 'ACTIVITY_VOTE_OPTION'
  | 'SECOND_HAND_PRODUCT'
  | 'CHAT_MESSAGE'
  | 'USER'

export type ModerationReportReason =
  | 'HARASSMENT'
  | 'PORNOGRAPHY'
  | 'VIOLENCE'
  | 'FRAUD'
  | 'SPAM'
  | 'ILLEGAL'
  | 'MISINFORMATION'
  | 'OTHER'

export type ModerationReportStatus = 'PENDING' | 'PROCESSING' | 'RESOLVED' | 'REJECTED'

export type ModerationReportAction =
  | 'NONE'
  | 'CONTENT_REMOVED'
  | 'USER_WARNED'
  | 'USER_BLOCKED'
  | 'ACCOUNT_DISABLED'

export interface ModerationUserBrief {
  id: number
  nickname: string
  avatar?: string | null
}

export interface ReportTargetSnapshot {
  title?: string
  summary?: string
  images?: string[]
  author?: ModerationUserBrief
  metadata?: Record<string, unknown>
}

export interface UGCReport {
  id: number
  reporterId: number
  reporter?: ModerationUserBrief
  targetType: ModerationReportTargetType
  targetId: string
  targetUserId?: number | null
  targetUser?: ModerationUserBrief
  reason: ModerationReportReason
  description?: string | null
  targetSnapshot?: ReportTargetSnapshot | null
  status: ModerationReportStatus
  action: ModerationReportAction
  handledBy?: number | null
  handler?: ModerationUserBrief
  handlingRemark?: string | null
  handledAt?: string | null
  isOverdue?: boolean
  createdAt: string
  updatedAt: string
}

export interface QueryModerationReportsParams {
  page?: number
  pageSize?: number
  status?: ModerationReportStatus
  targetType?: ModerationReportTargetType
  reason?: ModerationReportReason
  startTime?: string
  endTime?: string
}

export interface ModerationReportListResponse {
  data: UGCReport[]
  total: number
  page: number
  pageSize: number
  totalPages: number
}

export const getModerationReportsApi = (params: QueryModerationReportsParams) => {
  return request.get<ModerationReportListResponse>({
    url: `${BASE_URL}/admin/moderation/reports`,
    params
  })
}

export const getModerationReportDetailApi = (id: number) => {
  return request.get<UGCReport>({
    url: `${BASE_URL}/admin/moderation/reports/${id}`
  })
}

export const updateModerationReportStatusApi = (
  id: number,
  data: {
    status: ModerationReportStatus
    remark?: string
  }
) => {
  return request.patch<UGCReport>({
    url: `${BASE_URL}/admin/moderation/reports/${id}/status`,
    data
  })
}

export const handleModerationReportActionApi = (
  id: number,
  data: {
    action: ModerationReportAction
    remark?: string
  }
) => {
  return request.post<UGCReport>({
    url: `${BASE_URL}/admin/moderation/reports/${id}/actions`,
    data
  })
}
