<script setup lang="ts">
import { ref, onMounted } from 'vue'
import {
  ElTabs,
  ElTabPane,
  ElCard,
  ElMessage,
  ElForm,
  ElFormItem,
  ElInput,
  ElButton,
  ElInputNumber,
  ElRadio,
  ElRadioGroup
} from 'element-plus'
import { ImageUpload } from '@/components/ImageUpload'
import {
  getSystemConfigApi,
  updateSystemConfigApi,
  createSystemConfigApi
} from '@/api-new/system-configs'
import type {
  ContactInfoValue,
  EmergencyCenterValue,
  HomeAiDiagnosisBannerValue,
  HomeMenuIconsValue,
  MallHomePopupImageValue,
  MedicalConsultationConfigValue,
  ScrollingAnnouncementValue,
  PlatformFeeValue
} from '@/api-new/system-configs/types'

const HOME_MENU_ICON_CONFIG_KEY = 'home_menu_icons'
const HOME_AI_DIAGNOSIS_BANNER_CONFIG_KEY = 'home_ai_diagnosis_banner'
const MALL_HOME_POPUP_IMAGE_CONFIG_KEY = 'mall_home_popup_image'
const SCROLLING_ANNOUNCEMENT_CONFIG_KEY = 'scrolling_announcement'
const MEDICAL_CONSULTATION_CONFIG_KEY = 'medical_consultation_config'
const DEFAULT_PAYMENT_PROMPT_DISCLAIMER =
  '在线咨询仅供宠物健康管理参考，不能替代线下诊疗。若宠物出现急症或症状加重，请及时前往正规宠物医院就诊。'

const HOME_MENU_ITEMS = [
  { key: 'pet-list', label: '宠物档案' },
  { key: 'gold-doctor', label: '金牌咨询' },
  { key: 'emergency', label: '急救中心' },
  { key: 'health', label: '营养师' },
  { key: 'nearby', label: '附近' },
  { key: 'charity', label: '公益中心' },
  { key: 'lost-found', label: '走失领养' },
  { key: 'activity', label: '活动管理' },
  { key: 'community', label: '宠物社区' },
  { key: 'second-hand-mall', label: '二手商城' }
]

// 当前激活的 Tab
const activeTab = ref('contact')

// 联系方式表单数据
const contactForm = ref<ContactInfoValue>({
  wechatQrCode: '',
  hotline: '',
  workingHours: ''
})

const feeForm = ref<PlatformFeeValue>({
  feeRate: 5
})

const emergencyForm = ref<EmergencyCenterValue>({
  emergencyTime: '',
  emergencyHotline: ''
})

const homeMenuIconsForm = ref<HomeMenuIconsValue>({
  icons: HOME_MENU_ITEMS.reduce<Record<string, string>>((result, item) => {
    result[item.key] = ''
    return result
  }, {})
})

const homeAiDiagnosisBannerForm = ref<HomeAiDiagnosisBannerValue>({
  imageUrl: ''
})

const mallHomePopupImageForm = ref<MallHomePopupImageValue>({
  imageUrl: ''
})

const scrollingAnnouncementForm = ref<ScrollingAnnouncementValue>({
  source: 'fixed',
  announcementText: ''
})

const medicalConsultationForm = ref<MedicalConsultationConfigValue>({
  paymentPromptDisclaimer: DEFAULT_PAYMENT_PROMPT_DISCLAIMER
})

// 加载状态
const loading = ref(false)

const normalizeHomeMenuIconsValue = (value?: Partial<HomeMenuIconsValue>): HomeMenuIconsValue => {
  const icons = HOME_MENU_ITEMS.reduce<Record<string, string>>((result, item) => {
    result[item.key] = String(value?.icons?.[item.key] ?? '')
    return result
  }, {})

  return { icons }
}

