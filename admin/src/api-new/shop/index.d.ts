/**
 * 商城模块 API 类型声明
 */
export * from './types'
export const productApi: typeof import('./product')
export const homepageApi: typeof import('./homepage')
export const categoryApi: typeof import('./category')
export const couponApi: typeof import('./coupon')
