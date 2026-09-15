/**
 * 健康知识分类 API
 */

import request from '@/axios'
import type { PaginatedResponse } from '../types'
import type { HealthCategory, CategoryQueryParams, CategoryCreateParams } from './types'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 获取分类列表（支持分页和筛选）
 */
export const getHealthCategoryListApi = (params: CategoryQueryParams) => {
  return request.get<PaginatedResponse<HealthCategory>>({
    url: `${BASE_URL}/health-articles/categories`,
    params
  })
}

/**
 * 获取所有分类（不分页，用于下拉选择）
 */
export const getAllHealthCategoriesApi = (params?: CategoryQueryParams) => {
  return getHealthCategoryListApi({
    page: 1,
    pageSize: 100,
    ...params
  })
}

/**
 * 获取分类详情
 */
export const getHealthCategoryDetailApi = (id: number) => {
  return request.get<HealthCategory>({
    url: `${BASE_URL}/health-articles/categories/${id}`
  })
}

/**
 * 创建分类
 */
export const createHealthCategoryApi = (data: CategoryCreateParams) => {
  return request.post<HealthCategory>({
    url: `${BASE_URL}/health-articles/categories`,
    data
  })
}

/**
 * 更新分类
 */
export const updateHealthCategoryApi = (id: number, data: CategoryCreateParams) => {
  return request.put<HealthCategory>({
    url: `${BASE_URL}/health-articles/categories/${id}`,
    data
  })
}

/**
 * 删除分类
 */
export const deleteHealthCategoryApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/health-articles/categories/${id}`
  })
}
