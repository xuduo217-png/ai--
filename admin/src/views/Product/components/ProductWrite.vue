<script setup lang="ts">
import { ref, watch, reactive } from 'vue'
import {
  ElTag,
  ElButton,
  ElInput,
  ElInputNumber,
  ElTable,
  ElTableColumn,
  ElSelect,
  ElOption,
  ElMessage,
  ElTabPane,
  ElTabs,
  ElSwitch,
  ElEmpty
} from 'element-plus'
import { Form, FormSchema } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import { PropType } from 'vue'
import { useValidator } from '@/hooks/web/useValidator'
import { Product, ProductSku } from '@/api-new/shop'
import { ImageUpload } from '@/components/ImageUpload'
import { getImageUrl } from '@/utils/image'

const { required } = useValidator()

const props = defineProps({
  currentRow: {
    type: Object as PropType<Product | null>,
    default: () => null
  },
  formSchema: {
    type: Array as PropType<FormSchema[]>,
    default: () => []
  }
})

// SKU 相关数据
const skuList = ref<ProductSku[]>([])
const singleSkuSnapshot = ref<ProductSku | null>(null)
const activeTab = ref('basic')
const hasSkuEnabled = ref(false)

// 规格定义 - 使用独立的新增态与编辑态输入，避免两个输入框共享同一份状态导致串值
const specDefinitions = ref<Array<{ key: string; values: string[] }>>([])
const editingSpecKey = ref<number | null>(null)
const editingSpecDraft = ref('')
const newSpecKeyDraft = ref('')
// 为每个规格维护一个临时的规格值输入
const newSpecValues = ref<Record<number, string>>({})

// 商品图片列表
const productImages = ref<string[]>([])

// 新上传的图片 URL（用于 ImageUpload 组件）
const newImageUrl = ref('')

// 监听currentRow变化，同步categoryIdValue

const emit = defineEmits(['submit'])

// 基本信息表单
const rules = reactive({
  name: [required()],
  categoryId: [required()],
  price: [required()],
  stock: [required()],
  isActive: [required()]
})

const { formRegister, formMethods } = useForm()
const { setValues, getFormData, getElFormExpose } = formMethods

/**
 * 处理图片数组，将相对路径转换为完整 URL
 */
const processImageUrls = (images: string[]): string[] => {
  if (!images || !Array.isArray(images)) return []
  return images.map((img) => getImageUrl(img) || img).filter(Boolean)
}

// 监听 currentRow 变化
watch(
  () => props.currentRow,
  (currentRow) => {
    if (!currentRow) {
      // 新增模式，重置数据
      setValues({
        name: '',
        categoryId: undefined,
        price: undefined,
        stock: undefined,
        isActive: true,
        isVirtual: false,
        description: ''
      })
      skuList.value = []
      singleSkuSnapshot.value = null
      specDefinitions.value = []
      hasSkuEnabled.value = false
      activeTab.value = 'basic'
      productImages.value = []
      editingSpecKey.value = null
      editingSpecDraft.value = ''
      newSpecKeyDraft.value = ''
      newSpecValues.value = {}
      return
    }

    // 编辑模式，填充基本信息
    setValues({
      ...currentRow,
      isActive: currentRow.isActive ?? true,
      isVirtual: currentRow.isVirtual ?? false
    })
    // 同步图片列表（将相对路径转换为完整 URL）
    productImages.value = processImageUrls(currentRow.images || [])
    singleSkuSnapshot.value = null

    // 多规格商品才进入 SKU 管理；单规格商品只保留兼容 SKU 快照用于提交更新
    if (currentRow.hasSku && currentRow.skus && currentRow.skus.length > 0) {
      const skus = currentRow.skus
      // 将 SKU 图片的相对路径也转换为完整 URL
      skuList.value = skus.map((sku) => ({
        ...sku,
        image: getImageUrl(sku.image) || sku.image
      }))
      hasSkuEnabled.value = true

      // 从 SKU 中反推出规格定义
      if (skus.length > 0) {
        // 获取所有规格键（从第一个 SKU 的 specs 中获取）
        const specKeys = Object.keys(skus[0].specs)

        // 为每个规格键收集所有可能的值
        const newSpecDefinitions: Array<{ key: string; values: string[] }> = []

        specKeys.forEach((key) => {
          const values = new Set<string>()
          skus.forEach((sku: any) => {
            const value = sku.specs[key]
            if (value) {
              values.add(value)
            }
          })
          newSpecDefinitions.push({
            key,
            values: Array.from(values)
          })
        })

        specDefinitions.value = newSpecDefinitions
      }
    } else {
      const defaultSku = currentRow.skus?.[0]

      skuList.value = []
      specDefinitions.value = []
      hasSkuEnabled.value = false
      singleSkuSnapshot.value = defaultSku
        ? {
            ...defaultSku,
            image: getImageUrl(defaultSku.image) || defaultSku.image
          }
        : null
      editingSpecKey.value = null
      editingSpecDraft.value = ''
      newSpecKeyDraft.value = ''
      newSpecValues.value = {}
    }
  },
  {
    deep: true,
    immediate: true
  }
)

