import type {
  InternalAxiosRequestConfig,
  AxiosResponse,
  AxiosRequestConfig,
  AxiosInstance,
  AxiosRequestHeaders,
  AxiosError
} from 'axios'

/**
 * 请求拦截器接口
 */
interface RequestInterceptors<T> {
  // 请求拦截
  requestInterceptors?: (config: InternalAxiosRequestConfig) => InternalAxiosRequestConfig
  requestInterceptorsCatch?: (err: any) => any
  // 响应拦截
  responseInterceptors?: (config: T) => T
  responseInterceptorsCatch?: (err: any) => any
}

/**
 * 请求配置接口（扩展 AxiosRequestConfig，支持上传进度回调）
 */
interface RequestConfig<T = AxiosResponse> extends AxiosRequestConfig {
  interceptors?: RequestInterceptors<T>
  // 上传进度回调
  onUploadProgress?: (progressEvent: any) => void
}

export {
  AxiosResponse,
  RequestInterceptors,
  RequestConfig,
  AxiosInstance,
  InternalAxiosRequestConfig,
  AxiosRequestHeaders,
  AxiosError
}
