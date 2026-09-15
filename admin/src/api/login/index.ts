import request from '@/axios'
import type { UserType, LoginResponse, UserInfo, UserLoginType } from './types'

interface RoleParams {
  roleName: string
}

/**
 * 登录接口 - 对接后端 NestJS
 * POST /auth/login
 * @param data 登录信息 { username, password }
 * @returns Promise<LoginResponse> { access_token, user }
 */
export const loginApi = (data: UserLoginType): Promise<IResponse<LoginResponse>> => {
  return request.post({ url: '/auth/login', data })
}

/**
 * 登出接口
 * GET /auth/logout (可选,后端暂未实现)
 */
export const loginOutApi = (): Promise<IResponse> => {
  return request.get({ url: '/auth/logout' })
}

/**
 * 获取当前用户信息
 * GET /auth/profile
 */
export const getUserProfileApi = (): Promise<IResponse<UserInfo>> => {
  return request.get({ url: '/auth/profile' })
}

export const getUserListApi = ({ params }: AxiosConfig) => {
  return request.get<{
    code: string
    data: {
      list: UserType[]
      total: number
    }
  }>({ url: '/mock/user/list', params })
}

export const getAdminRoleApi = (
  params: RoleParams
): Promise<IResponse<AppCustomRouteRecordRaw[]>> => {
  return request.get({ url: '/mock/role/list', params })
}

export const getTestRoleApi = (params: RoleParams): Promise<IResponse<string[]>> => {
  return request.get({ url: '/mock/role/list2', params })
}

// 导出类型
export type { UserLoginType, LoginResponse, UserInfo } from './types'