const normalizeHomeAiDiagnosisBannerValue = (
  value?: Partial<HomeAiDiagnosisBannerValue>
): HomeAiDiagnosisBannerValue => {
  return {
    imageUrl: String(value?.imageUrl ?? '').trim()
  }
}

const normalizeMallHomePopupImageValue = (
  value?: Partial<MallHomePopupImageValue>
): MallHomePopupImageValue => {
  return {
    imageUrl: String(value?.imageUrl ?? '').trim()
  }
}

const normalizeScrollingAnnouncementValue = (
  value?: Partial<ScrollingAnnouncementValue>
): ScrollingAnnouncementValue => {
  const source = value?.source

  return {
    source: source === 'donation' || source === 'disabled' ? source : 'fixed',
    announcementText: String(value?.announcementText ?? '').trim()
  }
}

const normalizeMedicalConsultationValue = (
  value?: Partial<MedicalConsultationConfigValue>
): MedicalConsultationConfigValue => {
  const paymentPromptDisclaimer = String(value?.paymentPromptDisclaimer ?? '').trim()

  return {
    paymentPromptDisclaimer: paymentPromptDisclaimer || DEFAULT_PAYMENT_PROMPT_DISCLAIMER
  }
}

const saveOrCreateSystemConfig = async (
  configKey: string,
  configValue: Record<string, any>,
  description: string
) => {
  try {
    await updateSystemConfigApi(configKey, {
      configValue,
      description
    })
  } catch (error: any) {
    if (error?.response?.status === 404 || error?.status === 404 || error?.statusCode === 404) {
      await createSystemConfigApi({
        configKey,
        configValue,
        description
      })
      return
    }

    throw error
  }
}

/**
 * 加载联系方式配置
 */
const loadContactConfig = async () => {
  try {
    loading.value = true
    const res = await getSystemConfigApi('contact_info')

    if (res.data?.configValue) {
      contactForm.value = res.data.configValue as ContactInfoValue
    }
  } catch (error) {
    console.error('加载联系方式配置失败:', error)
    ElMessage.error('加载配置失败')
  } finally {
    loading.value = false
  }
}

/**
 * 加载平台手续费配置
 */
const loadPlatformFeeConfig = async () => {
  try {
    loading.value = true
    const res = await getSystemConfigApi('platform_fee_rate')

    if (res.data?.configValue) {
      feeForm.value = {
        feeRate: Number(res.data.configValue.feeRate ?? 5)
      }
    }
  } catch (error) {
    console.error('加载平台手续费配置失败:', error)
    feeForm.value = { feeRate: 5 }
  } finally {
    loading.value = false
  }
}

/**
 * 加载急救中心配置
 */
const loadEmergencyConfig = async () => {
  try {
    loading.value = true
    const res = await getSystemConfigApi('emergency_center')

    if (res.data?.configValue) {
      emergencyForm.value = {
        emergencyTime: String(res.data.configValue.emergencyTime ?? ''),
        emergencyHotline: String(res.data.configValue.emergencyHotline ?? '')
      }
    }
  } catch (error) {
    console.error('加载急救中心配置失败:', error)
    emergencyForm.value = {
      emergencyTime: '',
      emergencyHotline: ''
    }
  } finally {
    loading.value = false
  }
}

/**
 * 加载首页菜单图标配置
 */
const loadHomeMenuIconsConfig = async () => {
  try {
    loading.value = true
    const res = await getSystemConfigApi(HOME_MENU_ICON_CONFIG_KEY)

    homeMenuIconsForm.value = normalizeHomeMenuIconsValue(
      res.data?.configValue as Partial<HomeMenuIconsValue>
    )
  } catch (error) {
    console.error('加载首页菜单图标配置失败:', error)
    homeMenuIconsForm.value = normalizeHomeMenuIconsValue()
  } finally {
    loading.value = false
  }
}

/**
 * 加载首页 AI 智能诊断 Banner 配置
 */
