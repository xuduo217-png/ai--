export type UploadMediaKind = 'image' | 'video'

const IMAGE_EXTENSIONS = new Set(['.jpg', '.jpeg', '.jpe', '.jfif', '.png', '.gif', '.webp'])
const IMAGE_MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/gif', 'image/webp'])
const VIDEO_EXTENSIONS = new Set(['.mp4', '.m4v', '.mov', '.mpeg', '.mpg', '.avi', '.wmv', '.webm'])
const VIDEO_MIME_TYPES = new Set([
  'video/mp4',
  'video/x-m4v',
  'video/quicktime',
  'video/mpeg',
  'video/x-msvideo',
  'video/avi',
  'video/vnd.avi',
  'video/x-ms-wmv',
  'video/x-ms-asf',
  'video/webm'
])
const HEIC_EXTENSIONS = new Set(['.heic', '.heif'])
const HEIC_MIME_TYPES = new Set(['image/heic', 'image/heif'])

export const IMAGE_UPLOAD_ACCEPT = [...IMAGE_EXTENSIONS, ...IMAGE_MIME_TYPES].join(',')

export const VIDEO_UPLOAD_ACCEPT = [...VIDEO_EXTENSIONS, ...VIDEO_MIME_TYPES].join(',')

const fileExtension = (name: string) => {
  const index = name.lastIndexOf('.')
  return index >= 0 ? name.slice(index).toLowerCase() : ''
}

export const getUploadMediaValidationError = (file: File, kind: UploadMediaKind): string | null => {
  const extension = fileExtension(file.name.trim())
  const mimeType = file.type.trim().toLowerCase()

  if (HEIC_EXTENSIONS.has(extension) || HEIC_MIME_TYPES.has(mimeType)) {
    return '暂不支持 HEIC/HEIF，请选择 JPG、PNG、GIF 或 WebP 图片'
  }

  const extensions = kind === 'image' ? IMAGE_EXTENSIONS : VIDEO_EXTENSIONS
  const mimeTypes = kind === 'image' ? IMAGE_MIME_TYPES : VIDEO_MIME_TYPES
  const unsupportedMessage =
    kind === 'image'
      ? '图片仅支持 JPG、PNG、GIF 或 WebP 格式'
      : '视频仅支持 MP4、M4V、MOV、MPEG、AVI、WMV 或 WebM 格式'

  if (
    (extension && !extensions.has(extension)) ||
    (mimeType && !mimeTypes.has(mimeType)) ||
    (!extension && !mimeType)
  ) {
    return unsupportedMessage
  }

  return null
}

export const assertSupportedUploadFile = (formData: FormData, kind: UploadMediaKind) => {
  const file = formData.get('file')
  if (!(file instanceof File)) {
    throw new Error(kind === 'image' ? '请选择要上传的图片' : '请选择要上传的视频')
  }

  const validationError = getUploadMediaValidationError(file, kind)
  if (validationError) throw new Error(validationError)
}

export const getUploadErrorMessage = (error: unknown, fallback: string) => {
  if (error instanceof Error && error.message.trim()) return error.message.trim()
  if (typeof error === 'string' && error.trim()) return error.trim()
  if (error && typeof error === 'object' && 'message' in error) {
    const message = String((error as { message?: unknown }).message ?? '').trim()
    if (message) return message
  }
  return fallback
}

export const toUploadError = (error: unknown, fallback: string) =>
  error instanceof Error ? error : new Error(getUploadErrorMessage(error, fallback))
