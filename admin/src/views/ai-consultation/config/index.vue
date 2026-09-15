<script setup lang="ts">
import { onMounted, ref } from 'vue'
import {
  ElAlert,
  ElButton,
  ElCard,
  ElDivider,
  ElForm,
  ElFormItem,
  ElInput,
  ElMessage
} from 'element-plus'
import { ContentWrap } from '@/components/ContentWrap'
import {
  createSystemConfigApi,
  getSystemConfigApi,
  updateSystemConfigApi
} from '@/api-new/system-configs'
import type { AiDiagnosisConfigValue } from '@/api-new/system-configs/types'

defineOptions({
  name: 'AiConsultationConfigPage'
})

const CONFIG_KEY = 'ai_diagnosis_config'
const CONFIG_DESCRIPTION = 'AI问诊基础配置'

const defaultConfig: AiDiagnosisConfigValue = {
  bodyTemperatureOptions: [
    '偏低（低于37.5℃）',
    '正常（37.5℃ - 39.2℃）',
    '偏高（39.3℃ - 40℃）',
    '高热（高于40℃）'
  ],
  heartRateOptions: ['偏慢', '正常', '偏快', '明显过快'],
  breatheOptions: ['偏慢', '正常', '偏快', '呼吸困难'],
  disclaimerTitle: '风险提示',
  disclaimerContent:
    'AI问诊结果仅供参考，不能替代线下执业兽医的面诊、检查与治疗建议。如宠物出现精神沉郁、持续呕吐腹泻、呼吸困难、抽搐、高热等紧急症状，请立即前往线下宠物医院就诊。',
  disclaimerConfirmText: '我已知晓，继续问诊',
  disclaimerCancelText: '再想想'
}

interface AiDiagnosisConfigForm {
  bodyTemperatureOptionsText: string
  heartRateOptionsText: string
  breatheOptionsText: string
  disclaimerTitle: string
  disclaimerContent: string
  disclaimerConfirmText: string
  disclaimerCancelText: string
}

const loading = ref(false)

const createFormFromConfig = (config: AiDiagnosisConfigValue): AiDiagnosisConfigForm => {
  return {
    bodyTemperatureOptionsText: config.bodyTemperatureOptions.join('\n'),
    heartRateOptionsText: config.heartRateOptions.join('\n'),
    breatheOptionsText: config.breatheOptions.join('\n'),
    disclaimerTitle: config.disclaimerTitle,
    disclaimerContent: config.disclaimerContent,
    disclaimerConfirmText: config.disclaimerConfirmText,
    disclaimerCancelText: config.disclaimerCancelText
  }
}

const form = ref<AiDiagnosisConfigForm>(createFormFromConfig(defaultConfig))

const parseOptionsText = (text: string) => {
  return text
    .split('\n')
    .map((item) => item.trim())
    .filter(Boolean)
}

const buildConfigPayload = (): AiDiagnosisConfigValue => {
  return {
    bodyTemperatureOptions: parseOptionsText(form.value.bodyTemperatureOptionsText),
    heartRateOptions: parseOptionsText(form.value.heartRateOptionsText),
    breatheOptions: parseOptionsText(form.value.breatheOptionsText),
    disclaimerTitle: form.value.disclaimerTitle.trim(),
    disclaimerContent: form.value.disclaimerContent.trim(),
    disclaimerConfirmText: form.value.disclaimerConfirmText.trim(),
    disclaimerCancelText: form.value.disclaimerCancelText.trim()
  }
}

const normalizeConfig = (configValue?: Partial<AiDiagnosisConfigValue>): AiDiagnosisConfigValue => {
  return {
    bodyTemperatureOptions:
      configValue?.bodyTemperatureOptions && configValue.bodyTemperatureOptions.length > 0
        ? configValue.bodyTemperatureOptions
        : defaultConfig.bodyTemperatureOptions,
    heartRateOptions:
      configValue?.heartRateOptions && configValue.heartRateOptions.length > 0
        ? configValue.heartRateOptions
        : defaultConfig.heartRateOptions,
    breatheOptions:
      configValue?.breatheOptions && configValue.breatheOptions.length > 0
        ? configValue.breatheOptions
        : defaultConfig.breatheOptions,
    disclaimerTitle: configValue?.disclaimerTitle?.trim() || defaultConfig.disclaimerTitle,
    disclaimerContent: configValue?.disclaimerContent?.trim() || defaultConfig.disclaimerContent,
    disclaimerConfirmText:
      configValue?.disclaimerConfirmText?.trim() || defaultConfig.disclaimerConfirmText,
    disclaimerCancelText:
      configValue?.disclaimerCancelText?.trim() || defaultConfig.disclaimerCancelText
  }
}