// 监听 SKU 启用状态
watch(hasSkuEnabled, (val) => {
  if (!val) {
    skuList.value = []
    specDefinitions.value = []
    editingSpecKey.value = null
    editingSpecDraft.value = ''
    newSpecKeyDraft.value = ''
    newSpecValues.value = {}
  }
})

/**
 * 重置规格名称编辑态
 * 规格编辑结束后统一清理临时状态，避免旧输入残留到下一次编辑。
 */
const resetSpecEditState = () => {
  editingSpecKey.value = null
  editingSpecDraft.value = ''
}

/**
 * 将规格名称变更同步到已生成的 SKU 上
 * 如果只修改规格定义而不回写 SKU，最终提交时仍会带着旧的 specs 键，导致“保存看起来成功但实际无效”。
 */
const syncSkuSpecKey = (oldKey: string, newKey: string) => {
  if (!oldKey || oldKey === newKey) {
    return
  }

  skuList.value = skuList.value.map((sku) => {
    if (!sku.specs || !(oldKey in sku.specs)) {
      return sku
    }

    const nextSpecs = Object.entries(sku.specs).reduce<Record<string, string>>((result, entry) => {
      const [key, value] = entry
      result[key === oldKey ? newKey : key] = value
      return result
    }, {})

    return {
      ...sku,
      specs: nextSpecs
    }
  })
}

// 获取规格值组合
const getSpecCombinations = () => {
  if (specDefinitions.value.length === 0) return []

  const combinations: Record<string, string>[] = [{}]

  specDefinitions.value.forEach((spec) => {
    if (!spec.key || spec.values.length === 0) return

    const newCombinations: Record<string, string>[] = []

    combinations.forEach((combo) => {
      spec.values.forEach((value) => {
        newCombinations.push({
          ...combo,
          [spec.key]: value
        })
      })
    })

    combinations.length = 0
    combinations.push(...newCombinations)
  })

  return combinations
}

// 根据规格定义生成 SKU
const generateSkus = () => {
  const combinations = getSpecCombinations()

  if (combinations.length === 0) {
    ElMessage.warning('请先添加规格定义')
    return
  }

  // 保留现有 SKU 的价格和库存信息
  const existingSkuMap = new Map<string, ProductSku>()
  skuList.value.forEach((sku) => {
    const key = JSON.stringify(sku.specs)
    existingSkuMap.set(key, sku)
  })

  // 生成新的 SKU 列表
  const newSkus: ProductSku[] = combinations.map((combo) => {
    const key = JSON.stringify(combo)
    const existingSku = existingSkuMap.get(key)

    return {
      id: existingSku?.id || 0,
      name: Object.values(combo).join(' / '),
      specs: combo,
      price: existingSku?.price || 0,
      originalPrice: existingSku?.originalPrice,
      stock: existingSku?.stock || 0,
      status: existingSku?.status || 'ACTIVE',
      image: existingSku?.image || '',
      skuCode: existingSku?.skuCode || '',
      productId: props.currentRow?.id || 0,
      createdAt: existingSku?.createdAt || new Date(),
      updatedAt: existingSku?.updatedAt || new Date()
    } as ProductSku
  })

  skuList.value = newSkus
  ElMessage.success(`已生成 ${newSkus.length} 个 SKU`)
}

