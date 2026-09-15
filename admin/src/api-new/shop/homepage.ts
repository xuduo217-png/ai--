import request from '@/axios'
import type {
  MallHomepageHotProductsConfig,
  MallHomepageBannersConfig,
  MallHomepageBannerItem
} from './types'

const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

export const getMallHomepageHotProductsConfigApi = async (): Promise<
  IResponse<MallHomepageHotProductsConfig>
> => {
  try {
    const response = await request.get<MallHomepageHotProductsConfig>({
      url: `${BASE_URL}/admin/shop/homepage-hot-products`
    })
    return response
  } catch (error) {
    return Promise.reject(error)
  }
}

export const updateMallHomepageHotProductsConfigApi = async (params: {
  productIds: number[]
}): Promise<IResponse<MallHomepageHotProductsConfig>> => {
  try {
    const response = await request.put<MallHomepageHotProductsConfig>({
      url: `${BASE_URL}/admin/shop/homepage-hot-products`,
      data: params
    })
    return response
  } catch (error) {
    return Promise.reject(error)
  }
}

export const getMallHomepageBannersConfigApi = async (): Promise<
  IResponse<MallHomepageBannersConfig>
> => {
  try {
    const response = await request.get<MallHomepageBannersConfig>({
      url: `${BASE_URL}/admin/shop/homepage-banners`
    })
    return response
  } catch (error) {
    return Promise.reject(error)
  }
}

export const updateMallHomepageBannersConfigApi = async (params: {
  banners: MallHomepageBannerItem[]
}): Promise<IResponse<MallHomepageBannersConfig>> => {
  try {
    const response = await request.put<MallHomepageBannersConfig>({
      url: `${BASE_URL}/admin/shop/homepage-banners`,
      data: params
    })
    return response
  } catch (error) {
    return Promise.reject(error)
  }
}
