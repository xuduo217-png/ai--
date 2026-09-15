<script setup lang="tsx">
import { ref, unref, nextTick, computed } from 'vue'
import {
  ElTag,
  ElMessage,
  ElMessageBox,
  ElButton,
  ElImage,
  ElInput,
  ElCard,
  ElEmpty,
  ElPagination
} from 'element-plus'
import { Table } from '@/components/Table'
import { ContentWrap } from '@/components/ContentWrap'
import { Search } from '@/components/Search'
import { useTable } from '@/hooks/web/useTable'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { BaseButton } from '@/components/Button'
import { Dialog } from '@/components/Dialog'
import { Form } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import {
  getLostFoundListApi,
  createLostFoundApi,
  updateLostFoundApi,
  deleteLostFoundApi,
  toggleLostFoundPinApi,
  markLostFoundAsFoundApi,
  type LostFoundCreateParams
} from '@/api-new/lost-found'
import { getPetListApi } from '@/api-new/pets/pets'
import { formatToDateTime } from '@/utils/dateUtil'
import { getImageUrl } from '@/utils/image'

defineOptions({
  name: 'LostFound'
})

// 搜索参数
const searchParams = ref<Record<string, any>>({})

// 设置搜索参数
const setSearchParams = (params: any) => {
  searchParams.value = params
  currentPage.value = 1
  getList()
}

// 表格相关
const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const { pageSize, currentPage } = tableState
    const res = (await getLostFoundListApi({
      page: unref(currentPage),
      pageSize: unref(pageSize),
      ...unref(searchParams)
    })) as any

    // 根据后端 API 响应格式适配数据
    return {
      list: res.data || [],
      total: res.total || 0
    }
  }
})

const { total, loading, dataList, pageSize, currentPage } = tableState
const { getList } = tableMethods

// 对话框
const dialogVisible = ref(false)
const dialogTitle = ref('')
const currentRow = ref<any>(null)
const saveLoading = ref(false)

// 宠物选择弹窗
const petSelectDialogVisible = ref(false)
const selectedPet = ref<any>(null)
const petSearchKeyword = ref('')
const petList = ref<any[]>([])
const petLoading = ref(false)
const petPagination = ref({
  page: 1,
  pageSize: 30,
  total: 0
})

// 表单
const { formRegister, formMethods } = useForm()
const { setValues, getFormData, getElFormExpose } = formMethods

/**
 * 加载宠物列表
 */
const loadPetList = async () => {
  try {
    petLoading.value = true
    const res = (await getPetListApi({
      page: petPagination.value.page,
      pageSize: petPagination.value.pageSize,
      name: petSearchKeyword.value
    })) as any
    petList.value = res.data || []
    petPagination.value.total = res.total || 0
  } catch (error) {
    console.error('加载宠物列表失败:', error)
    ElMessage.error('加载宠物列表失败')
  } finally {
    petLoading.value = false
  }
}

/**
 * 宠物列表分页变化
 */
const handlePetPageChange = (page: number) => {
  petPagination.value.page = page
  loadPetList()
}

/**
 * 打开宠物选择弹窗
 */
const openPetSelectDialog = () => {
  petSearchKeyword.value = ''
  petPagination.value.page = 1
  loadPetList()
  petSelectDialogVisible.value = true
}

/**
 * 选择宠物
 */
const handleSelectPet = (pet: any) => {
  selectedPet.value = pet
  petSelectDialogVisible.value = false
}

/**
 * 清除选择的宠物
 */
const handleClearPet = () => {
  selectedPet.value = null
}

// 监听宠物选择弹窗打开
const handlePetSearch = () => {
  loadPetList()
}

// 当前选中的宠物显示文本
const selectedPetText = computed(() => {
  if (!selectedPet.value) return ''
  return `${selectedPet.value.name} (${selectedPet.value.category?.name || '-'}/${selectedPet.value.subCategory?.name || '-'})`
})

