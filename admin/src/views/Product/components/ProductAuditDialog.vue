<script setup lang="ts">
import { ref, computed } from 'vue'
import {
  ElImage,
  ElDescriptions,
  ElDescriptionsItem,
  ElInput,
  ElTag,
  ElButton,
  ElIcon
} from 'element-plus'
import { Loading } from '@element-plus/icons-vue'
import { reviewPendingProductApi } from '@/api-new/shop'
import { ElMessage } from 'element-plus'
import { getImageUrl } from '@/utils/image'

interface Props {
  productData: any
}

const props = defineProps<Props>()

const emit = defineEmits(['success', 'cancel'])

// 拒绝原因
const rejectReason = ref('')
const submitting = ref(false)

// 处理图片 URL（使用 getImageUrl）
const processedImages = computed(() => {
  if (!props.productData?.images || props.productData.images.length === 0) {
    return []
  }
  return props.productData.images.map((img: string) => getImageUrl(img))
})

// 状态映射
const statusMap = {
  under_review: { type: 'warning' as const, text: '待审核' },
  approved: { type: 'success' as const, text: '已通过' },
  rejected: { type: 'danger' as const, text: '已拒绝' }
}

// 新旧程度映射
const conditionMap = {
  new: '全新',
  '90%': '9成新',
  '80%': '8成新',
  '70%': '7成新',
  '60%': '6成新及以下'
}

// 是否显示审核操作（只有待审核状态可以审核）
const canAudit = computed(() => {
  return props.productData?.status === 'under_review'
})

// 关闭对话框
const handleClose = () => {
  emit('cancel')
}

// 审核通过
const handleApprove = async () => {
  if (submitting.value) return

  try {
    submitting.value = true
    await reviewPendingProductApi(props.productData.id, {
      approved: true
    })
    emit('success')
  } catch (error: any) {
    ElMessage.error(error?.message || '审核失败')
  } finally {
    submitting.value = false
  }
}