// 添加规格定义
const addSpecDefinition = () => {
  const nextSpecKey = newSpecKeyDraft.value.trim()

  if (!nextSpecKey) {
    ElMessage.warning('请输入规格名称')
    return
  }

  // 检查是否已存在
  const exists = specDefinitions.value.some((s) => s.key === nextSpecKey)
  if (exists) {
    ElMessage.warning('该规格已存在')
    return
  }

  specDefinitions.value.push({
    key: nextSpecKey,
    values: []
  })

  newSpecKeyDraft.value = ''
}

// 编辑规格名称
const editSpecKey = (index: number) => {
  editingSpecKey.value = index
  editingSpecDraft.value = specDefinitions.value[index].key
}

// 保存规格名称
const saveSpecKey = (index: number) => {
  const targetSpec = specDefinitions.value[index]
  const nextSpecKey = editingSpecDraft.value.trim()

  if (!targetSpec) {
    resetSpecEditState()
    return
  }

  if (!nextSpecKey) {
    ElMessage.warning('规格名称不能为空')
    return
  }

  const duplicateSpec = specDefinitions.value.some(
    (spec, specIndex) => specIndex !== index && spec.key === nextSpecKey
  )
  if (duplicateSpec) {
    ElMessage.warning('该规格已存在')
    return
  }

  const oldSpecKey = targetSpec.key
  targetSpec.key = nextSpecKey
  syncSkuSpecKey(oldSpecKey, nextSpecKey)
  resetSpecEditState()
}

// 取消编辑规格名称
const cancelEditSpecKey = () => {
  resetSpecEditState()
}

// 删除规格定义
const removeSpecDefinition = (index: number) => {
  specDefinitions.value.splice(index, 1)
}

// 添加规格值
const addSpecValue = (specIndex: number) => {
  const inputValue = newSpecValues.value[specIndex]?.trim()
  if (!inputValue) {
    ElMessage.warning('请输入规格值')
    return
  }

  const spec = specDefinitions.value[specIndex]
  if (spec.values.includes(inputValue)) {
    ElMessage.warning('该规格值已存在')
    return
  }

  spec.values.push(inputValue)
  // 清空输入
  newSpecValues.value[specIndex] = ''
}

// 移除规格值
const removeSpecValue = (specIndex: number, valueIndex: number) => {
  specDefinitions.value[specIndex].values.splice(valueIndex, 1)
}

// SKU 表格内直接编辑
const updateSkuField = (index: number, field: keyof ProductSku, value: any) => {
  ;(skuList.value[index] as any)[field] = value
}

// 删除 SKU
const removeSku = (index: number) => {
  skuList.value.splice(index, 1)
  ElMessage.success('删除成功')
}

const removeImage = (index: number) => {
  productImages.value.splice(index, 1)
  ElMessage.success('已删除')
}

// 处理 ImageUpload 组件上传成功
const handleImageUploaded = (response: any) => {
  if (response.url) {
    productImages.value.push(response.url)
    ElMessage.success('图片添加成功')
    // 重置以便上传下一张
    newImageUrl.value = ''
  }
}