// CRUD Schema 定义
const crudSchemas: CrudSchema[] = [
  {
    field: 'index',
    label: '序号',
    form: { hidden: true },
    search: { hidden: true },
    table: { type: 'index', width: 60 }
  },
  {
    field: 'isFound',
    label: '找回状态',
    search: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '全部', value: '' },
          { label: '未找回', value: false },
          { label: '已找回', value: true }
        ]
      }
    },
    form: { hidden: true },
    table: {
      show: true,
      width: 100,
      slots: {
        default: (data: any) => {
          return (
            <ElTag type={data.row.isFound ? 'success' : 'warning'}>
              {data.row.isFound ? '已找回' : '未找回'}
            </ElTag>
          )
        }
      }
    }
  },
  {
    field: 'isPinned',
    label: '置顶状态',
    search: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '全部', value: '' },
          { label: '已置顶', value: true },
          { label: '未置顶', value: false }
        ]
      }
    },
    form: { hidden: true },
    table: {
      show: true,
      width: 100,
      slots: {
        default: (data: any) => {
          return (
            <ElTag type={data.row.isPinned ? 'danger' : 'info'}>
              {data.row.isPinned ? '已置顶' : '未置顶'}
            </ElTag>
          )
        }
      }
    }
  },
  {
    field: 'keyword',
    label: '关键词',
    search: {
      component: 'Input',
      componentProps: {
        placeholder: '搜索描述、联系人'
      }
    },
    form: { hidden: true },
    table: {
      hidden: true
    }
  },
  {
    field: 'pet',
    label: '宠物信息',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请选择宠物',
        readonly: true
      },
      colProps: {
        span: 24
      },
      formItemProps: {
        slots: {
          default: () => {
            return (
              <div style="display: flex; flex-direction: column; gap: 12px; width: 100%;">
                {/* 选择按钮区域 */}
                <div style="display: flex; gap: 8px; align-items: center;">
                  <ElInput
                    model-value={selectedPetText.value}
                    placeholder="请选择宠物"
                    readonly
                    style="flex: 1"
                  >
                    {{
                      append: () => <BaseButton onClick={openPetSelectDialog}>选择宠物</BaseButton>
                    }}
                  </ElInput>
                  {selectedPet.value && (
                    <BaseButton type="danger" onClick={handleClearPet}>
                      清除
                    </BaseButton>
                  )}
                </div>
                {/* 已选宠物预览 */}
                {selectedPet.value && (
                  <div style="padding: 12px; border: 1px solid #e4e7ed; border-radius: 4px; display: flex; gap: 12px; align-items: center;">
                    <ElImage
                      src={getImageUrl(selectedPet.value.avatar)}
                      style={{
                        width: '60px',
                        height: '60px',
                        borderRadius: '4px',
                        objectFit: 'cover'
                      }}
                      fit="cover"
                    />
                    <div style={{ flex: 1, lineHeight: 1.5 }}>
                      <div style={{ fontWeight: 'bold', fontSize: '14px' }}>
                        {selectedPet.value.name}
                      </div>
                      <div style={{ fontSize: '12px', color: '#909399' }}>
                        {selectedPet.value.category?.name || '-'} /{' '}
                        {selectedPet.value.subCategory?.name || '-'}
                      </div>
                      <div style={{ fontSize: '12px', color: '#909399' }}>
                        性别: {selectedPet.value.gender === 1 ? '弟弟' : '妹妹'}
                        {selectedPet.value.weight && (
                          <span style={{ marginLeft: '8px' }}>
                            体重: {selectedPet.value.weight}kg
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )
          }
        }
      }
    },
    table: {
      show: true,
      width: 150,
      slots: {
        default: (data: any) => {
          const pet = data.row.pet
          const petName = data.row.petName || pet?.name || '-'
          const category = data.row.petCategory || pet?.category?.name || '-'
          const breed = data.row.petBreed || pet?.subCategory?.name || '-'
          const avatar = pet?.avatar
          return (
            <div style="display: flex; align-items: center; gap: 8px;">
              {avatar ? (
                <ElImage
                  src={getImageUrl(avatar)}
                  style={{
                    width: '40px',
                    height: '40px',
                    borderRadius: '4px',
                    objectFit: 'cover'
                  }}
                  preview-src-list={[getImageUrl(avatar)]}
                  preview-teleported
                />
              ) : (
                <div style="width: 40px; height: 40px; border-radius: 4px; background: #f2f3f5; color: #909399; display: flex; align-items: center; justify-content: center; font-size: 12px;">
                  无图
                </div>
              )}
              <div>
                <div style={{ fontWeight: 'bold' }}>{petName}</div>
                <div style={{ fontSize: '12px', color: '#999' }}>
                  {category} / {breed}
                </div>
              </div>
            </div>
          )
        }
      }
    }
  },
  {
    field: 'description',
    label: '描述',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        type: 'textarea',
        rows: 4,
        placeholder: '请输入描述（10-500字）'
      },
      colProps: {
        span: 24
      },
      formItemProps: {
        rules: [
          { required: true, message: '请输入描述', trigger: 'blur' },
          { min: 10, message: '描述至少10个字符', trigger: 'blur' },
          { max: 500, message: '描述最多500个字符', trigger: 'blur' }
        ]
      }
    },
    table: {
      show: true
    }
  },
  {
    field: 'contactName',
    label: '联系人',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入联系人姓名（2-20字）'
      },
      colProps: {
        span: 12
      },
      formItemProps: {
        rules: [
          { required: true, message: '请输入联系人姓名', trigger: 'blur' },
          { min: 2, message: '联系人姓名至少2个字符', trigger: 'blur' },
          { max: 20, message: '联系人姓名最多20个字符', trigger: 'blur' }
        ]
      }
    },
    table: {
      show: true,
      width: 120
    }
  },
  {
    field: 'contactPhone',
    label: '联系电话',
    search: { hidden: true },
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入联系电话'
      },
      colProps: {
        span: 12
      },
      formItemProps: {
        rules: [
          { required: true, message: '请输入联系电话', trigger: 'blur' },
          {
            pattern: /^1[3-9]\d{9}$/,
            message: '请输入正确的手机号码',
            trigger: 'blur'
          }
        ]
      }
    },
    table: {
      show: true,
      width: 130
    }
  },
  {
    field: 'publisher',
    label: '发布者',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 150,
      slots: {
        default: (data: any) => {
          const publisher = data.row.publisher
          return (
            <div>
              <div>{publisher?.username || '-'}</div>
              <div style={{ fontSize: '12px', color: '#999' }}>
                {data.row.publisherType === 'USER' ? '用户' : '管理员'}
              </div>
            </div>
          )
        }
      }
    }
  },
  {
    field: 'foundAt',
    label: '找回时间',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 180,
      slots: {
        default: (data: any) => {
          return data.row.foundAt ? formatToDateTime(data.row.foundAt) : '-'
        }
      }
    }
  },
  {
    field: 'createdAt',
    label: '发布时间',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 180,
      slots: {
        default: (data: any) => {
          return formatToDateTime(data.row.createdAt)
        }
      }
    }
  },
  {
    field: 'action',
    label: '操作',
    form: { hidden: true },
    search: { hidden: true },
    table: {
      show: true,
      width: 350,
      slots: {
        default: (data: any) => {
          return (
            <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
              {!data.row.isFound && (
                <ElButton type="success" size="small" onClick={() => handleMarkAsFound(data.row)}>
                  标记找回
                </ElButton>
              )}
              <ElButton
                type={data.row.isPinned ? 'warning' : 'info'}
                size="small"
                onClick={() => handleTogglePin(data.row)}
              >
                {data.row.isPinned ? '取消置顶' : '置顶'}
              </ElButton>
              <ElButton type="primary" size="small" onClick={() => handleEdit(data.row)}>
                编辑
              </ElButton>
              <ElButton type="danger" size="small" onClick={() => handleDelete(data.row)}>
                删除
              </ElButton>
            </div>
          )
        }
      }
    }
  }
]

