import request from '@/axios'
import type { PaginatedResponse } from '../types'
import type {
  Product,
  ProductQueryParams,
  ProductCreateParams,
  ProductUpdateParams,
  ProductSku
} from './types'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 商品管理 API
 */

/**
 * 获取商品列表（支持分页和筛选）
 */
export const getProductListApi = (params: ProductQueryParams) => {
  return request.get<PaginatedResponse<Product>>({
    url: `${BASE_URL}/shop/products`,
    params
  })
}

/**
 * 获取所有商品（用于选择器）
 */
export const getAllProductsApi = () => {
  return request.get<Product[]>({
    url: `${BASE_URL}/shop/products/all`
  })
}

/**
 * 获取商品详情
 */
export const getProductDetailApi = (id: number) => {
  return request.get<Product>({
    url: `${BASE_URL}/shop/products/${id}`
  })
}

/**
 * 创建商品
 */
export const createProductApi = (data: ProductCreateParams) => {
  return request.post<Product>({
    url: `${BASE_URL}/shop/products`,
    data
  })
}

/**
 * 更新商品
 */
export const updateProductApi = (id: number, data: ProductUpdateParams) => {
  return request.put<Product>({
    url: `${BASE_URL}/shop/products/${id}`,
    data
  })
}

/**
 * 删除商品
 */
export const deleteProductApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/shop/products/${id}`
  })
}

/**
 * 获取我发布的商品
 */
export const getMyProductsApi = (params: ProductQueryParams) => {
  return request.get<PaginatedResponse<Product>>({
    url: `${BASE_URL}/shop/products/my`,
    params
  })
}

/**
 * 获取商品的所有 SKU
 */
export const getProductSkusApi = (productId: number) => {
  return request.get<ProductSku[]>({
    url: `${BASE_URL}/shop/products/${productId}/skus`
  })
}

/**
 * 创建单个 SKU
 */
export const createProductSkuApi = (productId: number, data: Partial<ProductSku>) => {
  return request.post<ProductSku>({
    url: `${BASE_URL}/shop/products/${productId}/skus`,
    data
  })
}

/**
 * 批量创建 SKU
 */
export const createProductSkuBatchApi = (
  productId: number,
  data: { skus: Partial<ProductSku>[] }
) => {
  return request.post<ProductSku[]>({
    url: `${BASE_URL}/shop/products/${productId}/skus/batch`,
    data
  })
}

/**
 * 更新 SKU
 */
export const updateProductSkuApi = (
  productId: number,
  skuId: number,
  data: Partial<ProductSku>
) => {
  return request.put<ProductSku>({
    url: `${BASE_URL}/shop/products/${productId}/skus/${skuId}`,
    data
  })
}

/**
 * 删除 SKU
 */
export const deleteProductSkuApi = (productId: number, skuId: number) => {
  return request.delete({
    url: `${BASE_URL}/shop/products/${productId}/skus/${skuId}`
  })
}

/**
 * ==================== 商品审核 API（后台管理） ====================
 */

/**
 * 获取待审核商品列表（后台管理）
 */
export const getPendingProductsForAuditApi = (params: {
  page: number
  pageSize: number
  status?: string // under_review, on_shelf, off_shelf, rejected, sold (approved 为兼容旧值)
  keyword?: string
  categoryId?: number
}) => {
  return request.get<PaginatedResponse<any>>({
    url: `${BASE_URL}/admin/shop/pending-products`,
    params
  })
}

/**
 * 获取待审核商品详情（后台管理）
 */
export const getPendingProductDetailApi = (id: number) => {
  return request.get<any>({
    url: `${BASE_URL}/admin/shop/pending-products/${id}`
  })
}

/**
 * 审核商品（后台管理）
 */
export const reviewPendingProductApi = (
  id: number,
  data: {
    approved: boolean
    rejectReason?: string
  }
) => {
  return request.post({
    url: `${BASE_URL}/admin/shop/pending-products/${id}/review`,
    data
  })
}
