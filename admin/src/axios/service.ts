import axios, { AxiosError } from 'axios'
import { defaultRequestInterceptors, defaultResponseInterceptors } from './config'

import { AxiosInstance, InternalAxiosRequestConfig, RequestConfig, AxiosResponse } from './types'
import { ElMessage } from 'element-plus'
import { REQUEST_TIMEOUT } from '@/constants'
import { useUserStoreWithOut } from '@/store/modules/user'
import {
  extractAuthStatusCode,
  isLoginRequest,
  shouldForceLogoutOnAuthFailure
} from './auth-session'

export const PATH_URL = import.meta.env.VITE_API_BASE_PATH

const abortControllerMap: Map<string, AbortController> = new Map()

const axiosInstance: AxiosInstance = axios.create({
  timeout: REQUEST_TIMEOUT,
  baseURL: PATH_URL
})

axiosInstance.interceptors.request.use((res: InternalAxiosRequestConfig) => {
  const controller = new AbortController()
  const url = res.url || ''
  res.signal = controller.signal
  abortControllerMap.set(
    import.meta.env.VITE_USE_MOCK === 'true' ? url.replace('/mock', '') : url,
    controller
  )
  return res
})

axiosInstance.interceptors.response.use(
  (res: AxiosResponse) => {
    const url = res.config.url || ''
    abortControllerMap.delete(url)
    // 这里不能做任何处理，否则后面的 interceptors 拿不到完整的上下文了
    return res
  },
  (error: AxiosError) => {
    const url = error.config?.url || ''
    abortControllerMap.delete(url)

    const statusCode = extractAuthStatusCode({
      status: error.response?.status,
      data: error.response?.data as any
    })

    // 从响应中提取错误信息
    const errorMessage = (error.response?.data as any)?.message || error.message || '请求失败'

    // 401 未授权，自动退出登录（登录类公开接口除外）
    if (shouldForceLogoutOnAuthFailure({ url, statusCode })) {
      const userStore = useUserStoreWithOut()
      userStore.logout()
    }

    // 登录接口错误交给调用方处理，其他接口统一提示
    if (!isLoginRequest(url)) {
      ElMessage.error(errorMessage)
    }

    console.log('err： ' + errorMessage) // for debug

    // 返回更详细的错误信息
    return Promise.reject({
      message: errorMessage,
      statusCode: statusCode,
      data: error.response?.data
    })
  }
)

axiosInstance.interceptors.request.use(defaultRequestInterceptors)
axiosInstance.interceptors.response.use(defaultResponseInterceptors)

const service = {
  request: (config: RequestConfig) => {
    return new Promise((resolve, reject) => {
      if (config.interceptors?.requestInterceptors) {
        config = config.interceptors.requestInterceptors(config as any)
      }

      axiosInstance
        .request(config)
        .then((res) => {
          resolve(res)
        })
        .catch((err: any) => {
          reject(err)
        })
    })
  },
  cancelRequest: (url: string | string[]) => {
    const urlList = Array.isArray(url) ? url : [url]
    for (const _url of urlList) {
      abortControllerMap.get(_url)?.abort()
      abortControllerMap.delete(_url)
    }
  },
  cancelAllRequest() {
    for (const [_, controller] of abortControllerMap) {
      controller.abort()
    }
    abortControllerMap.clear()
  }
}

export default service
