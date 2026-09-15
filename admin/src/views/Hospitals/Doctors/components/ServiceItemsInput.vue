<script setup lang="ts">
import { ref, watch } from 'vue'
import { ElButton, ElInput, ElInputNumber } from 'element-plus'
import type { CreateServiceItemParams } from '@/api-new/doctors'

const props = defineProps<{
  modelValue: CreateServiceItemParams[]
}>()

const emit = defineEmits<{
  'update:modelValue': [value: CreateServiceItemParams[]]
}>()

// 内部数据（默认显示一行）
const items = ref<CreateServiceItemParams[]>([{ name: '', duration: 30, price: 0, isActive: true }])

// 监听外部值变化
watch(
  () => props.modelValue,
  (newVal) => {
    if (newVal && newVal.length > 0) {
      items.value = [...newVal]
    }
  },
  { immediate: true }
)

/**
 * 添加收费项
 */
const addItem = () => {
  items.value.push({
    name: '',
    duration: 30,
    price: 0,
    sortOrder: items.value.length,
    isActive: true
  })
  emitChange()
}

/**
 * 删除收费项
 */
const removeItem = (index: number) => {
  if (items.value.length <= 1) {
    return // 至少保留一项
  }
  items.value.splice(index, 1)
  // 重新计算排序
  items.value.forEach((item, i) => {
    item.sortOrder = i
  })
  emitChange()
}

/**
 * 更新收费项字段
 */
const updateItem = (index: number, field: string, value: any) => {
  items.value[index][field] = value
  emitChange()
}

/**
 * 触发更新
 */
const emitChange = () => {
  emit(
    'update:modelValue',
    items.value.filter((item) => item.name?.trim() !== '')
  )
}
</script>

<template>
  <div class="service-items-input">
    <div v-for="(item, index) in items" :key="index" class="service-item-row">
      <div class="item-fields">
        <div class="field-group">
          <label>服务名称</label>
          <el-input
            :model-value="item.name"
            placeholder="如：图文咨询"
            @input="updateItem(index, 'name', $event)"
          />
        </div>

        <div class="field-group">
          <label>时长（分钟）</label>
          <el-input-number
            :model-value="item.duration"
            :min="1"
            :max="1440"
            @change="updateItem(index, 'duration', $event)"
          />
        </div>

        <div class="field-group">
          <label>价格（元）</label>
          <el-input-number
            :model-value="item.price"
            :min="0"
            :precision="2"
            @change="updateItem(index, 'price', $event)"
          />
        </div>

        <div class="field-actions">
          <el-button
            v-if="items.length > 1"
            type="danger"
            circle
            size="small"
            @click="removeItem(index)"
          >
            删除
          </el-button>
        </div>
      </div>
    </div>

    <el-button type="primary" @click="addItem" class="add-button"> 添加收费项 </el-button>
  </div>
</template>

<style scoped lang="less">
.service-items-input {
  width: 100%;

  .service-item-row {
    margin-bottom: 12px;

    .item-fields {
      display: flex;
      gap: 12px;
      align-items: flex-start;

      .field-group {
        flex: 1;
        display: flex;
        flex-direction: column;
        gap: 4px;

        label {
          font-size: 12px;
          color: #606266;
          font-weight: 500;
        }
      }

      .field-actions {
        display: flex;
        align-items: center;
        padding-top: 20px;
      }
    }
  }

  .add-button {
    width: 100%;
  }
}
</style>
