/**
 * 文件上传相关类型定义
 */

/**
 * 文件上传响应
 */
export interface UploadResponse {
  /** 服务器文件 URL */
  url: string
  /** 视频缩略图 URL */
  thumbnail?: string
  /** 服务器文件名 */
  filename: string
  /** 原始文件名 */
  originalName: string
  /** 文件大小（字节） */
  size: number
  /** 文件记录 ID */
  id: number
}
