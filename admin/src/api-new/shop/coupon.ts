import request from '@/axios'
import type { PaginatedResponse } from '../types'
import type { Coupon, CouponCreateParams, CouponUpdateParams, UserCoupon } from './types'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 优惠券管理 API
 */

// ========== 管理端 ==========

/**
 * 清理对象中的空字符串和 undefined 值
 */
function cleanParams(params: Record<string, any>): Record<string, any> {
  const cleaned: Record<string, any> = {}
  for (const [key, value] of Object.entries(params)) {
    if (value !== '' && value !== undefined && value !== null) {
      cleaned[key] = value
    }
  }
  return cleaned
}

/**
 * 获取优惠券列表（分页）
 */
export const getCouponListApi = (params: any) => {
  return request.get<PaginatedResponse<Coupon>>({
    url: `${BASE_URL}/shop/coupons/list`,
    params: cleanParams(params)
  })
}

/**
 * 获取所有优惠券（管理员）
 */
export const getAllCouponsApi = () => {
  return request.get<Coupon[]>({
    url: `${BASE_URL}/shop/coupons`
  })
}

/**
 * 获取优惠券详情
 */
export const getCouponDetailApi = (id: number) => {
  return request.get<Coupon>({
    url: `${BASE_URL}/shop/coupons/${id}`
  })
}

/**
 * 创建优惠券（管理员）
 */
export const createCouponApi = (data: CouponCreateParams) => {
  return request.post<Coupon>({
    url: `${BASE_URL}/shop/coupons`,
    data
  })
}

/**
 * 更新优惠券（管理员）
 */
export const updateCouponApi = (id: number, data: CouponUpdateParams) => {
  return request.put<Coupon>({
    url: `${BASE_URL}/shop/coupons/${id}`,
    data
  })
}

/**
 * 切换优惠券状态（启用/禁用）
 */
export const toggleCouponStatusApi = (id: number) => {
  return request.put({
    url: `${BASE_URL}/shop/coupons/${id}/toggle-status`
  })
}

/**
 * 作废优惠券（管理员）
 */
export const revokeCouponApi = (id: number) => {
  return request.post({
    url: `${BASE_URL}/shop/coupons/${id}/revoke`
  })
}

/**
 * 获取优惠券二维码
 */
export const getCouponQRCodeApi = (id: number) => {
  return request.get<{
    success: boolean
    qrcode?: string
    message?: string
  }>({
    url: `${BASE_URL}/shop/coupons/${id}/qrcode`
  })
}

// ========== 用户端 ==========

/**
 * 获取可领取的优惠券
 */
export const getAvailableCouponsApi = () => {
  return request.get<Coupon[]>({
    url: `${BASE_URL}/shop/coupons/available`
  })
}

/**
 * 领取优惠券
 */
export const claimCouponApi = (couponId: number) => {
  return request.post<UserCoupon>({
    url: `${BASE_URL}/shop/coupons/claim`,
    data: { couponId }
  })
}

/**
 * 获取我的优惠券
 */
export const getMyCouponsApi = (status?: string) => {
  return request.get<UserCoupon[]>({
    url: `${BASE_URL}/shop/coupons/my`,
    params: { status }
  })
}
