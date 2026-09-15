/**
 * 医院管理 API
 */

import request from '@/axios'
import type {
  Hospital,
  HospitalStatus,
  HospitalQueryParams,
  HospitalCreateParams,
  HospitalUpdateParams
} from './types'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 将管理端查询参数对齐到后端 DTO。
 * 兼容旧调用里的 `keyword` 和 `isActive`，避免医院筛选静默失效。
 */
const normalizeHospitalQueryParams = (params: HospitalQueryParams = {}) => {
  const { keyword, isActive, name, status, ...restParams } = params

  const normalizedStatus: HospitalStatus | undefined =
    status ?? (typeof isActive === 'boolean' ? (isActive ? 'active' : 'inactive') : undefined)

  const normalizedParams = {
    ...restParams,
    name: name ?? keyword,
    status: normalizedStatus
  }

  return Object.fromEntries(
    Object.entries(normalizedParams).filter(
      ([, value]) => value !== undefined && value !== null && value !== ''
    )
  )
}

/**
 * 获取医院列表（支持分页和筛选）
 * 列表数据位于统一响应的 `data` 字段中，分页信息位于顶层 `pagination`。
 */
export const getHospitalListApi = (params: HospitalQueryParams) => {
  return request.get<Hospital[]>({
    url: `${BASE_URL}/hospitals`,
    params: normalizeHospitalQueryParams(params)
  })
}

/**
 * 获取医院详情
 */
export const getHospitalDetailApi = (id: number) => {
  return request.get<Hospital>({
    url: `${BASE_URL}/hospitals/${id}`
  })
}

/**
 * 创建医院
 */
export const createHospitalApi = (data: HospitalCreateParams) => {
  return request.post<Hospital>({
    url: `${BASE_URL}/hospitals`,
    data
  })
}

/**
 * 更新医院
 */
export const updateHospitalApi = (id: number, data: HospitalUpdateParams) => {
  return request.put<Hospital>({
    url: `${BASE_URL}/hospitals/${id}`,
    data
  })
}

/**
 * 删除医院
 */
export const deleteHospitalApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/hospitals/${id}`
  })
}

/**
 * 获取医院统计信息
 */
export const getHospitalStatisticsApi = () => {
  return request.get({
    url: `${BASE_URL}/hospitals/statistics`
  })
}

/**
 * 医院管理 API 统一导出对象
 * 用于按命名空间方式导入所有医院相关 API
 */
export const hospitalApi = {
  getHospitalListApi,
  getHospitalDetailApi,
  createHospitalApi,
  updateHospitalApi,
  deleteHospitalApi,
  getHospitalStatisticsApi
}
