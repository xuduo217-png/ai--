/**
 * 认证相关 API
 */
import request from '@/axios'
import type { LoginRequest, LoginResponse, ResetPasswordRequest, UserInfo } from './types'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'
/**
 * 用户名密码登录
 * POST /auth/login
 */
export const login = (data: LoginRequest) => {
  return request.post<LoginResponse>({ url: `${BASE_URL}/auth/login`, data })
}

/**
 * 重置密码
 * POST /auth/reset-password
 */
export const resetPassword = (data: ResetPasswordRequest) => {
  return request.post<{ success: boolean; message: string }>({
    url: `${BASE_URL}/auth/reset-password`,
    data
  })
}

/**
 * 获取当前用户信息
 * GET /auth/profile
 */
export const getProfile = () => {
  return request.get<UserInfo>({ url: '/auth/profile' })
}
