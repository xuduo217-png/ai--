import { extractPagedTableData as extractCommonPagedTableData } from '@/utils/pagination'

/**
 * 商品模块保留本地导出，避免批量修改旧引用路径
 * 实际解析逻辑统一复用公共分页工具，防止不同页面继续各自维护一套解包规则
 */
export const extractPagedTableData = (response: any): { list: any[]; total: number } => {
  return extractCommonPagedTableData(response)
}