const loadConfig = async () => {
  try {
    loading.value = true
    const res = await getSystemConfigApi(CONFIG_KEY)
    form.value = createFormFromConfig(
      normalizeConfig(res.data?.configValue as Partial<AiDiagnosisConfigValue>)
    )
  } catch (error: any) {
    console.error('加载 AI 问诊配置失败:', error)
    form.value = createFormFromConfig(defaultConfig)

    if (error?.response?.status !== 404 && error?.status !== 404) {
      ElMessage.error('加载配置失败，已回退到默认值')
    }
  } finally {
    loading.value = false
  }
}

const saveConfig = async () => {
  const payload = buildConfigPayload()

  if (
    payload.bodyTemperatureOptions.length === 0 ||
    payload.heartRateOptions.length === 0 ||
    payload.breatheOptions.length === 0
  ) {
    ElMessage.error('三个下拉选项组都至少需要保留一项')
    return
  }

  if (!payload.disclaimerTitle || !payload.disclaimerContent) {
    ElMessage.error('请完善免责声明标题和内容')
    return
  }

  try {
    loading.value = true

    try {
      await updateSystemConfigApi(CONFIG_KEY, {
        configValue: payload,
        description: CONFIG_DESCRIPTION
      })
    } catch (error: any) {
      if (error?.response?.status === 404 || error?.status === 404) {
        await createSystemConfigApi({
          configKey: CONFIG_KEY,
          configValue: payload,
          description: CONFIG_DESCRIPTION
        })
      } else {
        throw error
      }
    }

    ElMessage.success('保存成功')
  } catch (error) {
    console.error('保存 AI 问诊配置失败:', error)
    ElMessage.error('保存失败，请稍后重试')
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  loadConfig()
})
</script>

<template>
  <ContentWrap>
    <ElCard shadow="never">
      <template #header>
        <div class="card-header">
          <span>AI 问诊配置</span>
        </div>
      </template>

      <div v-loading="loading" class="config-page">
        <ElAlert
          title="这里的配置会同时影响 APP 端 AI 问诊记录页和 AI 问诊填写页"
          type="info"
          :closable="false"
          show-icon
          class="page-alert"
        />

        <ElForm label-width="148px">
          <ElFormItem label="免责声明标题">
            <ElInput v-model="form.disclaimerTitle" placeholder="请输入弹窗标题" clearable />
          </ElFormItem>

          <ElFormItem label="免责声明内容">
            <ElInput
              v-model="form.disclaimerContent"
              type="textarea"
              :rows="6"
              placeholder="请输入免责声明正文"
            />
          </ElFormItem>

          <ElFormItem label="确认按钮文案">
            <ElInput
              v-model="form.disclaimerConfirmText"
              placeholder="例如：我已知晓，继续问诊"
              clearable
            />
          </ElFormItem>

          <ElFormItem label="取消按钮文案">
            <ElInput v-model="form.disclaimerCancelText" placeholder="例如：再想想" clearable />
          </ElFormItem>

          <ElFormItem class="options-divider-item">
            <ElDivider>选项配置：一行一个选项，APP 端会按填写顺序展示。</ElDivider>
          </ElFormItem>

          <ElFormItem label="体温下拉选项">
            <ElInput
              v-model="form.bodyTemperatureOptionsText"
              type="textarea"
              :rows="6"
              placeholder="每行一个选项"
            />
          </ElFormItem>

          <ElFormItem label="心率下拉选项">
            <ElInput
              v-model="form.heartRateOptionsText"
              type="textarea"
              :rows="5"
              placeholder="每行一个选项"
            />
          </ElFormItem>

          <ElFormItem label="呼吸下拉选项">
            <ElInput
              v-model="form.breatheOptionsText"
              type="textarea"
              :rows="5"
              placeholder="每行一个选项"
            />
          </ElFormItem>

          <ElFormItem>
            <ElButton type="primary" :loading="loading" @click="saveConfig"> 保存配置 </ElButton>
          </ElFormItem>
        </ElForm>
      </div>
    </ElCard>
  </ContentWrap>
</template>

<style scoped lang="scss">
.card-header {
  font-size: 16px;
  font-weight: 600;
  color: var(--el-text-color-primary);
}

.config-page {
  max-width: 920px;
}

.page-alert {
  margin-bottom: 20px;
}

.options-divider-item {
  margin-bottom: 20px;
}

.options-divider-item :deep(.el-form-item__content) {
  margin-left: 0 !important;
}

.options-divider-item :deep(.el-divider__text) {
  font-size: 12px;
  color: var(--el-text-color-secondary);
}
</style>
