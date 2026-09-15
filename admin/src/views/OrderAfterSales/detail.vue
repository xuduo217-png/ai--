<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  ElButton,
  ElDialog,
  ElImage,
  ElInput,
  ElInputNumber,
  ElMessage,
  ElMessageBox,
  ElPageHeader,
  ElSkeleton,
  ElRadioButton,
  ElRadioGroup,
  ElTag,
  ElTimeline,
  ElTimelineItem,
  ElTooltip
} from 'element-plus'
import { CopyDocument, Refresh } from '@element-plus/icons-vue'
import {
  arbitrateAfterSaleApi,
  confirmAfterSaleReturnApi,
  getAfterSaleDetailApi,
  reviewAfterSaleApi,
  retryAfterSaleRefundApi
} from '@/api-new/after-sales'
import type {
  AdminAfterSale,
  AfterSaleType,
  ArbitrationDecision,
  AfterSaleStatus
} from '@/api-new/after-sales'
import { getImageUrl } from '@/utils/image'

const route = useRoute()
const router = useRouter()
const id = Number(route.params.id)
const loading = ref(false)
const submitting = ref(false)
const detail = ref<AdminAfterSale | null>(null)
const dialogVisible = ref(false)
const decision = ref<ArbitrationDecision>('support_buyer')
const remark = ref('')
const reviewVisible = ref(false)
const reviewDecision = ref<'approve' | 'reject'>('approve')
const reviewType = ref<AfterSaleType>('refund_only')
const reviewReason = ref('')
const returnAddress = ref('')
const approvedQuantities = ref<Record<string, number>>({})
const confirmReturnVisible = ref(false)
const returnRemark = ref('')
const restockQuantities = ref<Record<string, number>>({})

const statusText: Record<AfterSaleStatus, string> = {
  pending_handler: '等待处理',
  handler_rejected: '处理方已拒绝',
  handler_timeout: '处理超时',
  waiting_buyer_return: '等待买家退货',
  waiting_handler_receipt: '等待确认退货',
  arbitration_pending: '平台仲裁中',
  refunding: '退款处理中',
  refunded: '已退款',
  closed: '已关闭'
}

const statusType: Record<AfterSaleStatus, 'primary' | 'success' | 'warning' | 'danger' | 'info'> = {
  pending_handler: 'warning',
  handler_rejected: 'danger',
  handler_timeout: 'danger',
  waiting_buyer_return: 'primary',
  waiting_handler_receipt: 'primary',
  arbitration_pending: 'warning',
  refunding: 'primary',
  refunded: 'success',
  closed: 'info'
}

const statusHint: Record<AfterSaleStatus, string> = {
  pending_handler: '售后申请已提交，等待处理方审批',
  handler_rejected: '处理方已拒绝本次售后申请',
  handler_timeout: '处理方未在规定时间内完成处理',
  waiting_buyer_return: '审批已通过，等待买家寄回商品',
  waiting_handler_receipt: '买家已提交退货，等待确认收货',
  arbitration_pending: '买家已申请仲裁，等待平台判定',
  refunding: '退款指令已提交，正在等待支付渠道处理',
  refunded: '退款已完成，本次售后处理结束',
  closed: '本次售后已关闭'
}

const afterSaleTypeText: Record<AfterSaleType, string> = {
  refund_only: '仅退款',
  return_refund: '退货退款'
}

const reasonText: Record<string, string> = {
  product_issue: '商品问题',
  not_as_described: '与描述不符',
  damaged: '商品损坏',
  other: '其他原因'
}

const paymentMethodText: Record<string, string> = {
  balance: '余额支付',
  alipay: '支付宝',
  wechat: '微信支付',
  wechat_pay: '微信支付'
}

const orderStatusText: Record<string, string> = {
  pending: '待支付',
  paid: '已支付',
  shipped: '已发货',
  completed: '已完成',
  cancelled: '已取消'
}

const logActionText: Record<string, string> = {
  create: '发起售后',
  buyer_cancel: '买家取消售后',
  handler_approve_refund: '处理方同意退款',
  handler_approve_return: '处理方同意退货退款',
  handler_reject: '处理方拒绝申请',
  platform_approve_refund: '平台同意退款',
  platform_approve_return: '平台同意退货退款',
  platform_reject: '平台拒绝申请',
  submit_return: '买家提交退货',
  confirm_return: '卖家确认退货',
  platform_confirm_return: '平台确认退货',
  apply_arbitration: '买家申请仲裁',
  arbitration_support_buyer: '仲裁支持买家',
  arbitration_support_seller: '仲裁支持卖家',
  handler_timeout: '处理超时',
  buyer_return_timeout_close: '买家退货超时关闭',
  arbitration_timeout_close: '仲裁申请超时关闭',
  refund_success: '退款成功',
  refund_failed: '退款失败'
}

