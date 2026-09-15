<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { Dialog } from '@/components/Dialog'
import { useI18n } from '@/hooks/web/useI18n'
import { ElTag } from 'element-plus'
import { Table } from '@/components/Table'
import {
  getCategoryListApi,
  createCategoryApi,
  updateCategoryApi,
  deleteCategoryApi
} from '@/api-new/shop'
import type { ProductCategory } from '@/api-new/shop'
import { useTable } from '@/hooks/web/useTable'
import { ref, unref, reactive } from 'vue'
import Write from './components/CategoryWrite.vue'
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'
import { BaseButton } from '@/components/Button'
import { getImageUrl } from '@/utils/image'
import {
  MISSING_SECOND_LEVEL_CATEGORY_TEXT,
  shouldShowMissingSecondLevelCategoryWarning
} from './category.helpers'

const ids = ref<number[]>([])

const { tableRegister, tableState, tableMethods } = useTable({
  fetchDataApi: async () => {
    const { currentPage, pageSize } = tableState
    const res = await getCategoryListApi({ includeChildren: true })
    // 处理响应数据
    const data = res?.data || res
    // 仅对一级分类做分页切片，保留每个一级分类下的 children 供树表格展开。
    const flatList = flattenTree(Array.isArray(data) ? data : [])
    const startIndex = (unref(currentPage) - 1) * unref(pageSize)
    const endIndex = startIndex + unref(pageSize)
    return {
      list: flatList.slice(startIndex, endIndex),
      total: flatList.length
    }
  },
  fetchDelApi: async () => {
    const res = await Promise.all(unref(ids).map((id) => deleteCategoryApi(id)))
    return !!res
  }
})
const { loading, dataList, total, currentPage, pageSize } = tableState
const { getList, getElTableExpose, delList } = tableMethods

const { t } = useI18n()

const crudSchemas = reactive<CrudSchema[]>([
  {
    field: 'selection',
    search: {
      hidden: true
    },
    form: {
      hidden: true
    },
    detail: {
      hidden: true
    },
    table: {
      type: 'selection'
    }
  },
  {
    field: 'index',
    label: t('tableDemo.index'),
    type: 'index',
    search: {
      hidden: true
    },
    form: {
      hidden: true
    },
    detail: {
      hidden: true
    }
  },
  {
    field: 'id',
    label: 'ID',
    search: {
      hidden: true
    },
    form: {
      hidden: true
    },
    table: {
      width: 80
    }
  },
  {
    field: 'name',
    label: '分类名称',
    search: {
      hidden: true
    },
    form: {
      component: 'Input',
      formItemProps: {
        rules: [{ required: true, message: '请输入分类名称', trigger: 'blur' }]
      },
      colProps: {
        span: 24
      }
    },
    detail: {
      slots: {
        default: (data: any) => {
          return <>{data.row.name}</>
        }
      }
    },
    table: {
      minWidth: 420,
      slots: {
        default: (data: { row: ProductCategory }) => {
          const showWarning = shouldShowMissingSecondLevelCategoryWarning(data.row)

          return (
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
              <span>{data.row.name}</span>
              {showWarning ? (
                <span style={{ color: '#f56c6c', fontSize: '13px' }}>
                  {MISSING_SECOND_LEVEL_CATEGORY_TEXT}
                </span>
              ) : null}
            </div>
          )
        }
      }
    }
  },
  {
    field: 'image',
    label: '分类图片',
    search: {
      hidden: true
    },
    form: {
      component: 'ImageUpload',
      componentProps: {
        placeholder: '点击上传分类图片',
        aspectRatio: 1,
        cropBoxWidth: 200,
        cropBoxHeight: 200,
        category: 'category-image',
        circle: false,
        previewWidth: 100,
        previewHeight: 100
      },
      colProps: {
        span: 24
      }
    },
    table: {
      width: 100,
      slots: {
        default: (data: any) => {
          return data.row.image ? (
            <img
              src={getImageUrl(data.row.image)}
              style={{ width: '50px', height: '50px', objectFit: 'cover', borderRadius: '4px' }}
              alt="分类图片"
            />
          ) : (
            <span>-</span>
          )
        }
      }
    }
  },
  {
    field: 'status',
    label: '状态',
    search: {
      hidden: true
    },
    table: {
      width: 100,
      slots: {
        default: (data: any) => {
          const status = data.row.status
          return (
            <>
              <ElTag type={status === 'ACTIVE' ? 'success' : 'danger'}>
                {status === 'ACTIVE' ? '启用' : '禁用'}
              </ElTag>
            </>
          )
        }
      }
    },
    form: {
      component: 'RadioGroup',
      value: 'ACTIVE',
      colProps: {
        span: 12
      },
      componentProps: {
        options: [
          {
            value: 'ACTIVE',
            label: '启用'
          },
          {
            value: 'DISABLED',
            label: '禁用'
          }
        ]
      }
    },
    detail: {
      slots: {
        default: (data: any) => {
          return (
            <>
              <ElTag type={data.status === 'ACTIVE' ? 'success' : 'danger'}>
                {data.status === 'ACTIVE' ? '启用' : '禁用'}
              </ElTag>
            </>
          )
        }
      }
    }
  },
  {
    field: 'sortOrder',
    label: '排序',
    search: {
      hidden: true
    },
    form: {
      component: 'InputNumber',
      colProps: {
        span: 12
      },
      componentProps: {
        min: 0
      }
    },
    table: {
      width: 100
    }
  },
  {
    field: 'parentId',
    label: '父分类',
    search: {
      hidden: true
    },
    form: {
      component: 'Select',
      colProps: {
        span: 12
      },
      componentProps: {
        clearable: true,
        placeholder: '请选择父分类',
        options: []
      },
      optionApi: async () => {
        const res = await getCategoryListApi({ includeChildren: true })
        // 后端直接返回数组（经过拦截器处理后可能是 {data: [...]} 或直接数组）
        const data = Array.isArray(res) ? res : res?.data || []

        // 只返回一级分类（parentId 为 null 的分类）
        const categoryList = Array.isArray(data) ? data : []

        const filteredList = categoryList
          .filter((item: ProductCategory) => !item.parentId)
          // 转换为 Select 需要的格式 { label: string, value: any }
          .map((item: ProductCategory) => ({
            label: item.name,
            value: item.id
          }))

        console.log('✅ 处理后的一级分类（Select 格式）:', filteredList)

        return filteredList
      }
    },
    detail: {
      slots: {
        default: (data: any) => {
          return <>{data.row.parent?.name || '-'}</>
        }
      }
    },
    table: {
      width: 120,
      slots: {
        default: (data: any) => {
          return <>{data.row.parent?.name || '-'}</>
        }
      }
    }
  },
  {
    field: 'description',
    label: '描述',
    search: {
      hidden: true
    },
    form: {
      component: 'Input',
      componentProps: {
        type: 'textarea',
        rows: 3
      },
      colProps: {
        span: 24
      }
    },
    detail: {
      slots: {
        default: (data: any) => {
          return <>{data.row.description || '-'}</>
        }
      }
    },
    table: {
      hidden: true
    }
  },
  {
    field: 'action',
    width: '260px',
    label: t('tableDemo.action'),
    search: {
      hidden: true
    },
    form: {
      hidden: true
    },
    detail: {
      hidden: true
    },
    table: {
      slots: {
        default: (data: any) => {
          return (
            <>
              <BaseButton type="primary" onClick={() => action(data.row)}>
                {t('exampleDemo.edit')}
              </BaseButton>
              <BaseButton type="danger" onClick={() => delData(data.row)}>
                {t('exampleDemo.del')}
              </BaseButton>
            </>
          )
        }
      }
    }
  }
])

