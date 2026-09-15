<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ContentWrap } from '@/components/ContentWrap'
import { BaseButton } from '@/components/Button'
import { ElMessage } from 'element-plus'
import ProductWrite from './components/ProductWrite.vue'
import { productApi, getCategoryListApi, getProductDetailApi, type Product } from '@/api-new/shop'

const router = useRouter()
const route = useRoute()

const writeRef = ref()
const saveLoading = ref(false)
const currentRow = ref<Product | null>(null)
const categoryOptions = ref<any[]>([])

// 判断是编辑模式还是新增模式
const isEditMode = computed(() => {
  return !!route.params.id
})

const productId = computed(() => {
  const id = route.params.id
  return id ? parseInt(id as string) : null
})

// 定义分类类型
interface Category {
  id: number
  name: string
  parentId?: number | null
  children?: Category[]
}

// 加载分类列表
const loadCategories = async () => {
  try {
    const res = await getCategoryListApi({ includeChildren: true })

    console.log('API 返回的完整响应:', res)
    console.log('res.data:', res.data)

    // 将树形结构展平为扁平数组
    const flattenCategories = (categories: any[]): any[] => {
      const result: any[] = []
      categories.forEach((cat) => {
        result.push(cat)
        if (cat.children && cat.children.length > 0) {
          result.push(...flattenCategories(cat.children))
        }
      })
      return result
    }

    const allCategories = Array.isArray(res.data) ? flattenCategories(res.data) : []

    console.log('所有分类数据（扁平化后）:', allCategories)

    // 过滤出所有二级分类（有 parentId 的分类）
    const secondLevelCategories = allCategories
      .filter((cat: Category) => cat.parentId !== undefined && cat.parentId !== null)
      .map((cat: Category) => ({
        label: `${getParentCategoryName(allCategories, cat.parentId!)} / ${cat.name}`,
        value: cat.id
      }))

    console.log('过滤后的二级分类:', secondLevelCategories)

    categoryOptions.value = secondLevelCategories
  } catch (error) {
    console.error('加载分类失败:', error)
    ElMessage.error('加载分类失败')
  }
}

// 获取父分类名称
const getParentCategoryName = (categories: Category[], parentId: number): string => {
  const parent = categories.find((cat: Category) => cat.id === parentId)
  return parent ? parent.name : ''
}

// 加载商品详情（仅编辑模式）
const loadProductDetail = async () => {
  if (!productId.value) return

  try {
    const res = await getProductDetailApi(productId.value)
    currentRow.value = res.data
  } catch (error) {
    console.error('加载商品详情失败:', error)
    ElMessage.error('加载商品详情失败')
  }
}

onMounted(async () => {
  await loadCategories()
  if (isEditMode.value) {
    await loadProductDetail()
  }
})

// 获取表单 schema
import { CrudSchema, useCrudSchemas } from '@/hooks/web/useCrudSchemas'

const crudSchemas = computed<CrudSchema[]>(() => {
  const schemas: CrudSchema[] = [
    {
      field: 'name',
      label: '商品名称',
      form: {
        component: 'Input',
        colProps: {
          span: 24
        }
      }
    },
    {
      field: 'categoryId',
      label: '商品分类',
      form: {
        component: 'Select',
        componentProps: {
          get options() {
            return categoryOptions.value
          },
          clearable: true,
          placeholder: '请选择商品分类'
        },
        colProps: {
          span: 24
        }
      }
    },
    {
      field: 'price',
      label: '价格',
      form: {
        component: 'InputNumber',
        componentProps: {
          min: 0,
          precision: 2,
          step: 0.1
        },
        colProps: {
          span: 8
        }
      }
    },
    {
      field: 'stock',
      label: '库存',
      form: {
        component: 'InputNumber',
        componentProps: {
          min: 0,
          step: 1
        },
        colProps: {
          span: 8
        }
      }
    },
    {
      field: 'isActive',
      label: '状态',
      value: true,
      form: {
        component: 'RadioGroup',
        componentProps: {
          options: [
            { label: '上架', value: true },
            { label: '下架', value: false }
          ]
        },
        colProps: {
          span: 8
        }
      }
    },
    {
      field: 'isVirtual',
      label: '虚拟商品',
      value: false,
      form: {
        component: 'RadioGroup',
        componentProps: {
          options: [
            { label: '是', value: true },
            { label: '否', value: false }
          ]
        },
        colProps: {
          span: 24
        }
      }
    },
    {
      field: 'description',
      label: '商品描述',
      form: {
        component: 'Editor',
        colProps: {
          span: 24
        }
      }
    }
  ]

  return schemas
})

const { allSchemas } = useCrudSchemas(crudSchemas.value as any)

// 监听 categoryOptions 变化，重新生成 schemas
watch(
  categoryOptions,
  () => {
    console.log('categoryOptions 已更新:', categoryOptions.value)
  },
  { deep: true }
)