// 生成所有 schemas
const { allSchemas } = useCrudSchemas(crudSchemas)

/**
 * 新增走失信息
 */
const handleAdd = () => {
  dialogTitle.value = '发布走失信息'
  currentRow.value = null
  selectedPet.value = null
  dialogVisible.value = true

  nextTick(() => {
    setValues({
      pet: undefined,
      contactName: '',
      contactPhone: '',
      description: ''
    })
  })
}

/**
 * 编辑走失信息
 */
const handleEdit = (row: any) => {
  dialogTitle.value = '编辑走失信息'
  currentRow.value = row
  selectedPet.value = row.pet
  dialogVisible.value = true

  nextTick(() => {
    setValues({
      pet: row.petId,
      contactName: row.contactName,
      contactPhone: row.contactPhone,
      description: row.description
    })
  })
}

/**
 * 删除走失信息
 */
const handleDelete = async (row: any) => {
  try {
    await ElMessageBox.confirm('确定删除该走失信息吗？', '提示', {
      type: 'warning'
    })

    await deleteLostFoundApi(row.id)
    ElMessage.success('删除成功')
    getList()
  } catch (error) {
    // 取消删除
  }
}

/**
 * 提交表单
 */
const handleSubmit = async () => {
  try {
    saveLoading.value = true

    // 验证是否选择了宠物
    const editingManualPet = currentRow.value?.petId == null && !selectedPet.value
    if (!selectedPet.value && !editingManualPet) {
      ElMessage.error('请选择宠物')
      saveLoading.value = false
      return
    }

    const elForm = await getElFormExpose()
    try {
      const valid = await elForm?.validate()
      if (!valid) {
        ElMessage.error('请检查表单数据')
        saveLoading.value = false
        return
      }
    } catch (validateError) {
      console.error('表单验证失败:', validateError)
      ElMessage.error('请填写完整的表单信息')
      saveLoading.value = false
      return
    }

    // 获取表单数据
    const formData = (await getFormData()) as any

    // 构建提交数据，只包含需要的字段，不包含额外字段
    // 显式创建对象，避免混入额外字段
    const submitData: LostFoundCreateParams = {
      petId: selectedPet.value?.id ?? null,
      ...(editingManualPet
        ? {
            petName: currentRow.value.petName,
            petCategory: currentRow.value.petCategory,
            petBreed: currentRow.value.petBreed
          }
        : {}),
      contactName: String(formData.contactName || ''),
      contactPhone: String(formData.contactPhone || ''),
      description: String(formData.description || '')
    }

    // 清理对象，移除所有值为 undefined 的属性（双重保险）
    const cleanSubmitData = Object.fromEntries(
      Object.entries(submitData).filter(([_, value]) => value !== undefined)
    ) as LostFoundCreateParams

    console.log('提交数据:', cleanSubmitData)
    console.log('提交数据 JSON:', JSON.stringify(cleanSubmitData))

    if (currentRow.value?.id) {
      await updateLostFoundApi(currentRow.value.id, cleanSubmitData)
      ElMessage.success('更新成功')
    } else {
      await createLostFoundApi(cleanSubmitData)
      ElMessage.success('发布成功')
    }

    dialogVisible.value = false
    getList()
  } catch (error: any) {
    console.error('提交失败:', error)
    const errorMsg = error?.response?.data?.message || error?.message || '操作失败，请稍后重试'
    ElMessage.error(errorMsg)
  } finally {
    saveLoading.value = false
  }
}

