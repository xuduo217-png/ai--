<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { ElButton } from 'element-plus'
import { Refresh } from '@element-plus/icons-vue'
import { ArticleType, getSystemArticleByTypeApi } from '@/api-new/system-articles'
import { loadPrivacyPolicy, type PrivacyPolicyState } from './privacy-policy-state'

const loading = ref(true)
const policyState = ref<PrivacyPolicyState>({
  status: 'empty',
  content: '',
  updatedAt: ''
})

const formattedUpdatedAt = computed(() => {
  if (!policyState.value.updatedAt) {
    return ''
  }

  const updatedAt = new Date(policyState.value.updatedAt)
  if (Number.isNaN(updatedAt.getTime())) {
    return ''
  }

  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  }).format(updatedAt)
})

const fetchPrivacyPolicy = async () => {
  loading.value = true
  policyState.value = await loadPrivacyPolicy(() => getSystemArticleByTypeApi(ArticleType.PRIVACY))
  loading.value = false
}

onMounted(fetchPrivacyPolicy)
</script>

<template>
  <div class="privacy-policy-page">
    <header class="policy-header">
      <div class="policy-header__inner">
        <p class="policy-eyebrow">宠物医院服务平台</p>
        <h1>隐私政策</h1>
        <p class="policy-summary">了解我们如何收集、使用和保护您的个人信息。</p>
      </div>
    </header>

    <main class="policy-main" aria-live="polite" :aria-busy="loading">
      <div v-if="loading" class="policy-loading" role="status">
        <span class="policy-loading__line policy-loading__line--title"></span>
        <span class="policy-loading__line"></span>
        <span class="policy-loading__line"></span>
        <span class="policy-loading__line policy-loading__line--short"></span>
        <span class="sr-only">正在加载隐私政策</span>
      </div>

      <template v-else-if="policyState.status === 'ready'">
        <p v-if="formattedUpdatedAt" class="policy-updated-at">
          最后更新：{{ formattedUpdatedAt }}
        </p>
        <article class="policy-content" v-html="policyState.content"></article>
      </template>

      <section v-else-if="policyState.status === 'error'" class="policy-status">
        <h2>暂时无法加载隐私政策</h2>
        <p>请检查网络连接后重新加载。</p>
        <ElButton type="primary" :icon="Refresh" @click="fetchPrivacyPolicy"> 重新加载 </ElButton>
      </section>

      <section v-else class="policy-status">
        <h2>隐私政策暂未发布</h2>
        <p>管理员发布内容后，此页面将自动更新。</p>
      </section>
    </main>

    <footer class="policy-footer">宠物医院服务平台</footer>
  </div>
</template>

<style scoped lang="less">
.privacy-policy-page {
  height: 100%;
  min-height: 100vh;
  overflow-y: auto;
  background: #f5f7f8;
  color: #1f2933;
}

.policy-header {
  border-bottom: 1px solid #dce4e7;
  background: #ffffff;
}

.policy-header__inner,
.policy-main,
.policy-footer {
  width: min(calc(100% - 40px), 800px);
  margin: 0 auto;
}

.policy-header__inner {
  padding: 56px 0 40px;
}

.policy-eyebrow {
  margin: 0 0 12px;
  color: #087f8c;
  font-size: 14px;
  font-weight: 600;
}

h1 {
  margin: 0;
  color: #172b33;
  font-size: 38px;
  line-height: 1.25;
}

.policy-summary {
  margin: 16px 0 0;
  color: #52646d;
  font-size: 16px;
  line-height: 1.75;
}

.policy-main {
  min-height: 520px;
  padding: 40px 0 64px;
}

.policy-updated-at {
  margin: 0 0 32px;
  color: #60747d;
  font-size: 14px;
}

.policy-content {
  color: #293b43;
  font-size: 16px;
  line-height: 1.9;
  overflow-wrap: anywhere;
}

.policy-content :deep(h1),
.policy-content :deep(h2),
.policy-content :deep(h3) {
  margin: 40px 0 16px;
  color: #172b33;
  line-height: 1.4;
}

.policy-content :deep(h1) {
  font-size: 26px;
}

.policy-content :deep(h2) {
  font-size: 22px;
}

.policy-content :deep(h3) {
  font-size: 18px;
}

.policy-content :deep(p),
.policy-content :deep(ul),
.policy-content :deep(ol) {
  margin: 0 0 18px;
}

.policy-content :deep(a) {
  color: #087f8c;
  text-underline-offset: 3px;
}

.policy-content :deep(img) {
  max-width: 100%;
  height: auto;
}

.policy-content :deep(table) {
  display: block;
  width: 100%;
  overflow-x: auto;
  border-collapse: collapse;
}

.policy-content :deep(th),
.policy-content :deep(td) {
  padding: 10px 12px;
  border: 1px solid #d7e0e3;
  text-align: left;
}

.policy-loading,
.policy-status {
  min-height: 360px;
}

.policy-loading {
  padding-top: 20px;
}

.policy-loading__line {
  display: block;
  width: 100%;
  height: 16px;
  margin-bottom: 18px;
  border-radius: 4px;
  background: #e3e9eb;
  animation: loading-pulse 1.5s ease-in-out infinite;
}

.policy-loading__line--title {
  width: 45%;
  height: 28px;
  margin-bottom: 32px;
}

.policy-loading__line--short {
  width: 68%;
}

.policy-status {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  justify-content: center;
}

.policy-status h2 {
  margin: 0 0 12px;
  color: #172b33;
  font-size: 22px;
}

.policy-status p {
  margin: 0 0 24px;
  color: #52646d;
  font-size: 16px;
  line-height: 1.75;
}

.policy-footer {
  padding: 24px 0 32px;
  border-top: 1px solid #dce4e7;
  color: #60747d;
  font-size: 13px;
  text-align: center;
}

.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

@keyframes loading-pulse {
  0%,
  100% {
    opacity: 0.55;
  }

  50% {
    opacity: 1;
  }
}

@media (max-width: 600px) {
  .policy-header__inner,
  .policy-main,
  .policy-footer {
    width: min(calc(100% - 32px), 800px);
  }

  .policy-header__inner {
    padding: 40px 0 32px;
  }

  h1 {
    font-size: 32px;
  }

  .policy-main {
    min-height: 460px;
    padding: 32px 0 48px;
  }
}

@media (prefers-reduced-motion: reduce) {
  .policy-loading__line {
    animation: none;
  }
}
</style>
