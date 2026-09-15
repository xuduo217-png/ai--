/**
 * 急救指南分类 API
 */

import request from '@/axios'
import type {
  AidCategory,
  CreateCategoryParams,
  UpdateCategoryParams,
  CategoryQueryParams
} from './types'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 获取分类列表
 */
export const getAidGuideCategoryListApi = (params: CategoryQueryParams) => {
  return request.get({
    url: `${BASE_URL}/aid-guides/categories`,
    params
  })
}

/**
 * 获取分类详情
 */
export const getAidGuideCategoryDetailApi = (id: number) => {
  return request.get<AidCategory>({
    url: `${BASE_URL}/aid-guides/categories/${id}`
  })
}

/**
 * 创建分类
 */
export const createAidGuideCategoryApi = (data: CreateCategoryParams) => {
  return request.post<AidCategory>({
    url: `${BASE_URL}/aid-guides/categories`,
    data
  })
}

/**
 * 更新分类
 */
export const updateAidGuideCategoryApi = (id: number, data: UpdateCategoryParams) => {
  return request.put<AidCategory>({
    url: `${BASE_URL}/aid-guides/categories/${id}`,
    data
  })
}

/**
 * 切换分类启用状态
 */
export const toggleCategoryStatusApi = (id: number) => {
  return request.patch<AidCategory>({
    url: `${BASE_URL}/aid-guides/categories/${id}/status`
  })
}

/**
 * 删除分类
 */
export const deleteAidGuideCategoryApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/aid-guides/categories/${id}`
  })
}
