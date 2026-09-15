/**
 * 科室管理 API 类型定义
 */

/**
 * 科室实体
 */
export interface Department {
  id: number
  hospitalId: number // 所属医院ID
  name: string
  description?: string
  isActive: boolean
  createdAt: string
  updatedAt: string
}

/**
 * 创建科室参数
 */
export interface CreateDepartmentParams {
  hospitalId: number // 所属医院ID（必填）
  name: string
  description?: string
  isActive?: boolean
}

/**
 * 更新科室参数
 */
export interface UpdateDepartmentParams {
  hospitalId?: number // 所属医院ID（可选）
  name?: string
  description?: string
  isActive?: boolean
}

/**
 * 查询科室参数
 */
export interface QueryDepartmentParams {
  hospitalId?: number // 按医院ID筛选（可选）
  page?: number
  pageSize?: number
  name?: string
  isActive?: boolean
}