/**
 * 切换置顶状态
 */
const handleTogglePin = async (row: any) => {
  try {
    await toggleLostFoundPinApi(row.id)
    ElMessage.success(row.isPinned ? '取消置顶成功' : '置顶成功')
    getList()
  } catch (error: any) {
    const errorMsg = error?.response?.data?.message || '操作失败，请稍后重试'
    ElMessage.error(errorMsg)
  }
}

/**
 * 标记为已找回
 */
const handleMarkAsFound = async (row: any) => {
  try {
    await ElMessageBox.confirm(
      `确定标记 "${row.petName || row.pet?.name || '该宠物'}" 为已找回吗？`,
      '提示',
      {
        type: 'success'
      }
    )

    await markLostFoundAsFoundApi(row.id)
    ElMessage.success('标记成功')
    getList()
  } catch (error: any) {
    // 取消操作
    if (error !== 'cancel') {
      const errorMsg = error?.response?.data?.message || '操作失败，请稍后重试'
      ElMessage.error(errorMsg)
    }
  }
}
</script>

<template>
  <ContentWrap>
    <!-- 搜索区域 -->
    <Search
      :schema="allSchemas.searchSchema"
      @search="setSearchParams"
      @reset="setSearchParams({})"
    />

    <!-- 操作按钮 -->
    <div class="mb-10px">
      <BaseButton type="primary" @click="handleAdd"> 发布走失信息 </BaseButton>
    </div>

    <!-- 表格 -->
    <Table
      v-model:pageSize="pageSize"
      v-model:currentPage="currentPage"
      :columns="allSchemas.tableColumns"
      :data="dataList"
      :loading="loading"
      :pagination="{ total }"
      @register="tableRegister"
    />
  </ContentWrap>

  <!-- 创建/编辑对话框 -->
  <Dialog v-model="dialogVisible" :title="dialogTitle" width="800px">
    <Form :schema="allSchemas.formSchema" @register="formRegister" label-width="120px" />

    <template #footer>
      <BaseButton type="primary" :loading="saveLoading" @click="handleSubmit"> 保存 </BaseButton>
      <BaseButton @click="dialogVisible = false">取消</BaseButton>
    </template>
  </Dialog>

  <!-- 宠物选择弹窗 -->
  <Dialog v-model="petSelectDialogVisible" title="选择宠物" width="1400px">
    <!-- 搜索栏 -->
    <div style="margin-bottom: 16px; display: flex; gap: 8px">
      <ElInput
        v-model="petSearchKeyword"
        placeholder="输入宠物名称搜索"
        clearable
        style="flex: 1"
        @keyup.enter="handlePetSearch"
      >
        <template #append>
          <BaseButton @click="handlePetSearch">搜索</BaseButton>
        </template>
      </ElInput>
    </div>

    <!-- 宠物列表 -->
    <div v-loading="petLoading">
      <div style="display: flex; flex-wrap: wrap; gap: 12px">
        <div v-for="pet in petList" :key="pet.id" style="width: calc(20% - 10px)">
          <ElCard
            :body-style="{ padding: '10px' }"
            shadow="hover"
            style="cursor: pointer; height: 100%"
            :class="{ 'is-selected': selectedPet?.id === pet.id }"
            @click="handleSelectPet(pet)"
          >
            <div style="display: flex; flex-direction: column; gap: 8px">
              <ElImage
                :src="getImageUrl(pet.avatar)"
                style="width: 100%; height: 140px; border-radius: 4px; object-fit: cover"
                fit="cover"
              />
              <div>
                <div
                  style="
                    font-weight: bold;
                    font-size: 14px;
                    margin-bottom: 4px;
                    white-space: nowrap;
                    overflow: hidden;
                    text-overflow: ellipsis;
                  "
                >
                  {{ pet.name }}
                </div>
                <div style="font-size: 12px; color: #909399; margin-bottom: 2px">
                  {{ pet.category?.name || '-' }} / {{ pet.subCategory?.name || '-' }}
                </div>
                <div style="font-size: 12px; color: #909399">
                  性别: {{ pet.gender === 1 ? '弟弟' : '妹妹' }}
                  <span v-if="pet.weight" style="margin-left: 8px"> 体重: {{ pet.weight }}kg </span>
                </div>
              </div>
            </div>
          </ElCard>
        </div>
      </div>

      <!-- 空状态 -->
      <ElEmpty v-if="!petLoading && petList.length === 0" description="暂无宠物数据" />

      <!-- 分页 -->
      <div
        v-if="petPagination.total > 0"
        style="margin-top: 16px; display: flex; justify-content: center"
      >
        <el-pagination
          :current-page="petPagination.page"
          :page-size="petPagination.pageSize"
          :total="petPagination.total"
          layout="total, prev, pager, next"
          @current-change="handlePetPageChange"
        />
      </div>
    </div>

    <template #footer>
      <BaseButton @click="petSelectDialogVisible = false">取消</BaseButton>
    </template>
  </Dialog>
</template>

<style scoped lang="scss">
.mb-10px {
  margin-bottom: 10px;
}

.is-selected {
  border: 2px solid var(--el-color-primary);
}
</style>
