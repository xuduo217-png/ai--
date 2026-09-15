<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { Dialog } from '@/components/Dialog'
import { Table } from '@/components/Table'
import { Plus } from '@element-plus/icons-vue'
import { ref, unref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { ElTag, ElMessage, ElMessageBox, ElAvatar } from 'element-plus'
import { getDoctorListApi, deleteDoctorApi, type Doctor } from '@/api-new/doctors'
import { useTable } from '@/hooks/web/useTable'
import { Search } from '@/components/Search'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { BaseButton } from '@/components/Button'
import ServiceItemsManagement from './components/ServiceItemsManagement.vue'
import { getHospitalListApi } from '@/api-new/hospitals'
import { getImageUrl } from '@/utils/image'

const router = useRouter()

const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    // 使用服务端分页
    const { pageSize, currentPage } = tableState
    const res = await getDoctorListApi({
      page: unref(currentPage),
      pageSize: unref(pageSize),
      ...unref(searchParams)
    })

    return {
      list: res.data || [],
      total: res.pagination?.total || 0
    }
  }
})
const { total, loading, dataList, pageSize, currentPage } = tableState
const { getList } = tableMethods

// 搜索参数
const searchParams = ref<Record<string, any>>({})
const setSearchParams = (params: any) => {
  currentPage.value = 1
  searchParams.value = params
  getList()
}

// 收费项管理弹窗
const serviceItemsDialogVisible = ref(false)
const currentDoctor = ref<Doctor | null>(null)

// 获取医院列表（用于下拉选项，最多获取 100 条）
const hospitalList = ref<any[]>([])
const loadHospitals = async () => {
  try {
    const res = await getHospitalListApi({ page: 1, pageSize: 100 })
    hospitalList.value = res.data || []
  } catch (error) {
    console.error('获取医院列表失败', error)
  }
}

// 初始化加载医院列表
loadHospitals()

