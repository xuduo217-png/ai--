import { AxiosResponse, InternalAxiosRequestConfig } from './types'
import { ElMessage } from 'element-plus'
import qs from 'qs'
import { SUCCESS_CODE, TRANSFORM_REQUEST_DATA } from '@/constants'
import { useUserStoreWithOut } from '@/store/modules/user'
import { objToFormData } from '@/utils'
import {
  extractAuthStatusCode,
  isLoginRequest,
  shouldForceLogoutOnAuthFailure
} from './auth-session'

const defaultRequestInterceptors = (config: InternalAxiosRequestConfig) => {
  if (
    config.method === 'post' &&
    config.headers['Content-Type'] === 'application/x-www-form-urlencoded'
  ) {
    config.data = qs.stringify(config.data)
  } else if (
    TRANSFORM_REQUEST_DATA &&
    config.method === 'post' &&
    config.headers['Content-Type'] === 'multipart/form-data' &&
    !(config.data instanceof FormData)
  ) {
    config.data = objToFormData(config.data)
  }
  if (config.method === 'get' && config.params) {
    // 使用 qs 库序列化参数，数字类型会保留为数字（虽然传输时仍是字符串，
    // 但配合服务器端的 enableImplicitConversion 配置，class-transformer 会自动转换）
    config.paramsSerializer = {
      serialize: (params) => {
        return qs.stringify(params, { arrayFormat: 'brackets' })
      }
    }
  }
  return config
}

const defaultResponseInterceptors = (response: AxiosResponse) => {
  if (response?.config?.responseType === 'blob') {
    // 如果是文件流，直接过
    return response
  } else if (response.status === 204) {
    // 204 No Content（删除操作成功）
    return { code: SUCCESS_CODE, data: null, message: '操作成功' }
  } else if (response.data.code === SUCCESS_CODE) {
    // 返回业务数据，前端直接获取 data.data 字段内容
    return response.data
  } else {
    // 错误处理
    const errorMessage = response?.data?.message || '请求失败'
    const statusCode = extractAuthStatusCode(response)

    // 登录接口的特殊处理 - 不弹窗,让组件自己处理错误显示
    const requestUrl = response?.config?.url
    const isLoginApi = isLoginRequest(requestUrl)
    const shouldForceLogout = shouldForceLogoutOnAuthFailure({
      url: requestUrl,
      statusCode
    })

    if (!isLoginApi) {
      ElMessage.error(errorMessage)
    }

    // 401 未授权（包括 HTTP 200 + 业务 statusCode=401），自动退出登录
    if (shouldForceLogout) {
      const userStore = useUserStoreWithOut()
      userStore.logout()
    }

    // 抛出错误,让调用方可以捕获处理
    return Promise.reject({
      message: errorMessage,
      statusCode,
      data: response.data
    })
  }
}

export { defaultResponseInterceptors, defaultRequestInterceptors }