// 返回列表
const handleBack = () => {
  router.push('/product/index')
}

/**
 * 提取图片相对路径
 * 将完整 URL 转换为相对路径，如 http://xxx.com/uploads/abc.jpg -> /uploads/abc.jpg
 * 如果已经是相对路径，则原样返回
 */
const extractImagePath = (url: string | undefined): string | undefined => {
  if (!url) return undefined

  // 如果已经是相对路径，直接返回
  if (url.startsWith('/uploads/')) {
    return url
  }

  // 尝试从完整 URL 中提取相对路径
  try {
    const urlObj = new URL(url)
    const pathname = urlObj.pathname
    // 如果路径以 /uploads/ 开头，返回该路径
    if (pathname.startsWith('/uploads/')) {
      return pathname
    }
  } catch (e) {
    // URL 解析失败，可能是相对路径，直接返回
  }

  return url
}

/**
 * 处理图片数组，将完整 URL 转换为相对路径
 */
const processImageArray = (images: string[]): string[] => {
  if (!images || !Array.isArray(images)) return []
  return images.map((img) => extractImagePath(img) || img).filter(Boolean)
}

// 保存商品
const handleSave = async () => {
  const write = writeRef.value
  const formData = await write?.submit()
  if (formData) {
    saveLoading.value = true
    try {
      // 处理商品图片数组，将完整 URL 转换为相对路径
      const processedImages = processImageArray(formData.images || [])

      // 清理 SKU 数据，移除自动生成的字段
      const cleanSkus = (formData.skus || []).map((sku: any) => ({
        id: sku.id || undefined,
        name: sku.name,
        specs: sku.specs,
        price: Number(sku.price) || 0,
        originalPrice: sku.originalPrice != null ? Number(sku.originalPrice) : undefined,
        stock: Number(sku.stock) || 0,
        status: sku.status,
        image: extractImagePath(sku.image), // 处理 SKU 图片
        skuCode: sku.skuCode
      }))

      if (isEditMode.value && productId.value) {
        // 编辑模式 - 更新商品
        const updateData: any = {
          name: formData.name,
          description: formData.description || undefined,
          price: formData.price != null ? Number(formData.price) : 0,
          stock: formData.stock != null ? Number(formData.stock) : 0,
          categoryId: formData.categoryId,
          isActive: formData.isActive,
          isVirtual: formData.isVirtual ?? false,
          hasSku: formData.hasSku || false,
          skus: cleanSkus
        }

        // 只在有图片时才添加 images 字段（使用处理后的相对路径）
        if (processedImages.length > 0) {
          updateData.images = processedImages
        }

        await productApi.updateProductApi(productId.value, updateData)
        ElMessage.success('更新成功')
      } else {
        // 新增模式 - 创建商品
        const createData: any = {
          name: formData.name,
          description: formData.description || undefined,
          price: formData.price != null ? Number(formData.price) : 0,
          stock: formData.stock != null ? Number(formData.stock) : 0,
          categoryId: formData.categoryId,
          isActive: formData.isActive,
          isVirtual: formData.isVirtual ?? false,
          hasSku: formData.hasSku || false,
          publishSource: 'ADMIN',
          skus: cleanSkus
        }

        // 只在有图片时才添加 images 字段（使用处理后的相对路径）
        if (processedImages.length > 0) {
          createData.images = processedImages
        }

        await productApi.createProductApi(createData)
        ElMessage.success('创建成功')
      }

      router.push('/product/index')
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
    <div class="page-header">
      <h2>{{ isEditMode ? '编辑商品' : '新增商品' }}</h2>
      <BaseButton @click="handleBack">返回列表</BaseButton>
    </div>

    <div v-if="!isEditMode || currentRow">
      <ProductWrite
        ref="writeRef"
        :form-schema="allSchemas.formSchema"
        :category-options="categoryOptions"
        :current-row="currentRow"
      />
    </div>
    <div v-else class="loading-placeholder">
      <p>加载中...</p>
    </div>

    <div class="form-footer">
      <BaseButton type="primary" :loading="saveLoading" @click="handleSave">
        {{ isEditMode ? '保存' : '创建' }}
      </BaseButton>
      <BaseButton @click="handleBack">取消</BaseButton>
    </div>
  </ContentWrap>
</template>

<style scoped lang="scss">
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding-bottom: 15px;
  border-bottom: 1px solid var(--el-border-color);

  h2 {
    margin: 0;
    font-size: 20px;
    font-weight: 600;
  }
}

.form-footer {
  margin-top: 30px;
  padding-top: 20px;
  border-top: 1px solid var(--el-border-color);
  display: flex;
  gap: 12px;
}

.loading-placeholder {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 300px;
  color: var(--el-text-color-secondary);
}
</style>
