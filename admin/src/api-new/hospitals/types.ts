/**
 * 医院相关类型定义
 */

/**
 * 医院状态
 * 这里与后端 HospitalStatus 枚举保持一致，避免筛选参数失配。
 */
export type HospitalStatus = 'active' | 'inactive' | 'suspended'

/**
 * 医院信息
 */
export interface Hospital {
  id: number
  name: string
  logo?: string
  description?: string
  province: string
  city: string
  county: string
  address: string
  phone: string
  email?: string
  latitude?: number // 纬度
  longitude?: number // 经度
  facilities?: string // 设施（字符串，逗号分隔）
  status?: HospitalStatus
  isActive: boolean
  createdAt: string
  updatedAt: string
}

/**
 * 医院查询参数
 */
export interface HospitalQueryParams {
  page?: number
  pageSize?: number
  sortBy?: string
  sortOrder?: 'ASC' | 'DESC'
  name?: string
  city?: string
  province?: string
  status?: HospitalStatus
  minRating?: number
  maxRating?: number
  keyword?: string
  isActive?: boolean
}

/**
 * 医院创建参数
 */
export interface HospitalCreateParams {
  name: string
  logo?: string
  description?: string
  province: string
  city: string
  county: string
  address: string
  phone: string
  email?: string
  latitude?: number
  longitude?: number
  facilities?: string
  isActive?: boolean
}

/**
 * 医院更新参数
 */
export interface HospitalUpdateParams extends Partial<HospitalCreateParams> {
  id: number
}
