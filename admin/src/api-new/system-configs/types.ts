/**
 * 系统配置类型定义
 */

/**
 * 系统配置
 */
export interface SystemConfig {
  id: number
  configKey: string
  configValue: Record<string, any>
  description: string
  createdAt: string
  updatedAt: string
}

/**
 * 联系方式配置值
 */
export interface ContactInfoValue {
  wechatQrCode: string
  hotline: string
  workingHours: string
}

/**
 * 平台手续费配置值
 */
export interface PlatformFeeValue {
  feeRate: number
}

/**
 * 急救中心配置值
 */
export interface EmergencyCenterValue {
  emergencyTime: string
  emergencyHotline: string
}

/**
 * App 首页菜单图标配置值
 */
export interface HomeMenuIconsValue {
  icons: Record<string, string>
}

/**
 * App 首页 AI 智能诊断 Banner 配置值
 */
export interface HomeAiDiagnosisBannerValue {
  imageUrl: string
}

/**
 * 商城首页弹窗配置值
 */
export interface MallHomePopupImageValue {
  imageUrl: string
}

/**
 * App 首页滚动公告配置值
 */
export interface ScrollingAnnouncementValue {
  source: 'donation' | 'fixed' | 'disabled'
  announcementText: string
}

/**
 * AI 问诊配置值
 */
export interface AiDiagnosisConfigValue {
  bodyTemperatureOptions: string[]
  heartRateOptions: string[]
  breatheOptions: string[]
  disclaimerTitle: string
  disclaimerContent: string
  disclaimerConfirmText: string
  disclaimerCancelText: string
}

/**
 * 医疗咨询配置值
 */
export interface MedicalConsultationConfigValue {
  paymentPromptDisclaimer: string
}

/**
 * 创建系统配置参数
 */
export interface CreateSystemConfigParams {
  configKey: string
  configValue: Record<string, any>
  description?: string
}

/**
 * 更新系统配置参数
 */
export interface UpdateSystemConfigParams {
  configValue: Record<string, any>
  description?: string
}

/**
 * 查询系统配置参数
 */
export interface SystemConfigQueryParams {
  page?: number
  pageSize?: number
  configKey?: string
}
