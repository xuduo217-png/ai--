/**
 * 图片 URL 辅助函数
 * 用于拼接完整的图片 URL
 */

/**
 * 规范化基础地址
 * 统一去掉尾部斜杠，避免路径拼接出现双斜杠。
 */
const normalizeBaseURL = (value: string): string => {
  return value.trim().replace(/\/+$/, '')
}

const isAbsoluteUrl = (value: string): boolean => {
  return /^(https?:\/\/|data:|blob:)/i.test(value)
}

/**
 * 获取当前页面 origin
 * 当静态资源地址未显式配置时，优先回退到当前访问 origin，避免硬编码 localhost。
 */
const getRuntimeOrigin = (): string => {
  if (typeof window === 'undefined' || !window.location?.origin) {
    return ''
  }

  return normalizeBaseURL(window.location.origin)
}

/**
 * 获取静态资源服务器基础地址
 * 优先使用 VITE_STATIC_BASE_PATH（静态资源专用）。
 * 若服务端 API 使用相对地址（如 /server-api），则静态资源默认回退到当前 origin，
 * 便于通过 Vite/Nginx 代理统一访问 /uploads，避免把 localhost 写进数据。
 */
const getBaseURL = (): string => {
  const staticBasePath = import.meta.env.VITE_STATIC_BASE_PATH?.trim()
  if (staticBasePath) {
    return normalizeBaseURL(staticBasePath)
  }

  const runtimeOrigin = getRuntimeOrigin()
  const serverApiBasePath = import.meta.env.VITE_SERVER_API_BASE_URL?.trim()
  if (runtimeOrigin && (!serverApiBasePath || serverApiBasePath.startsWith('/'))) {
    return runtimeOrigin
  }

  const apiBasePath = import.meta.env.VITE_API_BASE_PATH?.trim()
  if (apiBasePath) {
    return normalizeBaseURL(apiBasePath)
  }

  if (serverApiBasePath && /^https?:\/\//i.test(serverApiBasePath)) {
    return normalizeBaseURL(serverApiBasePath)
  }

  return runtimeOrigin
}

/**
 * 从完整 URL 中提取上传相对路径
 * 仅对 /uploads/ 下的资源做收敛，其他第三方地址保持原样。
 */
export const extractUploadPath = (value: string | undefined | null): string | undefined => {
  if (value == null) {
    return undefined
  }

  const normalizedValue = value.trim()
  if (!normalizedValue) {
    return normalizedValue
  }

  if (normalizedValue.startsWith('/uploads/')) {
    return normalizedValue
  }

  if (!isAbsoluteUrl(normalizedValue)) {
    return normalizedValue
  }

  try {
    const pathname = new URL(normalizedValue).pathname
    if (pathname.startsWith('/uploads/')) {
      return pathname
    }
  } catch (_error) {
    return normalizedValue
  }

  return normalizedValue
}

/**
 * 获取完整的图片 URL
 * @param path 图片相对路径（如 /uploads/xxx.jpg）或完整 URL
 * @returns 完整的图片 URL
 */
export const getImageUrl = (path: string | undefined | null): string => {
  // 如果路径为空，返回空字符串
  if (!path) {
    return ''
  }

  const normalizedPath = path.trim()
  if (!normalizedPath) {
    return ''
  }

  // 如果已经是完整的 URL（以 http:// 或 https:// 开头），直接返回
  if (isAbsoluteUrl(normalizedPath)) {
    return normalizedPath
  }

  const baseURL = getBaseURL()
  if (!baseURL) {
    return normalizedPath
  }

  const finalPath = normalizedPath.startsWith('/') ? normalizedPath : `/${normalizedPath}`

  // 否则拼接服务器地址
  return `${baseURL}${finalPath}`
}

/**
 * 获取服务器基础地址（导出供其他模块使用）
 */
export { getBaseURL }

/**
 * 处理富文本内容中的图片 URL
 * 将 HTML 中的所有相对路径图片转换为完整 URL
 * @param html 富文本 HTML 内容
 * @returns 处理后的 HTML 内容
 */
export const processHtmlImages = (html: string | undefined | null): string => {
  if (!html) {
    return ''
  }

  // 匹配 <img src="..."> 中的 src 属性
  // 支持单引号、双引号、无引号的情况
  return html.replace(/<img([^>]*)\s+src=(["']?)([^"'\s>]+)\2/gi, (_match, attrs, quote, src) => {
    // 使用 getImageUrl 处理图片路径
    const fullUrl = getImageUrl(src)
    return `<img${attrs} src=${quote || '"'}${fullUrl}${quote || '"'}`
  })
}
