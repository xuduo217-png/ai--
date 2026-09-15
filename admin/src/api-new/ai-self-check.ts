/**
 * AI 自查表管理 API
 */

import request from '@/axios'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

// ==================== 类型定义 ====================

export type SelfCheckListType = 'PUBLIC' | 'SPECIFIC'
export type SelfCheckListStatus = 'ACTIVE' | 'INACTIVE'
export type QuestionType = 'SINGLE' | 'MULTIPLE' | 'TEXT'

export interface SelfCheckList {
  id: number
  title: string
  type: SelfCheckListType
  categoryId: number | null
  categoryName?: string
  status: SelfCheckListStatus
  sortOrder: number
  questionCount?: number
  createdAt: string
  updatedAt: string
}

export interface SelfCheckOption {
  id: number
  questionId: number
  optionText: string
  optionImage: string | null
  sortOrder: number
}

export interface SelfCheckQuestion {
  id: number
  listId: number
  questionText: string
  questionType: QuestionType
  required: boolean
  sortOrder: number
  options?: SelfCheckOption[]
}

// ==================== 自查表管理 ====================

/**
 * 获取自查表列表（分页+筛选）
 */
export const getSelfCheckListsApi = (params: any) => {
  return request.get({
    url: `${BASE_URL}/ai-self-check/lists`,
    params
  })
}

/**
 * 获取自查表详情
 */
export const getSelfCheckListDetailApi = (id: number) => {
  return request.get({
    url: `${BASE_URL}/ai-self-check/lists/${id}`
  })
}

/**
 * 创建自查表
 */
export const createSelfCheckListApi = (data: any) => {
  return request.post({
    url: `${BASE_URL}/ai-self-check/lists`,
    data
  })
}

/**
 * 更新自查表
 */
export const updateSelfCheckListApi = (id: number, data: any) => {
  return request.put({
    url: `${BASE_URL}/ai-self-check/lists/${id}`,
    data
  })
}

/**
 * 更新自查表状态
 */
export const updateSelfCheckListStatusApi = (id: number, status: SelfCheckListStatus) => {
  return request.post({
    url: `${BASE_URL}/ai-self-check/lists/${id}/status`,
    data: { status }
  })
}

/**
 * 删除自查表
 */
export const deleteSelfCheckListApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/ai-self-check/lists/${id}`
  })
}

/**
 * 根据宠物ID获取自查表列表
 */
export const getSelfCheckListsByPetApi = (petId: number) => {
  return request.get<SelfCheckList[]>({
    url: `${BASE_URL}/ai-self-check/lists/by-pet/${petId}`
  })
}

/**
 * 批量更新自查表排序
 * @param listIds 按新顺序排列的自查表 ID 数组
 */
export const reorderSelfCheckListsApi = (listIds: number[]) => {
  return request.patch({
    url: `${BASE_URL}/ai-self-check/lists/reorder`,
    data: { listIds }
  })
}

// ==================== 问题管理 ====================

/**
 * 获取问题列表
 */
export const getSelfCheckQuestionsApi = (listId: number) => {
  return request.get<SelfCheckQuestion[]>({
    url: `${BASE_URL}/ai-self-check/questions`,
    params: { listId }
  })
}

/**
 * 创建问题
 */
export const createQuestionApi = (data: any) => {
  return request.post({
    url: `${BASE_URL}/ai-self-check/questions`,
    data
  })
}

/**
 * 更新问题
 */
export const updateQuestionApi = (id: number, data: any) => {
  return request.put({
    url: `${BASE_URL}/ai-self-check/questions/${id}`,
    data
  })
}

/**
 * 删除问题
 */
export const deleteQuestionApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/ai-self-check/questions/${id}`
  })
}

/**
 * 批量更新问题排序
 * @param questionIds 按新顺序排列的问题 ID 数组
 */
export const reorderQuestionsApi = (questionIds: number[]) => {
  return request.patch({
    url: `${BASE_URL}/ai-self-check/questions/reorder`,
    data: { questionIds }
  })
}

/**
 * 批量更新选项排序
 * @param questionId 问题 ID
 * @param optionIds 按新顺序排列的选项 ID 数组
 */
export const reorderQuestionOptionsApi = (questionId: number, optionIds: number[]) => {
  return request.patch({
    url: `${BASE_URL}/ai-self-check/questions/${questionId}/options/reorder`,
    data: { optionIds }
  })
}
