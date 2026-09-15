/**
 * 医生管理 API
 */

import request from '@/axios'
import type { PaginatedResponse } from '../types'
import type {
  Doctor,
  CreateDoctorParams,
  UpdateDoctorParams,
  QueryDoctorParams,
  DoctorStatistics,
  DoctorServiceItem,
  CreateServiceItemParams,
  UpdateServiceItemParams,
  BatchCreateServiceItemsParams
} from './types'

// 导出类型
export type {
  Doctor,
  CreateDoctorParams,
  UpdateDoctorParams,
  QueryDoctorParams,
  DoctorStatistics,
  DoctorServiceItem,
  CreateServiceItemParams,
  UpdateServiceItemParams,
  BatchCreateServiceItemsParams
}

const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 获取医生列表（支持分页和筛选）
 */
export const getDoctorListApi = (params: QueryDoctorParams) => {
  return request.get<PaginatedResponse<Doctor>>({
    url: `${BASE_URL}/doctors`,
    params
  })
}

/**
 * 获取医生详情
 */
export const getDoctorDetailApi = (id: number) => {
  return request.get<Doctor>({
    url: `${BASE_URL}/doctors/${id}`
  })
}

/**
 * 创建医生
 */
export const createDoctorApi = (data: CreateDoctorParams) => {
  return request.post<Doctor>({
    url: `${BASE_URL}/doctors`,
    data
  })
}

/**
 * 更新医生信息
 */
export const updateDoctorApi = (id: number, data: UpdateDoctorParams) => {
  return request.put<Doctor>({
    url: `${BASE_URL}/doctors/${id}`,
    data
  })
}

/**
 * 删除医生
 */
export const deleteDoctorApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/doctors/${id}`
  })
}

/**
 * 获取医生统计信息
 */
export const getDoctorStatisticsApi = () => {
  return request.get<DoctorStatistics>({
    url: `${BASE_URL}/doctors/statistics`
  })
}

/**
 * 按医院获取医生列表
 */
export const getDoctorsByHospitalApi = (hospitalId: number) => {
  return request.get<Doctor[]>({
    url: `${BASE_URL}/doctors/hospital/${hospitalId}`
  })
}

/**
 * 按科室获取医生列表
 */
export const getDoctorsByDepartmentApi = (departmentId: number) => {
  return request.get<Doctor[]>({
    url: `${BASE_URL}/doctors/department/${departmentId}`
  })
}

// ========== 收费项管理 API ==========

/**
 * 获取医生的收费项列表
 */
export const getDoctorServiceItemsApi = (doctorId: number) => {
  return request.get<DoctorServiceItem[]>({
    url: `${BASE_URL}/doctors/${doctorId}/service-items`
  })
}

/**
 * 添加收费项
 */
export const addServiceItemApi = (doctorId: number, data: CreateServiceItemParams) => {
  return request.post<DoctorServiceItem>({
    url: `${BASE_URL}/doctors/${doctorId}/service-items`,
    data
  })
}

/**
 * 批量添加收费项
 */
export const batchAddServiceItemsApi = (doctorId: number, data: BatchCreateServiceItemsParams) => {
  return request.post<DoctorServiceItem[]>({
    url: `${BASE_URL}/doctors/${doctorId}/service-items/batch`,
    data
  })
}

/**
 * 更新收费项
 */
export const updateServiceItemApi = (
  doctorId: number,
  itemId: number,
  data: UpdateServiceItemParams
) => {
  return request.put<DoctorServiceItem>({
    url: `${BASE_URL}/doctors/${doctorId}/service-items/${itemId}`,
    data
  })
}

/**
 * 删除收费项
 */
export const deleteServiceItemApi = (doctorId: number, itemId: number) => {
  return request.delete({
    url: `${BASE_URL}/doctors/${doctorId}/service-items/${itemId}`
  })
}
