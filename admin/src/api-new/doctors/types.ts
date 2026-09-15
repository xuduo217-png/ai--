/**
 * 医生管理 API 类型定义
 */

/**
 * 医生实体
 */
export interface Doctor {
  id: number
  // 账号信息
  username: string
  phone: string
  // 基本信息
  name: string
  avatar?: string
  specialty: string
  description?: string
  experience: number
  rating: number
  isGoldDoctor: boolean
  consultationCount: number
  isActive: boolean
  lastLoginAt?: string
  // 关联信息
  hospitalId: number
  hospital?: Hospital
  departmentId: number
  department?: Department
  // 其他信息
  qualifications?: string
  tags?: string[]
  // 时间戳
  createdAt: string
  updatedAt: string
}

/**
 * 医院
 */
export interface Hospital {
  id: number
  name: string
  address?: string
  logo?: string
}

/**
 * 科室
 */
export interface Department {
  id: number
  name: string
  description?: string
}

/**
 * 创建医生参数
 */
export interface CreateDoctorParams {
  // 账号信息（必填）
  username: string
  password: string
  phone: string
  // 基本信息（必填）
  name: string
  specialty: string
  // 基本信息（可选）
  avatar?: string
  description?: string
  experience?: number
  isGoldDoctor?: boolean
  // 关联信息（必填）
  hospitalId: number
  departmentId: number
  // 其他信息（可选）
  qualifications?: string
  tags?: string[]
  isActive?: boolean
}

/**
 * 更新医生参数
 */
export interface UpdateDoctorParams {
  // 账号信息
  username?: string
  password?: string // 如果需要修改密码
  phone?: string
  // 基本信息
  name?: string
  avatar?: string
  specialty?: string
  description?: string
  experience?: number
  rating?: number
  isGoldDoctor?: boolean
  consultationCount?: number
  isActive?: boolean
  lastLoginAt?: string
  // 关联信息
  hospitalId?: number
  departmentId?: number
  // 其他信息
  qualifications?: string
  tags?: string[]
}

/**
 * 查询医生参数
 */
export interface QueryDoctorParams {
  page?: number
  pageSize?: number
  name?: string
  phone?: string
  specialty?: string
  hospitalId?: number
  departmentId?: number
  isGoldDoctor?: boolean
  isActive?: boolean
  minRating?: number
  minExperience?: number
  sortBy?: 'createdAt' | 'updatedAt' | 'name' | 'rating' | 'experience' | 'consultationCount'
}

/**
 * 医生统计信息
 */
export interface DoctorStatistics {
  totalDoctors: number
  avgRating: string
  totalConsultations: number
  activeDoctors: number
  goldDoctors: number
  byDepartment: {
    departmentName: string
    count: number
  }[]
}

/**
 * 医生收费项
 */
export interface DoctorServiceItem {
  id: number
  doctorId: number
  name: string
  duration: number
  price: number
  description?: string
  sortOrder: number
  isActive: boolean
  createdAt: string
  updatedAt: string
}

/**
 * 创建收费项参数
 */
export interface CreateServiceItemParams {
  name: string
  duration: number
  price: number
  description?: string
  sortOrder?: number
  isActive?: boolean
}

/**
 * 更新收费项参数
 */
export interface UpdateServiceItemParams {
  name?: string
  duration?: number
  price?: number
  description?: string
  sortOrder?: number
  isActive?: boolean
}

/**
 * 批量创建收费项参数
 */
export interface BatchCreateServiceItemsParams {
  serviceItems: CreateServiceItemParams[]
}
