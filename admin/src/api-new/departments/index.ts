/**
 * 科室管理 API
 */

import request from '@/axios'
import type { PaginatedResponse } from '../types'
import type {
  Department,
  CreateDepartmentParams,
  UpdateDepartmentParams,
  QueryDepartmentParams
} from './types'

// 导出类型
export type { Department, CreateDepartmentParams, UpdateDepartmentParams, QueryDepartmentParams }

const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 获取科室列表（支持分页和筛选）
 */
export const getDepartmentListApi = (params?: QueryDepartmentParams) => {
  return request.get<Department[] | PaginatedResponse<Department>>({
    url: `${BASE_URL}/departments`,
    params
  })
}

/**
 * 获取科室详情
 */
export const getDepartmentDetailApi = (id: number) => {
  return request.get<Department>({
    url: `${BASE_URL}/departments/${id}`
  })
}

/**
 * 创建科室
 */
export const createDepartmentApi = (data: CreateDepartmentParams) => {
  return request.post<Department>({
    url: `${BASE_URL}/departments`,
    data
  })
}

/**
 * 更新科室信息
 */
export const updateDepartmentApi = (id: number, data: UpdateDepartmentParams) => {
  return request.put<Department>({
    url: `${BASE_URL}/departments/${id}`,
    data
  })
}

/**
 * 删除科室
 */
export const deleteDepartmentApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/departments/${id}`
  })
}

/**
 * 科室管理 API 对象（统一导出）
 */
export const departmentApi = {
  getDepartmentListApi,
  getDepartmentDetailApi,
  createDepartmentApi,
  updateDepartmentApi,
  deleteDepartmentApi
}
