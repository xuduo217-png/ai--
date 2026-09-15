<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { Search } from '@/components/Search'
import { ElTag, ElMessage, ElMessageBox } from 'element-plus'
import { Table } from '@/components/Table'
import { petApi, type Pet, PetGenderLabel } from '@/api-new/pets'
import { getPetCategoryTreeApi, type PetCategoryTreeNode } from '@/api-new/pet-categories'
import { useTable } from '@/hooks/web/useTable'
import { reactive, ref, unref, computed, onMounted } from 'vue'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { BaseButton } from '@/components/Button'
import { Dialog } from '@/components/Dialog'
import Write from './components/PetWrite.vue'
// @ts-ignore
import PetDetail from './components/PetDetail.vue'
import { useI18n } from '@/hooks/web/useI18n'
import { getImageUrl } from '@/utils/image'
import { extractPagedTableData } from '@/utils/pagination'

defineOptions({
  name: 'PetList'
})

const { t } = useI18n()

// ========== 分类数据管理 ==========
const categoryTree = ref<PetCategoryTreeNode[]>([])
const firstLevelCategories = ref<Array<{ label: string; value: number }>>([])
const secondLevelCategories = ref<Record<number, Array<{ label: string; value: number }>>>({})

/**
 * 加载分类数据
 */
const loadCategories = async () => {
  try {
    const res = await getPetCategoryTreeApi()
    categoryTree.value = res.data || []

    // 构建一级分类选项
    firstLevelCategories.value = categoryTree.value
      .filter((cat) => !cat.parentId)
      .map((cat) => ({ label: cat.name, value: cat.id }))

    // 构建二级分类选项映射（parentId -> options）
    categoryTree.value.forEach((cat) => {
      if (cat.children?.length) {
        secondLevelCategories.value[cat.id] = cat.children.map((child) => ({
          label: child.name,
          value: child.id
        }))
      }
    })
  } catch (error) {
    console.error('加载分类数据失败:', error)
    ElMessage.error('加载分类数据失败')
  }
}

// 初始化时加载分类数据
onMounted(() => {
  loadCategories()
})

/**
 * 构建树状结构数据（用于 TreeSelect）
 */
const categoryTreeOptions = computed(() => {
  return buildTreeOptions(categoryTree.value)
})

/**
 * 递归构建树状选项
 */
const buildTreeOptions = (nodes: PetCategoryTreeNode[]): any[] => {
  return nodes
    .filter((node: PetCategoryTreeNode) => !node.parentId) // 只处理根节点
    .map((node: PetCategoryTreeNode) => ({
      value: node.id,
      label: node.name,
      children: node.children?.map((child: PetCategoryTreeNode) => ({
        value: child.id,
        label: child.name
      }))
    }))
}

/**
 * 获取分类显示名称（格式：类型-种类，如：猫-英短）
 */
const getCategoryDisplayName = (row: any): string => {
  const categoryName = row.category?.name || ''
  const subCategoryName = row.subCategory?.name || ''

  if (categoryName && subCategoryName) {
    return `${categoryName}-${subCategoryName}`
  } else if (categoryName) {
    return categoryName
  } else if (subCategoryName) {
    return subCategoryName
  }
  return '-'
}

// 搜索参数
const searchParams = ref<Record<string, any>>({})
const setSearchParams = (params: any) => {
  searchParams.value = params
  getList()
}

// 表单中当前选中的类型ID（用于二级分类联动）
const formCategoryId = ref<number | undefined>(undefined)

// 对话框相关（需要在 crudSchemas 之前声明，因为 crudSchemas 中会使用）
const dialogVisible = ref(false)
const dialogTitle = ref('')
const currentRow = ref<Pet | null>(null)
const writeRef = ref()
const saveLoading = ref(false)

// 详情对话框
const detailDialogVisible = ref(false)
const detailPetId = ref<number | null>(null)