const operatorText: Record<string, string> = {
  buyer: '买家',
  seller: '卖家',
  admin: '平台',
  system: '系统'
}

const canArbitrate = computed(() => detail.value?.availableActions.includes('arbitrate'))
const canRetry = computed(() => detail.value?.availableActions.includes('retry_refund'))
const canReview = computed(() => detail.value?.availableActions.includes('review_after_sale'))
const canConfirmReturn = computed(() => detail.value?.availableActions.includes('confirm_return'))
const hasOperations = computed(
  () => canReview.value || canConfirmReturn.value || canRetry.value || canArbitrate.value
)
const isPlatformHandled = computed(() => detail.value?.handlerType === 'platform')
const showReturnFlow = computed(() => {
  const current = detail.value
  return Boolean(
    current &&
    (current.afterSaleType === 'return_refund' ||
      current.returnRequired ||
      current.returnAddress ||
      current.returnTrackingNumber)
  )
})
const evidenceGroups = computed(() => {
  const current = detail.value
  if (!current) return []
  return [
    { label: '申请凭证', urls: current.evidenceUrls || [] },
    { label: '退货凭证', urls: current.returnEvidenceUrls || [] },
    { label: '仲裁凭证', urls: current.arbitrationEvidenceUrls || [] }
  ].filter((group) => group.urls.length > 0)
})
const evidencePreviewUrls = computed(() =>
  evidenceGroups.value.flatMap((group) => group.urls.map((url) => getImageUrl(url)))
)
const itemPaidAmount = computed(() =>
  (detail.value?.items || []).reduce((total, item) => total + Number(item.paidAmount || 0), 0)
)
const allocatedDiscountAmount = computed(() =>
  (detail.value?.items || []).reduce((total, item) => total + Number(item.discountAmount || 0), 0)
)

const formatMoney = (value?: number | string | null) => {
  if (value === undefined || value === null || value === '') return '-'
  const amount = Number(value)
  return Number.isFinite(amount) ? `¥${amount.toFixed(2)}` : '-'
}

