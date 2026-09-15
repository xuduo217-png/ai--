<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue'
import {
  ElMessage,
  ElMessageBox,
  ElTag,
  ElButton,
  ElDialog,
  ElDescriptions,
  ElDescriptionsItem,
  ElForm,
  ElFormItem,
  ElInput,
  ElSelect,
  ElOption,
  ElAlert,
  ElCard,
  ElTable,
  ElTableColumn,
  ElPagination,
  ElDivider,
  ElTabs,
  ElTabPane,
  ElImage
} from 'element-plus'
import { CopyDocument } from '@element-plus/icons-vue'
import { getOrderListApi, updateOrderStatusApi, setShippingInfoApi } from '@/api-new/orders'
import { getEnabledLogisticsApi } from '@/api-new/logistics'
import { getImageUrl } from '@/utils/image'
import type { Order, Logistics } from '@/api-new/types'
import { OrderStatus, OrderStatusText, OrderType } from '@/api-new/types'

// 搜索表单
const searchForm = reactive({
  search: '',
  status: undefined as OrderStatus | undefined,
  orderType: undefined as OrderType | undefined,
  afterSaleStatus: undefined as string | undefined,
  settlementStatus: undefined as 'pending' | 'settling' | 'settled' | undefined
})

// 表格数据
const tableData = ref<Order[]>([])
const loading = ref(false)
const pagination = reactive({
  page: 1,
  limit: 10,
  total: 0
})

// 详情对话框
const detailDialogVisible = ref(false)
const currentOrder = ref<Order | null>(null)
const activeTab = ref('order')

// 物流表单
const shippingForm = reactive({
  logisticsId: undefined as number | undefined,
  trackingNumber: ''
})

// 物流公司列表
const logisticsList = ref<Logistics[]>([])
const isSecondHand = computed(() => currentOrder.value?.orderType === OrderType.SECOND_HAND)

const afterSaleStatusText: Record<string, string> = {
  pending_handler: '等待处理',
  handler_rejected: '申请已拒绝',
  handler_timeout: '处理已超时',
  waiting_handler_receipt: '等待确认收货',
  pending_seller: '待卖家处理',
  seller_rejected: '卖家已拒绝',
  seller_timeout: '卖家处理超时',
  waiting_buyer_return: '等待买家退货',
  waiting_seller_receipt: '等待卖家收货',
  arbitration_pending: '平台仲裁中',
  refunding: '退款处理中',
  refunded: '已退款',
  closed: '已关闭'
}

const settlementStatusText: Record<string, string> = {
  pending: '待结算',
  settling: '结算审核中',
  settled: '已结算'
}

const copyTracking = async (value?: string) => {
  if (!value) return
  try {
    await navigator.clipboard.writeText(value)
    ElMessage.success('物流单号已复制')
  } catch (error) {
    console.error('复制物流单号失败:', error)
    ElMessage.error('复制失败，请手动选择物流单号')
  }
}

/**
 * 计算当前选择的物流公司名称
 */
const currentLogisticsName = computed(() => {
  if (shippingForm.logisticsId) {
    const logistics = logisticsList.value.find((item) => item.id === shippingForm.logisticsId)
    return logistics?.name
  }
  return currentOrder.value?.logistics?.name
})

/**
 * 判断是否有物流信息
 */
const hasLogisticsInfo = computed(() => {
  return !!(
    (shippingForm.logisticsId || currentOrder.value?.logisticsId) &&
    (shippingForm.trackingNumber || currentOrder.value?.trackingNumber)
  )
})

/**
 * 获取物流提示标题
 */
const getLogisticsTitle = () => {
  const logisticsName = currentLogisticsName.value || currentOrder.value?.logistics?.name || ''
  const trackingNumber = shippingForm.trackingNumber || currentOrder.value?.trackingNumber || ''

  if (currentOrder.value?.status === OrderStatus.COMPLETED) {
    return `订单已完成，通过 ${logisticsName} 配送，物流单号：${trackingNumber}`
  } else if (currentOrder.value?.status === OrderStatus.SHIPPED) {
    return `已通过 ${logisticsName} 发货，物流单号：${trackingNumber}`
  } else {
    return `将通过 ${logisticsName} 发货，物流单号：${trackingNumber}`
  }
}

