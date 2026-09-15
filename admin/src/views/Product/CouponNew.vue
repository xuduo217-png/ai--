<script setup lang="tsx">
import { ContentWrap } from '@/components/ContentWrap'
import { Table, TableColumn } from '@/components/Table'
import { BaseButton } from '@/components/Button'
import {
  ElTag,
  ElDialog,
  ElForm,
  ElFormItem,
  ElInput,
  ElInputNumber,
  ElSelect,
  ElOption,
  ElTransfer,
  ElMessage,
  ElMessageBox,
  ElDatePicker
} from 'element-plus'
import { ref, h, reactive, onMounted, nextTick } from 'vue'
import {
  getCouponListApi,
  createCouponApi,
  updateCouponApi,
  toggleCouponStatusApi,
  getCouponQRCodeApi,
  type Coupon
} from '@/api-new/shop'
import { getAllProductsApi } from '@/api-new/shop/product'
import { extractPagedTableData } from '@/utils/pagination'
import dayjs from 'dayjs'

const loading = ref(true)
const tableDataList = ref<Coupon[]>([])
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(10)

// 所有商品列表（用于 Transfer）
const allProducts = ref<any[]>([])

// 搜索条件
const searchForm = reactive({
  name: '',
  type: '',
  scope: '',
  isEnabled: undefined
})

// 对话框相关
const dialogVisible = ref(false)
const dialogTitle = ref('添加优惠券')
const dialogType = ref<'add' | 'edit'>('add')
const editingRow = ref<Coupon | null>(null)

// 商品选择对话框相关
const productSelectDialogVisible = ref(false)
const tempProductIds = ref<number[]>([])

// 二维码对话框相关
const qrCodeDialogVisible = ref(false)
const qrCodeLoading = ref(false)
const qrCodeImage = ref('')

// 表单引用
const formRef = ref()

// 表单数据
const formData = reactive<{
  id?: number
  name: string
  description?: string
  type: Coupon['type']
  minAmount: number
  discountValue: number
  maxDiscount?: number
  stock: number
  perUserLimit: number
  validFrom: string
  validAt: string
  // 新增字段
  scope: Coupon['scope']
  productIds?: number[]
  minOrderAmount: number
  canStack: number
  claimType?: Coupon['claimType'] | ''
  claimCode?: string
}>({
  name: '',
  type: 'FULL_REDUCTION',
  minAmount: 0,
  discountValue: 0,
  stock: 100,
  perUserLimit: 1,
  validFrom: '',
  validAt: '',
  scope: 'ALL',
  productIds: [],
  minOrderAmount: 0,
  canStack: 0,
  claimType: '',
  claimCode: ''
})

