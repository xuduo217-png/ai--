<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { Search } from '@/components/Search'
import { ElTag, ElMessage, ElMessageBox } from 'element-plus'
import { Table } from '@/components/Table'
import { hospitalApi, type Hospital } from '@/api-new/hospitals'
import { useTable } from '@/hooks/web/useTable'
import { reactive, ref, unref } from 'vue'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { BaseButton } from '@/components/Button'
import { Dialog } from '@/components/Dialog'
import Write from './components/HospitalWrite.vue'
import HospitalUsersDialog from './components/HospitalUsersDialog.vue'
import { useI18n } from '@/hooks/web/useI18n'
import { useRouter } from 'vue-router'
import { ElInput, ElCascader } from 'element-plus'
import { regionData, TextToCode } from 'rmc-element-china-area-data'
import { getImageUrl } from '@/utils/image'

defineOptions({
  name: 'HospitalManagement'
})

const { t } = useI18n()
const router = useRouter()

// 省市区级联选择器选项
const regionOptions = regionData

// 省市区级联选择器绑定的值（区域码数组）
const regionCode = ref<string[]>([])

// 搜索参数
const searchParams = ref<Record<string, any>>({})
const setSearchParams = (params: any) => {
  searchParams.value = params
  getList()
}

// 表格配置
const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const { currentPage, pageSize } = tableState
    const res = await hospitalApi.getHospitalListApi({
      page: unref(currentPage),
      pageSize: unref(pageSize),
      ...unref(searchParams)
    })
    // 根据后端 API 响应格式适配数据
    return {
      list: res.data || [],
      total: res.pagination?.total || 0
    }
  },
  fetchDelApi: async () => {
    // 删除操作在行内处理
    return true
  }
})

const { loading, dataList, total, currentPage, pageSize } = tableState
const { getList } = tableMethods

