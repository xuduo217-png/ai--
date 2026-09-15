/**
 * AI 问诊报告管理 API
 */

import request from '@/axios'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

// ==================== 类型定义 ====================

export type ReportStatus = 'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED' | 'TIMEOUT'

export interface SelfCheckOptionSnapshot {
  optionId: number
  optionText: string
  image?: string
  selected: boolean
}

export interface SelfCheckQuestionSnapshot {
  questionId: number
  questionText: string
  questionType: 'SINGLE' | 'MULTIPLE' | 'TEXT'
  sortOrder: number
  options: SelfCheckOptionSnapshot[]
}

export interface SelfCheckListSnapshot {
  listId: number
  listName: string
  listType: 'PUBLIC' | 'SPECIFIC'
  petCategoryId: number
  questions: SelfCheckQuestionSnapshot[]
}

export interface AiDiagnosisReport {
  id: number
  userId: number
  userName?: string
  userPhone?: string
  petId: number
  petName?: string
  status: ReportStatus
  symptoms: string
  selfCheckSnapshot?: SelfCheckListSnapshot[]
  westernDiagnosis?: any
  tcmDiagnosis?: any
  errorMessage?: string
  createdAt: string
  updatedAt: string
  completedAt?: string
  retryCount: number
}

export interface CreateReportParams {
  petId: number
  symptoms: string
  selfCheckSnapshot: SelfCheckListSnapshot[]
}

export interface QueryReportsParams {
  page?: number
  pageSize?: number
  id?: number
  userId?: number
  userPhone?: string
  petId?: number
  status?: ReportStatus
  keyword?: string
  startDate?: string
  endDate?: string
}

/**
 * AI 问诊报告中的宠物信息
 */
export interface AiDiagnosisPetInfo {
  id: number
  name: string
  categoryId?: number
  subCategoryId?: number
  age?: number
  gender?: number
  avatar?: string
  userId: number
  userName: string
}

// ==================== API 接口 ====================

/**
 * 获取 AI 问诊报告列表（分页+筛选）
 */
export const getAiDiagnosisReportsApi = (params: QueryReportsParams) => {
  return request.get({
    url: `${BASE_URL}/ai-diagnosis-reports`,
    params
  })
}

/**
 * 获取 AI 问诊报告详情
 */
export const getAiDiagnosisReportDetailApi = (id: number) => {
  return request.get<AiDiagnosisReport>({
    url: `${BASE_URL}/ai-diagnosis-reports/${id}`
  })
}

/**
 * 创建 AI 问诊报告
 */
export const createAiDiagnosisReportApi = (data: CreateReportParams) => {
  return request.post<AiDiagnosisReport>({
    url: `${BASE_URL}/ai-diagnosis-reports`,
    data
  })
}

/**
 * 删除 AI 问诊报告
 */
export const deleteAiDiagnosisReportApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/ai-diagnosis-reports/${id}`
  })
}

/**
 * 根据手机号查询用户的宠物列表
 * 如果 phone 为空，则获取当前用户的宠物
 */
export const getPetsByUserPhoneApi = (phone: string) => {
  // 如果 phone 为空，获取当前用户的宠物
  if (!phone) {
    return request.get<AiDiagnosisPetInfo[]>({
      url: `${BASE_URL}/users/me/pets`
    })
  }
  // 否则根据手机号查询
  return request.get<AiDiagnosisPetInfo[]>({
    url: `${BASE_URL}/users/phone/${phone}/pets`
  })
}