// 表格列定义
const columns: TableColumn[] = [
  {
    field: 'id',
    label: 'ID',
    width: 80
  },
  {
    field: 'name',
    label: '优惠券名称',
    minWidth: 150
  },
  {
    field: 'type',
    label: '类型',
    width: 100,
    formatter: (_: Recordable, __: TableColumn, cellValue: string) => {
      const typeMap: Record<string, { type: any; text: string }> = {
        FULL_REDUCTION: { type: 'success', text: '满减' },
        DISCOUNT: { type: 'warning', text: '折扣' },
        DIRECT_DISCOUNT: { type: 'primary', text: '直减' }
      }
      const type = typeMap[cellValue] || { type: 'info', text: cellValue }
      return h(ElTag, { type: type.type }, () => type.text)
    }
  },
  {
    field: 'discountInfo',
    label: '优惠信息',
    width: 150,
    formatter: (row: Coupon, _column: TableColumn, _cellValue: any) => {
      const minAmount = Number(row.minAmount || 0)
      const discountValue = Number(row.discountValue || 0)
      const maxDiscount = Number(row.maxDiscount || 0)

      if (row.type === 'FULL_REDUCTION') {
        // 满减券：满100减20
        return `满${minAmount}减${discountValue}`
      } else if (row.type === 'DIRECT_DISCOUNT') {
        // 直减券：直减10元
        return `直减${discountValue}元`
      } else if (row.type === 'DISCOUNT') {
        // 折扣券：8.5折，最大优惠50元
        const discountText = `${(discountValue / 10).toFixed(1)}折`
        return maxDiscount > 0 ? `${discountText}（最高${maxDiscount}元）` : discountText
      } else {
        return '-'
      }
    }
  },
  {
    field: 'scope',
    label: '使用范围',
    width: 100,
    formatter: (_: Recordable, __: TableColumn, cellValue: string) => {
      return h(ElTag, { type: 'success' }, () => (cellValue === 'ALL' ? '全品类' : '指定商品'))
    }
  },
  {
    field: 'quantityInfo',
    label: '发放情况',
    width: 200,
    slots: {
      default: (data: any) => {
        const { row } = data
        const claimed = Number(row.claimedCount ?? 0)
        const stock = Number(row.stock ?? 0)
        return (
          <div style="display: flex; align-items: center; gap: 8px">
            <span>{`${claimed}/${stock} 张`}</span>
            {row.isClaimedOut === 1 && (
              <span style="color: #f56c6c; font-weight: 500">【已领完】</span>
            )}
          </div>
        )
      }
    }
  },
  {
    field: 'statusDisplay',
    label: '状态',
    width: 180,
    slots: {
      default: (data: any) => {
        const { row } = data
        return (
          <div style="display: flex; gap: 4px; flex-wrap: wrap">
            <ElTag type={row.isEnabled === 0 ? 'success' : 'info'}>
              {row.isEnabled === 0 ? '启用' : '禁用'}
            </ElTag>
            {row.isClaimedOut === 1 && <ElTag type="danger">已领完</ElTag>}
            {row.isExpired === 1 && <ElTag type="warning">已过期</ElTag>}
          </div>
        )
      }
    }
  },
  {
    field: 'validityPeriod',
    label: '有效期',
    minWidth: 280,
    slots: {
      default: (data: any) => {
        const { row } = data
        const start = dayjs(row.validFrom).format('YYYY-MM-DD')
        const end = dayjs(row.validAt).format('YYYY-MM-DD')
        return (
          <div style="display: flex; align-items: center; gap: 8px">
            <span>{`${start} 至 ${end}`}</span>
            {row.isExpired === 1 && (
              <span style="color: #f56c6c; font-weight: 500">【已过期】</span>
            )}
          </div>
        )
      }
    }
  },
  {
    field: 'claimType',
    label: '领取方式',
    width: 120,
    formatter: (_: Recordable, __: TableColumn, cellValue: string) => {
      const typeMap: Record<string, string> = {
        NEW_USER: '新用户领取',
        SCAN_CODE: '扫码领取'
      }
      return typeMap[cellValue] || '-'
    }
  },
  {
    field: 'claimCode',
    label: '领取码',
    width: 150,
    formatter: (_: Recordable, __: TableColumn, cellValue: string) => {
      return cellValue || '-'
    }
  },
  {
    field: 'action',
    label: '操作',
    width: 280,
    slots: {
      default: (data) => {
        const { row } = data
        return (
          <div style="display: flex; gap: 8px; flex-wrap: wrap">
            <BaseButton type="primary" size="small" onClick={() => handleEdit(row)}>
              编辑
            </BaseButton>
            {row.claimType === 'SCAN_CODE' && (
              <BaseButton type="success" size="small" onClick={() => handleViewQRCode(row)}>
                查看二维码
              </BaseButton>
            )}
            <BaseButton
              type={row.isEnabled === 0 ? 'warning' : 'info'}
              size="small"
              onClick={() => handleToggleStatus(row)}
            >
              {row.isEnabled === 0 ? '禁用' : '启用'}
            </BaseButton>
          </div>
        )
      }
    }
  }
]

/**
 * 加载商品列表
 */
const loadProducts = async () => {
  try {
    const res = await getAllProductsApi()
    if (res?.data) {
      allProducts.value = res.data.map((item: any) => ({
        key: item.id,
        label: item.name
      }))
    }
  } catch (error) {
    console.error('加载商品列表失败:', error)
  }
}

/**
 * 获取优惠券列表
 */
const getCouponList = async () => {
  loading.value = true
  try {
    const res = await getCouponListApi({
      page: currentPage.value,
      limit: pageSize.value,
      ...searchForm
    })
    const { list, total: totalCount } = extractPagedTableData<Coupon>(res)
    tableDataList.value = list
    total.value = totalCount
  } finally {
    loading.value = false
  }
}

/**
 * 搜索
 */
const handleSearch = () => {
  currentPage.value = 1
  getCouponList()
}

/**
 * 重置搜索
 */
const handleReset = () => {
  Object.assign(searchForm, {
    name: '',
    type: '',
    scope: '',
    isEnabled: undefined
  })
  handleSearch()
}

/**
 * 打开添加对话框
 */
