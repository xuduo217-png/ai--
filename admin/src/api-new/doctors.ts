/**
 * 医生管理 API
 */

import request from '@/axios'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 医生状态
 */
export enum DoctorStatus {
  ACTIVE = 'active', // 在职
  INACTIVE = 'inactive', // 离职
  SUSPENDED = 'suspended' // 停职
}

/**
 * 医生接口定义
 */
export interface Doctor {
  id: number
  name: string
  phone: string
  specialty?: string
  title?: string
  introduction?: string
  avatar?: string
  status: DoctorStatus
  hospitalId?: number
  departmentId?: number
  hospital?: {
    id: number
    name: string
  }
  department?: {
    id: number
    name: string
  }
  createdAt: string
  updatedAt: string
}

/**
 * 查询医生列表参数
 */
export interface QueryDoctorsParams {
  page?: number
  pageSize?: number
  hospitalId?: number
  departmentId?: number
  status?: DoctorStatus
  keyword?: string
}

/**
 * 创建医生参数
 */
export interface CreateDoctorParams {
  // 账号信息（必填）
  username: string // 登录用户名
  password: string // 登录密码
  phone: string // 手机号

  // 基本信息
  name: string // 医生姓名
  avatar?: string // 头像 URL
  specialty: string // 专业领域/专长
  description?: string // 医生简介
  experience?: number // 从业经验（年）
  isGoldDoctor?: boolean // 是否为金牌医师

  // 关联信息（必填）
  hospitalId: number // 所属医院 ID
  departmentId: number // 所属科室 ID

  // 其他信息
  qualifications?: string // 资质证书
  tags?: string[] // 标签数组
  isActive?: boolean // 是否在职
}

/**
 * 更新医生参数（所有字段都是可选的）
 */
export type UpdateDoctorParams = Partial<
  Pick<
    CreateDoctorParams,
    | 'username'
    | 'password'
    | 'phone'
    | 'name'
    | 'avatar'
    | 'specialty'
    | 'description'
    | 'experience'
    | 'isGoldDoctor'
    | 'hospitalId'
    | 'departmentId'
    | 'qualifications'
    | 'tags'
    | 'isActive'
  > & {
    rating?: number // 评分（0-5）
    consultationCount?: number // 咨询次数
    lastLoginAt?: Date // 最后登录时间
  }
>

/**
 * 获取指定医院的医生列表
 */
export const getHospitalDoctorsApi = (hospitalId: number) => {
  return request.get<Doctor[]>({
    url: `${BASE_URL}/doctors/hospital/${hospitalId}`
  })
}

/**
 * 获取医生列表（分页、筛选）
 */
export const getDoctorListApi = (params: QueryDoctorsParams) => {
  return request.get({
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
export const createDoctorApi = (data: Partial<Doctor>) => {
  return request.post<Doctor>({
    url: `${BASE_URL}/doctors`,
    data
  })
}

/**
 * 更新医生信息
 */
export const updateDoctorApi = (id: number, data: Partial<Doctor>) => {
  return request.put<Doctor>({
    url: `${BASE_URL}/doctors/${id}`,
    data
  })
}

/**
 * 删除医生（软删除）
 */
export const deleteDoctorApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/doctors/${id}`
  })
}

// ========== 医生收费项相关类型 ==========

/**
 * 医生收费项
 */
export interface DoctorServiceItem {
  id: number
  doctorId: number
  name: string // 服务名称（如：图文咨询、电话咨询）
  duration: number // 服务时长（分钟）
  price: number // 服务价格（元）
  description?: string // 服务描述
  sortOrder: number // 排序序号（数字越小越靠前）
  isActive: boolean // 是否启用
  createdAt: string
  updatedAt: string
}

/**
 * 创建收费项参数
 */
export interface CreateServiceItemParams {
  name: string // 服务名称（如：图文咨询、电话咨询）
  duration: number // 服务时长（分钟）
  price: number // 服务价格（元）
  description?: string // 服务描述
  sortOrder?: number // 排序序号
  isActive?: boolean // 是否启用
}

/**
 * 更新收费项参数（所有字段都是可选的）
 */
export type UpdateServiceItemParams = Partial<CreateServiceItemParams>

// ========== 医生收费项相关 API ==========

/**
 * 获取医生的收费项列表
 */
export const getDoctorServiceItemsApi = (doctorId: number) => {
  return request.get<DoctorServiceItem[]>({
    url: `${BASE_URL}/doctors/${doctorId}/service-items`
  })
}

/**
 * 为医生添加收费项
 */
export const addServiceItemApi = (doctorId: number, data: CreateServiceItemParams) => {
  return request.post<DoctorServiceItem>({
    url: `${BASE_URL}/doctors/${doctorId}/service-items`,
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

/**
 * 批量创建收费项参数
 */
export interface BatchCreateServiceItemsParams {
  serviceItems: CreateServiceItemParams[] // 收费项列表
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