// @ts-ignore
const { allSchemas } = useCrudSchemas(crudSchemas)

const dialogVisible = ref(false)
const dialogTitle = ref('')

const currentRow = ref<ProductCategory | null>(null)

const AddAction = () => {
  dialogTitle.value = t('exampleDemo.add')
  currentRow.value = null
  dialogVisible.value = true
}

const delLoading = ref(false)

const delData = async (row: ProductCategory | null) => {
  const elTableExpose = await getElTableExpose()
  ids.value = row
    ? [row.id]
    : elTableExpose?.getSelectionRows().map((v: ProductCategory) => v.id) || []
  delLoading.value = true
  await delList(unref(ids).length).finally(() => {
    delLoading.value = false
  })
}

const action = (row: ProductCategory) => {
  dialogTitle.value = t('exampleDemo.edit')
  currentRow.value = row
  dialogVisible.value = true
}

const writeRef = ref()

const saveLoading = ref(false)

const save = async () => {
  const write = unref(writeRef)
  const formData = await write?.submit()
  if (formData) {
    saveLoading.value = true
    try {
      // 过滤掉不需要提交的字段
      const submitData: any = {
        name: formData.name,
        status: formData.status,
        sortOrder: formData.sortOrder,
        parentId: formData.parentId || null,
        description: formData.description || undefined
      }

      // 只在有图片时才添加 image 字段
      if (formData.image) {
        submitData.image = formData.image
      }

      if (formData.id) {
        await updateCategoryApi(formData.id, submitData)
      } else {
        await createCategoryApi(submitData)
      }
      dialogVisible.value = false
      currentPage.value = 1
      getList()
    } catch (error) {
      console.error('保存失败:', error)
    } finally {
      saveLoading.value = false
    }
  }
}

/**
 * 将树形结构扁平化（只保留一级分类，子分类通过 children 引用）
 * 避免子分类重复出现
 */
const flattenTree = (tree: ProductCategory[]): ProductCategory[] => {
  // 直接返回一级分类，子分类通过 children 属性引用
  // 这样表格可以展开查看子分类，而不会重复显示
  return tree
}
</script>

<template>
  <div>
    <ContentWrap>
      <div class="mb-10px flex">
        <BaseButton type="primary" @click="AddAction">{{ t('exampleDemo.add') }}</BaseButton>
        <BaseButton :loading="delLoading" type="danger" @click="delData(null)">
          {{ t('exampleDemo.del') }}
        </BaseButton>
      </div>

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
    </ContentWrap>

    <Dialog
      v-model="dialogVisible"
      :title="dialogTitle"
      width="800px"
      :key="dialogVisible ? 'open' : 'closed'"
    >
      <Write ref="writeRef" :form-schema="allSchemas.formSchema" :current-row="currentRow" />

      <template #footer>
        <BaseButton type="primary" :loading="saveLoading" @click="save">
          {{ t('exampleDemo.save') }}
        </BaseButton>
        <BaseButton @click="dialogVisible = false">{{ t('dialogDemo.close') }}</BaseButton>
      </template>
    </Dialog>
  </div>
</template>
