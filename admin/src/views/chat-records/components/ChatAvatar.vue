<template>
  <div :class="['chat-avatar', `chat-avatar--${type}`]" :style="avatarStyle">
    <img
      v-if="avatarUrl && !loadError"
      :src="avatarUrl"
      :alt="`${type} avatar`"
      class="chat-avatar__image"
      @error="handleImageError"
    />
    <div v-else class="chat-avatar__fallback">
      <el-icon :size="20">
        <UserFilled v-if="type === 'user'" />
        <Avatar v-else />
      </el-icon>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { UserFilled, Avatar } from '@element-plus/icons-vue'

/**
 * 聊天头像组件
 * 支持头像加载失败时显示备用图标
 */
interface Props {
  /** 头像类型：user（用户）或 doctor（医生） */
  type: 'user' | 'doctor'
  /** 头像 URL */
  avatarUrl?: string
  /** 头像尺寸（像素），默认 40px */
  size?: number
}

const props = withDefaults(defineProps<Props>(), {
  avatarUrl: '',
  size: 40
})

/** 图片加载状态 */
const loadError = ref(false)

/** 头像样式 */
const avatarStyle = computed(() => ({
  width: `${props.size}px`,
  height: `${props.size}px`
}))

/**
 * 处理图片加载错误
 * 显示备用图标
 */
const handleImageError = () => {
  loadError.value = true
}

// 监听 avatarUrl 变化，重置加载状态
const { avatarUrl } = toRefs(props)
watch(avatarUrl, () => {
  loadError.value = false
})
</script>

<script lang="ts">
import { toRefs, watch } from 'vue'
export default {
  name: 'ChatAvatar'
}
</script>

<style lang="less" scoped>
.chat-avatar {
  border-radius: 50%;
  overflow: hidden;
  flex-shrink: 0;
  position: relative;
  transition: all 0.2s ease;
  cursor: default;

  /** 头像悬停效果：放大 + 光晕 */
  &:hover {
    transform: scale(1.1);
    box-shadow: 0 0 12px rgba(64, 158, 255, 0.4);
  }

  /** 医生头像：白色边框 */
  &--doctor {
    border: 2px solid #ffffff;
  }

  &__image {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }

  &__fallback {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #ffffff;

    /** 用户头像备用渐变 */
    .chat-avatar--user & {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    }

    /** 医生头像备用渐变 */
    .chat-avatar--doctor & {
      background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
    }
  }
}
</style>
