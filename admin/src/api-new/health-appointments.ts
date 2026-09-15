/**
 * 健康预约管理 API
 */

import request from '@/axios'
import type { PaginatedResponse } from './types'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 健康预约类型
 */
export enum HealthAppointmentType {
  VACCINE = 'vaccine', // 疫苗接种
  DEWORMING = 'deworming', // 驱虫
  CHECKUP = 'checkup' // 体检
}

/**
 * 健康预约状态
 */
export enum HealthAppointmentStatus {
  PENDING = 'pending', // 待确认
  CONFIRMED = 'confirmed', // 已确认
  COMPLETED = 'completed', // 已完成
  CANCELLED = 'cancelled' // 已取消
}

/**
 * 健康预约类型标签映射
 */
export const HealthAppointmentTypeLabel: Record<HealthAppointmentType, string> = {
  [HealthAppointmentType.VACCINE]: '疫苗接种',
  [HealthAppointmentType.DEWORMING]: '驱虫',
  [HealthAppointmentType.CHECKUP]: '体检'
}

/**
 * 健康预约状态标签映射
 */
export const HealthAppointmentStatusLabel: Record<HealthAppointmentStatus, string> = {
  [HealthAppointmentStatus.PENDING]: '待确认',
  [HealthAppointmentStatus.CONFIRMED]: '已确认',
  [HealthAppointmentStatus.COMPLETED]: '已完成',
  [HealthAppointmentStatus.CANCELLED]: '已取消'
}

/**
 * 健康预约类型定义
 */
export interface HealthAppointment {
  id: number
  type: HealthAppointmentType
  status: HealthAppointmentStatus
  appointmentDate: string
  timeSlot: string
  petId: number
  hospitalId: number
  userId: number
  doctorId?: number
  notes?: string
  operationContent?: string // 本次操作内容（已完成预约时显示）
  detailContent?: string // 详情内容（已完成预约时显示，支持富文本）
  pet?: {
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
  user?: {
    id: number
    username: string
    phone: string
    avatar?: string
  }
  hospital?: {
    id: number
    name: string
  }
  doctor?: {
    id: number
    name: string
    phone: string
    avatar?: string
  }
  createdAt: string
  updatedAt: string
}

/**
 * 查询健康预约列表参数
 */
export interface QueryHealthAppointmentsParams {
  page?: number
  pageSize?: number
  sortOrder?: 'ASC' | 'DESC'
  sortBy?: string
  petId?: number
  petName?: string // 宠物名称（模糊搜索）
  ownerPhone?: string // 主人手机号（精确匹配）
  type?: HealthAppointmentType
  status?: HealthAppointmentStatus
  hospitalId?: number
}

/**
 * 完成预约参数
 */
export interface CompleteAppointmentParams {
  nextAppointmentDate?: string // 下次预约日期（可选）
  operationContent?: string // 本次操作内容（可选）
  detailContent?: string // 详情内容（可选，支持富文本）
  notes?: string // 备注（可选）
}

/**
 * 获取健康预约列表（分页、筛选）
 */
export const getHealthAppointmentListApi = (params: QueryHealthAppointmentsParams) => {
  return request.get<PaginatedResponse<HealthAppointment>>({
    url: `${BASE_URL}/health-appointments`,
    params
  })
}

/**
 * 获取健康预约详情
 */
export const getHealthAppointmentDetailApi = (id: number) => {
  return request.get<HealthAppointment>({
    url: `${BASE_URL}/health-appointments/${id}`
  })
}

/**
 * 获取指定宠物的健康预约列表
 */
export const getPetHealthAppointmentsApi = (
  petId: number,
  params?: Partial<QueryHealthAppointmentsParams>
) => {
  return request.get<PaginatedResponse<HealthAppointment>>({
    url: `${BASE_URL}/health-appointments/pet/${petId}`,
    params
  })
}

/**
 * 更新健康预约状态（用于确认预约）
 */
export const updateHealthAppointmentStatusApi = (
  id: number,
  data: { status: HealthAppointmentStatus; doctorId?: number }
) => {
  return request.patch<HealthAppointment>({
    url: `${BASE_URL}/health-appointments/${id}/status`,
    data
  })
}

/**
 * 完成健康预约（可设置下次预约时间）
 */
export const completeHealthAppointmentApi = (id: number, data: CompleteAppointmentParams) => {
  return request.patch<HealthAppointment>({
    url: `${BASE_URL}/health-appointments/${id}/complete`,
    data
  })
}

/**
 * 取消健康预约
 */
export const cancelHealthAppointmentApi = (id: number) => {
  return request.patch<HealthAppointment>({
    url: `${BASE_URL}/health-appointments/${id}/cancel`
  })
}

/**
 * 删除健康预约（软删除）
 */
export const deleteHealthAppointmentApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/health-appointments/${id}`
  })
}
