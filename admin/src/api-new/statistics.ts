/**
 * 统计数据 API
 */

import request from '@/axios'
import type { DashboardStatsResponse } from './types'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 获取首页统计数据
 * 包含医院、医生、用户、宠物的总数
 */
export const getDashboardStatsApi = () => {
  return request.get<DashboardStatsResponse>({
    url: `${BASE_URL}/statistics/dashboard`
  })
}
