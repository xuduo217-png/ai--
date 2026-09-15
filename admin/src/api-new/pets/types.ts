/**
 * 宠物管理模块类型定义
 */

/**
 * 宠物性别枚举
 * 1=弟弟，2=妹妹
 */
export enum PetGender {
  MALE = 1, // 弟弟
  FEMALE = 2 // 妹妹
}

/**
 * 宠物性别显示名称映射
 */
export const PetGenderLabel: Record<PetGender, string> = {
  [PetGender.MALE]: '弟弟',
  [PetGender.FEMALE]: '妹妹'
}

/**
 * 宠物类别
 */
export interface PetCategory {
  id: number
  name: string
  parentId: number | null
  sortOrder: number
  createdAt: string
  updatedAt: string
}

/**
 * 宠物类别树节点
 */
export interface PetCategoryTreeNode extends PetCategory {
  children?: PetCategoryTreeNode[]
}

/**
 * 宠物信息
 */
export interface Pet {
  id: number
  name: string
  avatar?: string
  categoryId?: number
  subCategoryId?: number
  category?: PetCategory
  subCategory?: PetCategory
  gender: PetGender
  birthDate?: string
  weight?: number
  tags?: string[]
  isNeutered?: boolean
  ownerId: number
  owner?: {
    id: number
    username: string
    phone: string
    avatar?: string
  }
  appointmentCount: number
  consultationCount: number
  createdAt: string
  updatedAt: string
  // 健康统计字段
  lastDewormingAt?: string
  nextDewormingAt?: string
  lastVaccineAt?: string
  nextVaccineAt?: string
  lastCheckupAt?: string
  nextCheckupAt?: string
  vaccineCount?: number
  dewormingCount?: number
  checkupCount?: number
  lastAppointmentAt?: string
}

/**
 * 查询参数
 */
export interface PetQueryParams {
  page?: number
  pageSize?: number
  name?: string
  categoryId?: number
  subCategoryId?: number
  gender?: PetGender
  ownerId?: number
  minWeight?: number
  maxWeight?: number
  tags?: string
  isNeutered?: boolean
}

/**
 * 创建参数
 */
export interface PetCreateParams {
  name: string
  avatar?: string
  categoryId?: number
  subCategoryId?: number
  gender: PetGender
  birthDate?: string
  weight?: number
  tags?: string[]
  isNeutered?: boolean
  vaccineCount?: number
  ownerId: number
}

/**
 * 更新参数
 */
export interface PetUpdateParams extends Partial<PetCreateParams> {
  id: number
}