// CRUD Schema 配置
const crudSchemas = reactive<CrudSchema[]>([
  {
    field: 'selection',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: { type: 'selection' }
  },
  {
    field: 'index',
    label: '序号',
    type: 'index',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true }
  },
  {
    field: 'name',
    label: '医院名称',
    search: {
      component: 'Input'
    },
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入医院名称'
      },
      colProps: { span: 24 }
    },
    table: {
      show: true
    }
  },
  {
    field: 'region',
    label: '所在地区',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        style: { display: 'none' }
      },
      formItemProps: {
        slots: {
          label: () => (
            <>
              <span style="color: #f56c6c; margin-right: 4px;">*</span>
              所在地区
            </>
          ),
          default: () => {
            return (
              <ElCascader
                v-model={regionCode.value}
                options={regionOptions}
                props={{
                  expandTrigger: 'hover',
                  checkStrictly: false
                }}
                placeholder="请选择省/市/区"
                clearable
                style={{ width: '100%' }}
              />
            )
          }
        }
      },
      colProps: { span: 24 }
    },
    table: {
      show: true,
      width: 200,
      slots: {
        default: (data: any) => {
          const { province, city, county } = data.row
          // 拼接省市区信息
          const regionParts = [province, city, county].filter(Boolean)
          return regionParts.length > 0 ? regionParts.join(' / ') : '-'
        }
      }
    }
  },
  {
    field: 'address',
    label: '详细地址',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入详细地址（街道、门牌号等）',
        maxlength: 500
      },
      formItemProps: {
        required: true
      },
      colProps: { span: 24 }
    },
    table: {
      hidden: true
    }
  },
  {
    field: 'phone',
    label: '联系电话',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入联系电话'
      },
      colProps: { span: 12 }
    },
    table: {
      show: true
    }
  },
  {
    field: 'email',
    label: '邮箱',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入邮箱（可选）'
      },
      colProps: { span: 12 }
    },
    table: {
      hidden: true
    }
  },

  {
    field: 'latitude',
    label: '纬度',
    search: { hidden: true },
    form: {
      component: 'InputNumber',
      value: 39.928281, // 北京天安门默认纬度
      componentProps: {
        min: -90,
        max: 90,
        precision: 6,
        step: 0.000001,
        placeholder: '请输入纬度 (-90 到 90)',
        controlsPosition: 'right',
        style: { width: '100%' }
      },
      colProps: { span: 12 }
    },
    table: {
      slots: {
        default: (data: any) => {
          return data.row.latitude ? Number(data.row.latitude).toFixed(6) : '-'
        }
      }
    }
  },
  {
    field: 'longitude',
    label: '经度',
    search: { hidden: true },
    form: {
      component: 'InputNumber',
      value: 116.409749, // 北京天安门默认经度
      componentProps: {
        min: -180,
        max: 180,
        precision: 6,
        step: 0.000001,
        placeholder: '请输入经度 (-180 到 180)',
        controlsPosition: 'right',
        style: { width: '100%' }
      },
      colProps: { span: 12 }
    },
    table: {
      slots: {
        default: (data: any) => {
          return data.row.longitude ? Number(data.row.longitude).toFixed(6) : '-'
        }
      }
    }
  },
  {
    field: 'mapPicker',
    label: '经纬度快速填充',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        style: { display: 'none' }
      },
      formItemProps: {
        slots: {
          default: () => {
            return (
              <div style="display: flex; align-items: center; gap: 12px; width: '100%';">
                <ElInput
                  modelValue={coordinatesInput.value}
                  onUpdate:modelValue={(val: string) => (coordinatesInput.value = val)}
                  placeholder="请输入经纬度，如：116.062500,40.529355"
                  style={{ flex: 1, maxWidth: '400px' }}
                />
                <BaseButton type="primary" onClick={handleParseCoordinates}>
                  识别并填充
                </BaseButton>
                <BaseButton
                  onClick={() => window.open('https://lbs.baidu.com/maptool/getpoint', '_blank')}
                >
                  打开拾取工具
                </BaseButton>
              </div>
            )
          }
        }
      },
      colProps: { span: 24 }
    },
    table: {
      hidden: true
    }
  },
  {
    field: 'logo',
    label: 'Logo 图片',
    search: { hidden: true },
    form: {
      component: 'ImageUpload',
      componentProps: {
        placeholder: '点击上传医院 Logo',
        aspectRatio: 1,
        cropBoxWidth: 200,
        cropBoxHeight: 200,
        category: 'hospital-logo',
        circle: false,
        previewWidth: 100,
        previewHeight: 100
      },
      colProps: { span: 24 }
    },
    table: {
      show: true,
      width: 100,
      slots: {
        default: (data: any) => {
          return data.row.logo ? (
            <img
              src={getImageUrl(data.row.logo)}
              style={{ width: '50px', height: '50px', objectFit: 'cover', borderRadius: '4px' }}
              alt="Logo"
            />
          ) : (
            <span>-</span>
          )
        }
      }
    }
  },
  {
    field: 'description',
    label: '医院描述',
    search: { hidden: true },
    table: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        type: 'textarea',
        rows: 3,
        placeholder: '请输入医院描述信息（可选）'
      },
      colProps: { span: 24 }
    }
  },
  {
    field: 'isActive',
    label: '状态',
    search: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '全部', value: '' },
          { label: '启用', value: true },
          { label: '禁用', value: false }
        ]
      }
    },
    form: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '启用', value: true },
          { label: '禁用', value: false }
        ]
      },
      value: true,
      colProps: { span: 24 }
    },
    table: {
      slots: {
        default: (data: any) => {
          // 后端返回 status 字段（'active'/'inactive'），判断是否启用
          const isActive = data.row.status === 'active' || data.row.isActive === true
          return isActive ? <ElTag type="success">启用</ElTag> : <ElTag type="danger">禁用</ElTag>
        }
      }
    }
  },
  {
    field: 'action',
    width: '360px',
    label: '操作',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: {
      slots: {
        default: (data: any) => {
          return (
            <>
              <BaseButton type="primary" onClick={() => handleEdit(data.row)}>
                编辑
              </BaseButton>
              <BaseButton onClick={() => handleDepartmentManagement(data.row)}>科室管理</BaseButton>
              <BaseButton onClick={() => handleUserManagement(data.row)}>管理员工</BaseButton>
              <BaseButton type="danger" onClick={() => handleDelete(data.row)}>
                删除
              </BaseButton>
            </>
          )
        }
      }
    }
  }
])

const { allSchemas } = useCrudSchemas(crudSchemas)

// 对话框相关
const dialogVisible = ref(false)
const dialogTitle = ref('')
const currentRow = ref<Hospital | null>(null)
const writeRef = ref()
const saveLoading = ref(false)

// 医院用户管理对话框相关
const hospitalUsersDialogVisible = ref(false)
const currentHospitalForUsers = ref<{ id: number; name: string } | null>(null)

// 经纬度输入相关
const coordinatesInput = ref('')

/**
 * 解析并填充经纬度
 * 支持格式：116.062500,40.529355 或 116.062500, 40.529355
 */
const handleParseCoordinates = () => {
  const input = coordinatesInput.value.trim()

  if (!input) {
    ElMessage.warning('请输入经纬度')
    return
  }

  // 支持中文逗号和英文逗号，并去除空格
  const parts = input.replace(/，/g, ',').split(',')

  if (parts.length !== 2) {
    ElMessage.error('格式错误，请输入正确的经纬度格式，如：116.062500,40.529355')
    return
  }

  const longitude = parseFloat(parts[0].trim())
  const latitude = parseFloat(parts[1].trim())

  // 验证经纬度范围
  if (isNaN(longitude) || isNaN(latitude)) {
    ElMessage.error('经纬度必须为数字')
    return
  }

  if (longitude < -180 || longitude > 180) {
    ElMessage.error('经度必须在 -180 到 180 之间')
    return
  }

  if (latitude < -90 || latitude > 90) {
    ElMessage.error('纬度必须在 -90 到 90 之间')
    return
  }

  // 设置经纬度到表单
  const write = unref(writeRef)
  write?.setFieldValue('longitude', longitude)
  write?.setFieldValue('latitude', latitude)

  ElMessage.success(`已填充经度：${longitude.toFixed(6)}，纬度：${latitude.toFixed(6)}`)

  // 清空输入框
  coordinatesInput.value = ''
}

