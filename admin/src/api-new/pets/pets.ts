/**
 * 宠物管理 API
 */

import request from '@/axios'
import type { PaginatedResponse } from '../types'
import type { Pet, PetQueryParams, PetCreateParams, PetUpdateParams } from './types'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 获取宠物列表（支持分页和筛选）
 */
export const getPetListApi = (params: PetQueryParams) => {
  return request.get<PaginatedResponse<Pet>>({
    url: `${BASE_URL}/pets`,
    params
  })
}

/**
 * 获取宠物详情
 */
export const getPetDetailApi = (id: number) => {
  return request.get<Pet>({
    url: `${BASE_URL}/pets/${id}`
  })
}

/**
 * 创建宠物
 */
export const createPetApi = (data: PetCreateParams) => {
  return request.post<Pet>({
    url: `${BASE_URL}/pets`,
    data
  })
}

/**
 * 更新宠物
 */
export const updatePetApi = (id: number, data: PetUpdateParams) => {
  return request.put<Pet>({
    url: `${BASE_URL}/pets/${id}`,
    data
  })
}

/**
 * 删除宠物
 */
export const deletePetApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/pets/${id}`
  })
}