// 表格配置
const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const { currentPage, pageSize } = tableState
    const res = await petApi.getPetListApi({
      page: unref(currentPage),
      pageSize: unref(pageSize),
      ...unref(searchParams)
    })

    return extractPagedTableData<Pet>(res)
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
    label: '宠物名称',
    search: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入宠物名称'
      }
    },
    form: {
      component: 'Input',
      componentProps: {
        placeholder: '请输入宠物名称'
      },
      colProps: { span: 12 }
    }
  },
  {
    field: 'ownerId',
    label: '拥有者',
    search: { hidden: true },
    form: {
      component: 'OwnerSelect',
      componentProps: computed(() => ({
        placeholder: '请输入手机号搜索拥有者',
        currentOwner: currentRow.value?.owner || undefined
      })),
      colProps: { span: 24 }
    },
    table: { hidden: true }
  },
  {
    field: 'avatar',
    label: '头像',
    search: { hidden: true },
    form: {
      component: 'ImageUpload',
      componentProps: {
        placeholder: '点击上传宠物头像',
        aspectRatio: 1,
        cropBoxWidth: 200,
        cropBoxHeight: 200,
        category: 'pet-avatar',
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
          return data.row.avatar ? (
            <img
              src={getImageUrl(data.row.avatar)}
              style={{ width: '40px', height: '40px', objectFit: 'cover', borderRadius: '50%' }}
              alt="头像"
            />
          ) : (
            <span>-</span>
          )
        }
      }
    }
  },
  {
    field: 'categoryId',
    label: '分类',
    search: {
      component: 'TreeSelect',
      componentProps: {
        data: categoryTreeOptions,
        placeholder: '请选择分类（可筛选大类或具体种类）',
        clearable: true,
        checkStrictly: true,
        renderAfterExpand: false
      }
    },
    form: {
      component: 'Select',
      componentProps: {
        options: firstLevelCategories,
        placeholder: '请选择类型',
        onChange: (value: number) => {
          // 当类型改变时，更新 formCategoryId 并清空种类
          formCategoryId.value = value
          // 清空种类值
          const write = unref(writeRef)
          if (write && write.setValues) {
            write.setValues({ subCategoryId: undefined })
          }
        }
      },
      colProps: { span: 12 }
    },
    table: {
      show: true,
      width: 150,
      slots: {
        default: (data: any) => {
          return <span>{getCategoryDisplayName(data.row)}</span>
        }
      }
    }
  },
  {
    field: 'subCategoryId',
    label: '种类',
    search: { hidden: true },
    form: {
      component: 'Select',
      componentProps: {
        options: computed(() => {
          // 表单中根据选中的类型显示对应的二级分类
          return formCategoryId.value ? secondLevelCategories.value[formCategoryId.value] || [] : []
        }),
        placeholder: '请先选择类型',
        disabled: computed(() => !formCategoryId.value)
      },
      colProps: { span: 12 }
    },
    table: { hidden: true }
  },
  {
    field: 'gender',
    label: '性别',
    search: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '全部', value: '' },
          { label: '弟弟', value: 1 },
          { label: '妹妹', value: 2 }
        ]
      }
    },
    form: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '弟弟', value: 1 },
          { label: '妹妹', value: 2 }
        ],
        placeholder: '请选择性别'
      },
      colProps: { span: 12 }
    },
    table: {
      show: true,
      width: 80,
      slots: {
        default: (data: any) => {
          return (
            <ElTag type={data.row.gender === 1 ? 'primary' : 'danger'}>
              {PetGenderLabel[data.row.gender] || '-'}
            </ElTag>
          )
        }
      }
    }
  },
  {
    field: 'birthDate',
    label: '出生日期',
    search: { hidden: true },
    form: {
      component: 'DatePicker',
      componentProps: {
        type: 'date',
        placeholder: '请选择出生日期',
        valueFormat: 'YYYY-MM-DD',
        style: { width: '100%' }
      },
      colProps: { span: 12 }
    },
    table: {
      show: true,
      width: 120
    }
  },
  {
    field: 'weight',
    label: '体重 (kg)',
    width: 150,
    search: { hidden: true },
    form: {
      component: 'InputNumber',
      componentProps: {
        min: 0,
        max: 999.99,
        precision: 2,
        step: 0.1,
        placeholder: '请输入体重',
        controlsPosition: 'right',
        style: { width: '100%' }
      },
      colProps: { span: 12 }
    },
    table: {
      show: true,
      width: 100,
      slots: {
        default: (data: any) => {
          return data.row.weight ? `${data.row.weight} kg` : '-'
        }
      }
    }
  },
  {
    field: 'vaccineCount',
    label: '已接种针数',
    search: { hidden: true },
    form: {
      component: 'InputNumber',
      componentProps: {
        min: 0,
        precision: 0,
        step: 1,
        placeholder: '请输入已接种针数',
        controlsPosition: 'right',
        style: { width: '100%' }
      },
      colProps: { span: 8 }
    },
    table: {
      show: true,
      width: 100,
      slots: {
        default: (data: any) => {
          return `${data.row.vaccineCount || 0} 针`
        }
      }
    }
  },
  {
    field: 'tags',
    label: '标签',
    search: { hidden: true },
    form: {
      component: 'Select',
      componentProps: {
        multiple: true,
        filterable: true,
        allowCreate: true,
        defaultFirstOption: true,
        placeholder: '请选择或输入标签',
        options: [
          { label: '疫苗齐全', value: '疫苗齐全' },
          { label: '慢性病', value: '慢性病' },
          { label: '老年犬', value: '老年犬' },
          { label: '术后恢复', value: '术后恢复' },
          { label: '需特殊护理', value: '需特殊护理' }
        ]
      },
      colProps: { span: 24 }
    },
    table: {
      show: true,
      width: 200,
      slots: {
        default: (data: any) => {
          if (!data.row.tags || data.row.tags.length === 0) {
            return <span>-</span>
          }
          return (
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '4px' }}>
              {data.row.tags.map((tag: string, index: number) => (
                <ElTag key={index} type="info" size="small">
                  {tag}
                </ElTag>
              ))}
            </div>
          )
        }
      }
    }
  },
  {
    field: 'isNeutered',
    label: '绝育状态',
    search: {
      component: 'Select',
      componentProps: {
        options: [
          { label: '全部', value: '' },
          { label: '已绝育', value: true },
          { label: '未绝育', value: false }
        ]
      }
    },
    form: {
      component: 'Switch',
      componentProps: {
        activeText: '已绝育',
        inactiveText: '未绝育'
      },
      colProps: { span: 12 }
    },
    table: {
      show: true,
      width: 100,
      slots: {
        default: (data: any) => {
          return data.row.isNeutered ? (
            <ElTag type="success">已绝育</ElTag>
          ) : (
            <ElTag type="info">未绝育</ElTag>
          )
        }
      }
    }
  },
  {
    field: 'owner',
    label: '拥有者',
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true,
      width: 180,
      slots: {
        default: (data: any) => {
          if (!data.row.owner) {
            return <span>-</span>
          }
          // 同时显示姓名和手机号
          const { username, phone } = data.row.owner
          return (
            <div>
              <div>{username}</div>
              <div style={{ fontSize: '12px', color: '#909399' }}>{phone}</div>
            </div>
          )
        }
      }
    }
  },
  {
    field: 'appointmentCount',
    label: '预约次数',
    width: 100,
    search: { hidden: true },
    form: { hidden: true },
    table: {
      show: true
    }
  },
  {
    field: 'action',
    width: '280px',
    label: '操作',
    search: { hidden: true },
    form: { hidden: true },
    detail: { hidden: true },
    table: {
      fixed: 'right',
      slots: {
        default: (data: any) => {
          return (
            <>
              <BaseButton type="info" onClick={() => handleDetail(data.row)}>
                详情
              </BaseButton>
              <BaseButton type="primary" onClick={() => handleEdit(data.row)}>
                编辑
              </BaseButton>
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

/**
 * 打开新增对话框
 */
const handleAdd = () => {
  dialogTitle.value = '新增宠物'
  currentRow.value = null
  formCategoryId.value = undefined // 重置类型选择
  dialogVisible.value = true
}

/**
 * 打开编辑对话框
 */
const handleEdit = (row: Pet) => {
  dialogTitle.value = '编辑宠物'
  currentRow.value = row
  formCategoryId.value = row.categoryId // 设置当前选中的类型
  dialogVisible.value = true
}

/**
 * 删除宠物
 */
const handleDelete = async (row: Pet) => {
  try {
    await ElMessageBox.confirm(`确定要删除宠物"${row.name}"吗？`, '提示', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    })

    await petApi.deletePetApi(row.id)
    ElMessage.success('删除成功')
    getList()
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}

/**
 * 查看详情
 */
const handleDetail = (row: Pet) => {
  detailPetId.value = row.id
  detailDialogVisible.value = true
}

/**
 * 提交表单
 */
const save = async () => {
  const write = unref(writeRef)
  let formData

  try {
    formData = await write?.submit()
  } catch (error: any) {
    ElMessage.error(error?.message || '请检查表单数据')
    return
  }

  if (formData) {
    saveLoading.value = true
    try {
      // 根据 currentRow 判断是新增还是编辑
      if (currentRow.value?.id) {
        // 编辑模式
        await petApi.updatePetApi(currentRow.value.id, formData)
      } else {
        // 新增模式
        await petApi.createPetApi(formData)
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
      <BaseButton type="primary" @click="handleAdd">新增宠物</BaseButton>
    </div>

    <!-- 表格 -->
    <Table
      v-model:pageSize="pageSize"
      v-model:currentPage="currentPage"
      :columns="allSchemas.tableColumns"
      :data="dataList"
      :loading="loading"
      :pagination="{
        total
      }"
      @register="tableRegister"
    />

    <!-- 新增/编辑对话框 -->
    <Dialog v-model="dialogVisible" :title="dialogTitle" width="800px" max-height="600px">
      <Write
        ref="writeRef"
        :form-schema="allSchemas.formSchema"
        :current-row="currentRow"
        :category-tree="categoryTree"
        :first-level-categories="firstLevelCategories"
        :second-level-categories="secondLevelCategories"
      />

      <template #footer>
        <BaseButton type="primary" :loading="saveLoading" @click="save">
          {{ t('exampleDemo.save') }}
        </BaseButton>
        <BaseButton @click="dialogVisible = false">{{ t('dialogDemo.close') }}</BaseButton>
      </template>
    </Dialog>

    <!-- 宠物详情对话框 -->
    <PetDetail v-model="detailDialogVisible" :pet-id="detailPetId" />
  </ContentWrap>
</template>

<style scoped lang="less">
.mb-10px {
  margin-bottom: 10px;
}
</style>
