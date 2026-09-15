/**
 * 认证模块类型定义
 */

// 登录请求
export interface LoginRequest {
  username: string
  password: string
}

// 重置密码请求
export interface ResetPasswordRequest {
  phone: string
  code: string
  newPassword: string
}

// 用户信息
export interface UserInfo {
  id: number
  username: string
  email?: string
  phone?: string
  role: string
  verified?: boolean
  createdAt?: string
  updatedAt?: string
}

// 登录响应
export interface LoginResponse {
  access_token: string
  user: UserInfo
}

// 注册响应
export interface RegisterResponse {
  id: number
  username: string
  email?: string
  role: string
  createdAt: string
}