const loadHomeAiDiagnosisBannerConfig = async () => {
  try {
    loading.value = true
    const res = await getSystemConfigApi(HOME_AI_DIAGNOSIS_BANNER_CONFIG_KEY)

    homeAiDiagnosisBannerForm.value = normalizeHomeAiDiagnosisBannerValue(
      res.data?.configValue as Partial<HomeAiDiagnosisBannerValue>
    )
  } catch (error) {
    console.error('加载首页AI智能诊断Banner配置失败:', error)
    homeAiDiagnosisBannerForm.value = normalizeHomeAiDiagnosisBannerValue()
  } finally {
    loading.value = false
  }
}

/**
 * 加载商城首页弹窗配置
 */
const loadMallHomePopupImageConfig = async () => {
  try {
    loading.value = true
    const res = await getSystemConfigApi(MALL_HOME_POPUP_IMAGE_CONFIG_KEY)

    mallHomePopupImageForm.value = normalizeMallHomePopupImageValue(
      res.data?.configValue as Partial<MallHomePopupImageValue>
    )
  } catch (error) {
    console.error('加载商城首页弹窗配置失败:', error)
    mallHomePopupImageForm.value = normalizeMallHomePopupImageValue()
  } finally {
    loading.value = false
  }
}

/**
 * 加载滚动公告配置
 */
const loadScrollingAnnouncementConfig = async () => {
  try {
    loading.value = true
    const res = await getSystemConfigApi(SCROLLING_ANNOUNCEMENT_CONFIG_KEY)

    scrollingAnnouncementForm.value = normalizeScrollingAnnouncementValue(
      res.data?.configValue as Partial<ScrollingAnnouncementValue>
    )
  } catch (error) {
    console.error('加载滚动公告配置失败:', error)
    scrollingAnnouncementForm.value = normalizeScrollingAnnouncementValue()
  } finally {
    loading.value = false
  }
}

/**
 * 加载医疗咨询配置
 */
const loadMedicalConsultationConfig = async () => {
  try {
    loading.value = true
    const res = await getSystemConfigApi(MEDICAL_CONSULTATION_CONFIG_KEY)

    medicalConsultationForm.value = normalizeMedicalConsultationValue(
      res.data?.configValue as Partial<MedicalConsultationConfigValue>
    )
  } catch (error) {
    console.error('加载医疗咨询配置失败:', error)
    medicalConsultationForm.value = normalizeMedicalConsultationValue()
  } finally {
    loading.value = false
  }
}

/**
 * 保存联系方式配置
 */
const saveContactConfig = async () => {
  try {
    loading.value = true

    await updateSystemConfigApi('contact_info', {
      configValue: contactForm.value,
      description: '联系方式配置'
    })

    ElMessage.success('保存成功')
  } catch (error) {
    console.error('保存联系方式配置失败:', error)
    ElMessage.error('保存失败，请稍后重试')
  } finally {
    loading.value = false
  }
}

/**
 * 保存急救中心配置
 */
const saveEmergencyConfig = async () => {
  try {
    loading.value = true

    await saveOrCreateSystemConfig('emergency_center', emergencyForm.value, '急救中心配置')

    ElMessage.success('保存成功')
  } catch (error) {
    console.error('保存急救中心配置失败:', error)
    ElMessage.error('保存失败，请稍后重试')
  } finally {
    loading.value = false
  }
}

/**
 * 保存平台手续费配置
 */
const savePlatformFeeConfig = async () => {
  try {
    loading.value = true

    await saveOrCreateSystemConfig('platform_fee_rate', feeForm.value, '平台手续费率配置（百分比）')

    ElMessage.success('保存成功')
  } catch (error) {
    console.error('保存平台手续费配置失败:', error)
    ElMessage.error('保存失败，请稍后重试')
  } finally {
    loading.value = false
  }
}

/**
 * 保存首页菜单配置
 */
