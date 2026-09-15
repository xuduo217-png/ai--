<script setup lang="ts">
import { ref, watch } from 'vue'
import { ElInput, ElButton, ElRadioGroup, ElRadio, ElMessage } from 'element-plus'
import { getUserList, getUserDetail } from '../../api-new/users/users'
import { UserRole } from '../../api-new/users/types'

const props = defineProps<{
  modelValue?: number
  placeholder?: string
  currentOwner?: any // 当前选中的拥有者信息（用于编辑模式回填）
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: number): void
}>()

const phone = ref('')
const searchResults = ref<any[]>([])
const selectedUserId = ref<number | undefined>(props.modelValue)
const loading = ref(false)
const hasSearched = ref(false)

// 添加调试日志
console.log('OwnerSelect 初始化:', {
  modelValue: props.modelValue,
  currentOwner: props.currentOwner
})

/**
 * 根据 ownerId 加载用户信息（编辑模式）
 */
const loadOwnerById = async (ownerId: number) => {
  console.log('开始加载拥有者信息，ID:', ownerId)
  loading.value = true
  try {
    // 使用 getUserDetail API 直接获取用户详情
    const res = await getUserDetail(ownerId)
    console.log('getUserDetail 响应:', res)

    // axios 响应拦截器返回完整响应对象，需要访问 data 属性
    const user = res.data
    if (user) {
      searchResults.value = [user]
      hasSearched.value = true
      selectedUserId.value = ownerId
      // 自动填充手机号
      phone.value = user.phone || ''
      console.log('拥有者信息加载成功:', user)
    } else {
      console.warn('getUserDetail 返回的 data 为空')
    }
  } catch (error) {
    console.error('加载拥有者信息失败:', error)
  } finally {
    loading.value = false
  }
}

// 监听 modelValue 变化，有值就加载用户信息
watch(
  () => props.modelValue,
  (newVal) => {
    console.log('modelValue changed:', newVal, 'hasSearched:', hasSearched.value)
    selectedUserId.value = newVal

    // 如果有 ownerId 且没有搜索结果，自动加载
    if (newVal && !hasSearched.value) {
      loadOwnerById(newVal)
    }
  },
  { immediate: true }
)

// 可选：如果有 currentOwner prop，直接使用（优化性能）
watch(
  () => props.currentOwner,
  (owner) => {
    console.log('currentOwner changed:', owner)
    if (owner && owner.id && !hasSearched.value) {
      searchResults.value = [owner]
      hasSearched.value = true
      selectedUserId.value = owner.id
      phone.value = owner.phone || ''
    }
  },
  { immediate: true }
)

/**
 * 搜索用户
 */
const handleSearch = async () => {
  if (!phone.value.trim()) {
    ElMessage.warning('请输入手机号')
    return
  }

  loading.value = true
  try {
    const res = await getUserList({
      page: 1,
      pageSize: 10,
      phone: phone.value.trim(),
      role: UserRole.USER
    })

    // 后端响应的 data 直接是数组
    searchResults.value = res.data || []
    hasSearched.value = true

    if (searchResults.value.length === 0) {
      ElMessage.info('未找到该手机号对应的用户')
    }
  } catch (error) {
    ElMessage.error('搜索失败，请稍后重试')
  } finally {
    loading.value = false
  }
}

// 监听选中值变化，同步到 v-model
watch(selectedUserId, (newVal) => {
  emit('update:modelValue', newVal as number)
})
</script>

<template>
  <div class="owner-select">
    <div class="search-box">
      <ElInput v-model="phone" :placeholder="placeholder" clearable @keyup.enter="handleSearch" />
      <ElButton type="primary" :loading="loading" @click="handleSearch" style="margin-left: 8px">
        搜索
      </ElButton>
    </div>

    <div v-if="hasSearched" class="result-list">
      <div v-if="searchResults.length > 0">
        <ElRadioGroup v-model="selectedUserId">
          <div v-for="user in searchResults" :key="user.id" class="user-item">
            <ElRadio :label="user.id">
              <span class="user-name">{{ user.username }}</span>
              <span class="user-phone">{{ user.phone }}</span>
            </ElRadio>
          </div>
        </ElRadioGroup>
      </div>
      <div v-else class="no-result">未找到用户</div>
    </div>
  </div>
</template>

<style scoped lang="less">
.owner-select {
  .search-box {
    display: flex;
    margin-bottom: 12px;
  }

  .result-list {
    border: 1px solid #dcdfe6;
    border-radius: 4px;
    padding: 8px;
    max-height: 200px;
    overflow-y: auto;
  }

  .user-item {
    padding: 8px 0;
    border-bottom: 1px solid #f0f0f0;

    &:last-child {
      border-bottom: none;
    }

    .user-name {
      font-weight: 500;
      margin-right: 12px;
    }

    .user-phone {
      color: #909399;
      font-size: 14px;
    }
  }

  .no-result {
    color: #909399;
    text-align: center;
    padding: 20px 0;
  }
}
</style>
