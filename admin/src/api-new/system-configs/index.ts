/**
 * 系统配置 API
 */

import request from '@/axios'
import type { PaginatedResponse } from '../types'
import type {
  SystemConfig,
  SystemConfigQueryParams,
  CreateSystemConfigParams,
  UpdateSystemConfigParams,
  ScrollingAnnouncementValue,
  MallHomePopupImageValue
} from './types'

// 导出类型
export type {
  SystemConfig,
  SystemConfigQueryParams,
  CreateSystemConfigParams,
  UpdateSystemConfigParams,
  ScrollingAnnouncementValue,
  MallHomePopupImageValue
}

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 获取所有配置列表（管理员，支持分页）
 */
export const getSystemConfigsApi = (params: SystemConfigQueryParams) => {
  return request.get<PaginatedResponse<SystemConfig>>({
    url: `${BASE_URL}/system-configs`,
    params
  })
}

/**
 * 根据 configKey 获取配置
 */
export const getSystemConfigApi = (key: string) => {
  return request.get<SystemConfig>({
    url: `${BASE_URL}/system-configs/${key}`
  })
}

/**
 * 创建新配置（管理员）
 */
export const createSystemConfigApi = (data: CreateSystemConfigParams) => {
  return request.post<SystemConfig>({
    url: `${BASE_URL}/system-configs`,
    data
  })
}

/**
 * 更新配置（管理员）
 */
export const updateSystemConfigApi = (key: string, data: UpdateSystemConfigParams) => {
  return request.put<SystemConfig>({
    url: `${BASE_URL}/system-configs/${key}`,
    data
  })
}

/**
 * 删除配置（管理员）
 */
export const deleteSystemConfigApi = (key: string) => {
  return request.delete({
    url: `${BASE_URL}/system-configs/${key}`
  })
}

/**
 * 系统配置 API 统一导出对象
 */
export const systemConfigApi = {
  getSystemConfigsApi,
  getSystemConfigApi,
  createSystemConfigApi,
  updateSystemConfigApi,
  deleteSystemConfigApi
}