const saveHomeMenuConfig = async () => {
  try {
    loading.value = true

    const popupImageConfigValue = normalizeMallHomePopupImageValue(mallHomePopupImageForm.value)
    const bannerConfigValue = normalizeHomeAiDiagnosisBannerValue(homeAiDiagnosisBannerForm.value)

    await saveOrCreateSystemConfig(
      MALL_HOME_POPUP_IMAGE_CONFIG_KEY,
      popupImageConfigValue,
      '商城首页弹窗配置'
    )
    await saveOrCreateSystemConfig(
      HOME_AI_DIAGNOSIS_BANNER_CONFIG_KEY,
      bannerConfigValue,
      'App 首页AI智能诊断Banner配置'
    )

    await saveOrCreateSystemConfig(
      HOME_MENU_ICON_CONFIG_KEY,
      homeMenuIconsForm.value,
      'App 首页菜单图标配置'
    )
    mallHomePopupImageForm.value = popupImageConfigValue
    homeAiDiagnosisBannerForm.value = bannerConfigValue

    ElMessage.success('保存成功')
  } catch (error) {
    console.error('保存首页菜单配置失败:', error)
    ElMessage.error('保存失败，请稍后重试')
  } finally {
    loading.value = false
  }
}

/**
 * 保存滚动公告配置
 */
const saveScrollingAnnouncementConfig = async () => {
  try {
    loading.value = true

    const configValue = normalizeScrollingAnnouncementValue(scrollingAnnouncementForm.value)

    await saveOrCreateSystemConfig(
      SCROLLING_ANNOUNCEMENT_CONFIG_KEY,
      configValue,
      'App 首页滚动公告配置'
    )
    scrollingAnnouncementForm.value = configValue

    ElMessage.success('保存成功')
  } catch (error) {
    console.error('保存滚动公告配置失败:', error)
    ElMessage.error('保存失败，请稍后重试')
  } finally {
    loading.value = false
  }
}

/**
 * 保存医疗咨询配置
 */
const saveMedicalConsultationConfig = async () => {
  try {
    loading.value = true

    const configValue = normalizeMedicalConsultationValue(medicalConsultationForm.value)
    await saveOrCreateSystemConfig(MEDICAL_CONSULTATION_CONFIG_KEY, configValue, '医疗咨询基础配置')
    medicalConsultationForm.value = configValue

    ElMessage.success('保存成功')
  } catch (error) {
    console.error('保存医疗咨询配置失败:', error)
    ElMessage.error('保存失败，请稍后重试')
  } finally {
    loading.value = false
  }
}

// 页面加载时获取配置
onMounted(() => {
  loadContactConfig()
  loadEmergencyConfig()
  loadPlatformFeeConfig()
  loadMallHomePopupImageConfig()
  loadHomeAiDiagnosisBannerConfig()
  loadHomeMenuIconsConfig()
  loadScrollingAnnouncementConfig()
  loadMedicalConsultationConfig()
})
</script>