// 提交表单
const submit = async () => {
  const elForm = await getElFormExpose()
  const valid = await elForm?.validate().catch((err: any) => {
    console.log(err)
  })
  if (valid) {
    const formData = await getFormData()

    // 验证分类是否已选择
    if (!formData.categoryId) {
      ElMessage.error('请选择商品分类')
      return
    }

    // 验证 SKU 价格
    if (hasSkuEnabled.value && skuList.value.length > 0) {
      const zeroPriceSku = skuList.value.find((sku) => !sku.price || sku.price <= 0)
      if (zeroPriceSku) {
        ElMessage.error(`SKU "${zeroPriceSku.name}" 的价格不能为 0，请设置价格（最小 0.01 元）`)
        return
      }
    }

    // 准备 SKU 数据
    let finalSkus: ProductSku[] | undefined
    const finalHasSku = hasSkuEnabled.value && skuList.value.length > 0

    if (finalHasSku) {
      // 多规格商品，使用用户配置的 SKU 列表
      finalSkus = skuList.value
    } else {
      // 单规格商品，自动创建默认 SKU
      finalSkus = [
        {
          id: singleSkuSnapshot.value?.id || 0,
          name: singleSkuSnapshot.value?.name || '默认规格',
          specs: singleSkuSnapshot.value?.specs || {},
          price: Number(formData.price) || 0,
          originalPrice: singleSkuSnapshot.value?.originalPrice,
          stock: Number(formData.stock) || 0,
          status: singleSkuSnapshot.value?.status || 'ACTIVE',
          image: singleSkuSnapshot.value?.image || '',
          skuCode: singleSkuSnapshot.value?.skuCode || '',
          productId: props.currentRow?.id || 0
        } as ProductSku
      ]
    }

    // 组合数据
    const submitData: any = {
      ...formData,
      images: productImages.value.length > 0 ? productImages.value : undefined,
      hasSku: finalHasSku,
      skus: finalSkus
    }

    return submitData
  }
}

defineExpose({
  submit
})
</script>

