/**
 * 健康知识文章 API
 */

import request from '@/axios'
import type { PaginatedResponse } from '../types'
import type { HealthArticle, ArticleQueryParams, ArticleCreateParams } from './types'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 获取文章列表（支持分页和筛选）
 */
export const getArticleListApi = (params: ArticleQueryParams) => {
  return request.get<PaginatedResponse<HealthArticle>>({
    url: `${BASE_URL}/health-articles`,
    params
  })
}

/**
 * 获取文章详情
 */
export const getArticleDetailApi = (id: number) => {
  return request.get<HealthArticle>({
    url: `${BASE_URL}/health-articles/${id}`
  })
}

/**
 * 创建文章
 */
export const createArticleApi = (data: ArticleCreateParams) => {
  return request.post<HealthArticle>({
    url: `${BASE_URL}/health-articles`,
    data
  })
}

/**
 * 更新文章
 */
export const updateArticleApi = (id: number, data: ArticleCreateParams) => {
  return request.put<HealthArticle>({
    url: `${BASE_URL}/health-articles/${id}`,
    data
  })
}

/**
 * 删除文章
 */
export const deleteArticleApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/health-articles/${id}`
  })
}

/**
 * 发布文章
 */
export const publishArticleApi = (id: number) => {
  return request.post({
    url: `${BASE_URL}/health-articles/${id}/publish`
  })
}

/**
 * 取消发布文章
 */
export const unpublishArticleApi = (id: number) => {
  return request.post({
    url: `${BASE_URL}/health-articles/${id}/unpublish`
  })
}
