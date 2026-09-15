/**
 * 健康知识模块类型定义
 */

/**
 * 文章状态
 */
export type ArticleStatus = 'DRAFT' | 'PUBLISHED'

/**
 * 健康知识分类
 */
export interface HealthCategory {
  id: number
  name: string
  icon?: string
  sortOrder: number
  isActive: boolean
  articleCount: number
  createdAt: string
  updatedAt: string
}

/**
 * 健康知识文章
 */
export interface HealthArticle {
  id: number
  title: string
  summary: string
  content: string
  coverImage?: string
  categoryId: number
  category?: HealthCategory
  status: ArticleStatus
  publishedAt?: string
  viewCount: number
  favoriteCount: number
  likeCount: number
  authorId: number
  createdAt: string
  updatedAt: string
}

/**
 * 分类查询参数
 */
export interface CategoryQueryParams {
  page?: number
  pageSize?: number
  name?: string
  isActive?: boolean
  sortBy?: string
  sortOrder?: 'ASC' | 'DESC'
}

/**
 * 分类创建参数
 */
export interface CategoryCreateParams {
  name: string
  icon?: string
  sortOrder?: number
  isActive?: boolean
}

/**
 * 分类更新参数
 */
export type CategoryUpdateParams = Partial<CategoryCreateParams>

/**
 * 文章查询参数
 */
export interface ArticleQueryParams {
  page?: number
  pageSize?: number
  keyword?: string
  categoryId?: number
  status?: ArticleStatus
  sortBy?: string
  sortOrder?: 'ASC' | 'DESC'
}

/**
 * 文章创建参数
 */
export interface ArticleCreateParams {
  title: string
  summary: string
  content: string
  coverImage?: string
  categoryId: number
  status?: ArticleStatus
}

/**
 * 文章更新参数
 */
export type ArticleUpdateParams = Partial<ArticleCreateParams>
