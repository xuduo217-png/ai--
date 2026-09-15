<script setup lang="ts">
import { ContentWrap } from '@/components/ContentWrap'
import { Form, FormSchema } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import { useValidator } from '@/hooks/web/useValidator'
import { ref, computed, onMounted, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  getDoctorDetailApi,
  createDoctorApi,
  updateDoctorApi,
  batchAddServiceItemsApi,
  type CreateDoctorParams,
  type UpdateDoctorParams,
  type CreateServiceItemParams
} from '@/api-new/doctors'
import { ElMessage, ElRow, ElCol, ElCard, ElButton } from 'element-plus'
import { ArrowLeft } from '@element-plus/icons-vue'
import ServiceItemsInput from './components/ServiceItemsInput.vue'
import { getHospitalListApi } from '@/api-new/hospitals'
import { getDepartmentListApi } from '@/api-new/departments'

const { required } = useValidator()
const route = useRoute()
const router = useRouter()

// 获取路由参数中的医生 ID（如果有则是编辑模式）
const doctorId = ref<number | null>(null)
const isEdit = computed(() => !!doctorId.value)

// 收费项数据（仅新建时使用）
const serviceItems = ref<CreateServiceItemParams[]>([])

// 表单加载状态
const loading = ref(false)

// 当前选择的医院ID（用于科室联动）
const selectedHospitalId = ref<number | null>(null)

// 获取医院列表（用于下拉选项）
const hospitalList = ref<any[]>([])
const loadHospitals = async () => {
  try {
    const res = await getHospitalListApi({ page: 1, pageSize: 100 })
    hospitalList.value = (res.data || []) as any
  } catch (error) {
    console.error('获取医院列表失败', error)
  }
}

// 获取所有科室列表（用于根据医院ID过滤）
const allDepartmentList = ref<any[]>([])
const loadDepartments = async () => {
  try {
    const res = await getDepartmentListApi({ page: 1, pageSize: 100 })
    allDepartmentList.value = (res.data || []) as any
  } catch (error) {
    console.error('获取科室列表失败', error)
  }
}

// 根据选中的医院过滤科室列表
const filteredDepartmentList = computed(() => {
  if (!selectedHospitalId.value) {
    return []
  }
  return allDepartmentList.value.filter((dept) => dept.hospitalId === selectedHospitalId.value)
})

// 初始化加载数据
onMounted(async () => {
  // 加载医院和科室列表
  await Promise.all([loadHospitals(), loadDepartments()])

  // 判断是新增还是编辑模式
  if (route.name === 'DoctorEdit' && route.params.id) {
    // 编辑模式
    doctorId.value = Number(route.params.id)
    // 等待 DOM 更新后再加载医生详情
    await nextTick()
    await loadDoctorDetail()
  } else {
    // 新增模式
    serviceItems.value = [{ name: '', duration: 30, price: 0, isActive: true }]
  }
})

/**
 * 加载医生详情
 */
const loadDoctorDetail = async () => {
  if (!doctorId.value) return

  loading.value = true
  try {
    const res = await getDoctorDetailApi(doctorId.value)
    const doctor = res.data as any // 使用 any 类型，因为后端返回的字段比类型定义多

    console.log('加载医生详情:', doctor)

    // 等待 Form 组件完全渲染
    await nextTick()

    // 设置表单数据（类型转换）
    setValues({
      username: doctor.username,
      password: '', // 编辑时不回显密码
      phone: doctor.phone,
      name: doctor.name,
      avatar: doctor.avatar,
      specialty: doctor.specialty,
      description: doctor.description,
      experience: Math.round(Number(doctor.experience)) || 0, // 转换为整数
      rating: Math.round(Number(doctor.rating)) || 0, // 转换为整数
      isGoldDoctor: Boolean(doctor.isGoldDoctor),
      hospitalId: Number(doctor.hospitalId),
      departmentId: Number(doctor.departmentId),
      isActive: Boolean(doctor.isActive)
    })

    // 设置当前医院ID（用于科室联动）
    if (doctor.hospitalId) {
      selectedHospitalId.value = Number(doctor.hospitalId)
    }

    console.log('表单数据已设置')
  } catch (error) {
    console.error('加载医生详情失败:', error)
    ElMessage.error('加载医生详情失败')
  } finally {
    loading.value = false
  }
}

