import request from '@/axios'
import type { PaginatedResponse } from '../types'
import type { ProductCategory } from './types'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 商品分类管理 API
 */

/**
 * 获取分类列表（支持树形结构）
 */
export const getCategoryListApi = (params?: {
  status?: string
  parentId?: number | null
  includeChildren?: boolean
  page?: number
  limit?: number
}) => {
  return request.get<PaginatedResponse<ProductCategory> | ProductCategory[]>({
    url: `${BASE_URL}/shop/categories`,
    params
  })
}

/**
 * 获取分类详情
 */
export const getCategoryDetailApi = (id: number) => {
  return request.get<ProductCategory>({
    url: `${BASE_URL}/shop/categories/${id}`
  })
}

/**
 * 获取分类路径（从根到当前分类）
 */
export const getCategoryPathApi = (id: number) => {
  return request.get<ProductCategory[]>({
    url: `${BASE_URL}/shop/categories/${id}/path`
  })
}

/**
 * 创建商品分类
 */
export const createCategoryApi = (data: Partial<ProductCategory>) => {
  return request.post<ProductCategory>({
    url: `${BASE_URL}/shop/categories`,
    data
  })
}

/**
 * 更新商品分类
 */
export const updateCategoryApi = (id: number, data: Partial<ProductCategory>) => {
  return request.put<ProductCategory>({
    url: `${BASE_URL}/shop/categories/${id}`,
    data
  })
}

/**
 * 更新分类排序
 */
export const updateCategorySortApi = (id: number, sortOrder: number) => {
  return request.put<ProductCategory>({
    url: `${BASE_URL}/shop/categories/${id}/sort`,
    data: { sortOrder }
  })
}

/**
 * 删除商品分类
 */
export const deleteCategoryApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/shop/categories/${id}`
  })
}