<template>
  <div class="product-form">
    <ElTabs v-model="activeTab">
      <!-- 基本信息标签页 -->
      <ElTabPane label="基本信息" name="basic">
        <!-- 表单字段 -->
        <Form :rules="rules" @register="formRegister" :schema="formSchema" />
      </ElTabPane>

      <!-- 规格管理标签页 -->
      <ElTabPane label="规格管理" name="sku">
        <!-- SKU 多规格开关 -->
        <div class="sku-toggle-top">
          <el-form-item label="启用多规格">
            <ElSwitch v-model="hasSkuEnabled" />
            <span class="ml-2 text-gray-500 text-sm"
              >开启后可设置商品的不同规格（如颜色、尺寸等）</span
            >
          </el-form-item>
        </div>

        <div v-if="!hasSkuEnabled" class="empty-sku">
          <ElEmpty description="暂未启用多规格，请开启上方开关" />
        </div>

        <div v-else class="sku-manager">
          <!-- 规格定义区域 -->
          <div class="spec-definitions">
            <h4>规格定义</h4>
            <p class="text-gray-500 text-sm mb-4"
              >定义商品的规格类型（如：颜色、尺寸），系统将自动生成 SKU</p
            >

            <!-- 规格列表 -->
            <div v-for="(spec, specIndex) in specDefinitions" :key="specIndex" class="spec-item">
              <div class="spec-header">
                <div v-if="editingSpecKey === specIndex" class="spec-key-edit">
                  <ElInput
                    v-model="editingSpecDraft"
                    placeholder="规格名称"
                    size="small"
                    @keyup.enter="saveSpecKey(specIndex)"
                    style="width: 150px; margin-right: 10px"
                  />
                  <ElButton type="primary" size="small" @click="saveSpecKey(specIndex)">
                    保存
                  </ElButton>
                  <ElButton size="small" @click="cancelEditSpecKey">取消</ElButton>
                </div>
                <div v-else class="spec-key-display">
                  <span class="spec-name cursor-pointer" @click="editSpecKey(specIndex)">{{
                    spec.key
                  }}</span>
                  <ElButton type="primary" size="small" text @click="editSpecKey(specIndex)">
                    编辑
                  </ElButton>
                  <ElButton
                    type="danger"
                    size="small"
                    text
                    @click="removeSpecDefinition(specIndex)"
                  >
                    删除
                  </ElButton>
                </div>
              </div>
              <div class="spec-values">
                <ElTag
                  v-for="(value, valueIndex) in spec.values"
                  :key="valueIndex"
                  closable
                  @close="removeSpecValue(specIndex, valueIndex)"
                  class="mr-2 mb-2"
                >
                  {{ value }}
                </ElTag>
                <ElInput
                  :model-value="newSpecValues[specIndex] || ''"
                  @input="(val) => (newSpecValues[specIndex] = val)"
                  @keyup.enter="addSpecValue(specIndex)"
                  placeholder="输入规格值"
                  size="small"
                  style="width: 150px"
                />
                <ElButton size="small" type="primary" @click="addSpecValue(specIndex)">
                  确认
                </ElButton>
              </div>
            </div>

            <!-- 添加新规格 -->
            <div class="add-spec">
              <ElInput
                v-model="newSpecKeyDraft"
                placeholder="规格名称（如：颜色）"
                style="width: 200px; margin-right: 10px"
                @keyup.enter="addSpecDefinition"
              />
              <ElButton type="primary" @click="addSpecDefinition">添加规格</ElButton>
              <ElButton
                type="success"
                @click="generateSkus"
                :disabled="specDefinitions.length === 0"
              >
                生成 SKU
              </ElButton>
            </div>
          </div>

          <!-- SKU 列表 -->
          <div class="sku-list mt-6">
            <h4>SKU 列表</h4>
            <div class="mb-4">
              <span class="text-gray-500 text-sm">可直接在表格中编辑 SKU 信息</span>
            </div>

            <ElTable :data="skuList" border>
              <ElTableColumn prop="name" label="SKU 名称" min-width="150" />
              <ElTableColumn label="规格" min-width="200">
                <template #default="{ row }">
                  <ElTag v-for="(value, key) in row.specs" :key="key" size="small" class="mr-1">
                    {{ key }}: {{ value }}
                  </ElTag>
                </template>
              </ElTableColumn>
              <ElTableColumn label="价格（元）" width="150">
                <template #default="{ row, $index }">
                  <ElInputNumber
                    :model-value="row.price"
                    :min="0.01"
                    :precision="2"
                    :step="0.1"
                    size="small"
                    @change="(val) => updateSkuField($index, 'price', val)"
                  />
                </template>
              </ElTableColumn>
              <ElTableColumn label="原价（元）" width="150">
                <template #default="{ row, $index }">
                  <ElInputNumber
                    :model-value="row.originalPrice"
                    :min="0"
                    :precision="2"
                    :step="0.1"
                    size="small"
                    @change="(val) => updateSkuField($index, 'originalPrice', val)"
                  />
                </template>
              </ElTableColumn>
              <ElTableColumn label="库存" width="150">
                <template #default="{ row, $index }">
                  <ElInputNumber
                    :model-value="row.stock"
                    :min="0"
                    :step="1"
                    size="small"
                    @change="(val) => updateSkuField($index, 'stock', val)"
                  />
                </template>
              </ElTableColumn>
              <ElTableColumn label="状态" width="140">
                <template #default="{ row, $index }">
                  <ElSelect
                    :model-value="row.status"
                    size="small"
                    @change="(val) => updateSkuField($index, 'status', val)"
                  >
                    <ElOption label="启用" value="ACTIVE" />
                    <ElOption label="禁用" value="INACTIVE" />
                    <ElOption label="缺货" value="OUT_OF_STOCK" />
                  </ElSelect>
                </template>
              </ElTableColumn>
              <ElTableColumn label="操作" width="100" fixed="right">
                <template #default="{ $index }">
                  <ElButton type="danger" size="small" text @click="removeSku($index)">
                    删除
                  </ElButton>
                </template>
              </ElTableColumn>
            </ElTable>
          </div>
        </div>
      </ElTabPane>

      <!-- 商品图片标签页 -->
      <ElTabPane label="商品图片" name="images">
        <div class="image-upload-section">
          <div class="image-list">
            <!-- 已上传的图片列表 -->
            <div v-for="(image, index) in productImages" :key="index" class="image-item">
              <img :src="image" alt="商品图片" class="preview-image" />
              <div class="image-actions">
                <BaseButton type="danger" size="small" @click="removeImage(index)">
                  删除
                </BaseButton>
              </div>
            </div>

            <!-- Upload new image - uses ImageUpload component for each upload -->
            <div v-if="productImages.length < 9" class="upload-trigger">
              <ImageUpload
                v-model="newImageUrl"
                :aspect-ratio="1"
                :crop-box-width="800"
                :crop-box-height="800"
                category="product-image"
                dialog-title="上传商品图片"
                :max-size="10"
                :preview-width="148"
                :preview-height="148"
                placeholder="+"
                @success="handleImageUploaded"
              />
            </div>
          </div>

          <p class="text-gray-500 text-sm mt-2">
            支持上传多张商品图片（最多9张），建议尺寸 800x800 像素，正方形比例
          </p>
        </div>
      </ElTabPane>
    </ElTabs>
  </div>
