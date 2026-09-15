<script setup lang="tsx">
import { watch, reactive } from 'vue'
import { Form, FormSchema } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import { PropType } from 'vue'
import { useValidator } from '@/hooks/web/useValidator'
import { Hospital } from '@/api-new/hospitals'
import { ElMessage } from 'element-plus'
import { CodeToText } from 'rmc-element-china-area-data'
import { getImageUrl } from '@/utils/image'

const { required } = useValidator()

const props = defineProps({
  currentRow: {
    type: Object as PropType<Hospital | null>,
    default: () => null
  },
  formSchema: {
    type: Array as PropType<FormSchema[]>,
    default: () => []
  },
  regionCode: {
    type: Array as PropType<string[]>,
    default: () => []
  }
})

// 基本信息表单规则 - name、phone、address 必填
const rules = reactive({
  name: [required()],
  phone: [required()],
  address: [required()]
})

const { formRegister, formMethods } = useForm()
const { setValues, getFormData, getElFormExpose } = formMethods

/**
 * 规范化可选字符串字段
 * whitelist 恢复后，空字符串会继续参与 DTO 校验；这里统一转成 undefined。
 */
const normalizeOptionalString = (value: unknown) => {
  if (typeof value !== 'string') return value
  const trimmedValue = value.trim()
  return trimmedValue ? trimmedValue : undefined
}

/**
 * 设置表单字段值
 * 用于父组件更新特定字段
 */
const setFieldValue = (field: string, value: any) => {
  setValues({ [field]: value })
}

/**
 * 从区域码数组中提取省市区文本
 */
const extractRegionFromCode = (codes: string[]) => {
  if (!codes || codes.length === 0) return { province: '', city: '', county: '' }

  const provinceCode = codes[0] || ''
  const cityCode = codes[1] || ''
  const countyCode = codes[2] || ''

  return {
    province: CodeToText[provinceCode] || '',
    city: CodeToText[cityCode] || '',
    county: CodeToText[countyCode] || ''
  }
}

/**
 * 监听 regionCode 变化，同步到表单的 region 字段
 * 确保 region 字段有值，通过表单验证
 */
watch(
  () => props.regionCode,
  (newCodes) => {
    if (newCodes && newCodes.length > 0) {
      // 将区域码数组转换为字符串，存储到 region 字段
      const regionValue = newCodes.join(',')
      setValues({ region: regionValue })
    } else {
      setValues({ region: '' })
    }
  },
  { deep: true }
)

// 监听 currentRow 变化
watch(
  () => props.currentRow,
  (currentRow) => {
    if (!currentRow) {
      // 新增模式，重置数据
      return
    }

    // 编辑模式，填充数据
    // 使用 getImageUrl 统一处理 logo URL
    const displayData = {
      ...currentRow,
      logo: getImageUrl(currentRow.logo)
    }

    setValues(displayData)
  },
  {
    deep: true,
    immediate: true
  }
)

/**
 * 提交表单
 */
const submit = async () => {
  const elForm = await getElFormExpose()

  // 验证省市区是否已选择
  if (!props.regionCode || props.regionCode.length === 0) {
    ElMessage.warning('请选择所在地区')
    return
  }

  const valid = await elForm?.validate().catch((err: any) => {
    console.log(err)
  })
  if (valid) {
    const formData = await getFormData()

    // 从区域码中提取省市区文本
    const regionInfo = extractRegionFromCode(props.regionCode)

    // 处理 logo 字段：将完整 URL 转换为相对路径
    let logoUrl = formData.logo
    if (logoUrl && logoUrl.startsWith('http')) {
      try {
        const urlObj = new URL(logoUrl)
        logoUrl = urlObj.pathname
      } catch (e) {
        // 如果 URL 解析失败，保持原样
        console.warn('URL 解析失败:', logoUrl)
      }
    }

    // 构建提交数据，只包含白名单字段（排除 id、rating、reviewCount、appointmentCount、createdAt、updatedAt）
    const submitData: any = {
      name: String(formData.name ?? '').trim(),
      logo: normalizeOptionalString(logoUrl),
      description: normalizeOptionalString(formData.description),
      province: regionInfo.province,
      city: regionInfo.city,
      county: regionInfo.county,
      address: String(formData.address ?? '').trim(),
      phone: String(formData.phone ?? '').trim(),
      email: normalizeOptionalString(formData.email),
      businessHours: formData.businessHours,
      facilities: normalizeOptionalString(formData.facilities)
    }

    // 处理经纬度：将字符串转为数字
    if (formData.latitude !== undefined && formData.latitude !== null && formData.latitude !== '') {
      submitData.latitude = Number(formData.latitude)
    }
    if (
      formData.longitude !== undefined &&
      formData.longitude !== null &&
      formData.longitude !== ''
    ) {
      submitData.longitude = Number(formData.longitude)
    }

    // 处理状态字段：前端使用 isActive，后端也支持
    if (formData.isActive !== undefined) {
      submitData.isActive = formData.isActive
    }

    return submitData
  }
}

defineExpose({
  submit,
  setFieldValue
})
</script>

<template>
  <div class="hospital-form">
    <!-- 表单字段 -->
    <Form :rules="rules" @register="formRegister" :schema="formSchema" />
  </div>
</template>

<style scoped lang="scss">
.hospital-form {
  padding: 0;
}

// 优化表单项间距
:deep(.el-form-item) {
  margin-bottom: 18px;
}
</style>
