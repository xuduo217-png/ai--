const PUBLIC_AUTH_URLS = [
  '/auth/login',
  '/auth/register',
  '/auth/send-code',
  '/auth/login/phone',
  '/auth/login/sms',
  '/auth/login/doctor/phone',
  '/auth/register/phone',
  '/auth/reset-password'
]

const toStatusCode = (value: unknown): number | undefined => {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value
  }

  if (typeof value === 'string' && value.trim() !== '') {
    const parsedValue = Number(value)
    if (Number.isFinite(parsedValue)) {
      return parsedValue
    }
  }

  return undefined
}

export const isPublicAuthRequest = (url?: string) => {
  if (!url) {
    return false
  }

  return PUBLIC_AUTH_URLS.some((publicUrl) => url.includes(publicUrl))
}

export const isLoginRequest = (url?: string) => {
  if (!url) {
    return false
  }

  return url.includes('/auth/login')
}

export const extractAuthStatusCode = (responseLike: {
  status?: number
  data?: Record<string, unknown> & {
    statusCode?: number | string
    code?: number | string
  }
}) => {
  return (
    toStatusCode(responseLike.data?.statusCode) ??
    toStatusCode(responseLike.data?.code) ??
    toStatusCode(responseLike.status)
  )
}

export const shouldForceLogoutOnAuthFailure = ({
  url,
  statusCode
}: {
  url?: string
  statusCode?: number
}) => {
  return statusCode === 401 && !isPublicAuthRequest(url)
}

export { PUBLIC_AUTH_URLS }
