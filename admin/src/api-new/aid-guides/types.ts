/**
 * 急救指南相关类型定义
 */

/**
 * 急救指南分类
 */
export interface AidCategory {
  id: number
  name: string
  icon?: string
  sortOrder: number
  isActive: boolean
  guideCount: number
  createdAt: string
  updatedAt: string
}

/**
 * 急救指南
 */
export interface AidGuide {
  id: number
  title: string
  icon?: string
  content: string
  categoryId: number
  category?: AidCategory
  status: 'DRAFT' | 'PUBLISHED'
  sortOrder: number
  publishedAt?: string
  authorId: number
  createdAt: string
  updatedAt: string
}

/**
 * 创建分类参数
 */
export interface CreateCategoryParams {
  name: string
  icon?: string
  sortOrder?: number
  isActive?: boolean
}

/**
 * 更新分类参数
 */
export type UpdateCategoryParams = Partial<CreateCategoryParams>

/**
 * 查询分类参数
 */
export interface CategoryQueryParams {
  page?: number
  pageSize?: number
  isActive?: boolean
  keyword?: string
}

/**
 * 创建指南参数
 */
export interface CreateGuideParams {
  title: string
  icon?: string
  content: string
  categoryId: number
  sortOrder?: number
  status?: 'DRAFT' | 'PUBLISHED'
}

/**
 * 更新指南参数
 */
export type UpdateGuideParams = Partial<CreateGuideParams>

/**
 * 查询指南参数
 */
export interface GuideQueryParams {
  page?: number
  pageSize?: number
  categoryId?: number
  status?: 'DRAFT' | 'PUBLISHED'
  keyword?: string
}
