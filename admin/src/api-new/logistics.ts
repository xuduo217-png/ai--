/**
 * 物流管理 API
 */
import request from '@/axios'
import type { Logistics, LogisticsForm } from './types'

// 重新导出类型
export type { Logistics, LogisticsForm } from './types'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 获取物流公司列表
 */
export const getLogisticsListApi = () => {
  return request.get<Logistics[]>({
    url: `${BASE_URL}/logistics`
  })
}

/**
 * 获取启用的物流公司（用于下拉选择）
 */
export const getEnabledLogisticsApi = () => {
  return request.get<Logistics[]>({
    url: `${BASE_URL}/logistics/enabled`
  })
}

/**
 * 创建物流公司
 */
export const createLogisticsApi = (data: LogisticsForm) => {
  return request.post<Logistics>({
    url: `${BASE_URL}/logistics`,
    data
  })
}

/**
 * 更新物流公司
 */
export const updateLogisticsApi = (id: number, data: LogisticsForm) => {
  return request.put<Logistics>({
    url: `${BASE_URL}/logistics/${id}`,
    data
  })
}

/**
 * 删除物流公司
 */
export const deleteLogisticsApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/logistics/${id}`
  })
}

/**
 * 切换物流公司启用状态
 */
export const toggleLogisticsApi = (id: number) => {
  return request.patch<Logistics>({
    url: `${BASE_URL}/logistics/${id}/toggle`
  })
}
