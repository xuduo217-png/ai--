/**
 * 商城模块 API 统一导出
 */

// 导出类型
export * from './types'

// 导出分类相关的独立函数
export * from './category'

// 导出优惠券相关的独立函数
export * from './coupon'

// 导出商品相关的所有函数
export * from './product'

// 导出商城首页配置相关函数
export * from './homepage'

// 导出商品 API 对象（用于兼容旧代码）
import * as productApis from './product'
export const productApi = productApis

// 导出分类 API 对象（用于兼容旧代码）
import * as categoryApis from './category'
export const categoryApi = categoryApis

// 导出商城首页配置 API 对象
import * as homepageApis from './homepage'
export const homepageApi = homepageApis

// 导出优惠券 API 对象（用于兼容旧代码）
import * as couponApis from './coupon'
export const couponApi = couponApis
