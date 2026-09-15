<script setup lang="tsx">
import { watch, reactive } from 'vue'
import type { FormRules } from 'element-plus'
import { Form, FormSchema } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import { PropType } from 'vue'
import { useValidator } from '@/hooks/web/useValidator'
import { Pet } from '@/api-new/pets'
import type { PetCategoryTreeNode } from '@/api-new/pet-categories'
import { getImageUrl } from '@/utils/image'

const { required } = useValidator()

const props = defineProps({
  currentRow: {
    type: Object as PropType<Pet | null>,
    default: () => null
  },
  formSchema: {
    type: Array as PropType<FormSchema[]>,
    default: () => []
  },
  categoryTree: {
    type: Array as PropType<PetCategoryTreeNode[]>,
    default: () => []
  },
  firstLevelCategories: {
    type: Array as PropType<Array<{ label: string; value: number }>>,
    default: () => []
  },
  secondLevelCategories: {
    type: Object as PropType<Record<number, Array<{ label: string; value: number }>>>,
    default: () => ({})
  }
})

// 表单验证规则
const rules: FormRules = reactive({
  name: [required(), { max: 50, message: '宠物名称不能超过50个字符', trigger: 'blur' }],
  ownerId: [required({ message: '请选择拥有者', trigger: 'change' })],
  gender: [required()],
  weight: [
    {
      type: 'number' as const,
      min: 0,
      max: 999.99,
      message: '体重范围为 0-999.99 kg',
      trigger: 'blur'
    }
  ],
  vaccineCount: [
    {
      type: 'number' as const,
      min: 0,
      message: '疫苗针数不能小于 0',
      trigger: 'blur'
    }
  ]
})

const { formRegister, formMethods } = useForm()
const { setValues, getFormData, getElFormExpose } = formMethods

/**
 * 监听 currentRow 变化，回填表单数据
 */
watch(
  () => props.currentRow,
  (currentRow) => {
    if (!currentRow) {
      // 新增模式，重置数据
      setValues({
        name: '',
        avatar: '',
        categoryId: undefined,
        subCategoryId: undefined,
        gender: undefined,
        birthDate: '',
        weight: undefined,
        vaccineCount: undefined,
        tags: [],
        isNeutered: false,
        ownerId: undefined
      })
      return
    }

    // 编辑模式，填充数据
    // 使用 getImageUrl 统一处理 avatar URL
    const displayData = {
      ...currentRow,
      avatar: getImageUrl(currentRow.avatar),
      weight:
        currentRow.weight !== undefined && currentRow.weight !== null
          ? Number(currentRow.weight)
          : undefined
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
  const valid = await elForm?.validate().catch((err: any) => {
    console.log(err)
  })

  if (valid) {
    const formData = await getFormData()

    // 处理 avatar 字段：将完整 URL 转换为相对路径
    let avatarUrl = formData.avatar
    if (avatarUrl && avatarUrl.startsWith('http')) {
      try {
        const urlObj = new URL(avatarUrl)
        avatarUrl = urlObj.pathname
      } catch (e) {
        console.warn('URL 解析失败:', avatarUrl)
      }
    }

    // 构建提交数据
    const submitData: any = {
      name: formData.name,
      avatar: avatarUrl || undefined,
      categoryId: formData.categoryId || null,
      subCategoryId: formData.subCategoryId || null,
      gender: formData.gender,
      birthDate: formData.birthDate || undefined,
      weight: formData.weight || undefined,
      vaccineCount: formData.vaccineCount ?? undefined,
      tags: formData.tags || [],
      isNeutered: formData.isNeutered || false,
      ownerId: formData.ownerId
    }

    return submitData
  }
}

defineExpose({
  submit,
  setValues
})
</script>

<template>
  <Form :rules="rules" @register="formRegister" :schema="formSchema" />
</template>
