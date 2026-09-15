/**
 * 宠物类别管理 API
 */

import request from '@/axios'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 宠物类别类型定义
 */
export interface PetCategory {
  id: number
  name: string
  parentId: number | null
  sortOrder: number
  createdAt: string
  updatedAt: string
}

/**
 * 宠物类别树节点（带子分类）
 */
export interface PetCategoryTreeNode extends PetCategory {
  children?: PetCategoryTreeNode[]
}

/**
 * 查询参数
 */
export interface QueryPetCategoriesParams {
  name?: string // 分类名称（模糊搜索）
}

/**
 * 创建宠物类别参数
 */
export interface CreatePetCategoryParams {
  name: string
  parentId?: number | null
  sortOrder: number
}

/**
 * 更新宠物类别参数
 */
export interface UpdatePetCategoryParams {
  name?: string
  parentId?: number | null
  sortOrder?: number
}

/**
 * 获取分类树（支持搜索）
 */
export const getPetCategoryTreeApi = (params?: QueryPetCategoriesParams) => {
  return request.get<PetCategoryTreeNode[]>({
    url: `${BASE_URL}/pet-categories/tree`,
    params
  })
}

/**
 * 获取分类列表（平铺）
 */
export const getPetCategoryListApi = (params?: QueryPetCategoriesParams) => {
  return request.get<PetCategory[]>({
    url: `${BASE_URL}/pet-categories`,
    params
  })
}

/**
 * 获取分类详情
 */
export const getPetCategoryDetailApi = (id: number) => {
  return request.get<PetCategory>({
    url: `${BASE_URL}/pet-categories/${id}`
  })
}

/**
 * 创建宠物类别
 */
export const createPetCategoryApi = (data: CreatePetCategoryParams) => {
  return request.post<PetCategory>({
    url: `${BASE_URL}/pet-categories`,
    data
  })
}

/**
 * 更新宠物类别
 */
export const updatePetCategoryApi = (id: number, data: UpdatePetCategoryParams) => {
  return request.put<PetCategory>({
    url: `${BASE_URL}/pet-categories/${id}`,
    data
  })
}

/**
 * 删除宠物类别（级联删除子分类）
 */
export const deletePetCategoryApi = (id: number) => {
  return request.delete<{ affected: number }>({
    url: `${BASE_URL}/pet-categories/${id}`
  })
}
