/**
 * 系统文章 API
 */
import request from '@/axios'

// API 基础路径
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 文章类型枚举
 */
export enum ArticleType {
  ABOUT_US = 'about_us', // 关于我们
  PRIVACY = 'privacy', // 隐私协议
  USER_AGREEMENT = 'user_agreement' // 用户协议
}

/**
 * 系统文章实体
 */
export interface SystemArticle {
  id: number // 主键ID
  type: ArticleType // 文章类型
  content: string // 文章内容(HTML)
  createdAt: string // 创建时间
  updatedAt: string // 更新时间
}

/**
 * 文章类型显示名称映射
 */
export const ArticleTypeLabels: Record<ArticleType, string> = {
  [ArticleType.ABOUT_US]: '关于我们',
  [ArticleType.PRIVACY]: '隐私协议',
  [ArticleType.USER_AGREEMENT]: '用户协议'
}

/**
 * 获取所有文章列表
 */
export const getSystemArticlesListApi = () => {
  return request.get<SystemArticle[]>({
    url: `${BASE_URL}/system-articles`
  })
}

/**
 * 根据类型获取文章
 */
export const getSystemArticleByTypeApi = (type: ArticleType) => {
  return request.get<SystemArticle>({
    url: `${BASE_URL}/system-articles/${type}`
  })
}

/**
 * 更新文章
 */
export const updateSystemArticleApi = (type: ArticleType, content: string) => {
  return request.put<SystemArticle>({
    url: `${BASE_URL}/system-articles/${type}`,
    data: { content }
  })
}

/**
 * 初始化文章（仅首次使用）
 */
export const initSystemArticlesApi = () => {
  return request.post<SystemArticle[]>({
    url: `${BASE_URL}/system-articles/init`
  })
}