// 表单验证规则（仅在 formSchema 中未定义时使用）
const rules = computed(() => ({
  username: [required()],
  password: isEdit.value ? [] : [required()],
  phone: [required()],
  name: [required()],
  specialty: [required()],
  rating: isEdit.value ? [required()] : [],
  hospitalId: [required()],
  departmentId: [required()]
  // experience 的验证已在 formSchema.formItemProps 中定义
}))

const { formRegister, formMethods } = useForm()
const { setValues, getFormData, getElFormExpose } = formMethods

/**
 * 设置表单字段值
 */
const setFieldValue = (field: string, value: any) => {
  setValues({ [field]: value })
}

// 表单配置（使用 computed 以响应式访问 hospitalList 等数据）
const formSchema = computed<FormSchema[]>(() => [
  {
    field: 'avatar',
    label: '头像',
    component: 'ImageUpload',
    componentProps: {
      placeholder: '点击上传医生头像',
      aspectRatio: 1,
      cropBoxWidth: 200,
      cropBoxHeight: 200,
      category: 'doctor-avatar',
      circle: true,
      previewWidth: 120,
      previewHeight: 120
    },
    colProps: { span: 24 }
  },
  {
    field: 'username',
    label: '用户名',
    component: 'Input',
    componentProps: {
      placeholder: '请输入登录用户名',
      disabled: isEdit.value
    }
  },
  {
    field: 'password',
    label: '密码',
    component: 'Input',
    componentProps: {
      type: 'password',
      showPassword: true,
      placeholder: isEdit.value ? '留空则不修改密码' : '请输入密码（至少6位）'
    }
  },
  {
    field: 'phone',
    label: '手机号',
    component: 'Input',
    componentProps: {
      placeholder: '请输入手机号'
    }
  },
  {
    field: 'name',
    label: '姓名',
    component: 'Input',
    componentProps: {
      placeholder: '请输入医生姓名'
    }
  },
  {
    field: 'specialty',
    label: '专长',
    component: 'Input',
    componentProps: {
      placeholder: '请输入专业领域'
    }
  },
  {
    field: 'description',
    label: '医生简介',
    component: 'Input',
    componentProps: {
      type: 'textarea',
      rows: 4,
      placeholder: '请输入医生简介、擅长领域等信息'
    },
    colProps: { span: 24 }
  },
  {
    field: 'experience',
    label: '经验(年)',
    component: 'InputNumber',
    componentProps: {
      placeholder: '请输入经验年限',
      min: 0,
      max: 50,
      step: 1, // 整数步长
      precision: 0, // 不显示小数
      controlsPosition: 'right' // 控制按钮在右侧
    },
    value: 0, // 设置默认值，避免初始验证失败
    formItemProps: {
      rules: [required()]
    }
  },
  ...(isEdit.value
    ? [
        {
          field: 'rating',
          label: '评分',
          component: 'InputNumber' as const,
          componentProps: {
            placeholder: '请输入评分（0-5）',
            min: 0,
            max: 5,
            step: 1, // 整数步长
            precision: 0, // 不显示小数
            controlsPosition: 'right' // 控制按钮在右侧
          },
          formItemProps: {
            rules: [required()]
          },
          value: 5
        }
      ]
    : []),
  {
    field: 'isGoldDoctor',
    label: '金牌医师',
    component: 'Switch',
    componentProps: {
      activeText: '是',
      inactiveText: '否'
    }
  },
  {
    field: 'hospitalId',
    label: '所属医院',
    component: 'Select',
    componentProps: {
      placeholder: '请选择所属医院',
      options: hospitalList.value,
      props: {
        label: 'name',
        value: 'id'
      },
      onChange: (value: number) => {
        // 医院变化时，更新科室列表并清空已选科室
        selectedHospitalId.value = value
        setFieldValue('departmentId', undefined)
      }
    }
  },
  {
    field: 'departmentId',
    label: '所属科室',
    component: 'Select',
    componentProps: {
      placeholder: '请先选择医院',
      options: filteredDepartmentList.value,
      props: {
        label: 'name',
        value: 'id'
      },
      disabled: !selectedHospitalId.value
    }
  },
  {
    field: 'isActive',
    label: '状态',
    component: 'Switch',
    componentProps: {
      activeText: '在职',
      inactiveText: '离职'
    },
    value: true
  }
])