// CRUD Schema 定义
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
    form: { hidden: true },
    search: { hidden: true },
    detail: { hidden: true },
    table: { type: 'index' }
  },
  {
    field: 'avatar',
    label: '头像',
    search: { hidden: true },
    form: {
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
    table: {
      show: true,
      width: 80,
      slots: {
        default: (data: any) => {
          return (
            <ElAvatar src={getImageUrl(data.row.avatar)} size={50}>
              {data.row.name?.charAt(0)}
            </ElAvatar>
          )
        }
      }
    }
  },
  {
    field: 'username',
    label: '用户名',
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入登录用户名'
      }
    },
    search: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入用户名'
      }
    },
    table: {
      show: true
    }
  },
  {
    field: 'password',
    label: '密码',
    form: {
      component: 'Input',
      componentProps: {
        type: 'password',
        showPassword: true,
        placeholder: '请输入密码（至少6位）'
      }
    },
    search: { hidden: true },
    table: { hidden: true }
  },
  {
    field: 'phone',
    label: '手机号',
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入手机号'
      }
    },
    search: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入手机号'
      }
    },
    table: {
      show: true,
      width: 130
    }
  },
  {
    field: 'name',
    label: '姓名',
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入医生姓名'
      }
    },
    search: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入姓名'
      }
    },
    table: {
      show: true,
      width: 100
    }
  },
  {
    field: 'specialty',
    label: '专长',
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入专业领域'
      }
    },
    search: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入专长'
      }
    },
    table: {
      show: true,
      width: 120
    }
  },
  {
    field: 'description',
    label: '医生简介',
    form: {
      component: 'Input',
      componentProps: {
        type: 'textarea',
        rows: 4,
        placeholder: '请输入医生简介、擅长领域等信息'
      }
    },
    search: { hidden: true },
    table: { hidden: true }
  },
  {
    field: 'experience',
    label: '经验(年)',
    form: {
      component: 'InputNumber',
      componentProps: {
        placeholder: '请输入经验年限',
        min: 0,
        max: 50
      }
    },
    search: { hidden: true },
    table: {
      show: true,
      width: 90
    }
  },
  {
    field: 'isGoldDoctor',
    label: '金牌医师',
    form: {
      component: 'Switch',
      componentProps: {
        activeText: '是',
        inactiveText: '否'
      }
    },
    search: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '全部', value: '' },
          { label: '是', value: true },
          { label: '否', value: false }
        ]
      }
    },
    table: {
      show: true,
      width: 100,
      slots: {
        default: (data: any) => {
          return data.row.isGoldDoctor ? (
            <ElTag type="warning">⭐ 金牌</ElTag>
          ) : (
            <ElTag type="info">普通</ElTag>
          )
        }
      }
    }
  },
  {
    field: 'rating',
    label: '评分',
    form: {
      component: 'InputNumber',
      componentProps: {
        placeholder: '请输入评分（0-5）',
        min: 0,
        max: 5,
        precision: 2,
        step: 0.1
      }
    },
    search: { hidden: true },
    table: {
      show: true,
      width: 90,
      slots: {
        default: (data: any) => {
          return <span>{data.row.rating ? `${data.row.rating}/5.0` : '-'}</span>
        }
      }
    }
  },
  {
    field: 'hospitalId',
    label: '所属医院',
    search: {
      component: 'Select',
      componentProps: {
        placeholder: '请选择医院',
        options: hospitalList,
        props: {
          label: 'name',
          value: 'id'
        }
      }
    },
    table: {
      show: true,
      width: 150,
      slots: {
        default: (data: any) => {
          return data.row.hospital?.name || '-'
        }
      }
    }
  },
  {
    field: 'departmentId',
    label: '所属科室',
    search: { hidden: true },
    table: {
      show: true,
      width: 120,
      slots: {
        default: (data: any) => {
          return data.row.department?.name || '-'
        }
      }
    }
  },
  {
    field: 'isActive',
    label: '状态',
    form: {
      component: 'Switch',
      componentProps: {
        activeText: '在职',
        inactiveText: '离职'
      }
    },
    search: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '全部', value: '' },
          { label: '在职', value: true },
          { label: '离职', value: false }
        ]
      }
    },
    table: {
      show: true,
      width: 80,
      slots: {
        default: (data: any) => {
          return data.row.isActive ? (
            <ElTag type="success">在职</ElTag>
          ) : (
            <ElTag type="danger">离职</ElTag>
          )
        }
      }
    }
  },
  {
    field: 'consultationCount',
    label: '咨询数',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 80
    }
  },
  {
    field: 'action',
    label: '操作',
    form: { hidden: true },
    detail: { hidden: true },
    search: { hidden: true },
    table: {
      width: 250,
      slots: {
        default: (data: any) => {
          const row = data.row as Doctor
          return (
            <>
              <BaseButton type="primary" onClick={() => handleEdit(row)}>
                编辑
              </BaseButton>
              <BaseButton onClick={() => handleServiceItems(row)}>收费项</BaseButton>
              <BaseButton type="danger" onClick={() => handleDelete(row)}>
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

/**
 * 新增医生
 */
const handleAdd = () => {
  router.push('/hospitals/doctors/create')
}

/**
 * 编辑医生
 */
const handleEdit = (row: Doctor) => {
  router.push(`/hospitals/doctors/edit/${row.id}`)
}

/**
 * 打开收费项管理弹窗
 */
const handleServiceItems = (row: Doctor) => {
  currentDoctor.value = row
  serviceItemsDialogVisible.value = true
}

/**
 * 删除医生
 */
const handleDelete = async (row: Doctor) => {
  try {
    await ElMessageBox.confirm(`确定要删除医生"${row.name}"吗？删除后无法恢复。`, '提示', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    })

    await deleteDoctorApi(row.id)
    ElMessage.success('删除成功')
    getList()
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}
</script>

<template>
  <ContentWrap>
    <!-- 搜索区域 -->
    <Search :schema="allSchemas.searchSchema" @reset="setSearchParams" @search="setSearchParams" />

    <!-- 操作按钮 -->
    <div class="mb-10px">
      <BaseButton type="primary" @click="handleAdd">
        <el-icon class="mr-5px"><Plus /></el-icon>
        新增医生
      </BaseButton>
    </div>

    <!-- 表格区域 -->
    <Table
      v-model:current-page="currentPage"
      v-model:page-size="pageSize"
      :columns="allSchemas.tableColumns"
      :data="dataList"
      :loading="loading"
      @register="tableRegister"
      :pagination="{
        total: total || 0
      }"
    />
  </ContentWrap>

  <!-- 收费项管理弹窗 -->
  <Dialog v-model="serviceItemsDialogVisible" title="收费项管理" width="900px">
    <ServiceItemsManagement
      v-if="currentDoctor"
      :doctor-id="currentDoctor.id"
      :doctor-name="currentDoctor.name"
      @close="serviceItemsDialogVisible = false"
      @refresh="getList"
    />
  </Dialog>
</template>