const handleAdd = () => {
  dialogTitle.value = '添加优惠券'
  dialogType.value = 'add'
  editingRow.value = null

  const now = dayjs()
  const tomorrow = now.add(30, 'day')

  Object.assign(formData, {
    name: '',
    description: '',
    type: 'FULL_REDUCTION',
    minAmount: 0,
    discountValue: 0,
    maxDiscount: undefined,
    stock: 100,
    perUserLimit: 1,
    validFrom: now.format('YYYY-MM-DD'),
    validAt: tomorrow.format('YYYY-MM-DD'),
    scope: 'ALL',
    productIds: [],
    minOrderAmount: 0,
    canStack: 0,
    claimType: '',
    claimCode: ''
  })

  dialogVisible.value = true
}

/**
 * 打开编辑对话框
 */
const handleEdit = async (row: Coupon) => {
  editingRow.value = row

  // 已发放的优惠券，编辑时弹出警告
  if (row.claimedCount > 0) {
    try {
      await ElMessageBox.confirm(
        '该优惠券已有人领取，修改后可能影响已领取用户的使用体验，确定要编辑吗？',
        '编辑警告',
        {
          confirmButtonText: '确定编辑',
          cancelButtonText: '取消',
          type: 'warning'
        }
      )
    } catch {
      return
    }
  }

  dialogTitle.value = '编辑优惠券'
  dialogType.value = 'edit'

  await nextTick()

  // 回显数据
  Object.assign(formData, {
    id: row.id,
    name: row.name,
    description: row.description,
    type: row.type,
    minAmount: row.minAmount,
    discountValue: row.discountValue,
    maxDiscount: row.maxDiscount,
    stock: row.stock,
    perUserLimit: row.perUserLimit,
    validFrom: dayjs(row.validFrom).format('YYYY-MM-DD'),
    validAt: dayjs(row.validAt).format('YYYY-MM-DD'),
    scope: row.scope,
    productIds: (row as any).products?.map((p: any) => p.id) || [],
    minOrderAmount: row.minOrderAmount || 0,
    canStack: row.canStack || 0,
    claimType: row.claimType || '',
    claimCode: row.claimCode || ''
  })

  dialogVisible.value = true
}

/**
 * 保存优惠券
 */
const handleSave = async () => {
  try {
    // 表单验证
    if (!formRef.value) {
      ElMessage.error('表单未初始化')
      return
    }

    await formRef.value.validate()

    // 处理时间
    const submitData = {
      ...formData,
      claimType: formData.claimType || undefined,
      validFrom: dayjs(formData.validFrom).startOf('day').toISOString(),
      validAt: dayjs(formData.validAt).endOf('day').toISOString()
    }

    if (dialogType.value === 'add') {
      await createCouponApi(submitData)
      ElMessage.success('添加成功')
    } else {
      // 更新时移除 id 和 claimCode 字段
      // id 已经由 URL 参数传递
      // claimCode 是创建时设置的，更新时不允许修改
      const { id, claimCode, ...updateData } = submitData as any
      await updateCouponApi(formData.id!, updateData)
      ElMessage.success('更新成功')
    }

    dialogVisible.value = false
    getCouponList()
  } catch (error) {
    if (error !== false) {
      ElMessage.error('操作失败，请检查表单数据')
      console.error(error)
    }
  }
}

/**
 * 查看二维码
 */
const handleViewQRCode = async (row: Coupon) => {
  qrCodeDialogVisible.value = true
  qrCodeLoading.value = true
  qrCodeImage.value = ''

  try {
    const res = await getCouponQRCodeApi(row.id!)

    // 检查响应中的 success 字段（注意：实际数据在 res.data 中）
    if (res.data?.success && res.data.qrcode) {
      qrCodeImage.value = res.data.qrcode
    } else {
      // 显示后端返回的错误消息
      ElMessage.error(res.data?.message || '获取二维码失败')
      qrCodeDialogVisible.value = false
    }
  } catch (error: any) {
    console.error('获取二维码失败:', error)
    ElMessage.error(error?.message || '网络错误，请重试')
    qrCodeDialogVisible.value = false
  } finally {
    qrCodeLoading.value = false
  }
}

/**
 * 打开商品选择对话框
 */
const handleOpenProductSelect = () => {
  tempProductIds.value = [...(formData.productIds || [])]
  productSelectDialogVisible.value = true
}

/**
 * 确认商品选择
 */
const handleConfirmProductSelect = () => {
  formData.productIds = [...tempProductIds.value]
  productSelectDialogVisible.value = false
}

/**
 * 取消商品选择
 */
const handleCancelProductSelect = () => {
  tempProductIds.value = []
  productSelectDialogVisible.value = false
}

/**
 * 切换状态
 */