/**
 * 返回列表页
 */
const handleBack = () => {
  router.push('/hospitals/doctors/list')
}

/**
 * 保存医生
 */
const handleSave = async () => {
  const elForm = await getElFormExpose()
  const valid = await elForm?.validate().catch((err) => {
    console.log(err)
  })
  if (!valid) {
    ElMessage.error('请检查表单数据')
    return
  }

  const formData = await getFormData()

  // 新增模式下，验证收费项配置
  if (!doctorId.value) {
    if (!serviceItems.value || serviceItems.value.length === 0) {
      ElMessage.error('请至少添加一个收费项')
      return
    }

    // 验证每个收费项的必填字段
    const invalidItem = serviceItems.value.find(
      (item) => !item.name || !item.duration || !item.price
    )
    if (invalidItem) {
      ElMessage.error('收费项的名称、时长和价格都是必填项')
      return
    }
  }

  loading.value = true
  try {
    if (doctorId.value) {
      // 编辑模式
      const updateData: UpdateDoctorParams = {
        name: formData.name,
        phone: formData.phone,
        specialty: formData.specialty,
        avatar: formData.avatar,
        description: formData.description,
        experience: formData.experience,
        rating: formData.rating,
        isGoldDoctor: formData.isGoldDoctor,
        hospitalId: formData.hospitalId,
        departmentId: formData.departmentId,
        isActive: formData.isActive
      }

      // 如果修改了密码，添加到更新数据中
      if (formData.password) {
        updateData.password = formData.password
      }

      await updateDoctorApi(doctorId.value, updateData)
      ElMessage.success('更新成功')
    } else {
      // 新增模式（新医生不设置评分，使用后端默认值）
      const createData: CreateDoctorParams = {
        username: formData.username,
        password: formData.password,
        phone: formData.phone,
        name: formData.name,
        avatar: formData.avatar,
        specialty: formData.specialty,
        description: formData.description,
        experience: formData.experience,
        isGoldDoctor: formData.isGoldDoctor,
        hospitalId: formData.hospitalId,
        departmentId: formData.departmentId,
        isActive: formData.isActive
      }

      // 1. 创建医生
      const doctorRes = await createDoctorApi(createData)
      const newDoctorId = doctorRes.data.id

      // 2. 批量创建收费项
      await batchAddServiceItemsApi(newDoctorId, {
        serviceItems: serviceItems.value
      })

      ElMessage.success('创建成功')
    }

    // 返回列表页
    handleBack()
  } catch (error) {
    console.error('保存失败:', error)
    ElMessage.error('保存失败，请稍后重试')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <ContentWrap>
    <!-- 页面标题和操作栏 -->
    <ElRow :gutter="20" class="mb-20px">
      <ElCol :span="12">
        <div class="flex items-center">
          <ElButton :icon="ArrowLeft" @click="handleBack">返回</ElButton>
          <h2 class="ml-10px">{{ isEdit ? '编辑医生' : '新增医生' }}</h2>
        </div>
      </ElCol>
      <ElCol :span="12" class="text-right">
        <ElButton type="primary" :loading="loading" @click="handleSave">
          {{ isEdit ? '保存' : '创建' }}
        </ElButton>
      </ElCol>
    </ElRow>

    <!-- 基本信息卡片 -->
    <ElCard class="mb-20px" shadow="never">
      <template #header>
        <div class="font-semibold">基本信息</div>
      </template>

      <Form
        v-loading="loading"
        :rules="rules"
        :schema="formSchema"
        @register="formRegister"
        label-width="120px"
      />
    </ElCard>

    <!-- 收费项配置（仅新建时显示） -->
    <ElCard v-if="!isEdit" shadow="never">
      <template #header>
        <div class="font-semibold">收费项配置（必填）</div>
      </template>

      <ServiceItemsInput v-model="serviceItems" />
    </ElCard>
  </ContentWrap>
</template>

<style scoped lang="less">
.mb-20px {
  margin-bottom: 20px;
}

.ml-10px {
  margin-left: 10px;
}

.text-right {
  text-align: right;
}

.font-semibold {
  font-weight: 600;
}

.flex {
  display: flex;
}

.items-center {
  align-items: center;
}
</style>
