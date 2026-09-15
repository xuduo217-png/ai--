/**
 * 统计数据相关类型定义
 */

/**
 * 首页统计数据响应
 */
export interface DashboardStatsResponse {
  code: number
  data: DashboardStats
  message: string
}

/**
 * 首页统计数据
 */
export interface DashboardStats {
  /** 合作医院总数 */
  hospitals: number
  /** 在职医生总数 */
  doctors: number
  /** 注册用户总数 */
  users: number
  /** 宠物档案总数 */
  pets: number
}