const formatTime = (value?: string | null) => {
  if (!value) return '-'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  const pad = (part: number) => String(part).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(
    date.getHours()
  )}:${pad(date.getMinutes())}`
}

const handlerDecisionLabel = (value?: string) => {
  if (!value) return isPlatformHandled.value ? '等待平台处理' : '等待卖家处理'
  const handler = isPlatformHandled.value ? '平台' : '卖家'
  return value === 'approved' ? `${handler}已同意` : `${handler}已拒绝`
}

const arbitrationDecisionLabel = (value?: ArbitrationDecision) => {
  if (!value) return '-'
  return value === 'support_buyer' ? '支持买家并退款' : '支持卖家并关闭售后'
}

const load = async () => {
  loading.value = true
  try {
    const response = await getAfterSaleDetailApi({ id })
    detail.value = response.data as AdminAfterSale
  } catch (error) {
    console.error('获取售后详情失败:', error)
    ElMessage.error('获取售后详情失败或无权访问')
  } finally {
    loading.value = false
  }
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

const openArbitration = (value: ArbitrationDecision) => {
  decision.value = value
  remark.value = ''
  dialogVisible.value = true
}

const openReview = (value: 'approve' | 'reject') => {
  const current = detail.value
  if (!current) return
  reviewDecision.value = value
  reviewType.value = current.afterSaleType
  reviewReason.value = ''
  returnAddress.value = ''
  approvedQuantities.value = Object.fromEntries(
    current.items.map((item) => [item.lineKey, item.requestedQuantity])
  )
  reviewVisible.value = true
}

const submitReview = async () => {
  const current = detail.value
  if (!current) return
  if (
    reviewDecision.value === 'approve' &&
    reviewType.value === 'return_refund' &&
    !returnAddress.value.trim()
  ) {
    ElMessage.warning('同意退货退款时必须填写退货地址')
    return
  }
  const approvedItems = current.items
    .map((item) => ({
      lineKey: item.lineKey,
      quantity: Number(approvedQuantities.value[item.lineKey] || 0)
    }))
    .filter((item) => item.quantity > 0)
  if (reviewDecision.value === 'approve' && approvedItems.length === 0) {
    ElMessage.warning('至少需要同意一个商品数量')
    return
  }
  try {
    await ElMessageBox.confirm('平台处理结果提交后将立即推进售后，确认提交？', '处理确认', {
      type: 'warning'
    })
    submitting.value = true
    await reviewAfterSaleApi({
      id,
      decision: reviewDecision.value,
      afterSaleType: reviewDecision.value === 'approve' ? reviewType.value : undefined,
      approvedItems: reviewDecision.value === 'approve' ? approvedItems : undefined,
      reason: reviewReason.value.trim() || undefined,
      returnAddress:
        reviewDecision.value === 'approve' && reviewType.value === 'return_refund'
          ? returnAddress.value.trim()
          : undefined
    })
    ElMessage.success(reviewDecision.value === 'approve' ? '售后已审批' : '售后已拒绝')
    reviewVisible.value = false
    await load()
  } catch (error) {
    if (error !== 'cancel') {
      console.error('平台处理售后失败:', error)
      ElMessage.error('平台处理售后失败')
    }
  } finally {
    submitting.value = false
  }
}

const openConfirmReturn = () => {
  const current = detail.value
  if (!current) return
  restockQuantities.value = Object.fromEntries(
    current.items.map((item) => [item.lineKey, item.approvedQuantity])
  )
  returnRemark.value = ''
  confirmReturnVisible.value = true
}

const submitConfirmReturn = async () => {
  const current = detail.value
  if (!current) return
  try {
    await ElMessageBox.confirm('确认收货后将按填写数量回补库存并发起退款，是否继续？', '确认退货', {
      type: 'warning'
    })
    submitting.value = true
    await confirmAfterSaleReturnApi({
      id,
      items: current.items.map((item) => ({
        lineKey: item.lineKey,
        restockQuantity: Number(restockQuantities.value[item.lineKey] || 0)
      })),
      remark: returnRemark.value.trim() || undefined
    })
    ElMessage.success('退货已确认，退款处理中')
    confirmReturnVisible.value = false
    await load()
  } catch (error) {
    if (error !== 'cancel') {
      console.error('确认退货失败:', error)
      ElMessage.error('确认退货失败')
    }
  } finally {
    submitting.value = false
  }
}

const submitArbitration = async () => {
  try {
    await ElMessageBox.confirm('仲裁提交后不可修改，确认提交？', '仲裁确认', {
      type: 'warning'
    })
    submitting.value = true
    await arbitrateAfterSaleApi({
      id,
      decision: decision.value,
      remark: remark.value.trim() || undefined
    })
    ElMessage.success('仲裁结果已提交')
    dialogVisible.value = false
    await load()
  } catch (error) {
    if (error !== 'cancel') {
      console.error('提交仲裁失败:', error)
      ElMessage.error('提交仲裁失败')
    }
  } finally {
    submitting.value = false
  }
}

const retryRefund = async () => {
  try {
    await ElMessageBox.confirm('确认重试该售后退款？', '退款重试', { type: 'warning' })
    submitting.value = true
    await retryAfterSaleRefundApi({ id })
    ElMessage.success('退款重试成功')
    await load()
  } catch (error) {
    if (error !== 'cancel') {
      console.error('退款重试失败:', error)
      ElMessage.error('退款重试失败')
    }
  } finally {
    submitting.value = false
  }
}

onMounted(load)
</script>

<template>
  <div class="after-sale-detail">
    <div class="page-frame">
      <div class="detail-toolbar">
        <el-page-header content="售后管理详情" @back="router.push('/orders/after-sales')" />
        <el-button :icon="Refresh" :loading="loading" @click="load">刷新</el-button>
      </div>

      <el-skeleton :loading="loading" animated :rows="10">
        <template v-if="detail">
          <section class="status-summary" :class="`status-${detail.status}`">
            <div class="status-copy">
              <div class="summary-kicker">
                <span>{{ detail.afterSaleNo }}</span>
                <el-tag :type="statusType[detail.status]" effect="light">
                  {{ statusText[detail.status] }}
                </el-tag>
              </div>
              <h1>{{ statusText[detail.status] }}</h1>
              <p>{{ statusHint[detail.status] }}</p>
            </div>
            <dl class="summary-metrics">
              <div>
                <dt>售后类型</dt>
                <dd>{{ afterSaleTypeText[detail.afterSaleType] }}</dd>
              </div>
              <div>
                <dt>申请金额</dt>
                <dd class="amount">{{ formatMoney(detail.requestedAmount) }}</dd>
              </div>
              <div>
                <dt>审批金额</dt>
                <dd>{{
                  detail.approvedAmount == null ? '待审批' : formatMoney(detail.approvedAmount)
                }}</dd>
              </div>
              <div>
                <dt>{{ detail.isOverdue ? '已超过截止时间' : '当前截止时间' }}</dt>
                <dd :class="{ overdue: detail.isOverdue }">{{
                  formatTime(detail.currentDeadlineAt)
                }}</dd>
              </div>
            </dl>
          </section>

          <div class="detail-layout">
            <main class="detail-main">
              <section class="detail-panel product-panel">
                <header class="panel-header">
                  <div>
                    <h2>售后商品</h2>
                    <p>订单号 {{ detail.order?.orderNo || '-' }}</p>
                  </div>
                  <el-tag effect="plain">
                    {{ detail.orderType === 'normal' ? '平台商城' : '二手交易' }}
                  </el-tag>
                </header>

                <div v-for="item in detail.items || []" :key="item.lineKey" class="product-row">
                  <el-image :src="getImageUrl(item.productImage || '')" fit="cover" />
                  <div class="product-copy">
                    <strong>{{ item.productName }}</strong>
                    <span class="product-sku">{{ item.skuName || '默认规格' }}</span>
                    <div class="product-meta">
                      <span>申请 {{ item.requestedQuantity }} 件</span>
                      <span>审批 {{ item.approvedQuantity }} 件</span>
                      <span>已退款 {{ item.refundedQuantity }} 件</span>
                    </div>
                  </div>
                  <div class="product-amount">
                    <span>该商品实付</span>
                    <strong>{{ formatMoney(item.paidAmount) }}</strong>
                  </div>
                </div>

                <dl class="amount-breakdown">
                  <div>
                    <dt>商品实付</dt>
                    <dd>{{ formatMoney(itemPaidAmount) }}</dd>
                  </div>
                  <div>
                    <dt>优惠分摊</dt>
                    <dd>{{
                      allocatedDiscountAmount > 0
                        ? `-${formatMoney(allocatedDiscountAmount)}`
                        : '¥0.00'
                    }}</dd>
                  </div>
                  <div>
                    <dt>申请退款</dt>
                    <dd>{{ formatMoney(detail.requestedAmount) }}</dd>
                  </div>
                  <div>
                    <dt>已退款</dt>
                    <dd class="refund-amount">{{ formatMoney(detail.refundAmount) }}</dd>
                  </div>
                </dl>
              </section>

              <section class="detail-panel process-panel">
                <header class="panel-header">
                  <div>
                    <h2>申请与处理</h2>
                    <p>{{ isPlatformHandled ? '平台直接处理' : '卖家处理，必要时平台仲裁' }}</p>
                  </div>
                </header>

                <div class="party-grid">
                  <div class="party-section">
                    <div class="party-title">
                      <span>买家申请</span>
                      <el-tag size="small" type="info" effect="plain">
                        {{ reasonText[detail.reasonCode] || detail.reasonCode }}
                      </el-tag>
                    </div>
                    <p class="party-content">{{ detail.description || '买家未填写补充说明' }}</p>
                  </div>
                  <div class="party-section">
                    <div class="party-title">
                      <span>{{ isPlatformHandled ? '平台处理' : '卖家处理' }}</span>
                      <el-tag
                        size="small"
                        :type="
                          (detail.handlerDecision || detail.sellerDecision) === 'rejected'
                            ? 'danger'
                            : 'info'
                        "
                        effect="plain"
                      >
                        {{ handlerDecisionLabel(detail.handlerDecision || detail.sellerDecision) }}
                      </el-tag>
                    </div>
                    <p class="party-content">
                      {{ detail.handlerReason || detail.sellerReason || '尚未填写处理说明' }}
                    </p>
                  </div>
                </div>

                <div v-if="showReturnFlow" class="return-flow">
                  <h3>退货信息</h3>
                  <dl class="info-list two-column">
                    <div>
                      <dt>退货地址</dt>
                      <dd>{{ detail.returnAddress || '-' }}</dd>
                    </div>
                    <div>
                      <dt>退货物流单号</dt>
                      <dd class="copy-value">
                        <span>{{ detail.returnTrackingNumber || '买家尚未填写' }}</span>
                        <el-tooltip v-if="detail.returnTrackingNumber" content="复制退货物流单号">
                          <el-button
                            link
                            :icon="CopyDocument"
                            @click="copyTracking(detail.returnTrackingNumber)"
                          />
                        </el-tooltip>
                      </dd>
                    </div>
                  </dl>
                </div>

                <div
                  v-if="detail.arbitrationReason || detail.arbitrationDecision"
                  class="arbitration-block"
                >
                  <h3>平台仲裁</h3>
                  <dl class="info-list two-column">
                    <div>
                      <dt>仲裁申请</dt>
                      <dd>{{ detail.arbitrationReason || '-' }}</dd>
                    </div>
                    <div>
                      <dt>仲裁结果</dt>
                      <dd>{{ arbitrationDecisionLabel(detail.arbitrationDecision) }}</dd>
                    </div>
                    <div class="span-all">
                      <dt>仲裁理由</dt>
                      <dd>{{ detail.arbitrationRemark || '-' }}</dd>
                    </div>
                  </dl>
                </div>

                <div v-if="evidenceGroups.length" class="evidence-section">
                  <h3>图片凭证</h3>
                  <div v-for="group in evidenceGroups" :key="group.label" class="evidence-group">
                    <span>{{ group.label }}</span>
                    <div class="evidence-grid">
                      <el-image
                        v-for="url in group.urls"
                        :key="url"
                        :src="getImageUrl(url)"
                        :preview-src-list="evidencePreviewUrls"
                        fit="cover"
                        preview-teleported
                      />
                    </div>
                  </div>
                </div>
              </section>
            </main>

            <aside class="detail-sidebar">
              <section class="detail-panel">
                <header class="panel-header compact">
                  <h2>订单信息</h2>
                </header>
                <dl class="info-list">
                  <div>
                    <dt>订单号</dt>
                    <dd class="break-all">{{ detail.order?.orderNo || '-' }}</dd>
                  </div>
                  <div>
                    <dt>订单状态</dt>
                    <dd>{{
                      orderStatusText[detail.order?.status || ''] || detail.order?.status || '-'
                    }}</dd>
                  </div>
                  <div>
                    <dt>支付方式</dt>
                    <dd>{{
                      paymentMethodText[detail.order?.paymentMethod || ''] ||
                      detail.order?.paymentMethod ||
                      '-'
                    }}</dd>
                  </div>
                  <div>
                    <dt>订单金额</dt>
                    <dd>{{ formatMoney(detail.order?.totalAmount) }}</dd>
                  </div>
                  <div>
                    <dt>支付单号</dt>
                    <dd class="break-all">{{ detail.order?.paymentNo || '-' }}</dd>
                  </div>
                  <div>
                    <dt>支付流水</dt>
                    <dd class="break-all">{{ detail.order?.transactionId || '-' }}</dd>
                  </div>
                  <div>
                    <dt>发货时间</dt>
                    <dd>{{ formatTime(detail.order?.shippedAt) }}</dd>
                  </div>
                  <div>
                    <dt>物流单号</dt>
                    <dd class="copy-value">
                      <span>{{ detail.order?.trackingNumber || '尚未填写' }}</span>
                      <el-tooltip v-if="detail.order?.trackingNumber" content="复制物流单号">
                        <el-button
                          link
                          :icon="CopyDocument"
                          @click="copyTracking(detail.order?.trackingNumber)"
                        />
                      </el-tooltip>
                    </dd>
                  </div>
                </dl>
              </section>

              <section class="detail-panel">
                <header class="panel-header compact">
                  <h2>联系人与收货</h2>
                </header>
                <dl class="info-list">
                  <div>
                    <dt>买家</dt>
                    <dd>{{ detail.buyer?.username || detail.buyerId }}</dd>
                  </div>
                  <div>
                    <dt>买家手机</dt>
                    <dd>{{ detail.buyer?.phone || '-' }}</dd>
                  </div>
                  <div v-if="!isPlatformHandled">
                    <dt>卖家</dt>
                    <dd>{{ detail.seller?.username || detail.sellerId || '-' }}</dd>
                  </div>
                  <div v-if="!isPlatformHandled">
                    <dt>卖家手机</dt>
                    <dd>{{ detail.seller?.phone || '-' }}</dd>
                  </div>
                  <div>
                    <dt>收货人</dt>
                    <dd
                      >{{ detail.order?.receiverName || '-' }}
                      {{ detail.order?.receiverPhone || '' }}</dd
                    >
                  </div>
                  <div>
                    <dt>收货地址</dt>
                    <dd>{{ detail.order?.shippingAddress || '-' }}</dd>
                  </div>
                </dl>
              </section>

              <section class="detail-panel timeline-panel">
                <header class="panel-header compact">
                  <h2>操作时间线</h2>
                </header>
                <el-timeline v-if="detail.logs?.length">
                  <el-timeline-item
                    v-for="log in detail.logs"
                    :key="log.id"
                    :timestamp="formatTime(log.createdAt)"
                    placement="top"
                  >
                    <div class="timeline-title">
                      <strong>{{ logActionText[log.action] || '售后状态更新' }}</strong>
                      <span>{{ operatorText[log.operatorType] || '系统' }}</span>
                    </div>
                    <p v-if="log.description">{{ log.description }}</p>
                  </el-timeline-item>
                </el-timeline>
                <p v-else class="empty-state">暂无操作记录</p>
              </section>
            </aside>
          </div>

          <div v-if="hasOperations" class="action-dock">
            <div>
              <strong>处理当前售后</strong>
              <span>当前状态：{{ statusText[detail.status] }}</span>
            </div>
            <div class="actions">
              <el-button
                v-if="canReview"
                type="danger"
                plain
                :disabled="submitting"
                @click="openReview('reject')"
                >拒绝申请</el-button
              >
              <el-button
                v-if="canReview"
                type="primary"
                :disabled="submitting"
                @click="openReview('approve')"
                >审批通过</el-button
              >
              <el-button
                v-if="canConfirmReturn"
                type="primary"
                :disabled="submitting"
                @click="openConfirmReturn"
                >确认退货</el-button
              >
              <el-button v-if="canRetry" type="warning" :loading="submitting" @click="retryRefund"
                >重试退款</el-button
              >
              <el-button
                v-if="canArbitrate"
                type="danger"
                :disabled="submitting"
                @click="openArbitration('support_seller')"
                >支持卖家</el-button
              >
              <el-button
                v-if="canArbitrate"
                type="primary"
                :disabled="submitting"
                @click="openArbitration('support_buyer')"
                >支持买家并退款</el-button
              >
            </div>
          </div>
        </template>
      </el-skeleton>
    </div>

    <el-dialog
      v-model="dialogVisible"
      title="提交仲裁结果"
      width="560px"
      :close-on-click-modal="false"
    >
      <p>{{ decision === 'support_buyer' ? '支持买家并执行整单退款' : '支持卖家并关闭售后' }}</p>
      <el-input
        v-model="remark"
        type="textarea"
        :rows="5"
        maxlength="2000"
        show-word-limit
        placeholder="仲裁处理理由（选填）"
      />
      <template #footer>
        <el-button :disabled="submitting" @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="submitArbitration"
          >确认提交</el-button
        >
      </template>
    </el-dialog>

    <el-dialog
      v-model="reviewVisible"
      :title="reviewDecision === 'approve' ? '审批平台售后' : '拒绝平台售后'"
      width="640px"
      :close-on-click-modal="false"
    >
      <template v-if="reviewDecision === 'approve' && detail">
        <el-radio-group v-model="reviewType" class="decision-mode">
          <el-radio-button value="refund_only">仅退款</el-radio-button>
          <el-radio-button value="return_refund" :disabled="detail.order?.status === 'paid'"
            >退货退款</el-radio-button
          >
        </el-radio-group>
        <div class="quantity-list">
          <div v-for="item in detail.items" :key="item.lineKey" class="quantity-row">
            <span>{{ item.productName }}</span>
            <el-input-number
              v-model="approvedQuantities[item.lineKey]"
              :min="0"
              :max="item.requestedQuantity"
              :step="1"
            />
          </div>
        </div>
        <el-input
          v-if="reviewType === 'return_refund'"
          v-model="returnAddress"
          class="dialog-field"
          maxlength="1000"
          placeholder="退货地址"
        />
      </template>
      <el-input
        v-model="reviewReason"
        class="dialog-field"
        type="textarea"
        :rows="4"
        maxlength="2000"
        show-word-limit
        placeholder="平台处理理由（选填）"
      />
      <template #footer>
        <el-button :disabled="submitting" @click="reviewVisible = false">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="submitReview">确认提交</el-button>
      </template>
    </el-dialog>

    <el-dialog
      v-model="confirmReturnVisible"
      title="确认退货与回库数量"
      width="640px"
      :close-on-click-modal="false"
    >
      <div v-if="detail" class="quantity-list">
        <div v-for="item in detail.items" :key="item.lineKey" class="quantity-row">
          <span>{{ item.productName }}（同意 {{ item.approvedQuantity }} 件）</span>
          <el-input-number
            v-model="restockQuantities[item.lineKey]"
            :min="0"
            :max="item.approvedQuantity"
            :step="1"
          />
        </div>
      </div>
      <el-input
        v-model="returnRemark"
        class="dialog-field"
        type="textarea"
        :rows="3"
        maxlength="1000"
        placeholder="验货备注（选填）"
      />
      <template #footer>
        <el-button :disabled="submitting" @click="confirmReturnVisible = false">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="submitConfirmReturn"
          >确认并退款</el-button
        >
      </template>
    </el-dialog>
  </div>
</template>

<style scoped lang="scss">
.after-sale-detail {
  min-height: 100%;
  padding: 20px;
  background: var(--app-content-bg-color);
}

.page-frame {
  width: min(100%, 1440px);
  margin: 0 auto;
}

.detail-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 16px;
}

.status-summary {
  display: flex;
  gap: 32px;
  align-items: stretch;
  justify-content: space-between;
  padding: 24px;
  background: #fff;
  border: 1px solid var(--el-border-color-lighter);
  border-left: 4px solid var(--el-color-primary);
  border-radius: 6px;
}

.status-summary.status-handler_rejected,
.status-summary.status-handler_timeout {
  border-left-color: var(--el-color-danger);
}

.status-summary.status-refunded {
  border-left-color: var(--el-color-success);
}

.status-summary.status-closed {
  border-left-color: var(--el-text-color-secondary);
}

.status-copy {
  min-width: 280px;
}

.summary-kicker {
  display: flex;
  gap: 10px;
  align-items: center;
  color: var(--el-text-color-secondary);
  font-size: 12px;
}

.status-copy h1 {
  margin: 12px 0 6px;
  color: var(--el-text-color-primary);
  font-size: 24px;
  line-height: 1.25;
  letter-spacing: 0;
}

.status-copy p,
.panel-header p {
  margin: 0;
  color: var(--el-text-color-secondary);
  font-size: 13px;
  line-height: 1.6;
}

.summary-metrics {
  display: grid;
  flex: 1;
  grid-template-columns: repeat(4, minmax(120px, 1fr));
  margin: 0;
  border-left: 1px solid var(--el-border-color-lighter);
}

.summary-metrics > div {
  display: flex;
  flex-direction: column;
  justify-content: center;
  min-width: 0;
  padding: 0 20px;
}

.summary-metrics dt,
.amount-breakdown dt,
.info-list dt {
  color: var(--el-text-color-secondary);
  font-size: 12px;
}

.summary-metrics dd,
.amount-breakdown dd,
.info-list dd {
  margin: 7px 0 0;
  color: var(--el-text-color-primary);
  font-size: 14px;
  font-weight: 600;
  line-height: 1.5;
}

.summary-metrics .amount {
  color: var(--el-color-danger);
  font-size: 20px;
}

.summary-metrics .overdue {
  color: var(--el-color-danger);
}

.detail-layout {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 360px;
  gap: 16px;
  align-items: start;
  margin-top: 16px;
}

.detail-main,
.detail-sidebar {
  display: grid;
  gap: 16px;
  min-width: 0;
}

.detail-panel {
  min-width: 0;
  padding: 20px;
  background: #fff;
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 6px;
}

.panel-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 18px;
  padding-bottom: 14px;
  border-bottom: 1px solid var(--el-border-color-lighter);
}

.panel-header.compact {
  margin-bottom: 8px;
}

.panel-header h2,
.process-panel h3 {
  margin: 0;
  color: var(--el-text-color-primary);
  font-size: 16px;
  font-weight: 600;
  letter-spacing: 0;
}

.panel-header p {
  margin-top: 4px;
}

.product-row {
  display: flex;
  gap: 16px;
  align-items: center;
  min-height: 96px;
  padding: 14px 0;
  border-bottom: 1px solid var(--el-border-color-lighter);
}

.product-row .el-image {
  flex: 0 0 76px;
  width: 76px;
  height: 76px;
  border-radius: 4px;
}

.product-copy {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 7px;
  min-width: 0;
}

.product-copy strong {
  overflow: hidden;
  color: var(--el-text-color-primary);
  font-size: 14px;
  line-height: 1.5;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.product-sku,
.product-meta {
  color: var(--el-text-color-secondary);
  font-size: 12px;
}

.product-meta {
  display: flex;
  gap: 16px;
  flex-wrap: wrap;
}

.product-amount {
  display: flex;
  flex: 0 0 112px;
  flex-direction: column;
  gap: 6px;
  align-items: flex-end;
  color: var(--el-text-color-secondary);
  font-size: 12px;
}

.product-amount strong {
  color: var(--el-text-color-primary);
  font-size: 16px;
}

.amount-breakdown {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  margin: 16px 0 0;
  padding: 16px;
  background: var(--el-fill-color-lighter);
  border-radius: 4px;
}

.amount-breakdown > div {
  padding: 0 16px;
  text-align: right;
  border-right: 1px solid var(--el-border-color-lighter);
}

.amount-breakdown > div:last-child {
  border-right: 0;
}

.amount-breakdown .refund-amount {
  color: var(--el-color-success);
}

.party-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 4px;
}

.party-section {
  min-width: 0;
  padding: 18px;
}

.party-section + .party-section {
  border-left: 1px solid var(--el-border-color-lighter);
}

.party-title {
  display: flex;
  gap: 10px;
  align-items: center;
  justify-content: space-between;
  color: var(--el-text-color-primary);
  font-size: 14px;
  font-weight: 600;
}

.party-content {
  min-height: 42px;
  margin: 14px 0 0;
  color: var(--el-text-color-regular);
  font-size: 13px;
  line-height: 1.7;
  white-space: pre-wrap;
}

.return-flow,
.arbitration-block,
.evidence-section {
  margin-top: 22px;
  padding-top: 20px;
  border-top: 1px solid var(--el-border-color-lighter);
}

.process-panel h3 {
  margin-bottom: 14px;
  font-size: 14px;
}

.info-list {
  margin: 0;
}

.info-list > div {
  display: grid;
  grid-template-columns: 92px minmax(0, 1fr);
  gap: 12px;
  align-items: start;
  padding: 11px 0;
  border-bottom: 1px solid var(--el-border-color-lighter);
}

.info-list > div:last-child {
  border-bottom: 0;
}

.info-list dd {
  margin-top: 0;
  font-weight: 400;
  text-align: right;
}

.info-list.two-column {
  display: grid;
  grid-template-columns: 1fr 1fr;
  column-gap: 24px;
}

.info-list.two-column > div {
  grid-template-columns: 100px minmax(0, 1fr);
}

.info-list.two-column .span-all {
  grid-column: 1 / -1;
}

.copy-value {
  display: flex;
  gap: 4px;
  align-items: flex-start;
  justify-content: flex-end;
}

.break-all {
  overflow-wrap: anywhere;
}

.evidence-group + .evidence-group {
  margin-top: 14px;
}

.evidence-group > span {
  display: block;
  margin-bottom: 8px;
  color: var(--el-text-color-secondary);
  font-size: 12px;
}

.decision-mode {
  margin-bottom: 16px;
}

.quantity-list {
  margin-bottom: 16px;
  border-top: 1px solid var(--el-border-color-lighter);
}

.quantity-row {
  display: flex;
  gap: 16px;
  align-items: center;
  justify-content: space-between;
  padding: 12px 0;
  border-bottom: 1px solid var(--el-border-color-lighter);
}

.dialog-field {
  margin-top: 16px;
}

.evidence-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, 96px);
  gap: 10px;
}

.evidence-grid .el-image {
  width: 96px;
  height: 96px;
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 4px;
}

.timeline-panel :deep(.el-timeline) {
  margin: 4px 0 0;
  padding-left: 4px;
}

.timeline-panel :deep(.el-timeline-item__timestamp) {
  margin-bottom: 5px;
  color: var(--el-text-color-secondary);
  font-size: 12px;
}

.timeline-title {
  display: flex;
  gap: 8px;
  align-items: center;
  justify-content: space-between;
  color: var(--el-text-color-primary);
  font-size: 13px;
}

.timeline-title span {
  color: var(--el-text-color-secondary);
  font-size: 12px;
  font-weight: 400;
}

.timeline-panel :deep(.el-timeline-item__content) p {
  margin: 6px 0 0;
  color: var(--el-text-color-secondary);
  font-size: 12px;
  line-height: 1.6;
}

.empty-state {
  margin: 24px 0;
  color: var(--el-text-color-secondary);
  font-size: 13px;
  text-align: center;
}

.action-dock {
  position: sticky;
  bottom: 16px;
  z-index: 5;
  display: flex;
  gap: 20px;
  align-items: center;
  justify-content: space-between;
  margin-top: 16px;
  padding: 14px 18px;
  background: rgba(255, 255, 255, 0.96);
  border: 1px solid var(--el-border-color);
  border-radius: 6px;
  box-shadow: 0 6px 18px rgba(31, 45, 61, 0.1);
  backdrop-filter: blur(8px);
}

.action-dock > div:first-child {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.action-dock strong {
  color: var(--el-text-color-primary);
  font-size: 14px;
}

.action-dock span {
  color: var(--el-text-color-secondary);
  font-size: 12px;
}

.actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  justify-content: flex-end;
}

.actions :deep(.el-button + .el-button) {
  margin-left: 0;
}

@media (max-width: 1180px) {
  .status-summary {
    flex-direction: column;
  }

  .summary-metrics {
    border-top: 1px solid var(--el-border-color-lighter);
    border-left: 0;
  }

  .summary-metrics > div {
    padding-top: 18px;
  }

  .detail-layout {
    grid-template-columns: 1fr;
  }

  .detail-sidebar {
    grid-template-columns: 1fr 1fr;
  }

  .timeline-panel {
    grid-column: 1 / -1;
  }
}

@media (max-width: 760px) {
  .after-sale-detail {
    padding: 12px;
  }

  .detail-toolbar,
  .action-dock {
    align-items: flex-start;
  }

  .status-summary,
  .detail-panel {
    padding: 16px;
  }

  .summary-metrics,
  .amount-breakdown,
  .party-grid,
  .info-list.two-column,
  .detail-sidebar {
    grid-template-columns: 1fr;
  }

  .summary-metrics > div,
  .amount-breakdown > div {
    padding: 12px 0;
    border-right: 0;
    border-bottom: 1px solid var(--el-border-color-lighter);
  }

  .summary-metrics > div:last-child,
  .amount-breakdown > div:last-child {
    border-bottom: 0;
  }

  .party-section + .party-section {
    border-top: 1px solid var(--el-border-color-lighter);
    border-left: 0;
  }

  .info-list.two-column .span-all {
    grid-column: auto;
  }

  .product-row {
    align-items: flex-start;
  }

  .product-amount {
    flex-basis: 90px;
  }

  .action-dock {
    position: static;
    flex-direction: column;
  }
}
</style>