/**
 * 获取订单列表
 */
const fetchOrders = async () => {
  loading.value = true
  try {
    const response = await getOrderListApi({
      search: searchForm.search,
      status: searchForm.status,
      orderType: searchForm.orderType,
      afterSaleStatus: searchForm.afterSaleStatus,
      settlementStatus: searchForm.settlementStatus,
      page: pagination.page,
      limit: pagination.limit
    })
    // 后端响应格式: { code: 0, data: Order[], message: "", meta: { total, page, limit } }
    // 后端返回的数据直接赋值
    tableData.value = (response.data as any) || []
    pagination.total = (response.meta as any)?.total || 0
  } catch (error) {
    console.error('获取订单列表失败:', error)
    ElMessage.error('获取订单列表失败')
  } finally {
    loading.value = false
  }
}

/**
 * 查看订单详情
 */
const handleViewDetail = async (row: Order) => {
  currentOrder.value = row
  activeTab.value = 'order' // 重置到订单信息标签页
  // 如果已支付或已发货或已完成，加载物流公司列表
  if (
    row.orderType !== OrderType.SECOND_HAND &&
    [OrderStatus.PAID, OrderStatus.SHIPPED, OrderStatus.COMPLETED].includes(
      row.status as OrderStatus
    )
  ) {
    const { data } = await getEnabledLogisticsApi()
    logisticsList.value = data
    // 回填物流信息
    if (row.logisticsId) {
      shippingForm.logisticsId = row.logisticsId
      shippingForm.trackingNumber = row.trackingNumber || ''
    } else {
      shippingForm.logisticsId = undefined
      shippingForm.trackingNumber = ''
    }
  }
  detailDialogVisible.value = true
}

/**
 * 更新订单状态
 */
const handleUpdateStatus = async (id: number, status: OrderStatus, reason?: string) => {
  try {
    const confirmText =
      {
        [OrderStatus.PAID]: '确认将订单标记为已支付？',
        [OrderStatus.SHIPPED]: '确认将订单标记为已发货？',
        [OrderStatus.COMPLETED]: '确认订单已送达完成？',
        [OrderStatus.CANCELLED]: '确认取消该订单吗？'
      }[status] || '确认操作？'

    await ElMessageBox.confirm(confirmText, '操作确认', {
      type: 'warning',
      confirmButtonText: '确认',
      cancelButtonText: '取消'
    })

    await updateOrderStatusApi(id, {
      status,
      cancelReason: reason
    })

    ElMessage.success('操作成功')
    detailDialogVisible.value = false
    await fetchOrders()
  } catch (error: any) {
    if (error !== 'cancel') {
      ElMessage.error(error.response?.data?.message || '操作失败')
    }
  }
}

/**
 * 设置物流信息
 */
const handleSetShipping = async () => {
  if (!shippingForm.logisticsId || !shippingForm.trackingNumber) {
    ElMessage.warning('请完善物流信息')
    return
  }

  try {
    await setShippingInfoApi(currentOrder.value!.id, {
      logisticsId: shippingForm.logisticsId,
      trackingNumber: shippingForm.trackingNumber
    })

    ElMessage.success('发货成功')
    detailDialogVisible.value = false
    await fetchOrders()
  } catch (error: any) {
    ElMessage.error(error.response?.data?.message || '操作失败')
  }
}

/**
 * 取消订单
 */
const handleCancel = async (row: Order) => {
  try {
    const { value } = await ElMessageBox.prompt('请输入取消原因', '取消订单', {
      confirmButtonText: '确认',
      cancelButtonText: '取消',
      inputPattern: /.+/,
      inputErrorMessage: '请输入取消原因'
    })

    await handleUpdateStatus(row.id, OrderStatus.CANCELLED, value)
  } catch (error) {
    // 用户取消
  }
}

