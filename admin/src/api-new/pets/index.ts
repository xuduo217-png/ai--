/**
 * 宠物模块 API 统一导出
 */

// 导出类型
export * from './types'

// 导出宠物相关的所有API函数
export * from './pets'

// 导出宠物 API 对象
import * as petApis from './pets'
export const petApi = petApis
