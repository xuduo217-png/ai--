/**
 * 用户管理模块类型定义
 */

/**
 * 用户角色枚举
 */
export enum UserRole {
  SUPER_ADMIN = 'SUPER_ADMIN',
  HOSPITAL_ADMIN = 'HOSPITAL_ADMIN',
  STAFF = 'STAFF',
  DOCTOR = 'DOCTOR',
  USER = 'USER'
}

/**
 * 用户角色显示名称映射
 */
export const UserRoleLabel: Record<UserRole, string> = {
  [UserRole.SUPER_ADMIN]: '超级管理员',
  [UserRole.HOSPITAL_ADMIN]: '医院管理员',
  [UserRole.STAFF]: '员工',
  [UserRole.DOCTOR]: '医生',
  [UserRole.USER]: '普通用户'
}

/**
 * 用户信息
 */
export interface User {
  id: number
  username: string
  email?: string
  phone: string
  role: UserRole
  avatar?: string
  verified: boolean
  lastLoginAt?: string
  isActive: boolean
  hospitalId?: number
  hospital?: {
    id: number
    name: string
  }
  remarks?: string
  balance?: number
  pendingBalance?: number
  createdAt: string
  updatedAt: string
}

/**
 * 获取用户列表请求参数
 */
export interface GetUserListParams {
  page?: number
  pageSize?: number
  role?: UserRole
  phone?: string
  isActive?: boolean
  hospitalId?: number
}

/**
 * 更新用户信息请求
 */
export interface UpdateUserRequest {
  username?: string
  password?: string
  email?: string
  phone?: string
  role?: UserRole
  avatar?: string
  isActive?: boolean
  hospitalId?: number
  remarks?: string
}

/**
 * 创建用户请求
 */
export interface CreateUserRequest {
  username?: string
  password: string
  email?: string
  phone: string
  role?: UserRole
  avatar?: string
  hospitalId?: number
}

/**
 * 管理员重置用户密码请求
 */
export interface ResetUserPasswordRequest {
  id: number
  password: string
}

export type AdjustUserBalanceType = 'increase' | 'decrease'

export interface AdjustUserBalanceRequest {
  type: AdjustUserBalanceType
  amount: number
  remark?: string
}
