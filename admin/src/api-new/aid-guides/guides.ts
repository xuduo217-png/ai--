/**
 * 急救指南 API
 */

import request from '@/axios'
import type { AidGuide, CreateGuideParams, UpdateGuideParams, GuideQueryParams } from './types'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 获取指南列表
 */
export const getGuideListApi = (params: GuideQueryParams) => {
  return request.get({
    url: `${BASE_URL}/aid-guides`,
    params
  })
}

/**
 * 获取指南详情
 */
export const getGuideDetailApi = (id: number) => {
  return request.get<AidGuide>({
    url: `${BASE_URL}/aid-guides/${id}`
  })
}

/**
 * 创建指南
 */
export const createGuideApi = (data: CreateGuideParams) => {
  return request.post<AidGuide>({
    url: `${BASE_URL}/aid-guides`,
    data
  })
}

/**
 * 更新指南
 */
export const updateGuideApi = (id: number, data: UpdateGuideParams) => {
  return request.put<AidGuide>({
    url: `${BASE_URL}/aid-guides/${id}`,
    data
  })
}

/**
 * 切换指南发布状态
 */
export const toggleGuideStatusApi = (id: number) => {
  return request.patch<AidGuide>({
    url: `${BASE_URL}/aid-guides/${id}/status`
  })
}

/**
 * 删除指南
 */
export const deleteGuideApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/aid-guides/${id}`
  })
}