/**
 * 打开新增对话框
 */
const handleAdd = () => {
  dialogTitle.value = '新增医院'
  currentRow.value = null
  regionCode.value = []
  coordinatesInput.value = ''
  dialogVisible.value = true
}

/**
 * 打开编辑对话框
 */
const handleEdit = (row: Hospital) => {
  dialogTitle.value = '编辑医院'
  currentRow.value = row
  coordinatesInput.value = ''

  // 如果有省市区信息，尝试反向查找区域码并填充到级联选择器
  if (row.province && row.city && row.county) {
    try {
      const codeInfo = TextToCode[row.province]?.[row.city]?.[row.county]
      if (codeInfo && codeInfo.code) {
        regionCode.value = [
          TextToCode[row.province].code,
          TextToCode[row.province][row.city].code,
          codeInfo.code
        ]
      } else {
        regionCode.value = []
      }
    } catch (error) {
      console.warn('省市区名称转区域码失败，请重新选择', error)
      regionCode.value = []
    }
  } else {
    regionCode.value = []
  }

  dialogVisible.value = true
}

/**
 * 删除医院
 */
const handleDelete = async (row: Hospital) => {
  try {
    await ElMessageBox.confirm(`确定要删除医院"${row.name}"吗？`, '提示', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    })

    await hospitalApi.deleteHospitalApi(row.id)
    ElMessage.success('删除成功')
    getList()
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}

/**
 * 跳转到科室管理页面
 */
const handleDepartmentManagement = (row: Hospital) => {
  router.push({
    path: `/hospitals/${row.id}/departments`,
    query: {
      hospitalName: row.name
    }
  })
}

/**
 * 打开医院用户管理对话框
 */
const handleUserManagement = (row: Hospital) => {
  currentHospitalForUsers.value = {
    id: row.id,
    name: row.name
  }
  hospitalUsersDialogVisible.value = true
}

/**
 * 医院用户管理刷新回调
 */
const handleUserManagementRefresh = () => {
  // 刷新医院列表（如果需要显示管理员/员工数量）
  getList()
}

/**
 * 提交表单
 */
const save = async () => {
  const write = unref(writeRef)
  const formData = await write?.submit()
  if (formData) {
    saveLoading.value = true
    try {
      // 根据 currentRow 判断是新增还是编辑
      if (currentRow.value?.id) {
        // 编辑模式
        await hospitalApi.updateHospitalApi(currentRow.value.id, formData)
      } else {
        // 新增模式
        await hospitalApi.createHospitalApi(formData)
      }

      dialogVisible.value = false
      getList()
      ElMessage.success('保存成功')
    } catch (error) {
      console.error('保存失败:', error)
      ElMessage.error('保存失败')
    } finally {
      saveLoading.value = false
    }
  }
}
</script>

<template>
  <ContentWrap>
    <!-- 搜索区域 -->
    <Search :schema="allSchemas.searchSchema" @search="setSearchParams" @reset="setSearchParams" />

    <!-- 操作按钮 -->
    <div class="mb-10px">
      <BaseButton type="primary" @click="handleAdd">新增医院</BaseButton>
    </div>

    <!-- 表格 -->
    <Table
      v-model:pageSize="pageSize"
      v-model:currentPage="currentPage"
      :columns="allSchemas.tableColumns"
      :data="dataList"
      :loading="loading"
      :pagination="{
        total: total
      }"
      @register="tableRegister"
    />

    <!-- 新增/编辑对话框 -->
    <Dialog v-model="dialogVisible" :title="dialogTitle" width="800px" max-height="600px">
      <Write
        ref="writeRef"
        :form-schema="allSchemas.formSchema"
        :current-row="currentRow"
        :region-code="regionCode"
      />

      <template #footer>
        <BaseButton type="primary" :loading="saveLoading" @click="save">
          {{ t('exampleDemo.save') }}
        </BaseButton>
        <BaseButton @click="dialogVisible = false">{{ t('dialogDemo.close') }}</BaseButton>
      </template>
    </Dialog>

    <!-- 医院用户管理对话框 -->
    <HospitalUsersDialog
      v-if="currentHospitalForUsers"
      v-model="hospitalUsersDialogVisible"
      :hospital-id="currentHospitalForUsers.id"
      :hospital-name="currentHospitalForUsers.name"
      @refresh="handleUserManagementRefresh"
    />
  </ContentWrap>
</template>

<style scoped lang="less">
.mb-10px {
  margin-bottom: 10px;
}
</style>