/**
 * 获取状态标签类型
 */
const getStatusType = (status: OrderStatus) => {
  const map = {
    pending: 'warning',
    paid: 'primary',
    shipped: 'info',
    completed: 'success',
    cancelled: 'danger'
  } as const
  return map[status]
}

onMounted(() => {
  fetchOrders()
})
</script>

<template>
  <div class="order-management">
    <!-- 搜索区 -->
    <el-card class="search-card">
      <el-form :inline="true" :model="searchForm">
        <el-form-item label="关键词">
          <el-input
            v-model="searchForm.search"
            placeholder="订单号/用户名/手机号"
            clearable
            style="width: 200px"
            @keyup.enter="fetchOrders"
          />
        </el-form-item>
        <el-form-item label="订单状态">
          <el-select v-model="searchForm.status" placeholder="全部" clearable style="width: 150px">
            <el-option label="待支付" :value="OrderStatus.PENDING" />
            <el-option label="已支付" :value="OrderStatus.PAID" />
            <el-option label="已发货" :value="OrderStatus.SHIPPED" />
            <el-option label="已完成" :value="OrderStatus.COMPLETED" />
            <el-option label="已取消" :value="OrderStatus.CANCELLED" />
          </el-select>
        </el-form-item>
        <el-form-item label="订单类型">
          <el-select
            v-model="searchForm.orderType"
            placeholder="全部"
            clearable
            style="width: 150px"
          >
            <el-option label="普通订单" :value="OrderType.NORMAL" />
            <el-option label="二手订单" :value="OrderType.SECOND_HAND" />
          </el-select>
        </el-form-item>
        <el-form-item label="售后状态">
          <el-select
            v-model="searchForm.afterSaleStatus"
            placeholder="全部"
            clearable
            style="width: 170px"
          >
            <el-option
              v-for="(label, value) in afterSaleStatusText"
              :key="value"
              :label="label"
              :value="value"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="结算状态">
          <el-select
            v-model="searchForm.settlementStatus"
            placeholder="全部"
            clearable
            style="width: 150px"
          >
            <el-option
              v-for="(label, value) in settlementStatusText"
              :key="value"
              :label="label"
              :value="value"
            />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="fetchOrders">查询</el-button>
          <el-button
            @click="
              () => {
                searchForm.search = ''
                searchForm.status = undefined
                searchForm.orderType = undefined
                searchForm.afterSaleStatus = undefined
                searchForm.settlementStatus = undefined
                fetchOrders()
              }
            "
          >
            重置
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 订单表格 -->
    <el-card class="table-card">
      <el-table :data="tableData" v-loading="loading" border stripe style="width: 100%">
        <el-table-column prop="orderNo" label="订单号" fixed="left" />
        <el-table-column label="类型" width="100">
          <template #default="scope">
            <el-tag :type="scope.row.orderType === OrderType.SECOND_HAND ? 'warning' : 'primary'">
              {{ scope.row.orderType === OrderType.SECOND_HAND ? '二手' : '普通' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="买家" width="120">
          <template #default="scope">
            {{ scope?.row?.user?.username || '-' }}
          </template>
        </el-table-column>
        <el-table-column label="卖家" width="120">
          <template #default="scope">{{
            scope.row.seller?.username || scope.row.sellerId || '-'
          }}</template>
        </el-table-column>
        <el-table-column label="手机号" width="130">
          <template #default="scope">
            {{ scope?.row?.user?.phone || scope?.row?.receiverPhone || '-' }}
          </template>
        </el-table-column>
        <el-table-column label="售后状态" width="140">
          <template #default="scope">
            <el-tag v-if="scope.row.afterSaleSummary" type="warning">
              {{
                afterSaleStatusText[scope.row.afterSaleSummary.status] ||
                scope.row.afterSaleSummary.status
              }}
            </el-tag>
            <span v-else>-</span>
          </template>
        </el-table-column>
        <el-table-column label="结算状态" width="120">
          <template #default="scope">
            {{
              scope.row.orderType === OrderType.SECOND_HAND
                ? settlementStatusText[scope.row.settlementStatus || ''] || '-'
                : '-'
            }}
          </template>
        </el-table-column>
        <el-table-column prop="shippedAt" label="发货时间" width="180">
          <template #default="scope">{{ scope.row.shippedAt || '-' }}</template>
        </el-table-column>
        <el-table-column label="物流单号" min-width="170">
          <template #default="scope">
            <span>{{ scope.row.trackingNumber || '-' }}</span>
            <el-button
              v-if="scope.row.trackingNumber"
              link
              :icon="CopyDocument"
              title="复制物流单号"
              @click="copyTracking(scope.row.trackingNumber)"
            />
          </template>
        </el-table-column>
        <el-table-column prop="totalAmount" label="订单金额" width="100" align="right">
          <template #default="scope"> ¥{{ scope?.row?.totalAmount || 0 }} </template>
        </el-table-column>
        <el-table-column prop="status" label="订单状态" width="100">
          <template #default="scope">
            <el-tag v-if="scope?.row" :type="getStatusType(scope.row.status as OrderStatus)">
              {{ OrderStatusText[scope.row.status as OrderStatus] || scope.row.status }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="下单时间" width="240" />
        <el-table-column label="操作" width="300" fixed="right">
          <template #default="scope">
            <el-button type="primary" size="small" @click="handleViewDetail(scope.row)">
              查看详情
            </el-button>

            <!-- 待支付：标记为已支付 -->
            <el-button
              v-if="
                scope?.row?.orderType !== OrderType.SECOND_HAND &&
                scope?.row?.status === OrderStatus.PENDING
              "
              type="success"
              size="small"
              @click="handleUpdateStatus(scope.row.id, OrderStatus.PAID)"
            >
              标记已支付
            </el-button>

            <!-- 已支付：设置物流 -->
            <el-button
              v-if="
                scope?.row?.orderType !== OrderType.SECOND_HAND &&
                scope?.row?.status === OrderStatus.PAID
              "
              type="warning"
              size="small"
              @click="handleViewDetail(scope.row)"
            >
              设置物流
            </el-button>

            <!-- 已发货：标记完成 -->
            <el-button
              v-if="
                scope?.row?.orderType !== OrderType.SECOND_HAND &&
                scope?.row?.status === OrderStatus.SHIPPED
              "
              type="success"
              size="small"
              @click="handleUpdateStatus(scope.row.id, OrderStatus.COMPLETED)"
            >
              标记完成
            </el-button>

            <!-- 待支付、已支付可取消 -->
            <el-button
              v-if="
                scope?.row?.orderType !== OrderType.SECOND_HAND &&
                scope?.row?.status === OrderStatus.PENDING
              "
              type="danger"
              size="small"
              @click="handleCancel(scope.row)"
            >
              取消订单
            </el-button>
          </template>
        </el-table-column>
      </el-table>

      <!-- 分页 -->
      <el-pagination
        v-model:current-page="pagination.page"
        v-model:page-size="pagination.limit"
        :total="pagination.total"
        :page-sizes="[10, 20, 50, 100]"
        layout="total, sizes, prev, pager, next, jumper"
        style="margin-top: 16px; justify-content: flex-end"
        @current-change="fetchOrders"
        @size-change="fetchOrders"
      />
    </el-card>

    <!-- 订单详情对话框 -->
    <el-dialog
      v-model="detailDialogVisible"
      title="订单详情"
      width="1000px"
      @close="
        () => {
          shippingForm.logisticsId = undefined
          shippingForm.trackingNumber = ''
        }
      "
    >
      <template v-if="currentOrder">
        <el-tabs v-model="activeTab" type="border-card">
          <!-- 订单信息 -->
          <el-tab-pane label="订单信息" name="order">
            <el-descriptions :column="2" border>
              <el-descriptions-item label="订单号">
                {{ currentOrder.orderNo }}
              </el-descriptions-item>
              <el-descriptions-item label="订单状态">
                <el-tag :type="getStatusType(currentOrder.status as OrderStatus)">
                  {{ OrderStatusText[currentOrder.status as OrderStatus] || currentOrder.status }}
                </el-tag>
              </el-descriptions-item>
              <el-descriptions-item label="用户">
                {{ currentOrder.user?.username }}
              </el-descriptions-item>
              <el-descriptions-item label="订单类型">
                <el-tag :type="isSecondHand ? 'warning' : 'primary'">{{
                  isSecondHand ? '二手订单' : '普通订单'
                }}</el-tag>
              </el-descriptions-item>
              <el-descriptions-item label="卖家">
                {{ currentOrder.seller?.username || currentOrder.sellerId || '-' }}
              </el-descriptions-item>
              <el-descriptions-item label="售后状态">
                {{
                  currentOrder.afterSaleSummary
                    ? afterSaleStatusText[currentOrder.afterSaleSummary.status] ||
                      currentOrder.afterSaleSummary.status
                    : '-'
                }}
              </el-descriptions-item>
              <el-descriptions-item label="结算状态">
                {{
                  isSecondHand
                    ? settlementStatusText[currentOrder.settlementStatus || ''] || '-'
                    : '-'
                }}
              </el-descriptions-item>
              <el-descriptions-item label="订单金额">
                ¥{{ currentOrder.totalAmount }}
              </el-descriptions-item>
              <el-descriptions-item label="收货人">
                {{ currentOrder.receiverName }}
              </el-descriptions-item>
              <el-descriptions-item label="联系电话">
                {{ currentOrder.receiverPhone }}
              </el-descriptions-item>
              <el-descriptions-item label="收货地址" :span="2">
                {{ currentOrder.shippingAddress }}
              </el-descriptions-item>
              <el-descriptions-item v-if="currentOrder.remark" label="备注" :span="2">
                {{ currentOrder.remark }}
              </el-descriptions-item>
            </el-descriptions>

            <template v-if="isSecondHand && currentOrder.status !== OrderStatus.PENDING">
              <el-divider content-position="left">二手订单物流</el-divider>
              <el-alert
                v-if="currentOrder.status === OrderStatus.PAID"
                type="info"
                :closable="false"
                title="等待卖家在 APP 中确认发货"
              />
              <el-descriptions v-else :column="2" border>
                <el-descriptions-item label="发货时间">{{
                  currentOrder.shippedAt || '-'
                }}</el-descriptions-item>
                <el-descriptions-item label="物流单号">
                  <span>{{ currentOrder.trackingNumber || '卖家未填写物流单号' }}</span>
                  <el-button
                    v-if="currentOrder.trackingNumber"
                    link
                    :icon="CopyDocument"
                    title="复制物流单号"
                    @click="copyTracking(currentOrder.trackingNumber)"
                  />
                </el-descriptions-item>
              </el-descriptions>
            </template>

            <!-- 普通订单物流信息（已支付后显示） -->
            <template
              v-if="
                !isSecondHand &&
                [OrderStatus.PAID, OrderStatus.SHIPPED, OrderStatus.COMPLETED].includes(
                  currentOrder.status as OrderStatus
                )
              "
            >
              <el-divider content-position="left">物流信息</el-divider>

              <!-- 已支付状态：显示输入框和确认发货按钮 -->
              <template v-if="currentOrder.status === OrderStatus.PAID">
                <el-form :model="shippingForm" label-width="100px">
                  <el-form-item label="物流公司" required>
                    <el-select
                      v-model="shippingForm.logisticsId"
                      placeholder="请选择物流公司"
                      style="width: 300px"
                    >
                      <el-option
                        v-for="item in logisticsList"
                        :key="item.id"
                        :label="item.name"
                        :value="item.id"
                      />
                    </el-select>
                  </el-form-item>
                  <el-form-item label="物流单号" required>
                    <el-input
                      v-model="shippingForm.trackingNumber"
                      placeholder="请输入物流单号"
                      style="width: 300px"
                    />
                  </el-form-item>
                </el-form>

                <!-- 实时显示物流信息预览 -->
                <div v-if="hasLogisticsInfo" style="margin-top: 20px">
                  <el-alert type="success" :closable="false" :title="getLogisticsTitle()" />
                </div>

                <!-- 确认发货按钮 -->
                <div style="text-align: right; margin-top: 20px">
                  <el-button type="primary" @click="handleSetShipping"> 确认发货 </el-button>
                </div>
              </template>

              <!-- 已发货/已完成状态：只显示物流信息 -->
              <template
                v-if="
                  currentOrder.status === OrderStatus.SHIPPED ||
                  currentOrder.status === OrderStatus.COMPLETED
                "
              >
                <el-alert
                  :type="currentOrder.status === OrderStatus.COMPLETED ? 'info' : 'success'"
                  :closable="false"
                  :title="getLogisticsTitle()"
                />
              </template>
            </template>
          </el-tab-pane>

          <!-- 商品信息 -->
          <el-tab-pane label="商品信息" name="product">
            <div class="product-list">
              <div v-for="item in currentOrder.items" :key="item.productId" class="product-item">
                <!-- 左侧图片 -->
                <div class="product-image">
                  <el-image
                    :src="
                      item.productImage ? getImageUrl(item.productImage) : '/placeholder-image.png'
                    "
                    fit="cover"
                    style="width: 100%; height: 100%"
                  >
                    <template #error>
                      <div class="image-error">
                        <span>暂无图片</span>
                      </div>
                    </template>
                  </el-image>
                </div>

                <!-- 右侧信息 -->
                <div class="product-info">
                  <div class="product-name">{{ item.productName }}</div>
                  <div class="product-details">
                    <span class="detail-item">
                      <el-tag size="small" type="info"
                        >规格: {{ item.skuName || '默认规格' }}</el-tag
                      >
                    </span>
                    <span class="detail-item">
                      <el-tag size="small" type="warning">单价: ¥{{ item.price }}</el-tag>
                    </span>
                    <span class="detail-item">
                      <el-tag size="small" type="success">数量: x{{ item.quantity }}</el-tag>
                    </span>
                  </div>
                  <div class="product-total">
                    小计:
                    <span class="total-price">¥{{ (item.price * item.quantity).toFixed(2) }}</span>
                  </div>
                </div>
              </div>
            </div>
          </el-tab-pane>
        </el-tabs>
      </template>

      <template #footer>
        <el-button @click="detailDialogVisible = false">关闭</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped lang="scss">
.order-management {
  padding: 16px;

  .search-card {
    margin-bottom: 16px;
  }

  .table-card {
    :deep(.el-pagination) {
      display: flex;
      justify-content: flex-end;
    }
  }

  // 商品列表样式
  .product-list {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .product-item {
    display: flex;
    gap: 16px;
    padding: 16px;
    border: 1px solid #ebeef5;
    border-radius: 4px;
    transition: all 0.3s;

    &:hover {
      box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.1);
    }
  }

  .product-image {
    flex-shrink: 0;
    width: 100px;
    height: 100px;
    border-radius: 4px;
    overflow: hidden;
    background-color: #f5f7fa;

    .image-error {
      display: flex;
      align-items: center;
      justify-content: center;
      width: 100%;
      height: 100%;
      background-color: #f5f7fa;
      color: #909399;
      font-size: 12px;
    }
  }

  .product-info {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .product-name {
    font-size: 16px;
    font-weight: 500;
    color: #303133;
  }

  .product-details {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }

  .product-total {
    margin-top: auto;
    font-size: 14px;
    color: #606266;

    .total-price {
      font-size: 18px;
      font-weight: 500;
      color: #f56c6c;
    }
  }
}
</style>