</template>

<style scoped lang="scss">
.product-form {
  .sku-toggle-top {
    padding: 20px;
    background: #f5f7fa;
    border-radius: 4px;
    margin-bottom: 20px;
  }

  .empty-sku {
    padding: 40px 0;
  }

  .sku-manager {
    padding: 20px;

    .spec-definitions {
      margin-bottom: 30px;

      h4 {
        margin-bottom: 10px;
        font-size: 16px;
        font-weight: 600;
      }

      .spec-item {
        margin-bottom: 20px;
        padding: 20px;
        background: #f9fafc;
        border-radius: 8px;
        border: 1px solid #e5e7eb;

        .spec-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 15px;

          .spec-key-edit {
            display: flex;
            align-items: center;
            width: 100%;
          }

          .spec-key-display {
            display: flex;
            align-items: center;
            gap: 10px;

            .spec-name {
              font-weight: 600;
              color: #303133;
              font-size: 14px;
            }
          }
        }

        .spec-values {
          display: flex;
          flex-wrap: wrap;
          align-items: center;
          gap: 8px;
        }
      }

      .add-spec {
        display: flex;
        align-items: center;
        padding: 20px;
        background: #f0f2f5;
        border-radius: 8px;
        border: 1px dashed #dcdfe6;
      }
    }

    .sku-list {
      h4 {
        margin-bottom: 15px;
        font-size: 16px;
        font-weight: 600;
      }
    }
  }

  .image-upload-section {
    padding: 20px;

    .image-list {
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      margin-bottom: 12px;
    }

    .image-item {
      position: relative;
      width: 148px;
      height: 148px;
      border: 1px solid var(--el-border-color);
      border-radius: 4px;
      overflow: hidden;
      flex-shrink: 0;

      .preview-image {
        width: 100%;
        height: 100%;
        object-fit: cover;
      }

      .image-actions {
        position: absolute;
        bottom: 0;
        left: 0;
        right: 0;
        padding: 8px;
        background: linear-gradient(to top, rgba(0, 0, 0, 0.7), transparent);
        display: flex;
        justify-content: center;
        opacity: 0;
        transition: opacity 0.3s;

        &:hover {
          opacity: 1;
        }
      }
    }

    .upload-trigger {
      width: 148px;
      height: 148px;
      flex-shrink: 0;
    }
  }
}

.cursor-pointer {
  cursor: pointer;
}
</style>
