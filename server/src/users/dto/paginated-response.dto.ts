/**
 * 分页响应 DTO
 * 统一的分页数据结构
 */
export class PaginatedResponseDto<T> {
  /**
   * 数据列表
   */
  list: T[];

  /**
   * 总数量
   */
  total: number;

  /**
   * 当前页码
   */
  page: number;

  /**
   * 每页数量
   */
  pageSize: number;
}

/**
 * 创建分页响应的辅助函数
 */
export function createPaginatedResponse<T>(
  list: T[],
  total: number,
  page: number,
  pageSize: number,
): PaginatedResponseDto<T> {
  return {
    list,
    total,
    page,
    pageSize,
  };
}
