/**
 * 敏感词管理 API
 */
import request from '@/axios'

const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

export interface SensitiveWord {
  id: number
  word: string
  severity: number
  replacement?: string
  category?: string
  isActive: boolean
  createdAt: string
  updatedAt: string
}

export interface CreateSensitiveWordParams {
  word: string
  severity?: number
  replacement?: string
  category?: string
  isActive?: boolean
}

export interface UpdateSensitiveWordParams {
  id: number
  data: Partial<CreateSensitiveWordParams>
}

export interface DeleteSensitiveWordParams {
  id: number
}

export interface BatchImportSensitiveWordsParams {
  words: string[]
}

export interface BatchImportSensitiveWordsResult {
  created: number
  skipped: number
}

export const getSensitiveWordsApi = async (_params: Record<string, never>) => {
  try {
    return await request.get<SensitiveWord[]>({
      url: `${BASE_URL}/admin/community/sensitive-words`
    })
  } catch (error) {
    return Promise.reject(error)
  }
}

export const createSensitiveWordApi = async (data: CreateSensitiveWordParams) => {
  try {
    return await request.post<SensitiveWord>({
      url: `${BASE_URL}/admin/community/sensitive-words`,
      data
    })
  } catch (error) {
    return Promise.reject(error)
  }
}

export const updateSensitiveWordApi = async ({ id, data }: UpdateSensitiveWordParams) => {
  try {
    return await request.put<SensitiveWord>({
      url: `${BASE_URL}/admin/community/sensitive-words/${id}`,
      data
    })
  } catch (error) {
    return Promise.reject(error)
  }
}

export const deleteSensitiveWordApi = async ({ id }: DeleteSensitiveWordParams) => {
  try {
    return await request.delete({
      url: `${BASE_URL}/admin/community/sensitive-words/${id}`
    })
  } catch (error) {
    return Promise.reject(error)
  }
}

export const batchImportSensitiveWordsApi = async (data: BatchImportSensitiveWordsParams) => {
  try {
    return await request.post<BatchImportSensitiveWordsResult>({
      url: `${BASE_URL}/admin/community/sensitive-words/batch`,
      data
    })
  } catch (error) {
    return Promise.reject(error)
  }
}
