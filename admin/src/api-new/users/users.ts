/**
 * 用户管理 API
 */
import request from '@/axios'
import type {
  GetUserListParams,
  UpdateUserRequest,
  CreateUserRequest,
  ResetUserPasswordRequest,
  AdjustUserBalanceRequest,
  User
} from './types'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 创建用户
 * POST /users
 */
export const createUser = (data: CreateUserRequest) => {
  return request.post<User>({ url: `${BASE_URL}/users`, data })
}

/**
 * 获取用户列表（服务端分页）
 * GET /users
 * 支持分页和筛选，自动排除超级管理员用户
 * 注意：后端响应已被拦截器处理，data 是数组，pagination 包含分页信息
 */
export const getUserList = (params?: GetUserListParams) => {
  return request.get<User[]>({
    url: `${BASE_URL}/users`,
    params
  })
}

/**
 * 获取用户详情
 * GET /users/:id
 */
export const getUserDetail = (id: number) => {
  return request.get<User>({ url: `${BASE_URL}/users/${id}` })
}

/**
 * 更新用户信息
 * PUT /users/:id
 */
export const updateUser = (id: number, data: UpdateUserRequest) => {
  return request.put<User>({ url: `${BASE_URL}/users/${id}`, data })
}

/**
 * 管理员重置用户密码
 * PUT /users/:id
 */
export const resetUserPassword = ({ id, password }: ResetUserPasswordRequest) => {
  return request.put<User>({
    url: `${BASE_URL}/users/${id}`,
    data: { password }
  })
}

/**
 * 管理员调整用户可用余额
 * POST /users/:id/balance/adjust
 */
export const adjustUserBalance = (id: number, data: AdjustUserBalanceRequest) => {
  return request.post<User>({
    url: `${BASE_URL}/users/${id}/balance/adjust`,
    data
  })
}

/**
 * 删除用户
 * DELETE /users/:id
 */
export const deleteUser = (id: number) => {
  return request.delete<boolean>({ url: `${BASE_URL}/users/${id}` })
}

/**
 * 升级用户为医生
 * POST /users/:id/upgrade-doctor
 */
export const upgradeUserToDoctor = (id: number) => {
  return request.post<User>({ url: `${BASE_URL}/users/${id}/upgrade-doctor` })
}

/**
 * 获取医院的员工列表（STAFF 角色）
 * GET /users/hospital/:hospitalId/staff
 */
export const getHospitalStaffApi = (hospitalId: number) => {
  return request.get<User[]>({
    url: `${BASE_URL}/users/hospital/${hospitalId}/staff`
  })
}