// 审核拒绝
const handleReject = async () => {
  if (!rejectReason.value.trim()) {
    ElMessage.warning('请填写拒绝原因')
    return
  }

  if (submitting.value) return

  try {
    submitting.value = true
    await reviewPendingProductApi(props.productData.id, {
      approved: false,
      rejectReason: rejectReason.value.trim()
    })
    emit('success')
  } catch (error: any) {
    ElMessage.error(error?.message || '审核失败')
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="product-audit-dialog">
    <!-- 商品基本信息 -->
    <ElDescriptions :column="2" border>
      <ElDescriptionsItem label="商品标题" :span="2">
        {{ productData?.title }}
      </ElDescriptionsItem>

      <ElDescriptionsItem label="商品状态">
        <div class="status-with-time">
          <ElTag v-if="productData?.status" :type="statusMap[productData.status]?.type">
            {{ statusMap[productData.status]?.text }}
          </ElTag>
          <div v-if="productData?.status === 'approved'" class="audit-time">
            审核时间：{{ new Date(productData?.updatedAt).toLocaleString('zh-CN') }}
          </div>
        </div>
      </ElDescriptionsItem>

      <ElDescriptionsItem label="价格">¥{{ productData?.price }}</ElDescriptionsItem>

      <!-- 拒绝原因（仅拒绝状态显示） -->
      <ElDescriptionsItem v-if="productData?.status === 'rejected'" label="拒绝原因" :span="2">
        <div class="reject-reason-inline">{{ productData.rejectReason }}</div>
      </ElDescriptionsItem>

      <ElDescriptionsItem label="新旧程度">
        {{ conditionMap[productData?.condition] || productData?.condition }}
      </ElDescriptionsItem>

      <!-- <ElDescriptionsItem label="运费">
        {{ productData?.shippingFee > 0 ? `¥${productData.shippingFee}` : '包邮' }}
      </ElDescriptionsItem>

      <ElDescriptionsItem label="是否可议价">
        <ElTag :type="productData?.negotiable ? 'success' : 'info'">
          {{ productData?.negotiable ? '可议价' : '不可议价' }}
        </ElTag>
      </ElDescriptionsItem> -->
    </ElDescriptions>

    <!-- 商品描述 -->
    <div class="section-title" style="margin-top: 20px">商品描述</div>
    <div class="description-content">
      {{ productData?.description || '暂无描述' }}
    </div>

    <!-- 商品图片 -->
    <div class="section-title" style="margin-top: 20px">商品图片</div>
    <div class="images-container">
      <ElImage
        v-for="(img, index) in processedImages"
        :key="index"
        :src="img"
        :preview-src-list="processedImages"
        :initial-index="index"
        fit="cover"
        style="width: 120px; height: 120px"
        preview-teleported
      />
      <span v-if="processedImages.length === 0">暂无图片</span>
    </div>

    <!-- 用户信息 -->
    <div class="section-title" style="margin-top: 20px">发布用户信息</div>
    <ElDescriptions :column="2" border>
      <ElDescriptionsItem label="用户名称">
        {{ productData?.user?.username || '-' }}
      </ElDescriptionsItem>

      <ElDescriptionsItem label="手机号">
        {{ productData?.user?.phone || '-' }}
      </ElDescriptionsItem>

      <ElDescriptionsItem label="用户ID">
        {{ productData?.userId }}
      </ElDescriptionsItem>

      <ElDescriptionsItem label="提交时间">
        {{ new Date(productData?.createdAt).toLocaleString('zh-CN') }}
      </ElDescriptionsItem>
    </ElDescriptions>

    <!-- 审核操作区 -->
    <div v-if="canAudit" class="audit-actions">
      <div class="section-title">审核操作</div>

      <div v-if="!submitting" class="audit-form">
        <div class="reject-reason-field">
          <label class="field-label">拒绝原因（拒绝时必填）</label>
          <ElInput
            v-model="rejectReason"
            type="textarea"
            :rows="3"
            placeholder="请输入拒绝原因"
            maxlength="500"
            show-word-limit
          />
        </div>

        <div class="action-buttons">
          <ElButton type="success" size="large" @click="handleApprove"> 审核通过 </ElButton>
          <ElButton type="danger" size="large" @click="handleReject"> 审核拒绝 </ElButton>
          <ElButton size="large" @click="handleClose"> 取消 </ElButton>
        </div>
      </div>

      <div v-else class="submitting-state">
        <ElIcon class="is-loading" :size="32">
          <Loading />
        </ElIcon>
        <span class="submitting-text">提交中...</span>
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.product-audit-dialog {
  padding: 0;

  .section-title {
    font-size: 16px;
    font-weight: 600;
    color: #303133;
    margin-bottom: 12px;
    padding-left: 12px;
    border-left: 4px solid #409eff;
  }

  // 状态和时间组合
  .status-with-time {
    display: flex;
    flex-direction: row;
    align-items: center;
    gap: 12px;

    .audit-time {
      font-size: 12px;
      color: #67c23a;
      font-weight: 500;
    }
  }

  // 拒绝原因内联显示
  .reject-reason-inline {
    padding: 8px 12px;
    background: #fef0f0;
    border-left: 3px solid #f56c6c;
    border-radius: 4px;
    color: #f56c6c;
    line-height: 1.6;
    white-space: pre-wrap;
    word-break: break-word;
  }

  .description-content {
    padding: 16px;
    background: #f5f7fa;
    border-radius: 8px;
    white-space: pre-wrap;
    word-break: break-word;
    line-height: 1.8;
    color: #606266;
    font-size: 14px;
  }

  .images-container {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;

    :deep(.el-image) {
      border-radius: 8px;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
      transition: transform 0.3s;

      &:hover {
        transform: scale(1.05);
      }
    }
  }

  // 审核操作区
  .audit-actions {
    margin-top: 30px;
    padding: 24px;
    background: #fafafa;
    border-radius: 8px;
    border: 1px solid #e4e7ed;

    .audit-form {
      .reject-reason-field {
        margin-bottom: 20px;

        .field-label {
          display: block;
          margin-bottom: 8px;
          font-weight: 500;
          color: #303133;
          font-size: 14px;
        }

        :deep(.el-textarea) {
          .el-textarea__inner {
            border-radius: 6px;
          }
        }
      }

      .action-buttons {
        display: flex;
        gap: 12px;
        justify-content: center;
        padding-top: 20px;
        border-top: 1px solid #e4e7ed;

        .el-button {
          min-width: 120px;
        }
      }
    }

    .submitting-state {
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 40px 0;
      color: #909399;
      font-size: 16px;

      .submitting-text {
        margin-left: 12px;
      }
    }
  }
}
</style>
