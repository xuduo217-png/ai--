/**
 * 订单管理 API
 */
import request from '@/axios'
import type { Order, OrderQueryParams, UpdateOrderStatusDto, UpdateShippingDto } from './types'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 获取订单列表（支持搜索和筛选）
 *
 * 后端响应格式：
 * {
 *   code: 0,
 *   data: Order[],
 *   message: "",
 *   meta: { total, page, limit, timestamp }
 * }
 */
export const getOrderListApi = async (params: OrderQueryParams) => {
  try {
    return await request.get<Order[]>({
      url: `${BASE_URL}/shop/orders`,
      params
    })
  } catch (error) {
    return Promise.reject(error)
  }
}

/**
 * 获取订单详情
 */
export const getOrderDetailApi = async (id: number) => {
  try {
    return await request.get<Order>({
      url: `${BASE_URL}/shop/orders/${id}`
    })
  } catch (error) {
    return Promise.reject(error)
  }
}

/**
 * 更新订单状态
 */
export const updateOrderStatusApi = async (id: number, data: UpdateOrderStatusDto) => {
  try {
    return await request.put<Order>({
      url: `${BASE_URL}/shop/orders/${id}/status`,
      data
    })
  } catch (error) {
    return Promise.reject(error)
  }
}

/**
 * 设置物流信息（自动标记为已发货）
 */
export const setShippingInfoApi = async (id: number, data: UpdateShippingDto) => {
  try {
    return await request.patch<Order>({
      url: `${BASE_URL}/shop/orders/${id}/shipping`,
      data
    })
  } catch (error) {
    return Promise.reject(error)
  }
}

// 重新导出类型
export type { Order, OrderQueryParams, UpdateOrderStatusDto, UpdateShippingDto } from './types'