<template>
  <div class="system-configs-container">
    <ElCard>
      <ElTabs v-model="activeTab">
        <!-- 联系方式 Tab -->
        <ElTabPane label="联系方式" name="contact">
          <div v-loading="loading" class="config-form">
            <el-form label-width="120px">
              <!-- 微信二维码 -->
              <el-form-item label="微信二维码">
                <ImageUpload
                  v-model="contactForm.wechatQrCode"
                  :aspect-ratio="1"
                  :crop-box-width="300"
                  :crop-box-height="300"
                  category="system-config-wechat"
                  dialog-title="上传微信二维码"
                  :disabled="loading"
                />
                <div class="form-item-tip"> 建议上传正方形图片，尺寸不超过 500x500 像素 </div>
              </el-form-item>

              <!-- 客服热线 -->
              <el-form-item label="客服热线" required>
                <el-input
                  v-model="contactForm.hotline"
                  placeholder="请输入客服热线，如：400-123-4567"
                  :disabled="loading"
                  clearable
                />
              </el-form-item>

              <!-- 工作时间 -->
              <el-form-item label="工作时间" required>
                <el-input
                  v-model="contactForm.workingHours"
                  type="textarea"
                  :rows="4"
                  placeholder="请输入工作时间，例如：&#10;周一至周五 9:00-18:00&#10;周末 10:00-17:00"
                  :disabled="loading"
                />
              </el-form-item>

              <!-- 操作按钮 -->
              <el-form-item>
                <el-button type="primary" :loading="loading" @click="saveContactConfig">
                  保存
                </el-button>
              </el-form-item>
            </el-form>
          </div>
        </ElTabPane>

        <ElTabPane label="急救中心" name="emergency">
          <div v-loading="loading" class="config-form">
            <el-form label-width="120px">
              <el-form-item label="急救时间" required>
                <el-input
                  v-model="emergencyForm.emergencyTime"
                  placeholder="请输入急救时间，如：24小时在线"
                  :disabled="loading"
                  clearable
                />
              </el-form-item>

              <el-form-item label="急救热线" required>
                <el-input
                  v-model="emergencyForm.emergencyHotline"
                  placeholder="请输入急救热线，如：400-000-0000"
                  :disabled="loading"
                  clearable
                />
              </el-form-item>

              <el-form-item>
                <el-button type="primary" :loading="loading" @click="saveEmergencyConfig">
                  保存
                </el-button>
              </el-form-item>
            </el-form>
          </div>
        </ElTabPane>

        <ElTabPane label="首页菜单" name="home-menu">
          <div v-loading="loading" class="config-form home-menu-config-form">
            <el-form label-width="180px" class="home-ai-banner-form">
              <el-form-item label="商城首页弹窗">
                <ImageUpload
                  v-model="mallHomePopupImageForm.imageUrl"
                  :direct-upload="true"
                  :preview-width="240"
                  :preview-height="240"
                  placeholder="上传商城首页弹窗图片"
                  category="mall-home-popup"
                  dialog-title="上传商城首页弹窗图片"
                  :disabled="loading"
                />
                <div class="form-item-tip">
                  上传后 App 每次进入商城首页都会弹出该图片，图片可长按保存到本地相册。
                </div>
              </el-form-item>

              <el-form-item label="首页AI智能诊断Banner">
                <ImageUpload
                  v-model="homeAiDiagnosisBannerForm.imageUrl"
                  :direct-upload="true"
                  :preview-width="320"
                  :preview-height="131"
                  placeholder="上传首页AI智能诊断Banner"
                  category="home-ai-diagnosis-banner"
                  dialog-title="上传首页AI智能诊断Banner"
                  :disabled="loading"
                />
                <div class="form-item-tip">
                  上传并点击保存后，App
                  首页菜单上方横幅会优先显示该图片；未上传时继续显示当前默认图片。
                </div>
              </el-form-item>
            </el-form>

            <div class="form-item-tip">
              上传后 App
              首页对应菜单会优先显示图片；未上传的菜单继续使用默认图标和背景色。图标会按正方形裁剪。
            </div>

            <div class="home-menu-icon-grid">
              <div v-for="item in HOME_MENU_ITEMS" :key="item.key" class="home-menu-icon-item">
                <div class="home-menu-icon-title">{{ item.label }}</div>
                <ImageUpload
                  v-model="homeMenuIconsForm.icons[item.key]"
                  :aspect-ratio="1"
                  :crop-box-width="240"
                  :crop-box-height="240"
                  :preview-width="100"
                  :preview-height="100"
                  :placeholder="`上传${item.label}`"
                  category="home-menu-icon"
                  :dialog-title="`上传${item.label}图标`"
                  :disabled="loading"
                />
              </div>
            </div>

            <el-button type="primary" :loading="loading" @click="saveHomeMenuConfig">
              保存
            </el-button>
          </div>
        </ElTabPane>

        <ElTabPane label="医疗咨询" name="medical-consultation">
          <div v-loading="loading" class="config-form">
            <el-form label-width="140px">
              <el-form-item label="付费提示免责声明" required>
                <el-input
                  v-model="medicalConsultationForm.paymentPromptDisclaimer"
                  type="textarea"
                  :rows="5"
                  placeholder="请输入免费咨询次数用完后付费提示上方展示的免责声明"
                  :disabled="loading"
                />
                <div class="form-item-tip">
                  该文案会展示在 App 聊天页“免费咨询次数已用完”提示框上方。
                </div>
              </el-form-item>

              <el-form-item>
                <el-button type="primary" :loading="loading" @click="saveMedicalConsultationConfig">
                  保存
                </el-button>
              </el-form-item>
            </el-form>
          </div>
        </ElTabPane>

        <ElTabPane label="交易配置" name="trade">
          <div v-loading="loading" class="config-form">
            <el-form label-width="120px">
              <el-form-item label="平台手续费">
                <div class="fee-rate-row">
                  <el-input-number
                    v-model="feeForm.feeRate"
                    :min="0"
                    :max="100"
                    :precision="2"
                    :step="0.1"
                    :disabled="loading"
                  />
                  <span class="fee-rate-unit">%</span>
                </div>
                <div class="form-item-tip">
                  用户发布商品成交后，后台审核入账金额 = 成交金额 - 手续费
                </div>
              </el-form-item>

              <el-form-item>
                <el-button type="primary" :loading="loading" @click="savePlatformFeeConfig">
                  保存
                </el-button>
              </el-form-item>
            </el-form>
          </div>
        </ElTabPane>

        <ElTabPane label="滚动公告" name="scrolling-announcement">
          <div v-loading="loading" class="config-form">
            <el-form label-width="120px">
              <el-form-item label="公告来源">
                <el-radio-group v-model="scrollingAnnouncementForm.source" :disabled="loading">
                  <el-radio value="donation">捐赠记录</el-radio>
                  <el-radio value="fixed">固定内容</el-radio>
                  <el-radio value="disabled">关闭</el-radio>
                </el-radio-group>
              </el-form-item>

              <el-form-item label="公告内容">
                <el-input
                  v-model="scrollingAnnouncementForm.announcementText"
                  placeholder="请输入首页滚动公告内容"
                  :disabled="loading || scrollingAnnouncementForm.source !== 'fixed'"
                  maxlength="200"
                  show-word-limit
                  clearable
                />
                <div class="form-item-tip"
                  >选择捐赠记录时展示最新 20
                  条公益捐赠；选择固定内容时使用此文案，内容为空则隐藏；选择关闭时首页隐藏公告。</div
                >
              </el-form-item>

              <el-form-item>
                <el-button
                  type="primary"
                  :loading="loading"
                  @click="saveScrollingAnnouncementConfig"
                >
                  保存
                </el-button>
              </el-form-item>
            </el-form>
          </div>
        </ElTabPane>
      </ElTabs>
    </ElCard>
  </div>
</template>

<style scoped lang="scss">
.system-configs-container {
  padding: 20px;

  .config-form {
    max-width: 800px;
    padding: 20px 0;

    .form-item-tip {
      margin-top: 8px;
      font-size: 12px;
      color: var(--el-text-color-secondary);
    }

    .fee-rate-row {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .fee-rate-unit {
      font-size: 14px;
      color: var(--el-text-color-regular);
    }
  }

  .home-menu-config-form {
    max-width: 100%;
  }

  .home-menu-icon-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
    gap: 18px;
    margin: 18px 0 24px;
  }

  .home-menu-icon-item {
    padding: 16px;
    background: var(--el-fill-color-lighter);
    border: 1px solid var(--el-border-color-light);
    border-radius: 8px;
  }

  .home-menu-icon-title {
    margin-bottom: 10px;
    font-size: 14px;
    font-weight: 500;
    color: var(--el-text-color-primary);
  }
}
</style>
