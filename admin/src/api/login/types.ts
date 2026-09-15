// 登录请求类型
export interface UserLoginType {
  username: string
  password: string
}

// 登录响应 - 用户信息
export interface UserInfo {
  id: number
  username: string
  email?: string
  role: string
  phone?: string
  verified?: boolean
}

// 登录响应 - 完整类型
export interface LoginResponse {
  access_token: string
  user: UserInfo
}

// 向后兼容的旧类型 (保留以避免破坏其他地方的代码)
export interface UserType {
  username: string
  password: string
  role: string
  roleId: string
}
