type PaginationResponseLike<T> = {
  data?:
    | T[]
    | {
        data?: T[]
        list?: T[]
        items?: T[]
        total?: number
        meta?: Record<string, any>
        pagination?: Record<string, any>
      }
  list?: T[]
  items?: T[]
  total?: number
  meta?: Record<string, any>
  pagination?: Record<string, any>
}

export const extractPagedTableData = <T = any>(
  response?: PaginationResponseLike<T> | null
): { list: T[]; total: number } => {
  const directList = Array.isArray(response?.data) ? response.data : null
  const nestedData =
    !Array.isArray(response?.data) && Array.isArray(response?.data?.data)
      ? response.data.data
      : null
  const nestedList =
    !Array.isArray(response?.data) && Array.isArray(response?.data?.list)
      ? response.data.list
      : null
  const nestedItems =
    !Array.isArray(response?.data) && Array.isArray(response?.data?.items)
      ? response.data.items
      : null
  const rootList = Array.isArray(response?.list) ? response.list : null
  const rootItems = Array.isArray(response?.items) ? response.items : null

  const list = directList || nestedData || nestedList || nestedItems || rootList || rootItems || []
  const total =
    response?.pagination?.total ??
    (!Array.isArray(response?.data) ? response?.data?.pagination?.total : undefined) ??
    response?.meta?.total ??
    (!Array.isArray(response?.data) ? response?.data?.meta?.total : undefined) ??
    (!Array.isArray(response?.data) ? response?.data?.total : undefined) ??
    response?.total ??
    list.length

  return {
    list,
    total: Number(total) || 0
  }
}