const handleToggleStatus = async (row: Coupon) => {
  const actionText = row.isEnabled === 0 ? '禁用' : '启用'

  try {
    await ElMessageBox.confirm(
      `确定要${actionText}优惠券"${row.name}"吗？${
        row.isEnabled === 0 ? '禁用后，已领取但未使用的优惠券将失效。' : ''
      }`,
      `${actionText}确认`,
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      }
    )

    await toggleCouponStatusApi(row.id)
    ElMessage.success(`${actionText}成功`)
    getCouponList()
  } catch (error) {
    if (error !== 'cancel') {
      ElMessage.error(`${actionText}失败`)
    }
  }
}

onMounted(() => {
  loadProducts()
  getCouponList()
})
</script>

<template>
  <ContentWrap>
    <!-- 搜索栏 -->
    <div style="margin-bottom: 16px; display: flex; gap: 12px; align-items: center">
      <ElInput
        v-model="searchForm.name"
        placeholder="优惠券名称"
        style="width: 200px"
        @keyup.enter="handleSearch"
      />
      <ElSelect v-model="searchForm.type" placeholder="类型" style="width: 120px" clearable>
        <ElOption label="满减" value="FULL_REDUCTION" />
        <ElOption label="折扣" value="DISCOUNT" />
        <ElOption label="直减" value="DIRECT_DISCOUNT" />
      </ElSelect>
      <ElSelect v-model="searchForm.scope" placeholder="使用范围" style="width: 120px" clearable>
        <ElOption label="全品类" value="ALL" />
        <ElOption label="指定商品" value="SPECIFIC" />
      </ElSelect>
      <ElSelect v-model="searchForm.isEnabled" placeholder="状态" style="width: 120px" clearable>
        <ElOption label="启用" :value="0" />
        <ElOption label="禁用" :value="1" />
      </ElSelect>
      <BaseButton type="primary" @click="handleSearch">搜索</BaseButton>
      <BaseButton @click="handleReset">重置</BaseButton>
    </div>

    <!-- 新增按钮 -->
    <div style="margin-bottom: 16px">
      <BaseButton type="primary" @click="handleAdd">添加优惠券</BaseButton>
    </div>

    <Table
      :columns="columns"
      :data="tableDataList"
      :loading="loading"
      :total="total"
      v-model:page="currentPage"
      v-model:pageSize="pageSize"
      @page-change="getCouponList"
    />

    <!-- 编辑对话框 -->
    <ElDialog v-model="dialogVisible" :title="dialogTitle" width="700px">
      <ElForm ref="formRef" :model="formData" label-width="140px">
        <ElFormItem label="优惠券名称" required>
          <ElInput v-model="formData.name" placeholder="请输入优惠券名称" />
        </ElFormItem>

        <ElFormItem label="优惠券描述">
          <ElInput
            v-model="formData.description"
            type="textarea"
            :rows="2"
            placeholder="请输入优惠券描述"
          />
        </ElFormItem>

        <ElFormItem label="优惠券类型" required>
          <ElSelect v-model="formData.type" placeholder="请选择类型" style="width: 100%">
            <ElOption label="满减" value="FULL_REDUCTION" />
            <ElOption label="折扣" value="DISCOUNT" />
            <ElOption label="直减" value="DIRECT_DISCOUNT" />
          </ElSelect>
        </ElFormItem>

        <ElFormItem v-if="formData.type === 'FULL_REDUCTION'" label="满减金额" required>
          <div style="display: flex; align-items: center; gap: 8px">
            <span>满</span>
            <ElInputNumber v-model="formData.minAmount" :min="0" :precision="2" />
            <span>元减</span>
            <ElInputNumber v-model="formData.discountValue" :min="0" :precision="2" />
            <span>元</span>
          </div>
        </ElFormItem>

        <ElFormItem v-if="formData.type === 'DISCOUNT'" label="折扣比例" required>
          <div style="display: flex; align-items: center; gap: 8px">
            <ElInputNumber v-model="formData.discountValue" :min="0.1" :max="10" :precision="1" />
            <span>折（如85表示8.5折）</span>
          </div>
        </ElFormItem>

        <ElFormItem v-if="formData.type === 'DISCOUNT'" label="最大优惠金额">
          <ElInputNumber v-model="formData.maxDiscount" :min="0" :precision="2" />
          <span style="margin-left: 8px">元（选填）</span>
        </ElFormItem>

        <ElFormItem v-if="formData.type === 'DIRECT_DISCOUNT'" label="直减金额" required>
          <div style="display: flex; align-items: center; gap: 8px">
            <ElInputNumber v-model="formData.discountValue" :min="0" :precision="2" />
            <span>元</span>
          </div>
        </ElFormItem>

        <ElFormItem label="使用范围" required>
          <ElSelect v-model="formData.scope" placeholder="请选择使用范围" style="width: 100%">
            <ElOption label="全品类" value="ALL" />
            <ElOption label="指定商品" value="SPECIFIC" />
          </ElSelect>
        </ElFormItem>

        <ElFormItem v-if="formData.scope === 'SPECIFIC'" label="指定商品" required>
          <div style="display: flex; gap: 8px; align-items: center">
            <span>{{ formData.productIds?.length || 0 }} 个商品</span>
            <BaseButton type="primary" @click="handleOpenProductSelect">选择商品</BaseButton>
          </div>
        </ElFormItem>

        <ElFormItem label="发放总量" required>
          <ElInputNumber v-model="formData.stock" :min="1" />
        </ElFormItem>

        <ElFormItem label="每人限领数量" required>
          <ElInputNumber v-model="formData.perUserLimit" :min="1" />
        </ElFormItem>

        <ElFormItem label="最低订单金额" required>
          <div style="display: flex; align-items: center; gap: 8px">
            <ElInputNumber v-model="formData.minOrderAmount" :min="0" :precision="2" />
            <span>元（0表示不限制）</span>
          </div>
        </ElFormItem>

        <ElFormItem label="是否可叠加使用">
          <ElSelect v-model="formData.canStack" style="width: 100%">
            <ElOption label="否" :value="0" />
            <ElOption label="是" :value="1" />
          </ElSelect>
        </ElFormItem>

        <ElFormItem label="领取方式">
          <ElSelect
            v-model="formData.claimType"
            placeholder="请选择领取方式"
            style="width: 100%"
            clearable
          >
            <ElOption label="新用户领取" value="NEW_USER" />
            <ElOption label="扫码领取" value="SCAN_CODE" />
          </ElSelect>
        </ElFormItem>

        <ElFormItem label="有效期" required>
          <ElDatePicker
            v-model="formData.validFrom"
            type="date"
            placeholder="选择开始日期"
            format="YYYY-MM-DD"
            value-format="YYYY-MM-DD"
            style="width: 100%"
          />
          <span style="margin: 0 8px">至</span>
          <ElDatePicker
            v-model="formData.validAt"
            type="date"
            placeholder="选择结束日期"
            format="YYYY-MM-DD"
            value-format="YYYY-MM-DD"
            style="width: 100%"
          />
        </ElFormItem>
      </ElForm>
      <template #footer>
        <BaseButton @click="dialogVisible = false">取消</BaseButton>
        <BaseButton type="primary" @click="handleSave">保存</BaseButton>
      </template>
    </ElDialog>

    <!-- 商品选择对话框 -->
    <ElDialog
      v-model="productSelectDialogVisible"
      title="选择商品"
      width="1000px"
      :close-on-click-modal="false"
    >
      <ElTransfer
        v-model="tempProductIds"
        :data="allProducts"
        filterable
        filter-placeholder="搜索商品名称"
        :titles="['可选商品', '已选商品']"
        style="display: flex; justify-content: center; align-items: center"
        class="custom-transfer"
      />
      <template #footer>
        <BaseButton @click="handleCancelProductSelect">取消</BaseButton>
        <BaseButton type="primary" @click="handleConfirmProductSelect">确定</BaseButton>
      </template>
    </ElDialog>

    <!-- 二维码对话框 -->
    <ElDialog v-model="qrCodeDialogVisible" title="优惠券领取二维码" width="450px">
      <div v-loading="qrCodeLoading" style="text-align: center; padding: 20px">
        <img
          v-if="qrCodeImage"
          :src="qrCodeImage"
          style="
            width: 300px;
            height: 300px;
            border: 1px solid #dcdfe6;
            border-radius: 4px;
            display: inline-block;
          "
          alt="二维码"
        />
        <div v-if="qrCodeImage" style="margin-top: 16px; color: #606266; font-size: 14px">
          请使用 APP 扫码领取优惠券
        </div>
      </div>
      <template #footer>
        <BaseButton @click="qrCodeDialogVisible = false">关闭</BaseButton>
      </template>
    </ElDialog>
  </ContentWrap>
</template>

<style scoped>
/* 增加 Transfer 组件的宽度和高度 */
:deep(.el-transfer) {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 20px;
}

:deep(.el-transfer-panel) {
  width: 400px !important;
  height: 500px !important;
}

:deep(.el-transfer-panel__body) {
  height: 420px;
}

:deep(.el-transfer-panel__list) {
  height: 420px;
}

/* 中间按钮容器样式 */
:deep(.el-transfer__buttons) {
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 12px;
  padding: 20px 0;
}

:deep(.el-transfer__buttons .el-button) {
  margin: 0 !important;
}
</style>
