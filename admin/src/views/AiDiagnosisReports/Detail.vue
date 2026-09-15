<template>
  <ContentWrap>
    <div v-if="loading" class="flex justify-center py-8">
      <el-icon class="is-loading" :size="32"><Loading /></el-icon>
    </div>

    <div v-else-if="report" class="report-detail">
      <!-- 返回按钮 -->
      <div class="mb-4">
        <ElButton @click="handleBack">
          <el-icon><ArrowLeft /></el-icon>
          返回列表
        </ElButton>
      </div>

      <!-- 基础信息卡片 -->
      <el-card class="mb-4" shadow="never">
        <template #header>
          <div class="card-header">
            <span class="text-lg font-semibold">基础信息</span>
            <el-tag :type="statusType" size="large">{{ statusText }}</el-tag>
          </div>
        </template>
        <el-descriptions :column="3" border>
          <el-descriptions-item label="报告 ID">{{ report.id }}</el-descriptions-item>
          <el-descriptions-item label="宠物名称">
            <span class="font-medium">{{ report.petName }}</span>
          </el-descriptions-item>
          <el-descriptions-item label="用户手机号">{{ report.userPhone }}</el-descriptions-item>
          <el-descriptions-item label="创建时间">{{ report.createdAt }}</el-descriptions-item>
          <el-descriptions-item label="完成时间">
            <span :class="report.completedAt ? 'text-success' : 'text-warning'">
              {{ report.completedAt || '未完成' }}
            </span>
          </el-descriptions-item>
          <el-descriptions-item label="重试次数">
            <el-tag v-if="report.retryCount > 0" type="warning" size="small">
              已重试 {{ report.retryCount }} 次
            </el-tag>
            <span v-else class="text-gray-400">无需重试</span>
          </el-descriptions-item>
        </el-descriptions>
      </el-card>

      <!-- 症状描述卡片 -->
      <el-card v-if="report.symptoms" class="mb-4" shadow="never">
        <template #header>
          <span class="text-lg font-semibold">症状描述</span>
        </template>
        <div class="symptoms-content bg-blue-50 p-4 rounded">
          <p class="text-gray-700 leading-relaxed">{{ report.symptoms }}</p>
        </div>
      </el-card>

      <!-- 自查表答案卡片 -->
      <el-card
        v-if="report.selfCheckSnapshot && report.selfCheckSnapshot.length > 0"
        class="mb-4"
        shadow="never"
      >
        <template #header>
          <span class="text-lg font-semibold">自查表答案</span>
        </template>
        <el-collapse>
          <el-collapse-item
            v-for="list in report.selfCheckSnapshot"
            :key="list.listId"
            :title="list.listName"
          >
            <div class="checklist-content">
              <div
                v-for="question in list.questions"
                :key="question.questionId"
                class="mb-4 last:mb-0"
              >
                <div class="question-item">
                  <p class="font-medium mb-2">{{ question.questionText }}</p>
                  <div v-if="question.questionType !== 'TEXT'" class="options-grid">
                    <div
                      v-for="option in question.options"
                      :key="option.optionId"
                      :class="['option-tag', option.selected ? 'selected' : '']"
                    >
                      {{ option.optionText }}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </el-collapse-item>
        </el-collapse>
      </el-card>

      <!-- 诊断结果 Tab 区域 -->
      <div v-if="report.westernDiagnosis || report.tcmDiagnosis" class="diagnosis-tabs-wrapper">
        <el-tabs v-model="activeTab" type="card" class="diagnosis-tabs" @tab-click="handleTabClick">
          <!-- 西医诊断 Tab -->
          <el-tab-pane v-if="report.westernDiagnosis" label="西医诊断" name="western">
            <!-- 概率图表 -->
            <div
              v-if="
                report.westernDiagnosis.diagnosis && report.westernDiagnosis.diagnosis.length > 0
              "
              class="chart-section"
            >
              <h4 class="section-title">诊断概率分析</h4>
              <div ref="westernChartRef" class="chart-container"></div>
            </div>

            <!-- 诊断结果和用药建议（按症状分组） -->
            <div class="content-section">
              <h4 class="section-title">诊断结果与用药建议</h4>
              <div
                v-for="(diag, index) in report.westernDiagnosis.diagnosis"
                :key="index"
                class="diagnosis-group western-item"
              >
                <!-- 诊断结果 -->
                <div class="diagnosis-info">
                  <div class="diagnosis-header-row">
                    <span class="diagnosis-name">{{ diag.symptom }}</span>
                    <el-tag :type="getProbabilityType(diag.probability)" size="small">
                      {{ (diag.probability * 100).toFixed(1) }}%
                    </el-tag>
                  </div>
                  <p class="diagnosis-reason">
                    <el-icon class="text-blue-500"><InfoFilled /></el-icon>
                    {{ diag.reason }}
                  </p>
                </div>

                <!-- 对应该症状的用药建议 -->
                <div v-if="getMedicationsBySymptom(diag.symptom)" class="medication-section">
                  <h6 class="medication-title">用药建议</h6>
                  <el-table
                    :data="getMedicationsBySymptom(diag.symptom)"
                    border
                    stripe
                    style="width: 100%"
                  >
                    <el-table-column prop="drug_name" label="药物名称" min-width="120" />
                    <el-table-column prop="dosage" label="剂量" min-width="120" />
                    <el-table-column prop="frequency" label="给药频率" min-width="100" />
                  </el-table>
                </div>
              </div>
            </div>
          </el-tab-pane>

          <!-- 中医诊断 Tab -->
          <el-tab-pane v-if="report.tcmDiagnosis" label="中医诊断" name="tcm">
            <!-- 证候概率图表 -->
            <div
              v-if="report.tcmDiagnosis.data && report.tcmDiagnosis.data.length > 0"
              class="chart-section"
            >
              <h4 class="section-title">证候概率分析</h4>
              <div ref="tcmChartRef" class="chart-container"></div>
            </div>

            <!-- 证候列表 -->
            <div class="content-section">
              <h4 class="section-title">证候诊断</h4>
              <div
                v-for="(item, index) in report.tcmDiagnosis.data"
                :key="index"
                class="diagnosis-group tcm-item"
              >
                <!-- 证候结果 -->
                <div class="diagnosis-info">
                  <div class="diagnosis-header-row">
                    <span class="diagnosis-name">{{ item.zhengming }}</span>
                    <el-tag :type="getProbabilityType(item.p)" size="small">
                      {{ (item.p * 100).toFixed(1) }}%
                    </el-tag>
                  </div>
                  <p class="diagnosis-reason">
                    <el-icon class="text-orange-500"><InfoFilled /></el-icon>
                    {{ item.description }}
                  </p>
                </div>

                <!-- 治则和基础方剂 -->
                <div class="tcm-therapy-section">
                  <div class="tcm-details">
                    <p><strong>治则：</strong>{{ item.therapy }}</p>
                    <p><strong>基础：</strong>{{ item.base }}</p>
                    <p v-if="item.continue"><strong>继续：</strong>{{ item.continue }}</p>
                    <p v-if="item.suggest"><strong>建议：</strong>{{ item.suggest }}</p>
                  </div>
                  <div v-if="item.base_prescription" class="prescription-box">
                    <p class="prescription-title">基础方剂</p>
                    <p class="prescription-name">{{ item.base_prescription }}</p>
                    <p class="prescription-usage">用法：{{ item.base_prescription_usage }}</p>
                  </div>
                </div>
              </div>
            </div>
          </el-tab-pane>
        </el-tabs>
      </div>

      <!-- 错误信息 -->
      <el-card v-if="report.errorMessage" class="error-card" shadow="never">
        <template #header>
          <span class="text-red-500 font-semibold">错误信息</span>
        </template>
        <p class="text-red-600">{{ report.errorMessage }}</p>
      </el-card>
    </div>
  </ContentWrap>
</template>

<script setup lang="ts">
import { ref, computed, nextTick, onUnmounted, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ContentWrap } from '@/components/ContentWrap'
import { Loading, InfoFilled, ArrowLeft } from '@element-plus/icons-vue'
import {
  ElMessage,
  ElTabs,
  ElTabPane,
  ElTable,
  ElTableColumn,
  ElCard,
  ElCollapse,
  ElCollapseItem,
  ElDescriptions,
  ElDescriptionsItem,
  ElTag,
  ElIcon,
  ElButton
} from 'element-plus'
import {
  getAiDiagnosisReportDetailApi,
  type AiDiagnosisReport
} from '@/api-new/ai-diagnosis-reports'
import * as echarts from 'echarts'
import type { EChartsOption } from 'echarts'

defineOptions({
  name: 'AiDiagnosisReportDetail'
})

const route = useRoute()
const router = useRouter()

const loading = ref(false)
const report = ref<AiDiagnosisReport>()
const activeTab = ref('western')
const westernChartRef = ref<HTMLElement>()
const tcmChartRef = ref<HTMLElement>()
let westernChart: any = null
let tcmChart: any = null

/**
 * 返回列表
 */
const handleBack = () => {
  router.back()
}

/**
 * 获取指定症状的用药建议
 */
const getMedicationsBySymptom = (symptom: string) => {
  if (!report.value?.westernDiagnosis?.medications) return null

  return report.value.westernDiagnosis.medications.filter((med: any) => {
    return med.symptom === symptom
  })
}

const statusText = computed(() => {
  const map: Record<string, string> = {
    PENDING: '待生成',
    PROCESSING: '生成中',
    COMPLETED: '已完成',
    FAILED: '失败',
    TIMEOUT: '超时'
  }
  const status = report.value?.status
  return status ? map[status] : status
})

const statusType = computed(() => {
  const map: Record<string, any> = {
    PENDING: 'info',
    PROCESSING: 'warning',
    COMPLETED: 'success',
    FAILED: 'danger',
    TIMEOUT: 'danger'
  }
  const status = report.value?.status
  return status ? map[status] : 'info'
})

// 获取概率标签类型
const getProbabilityType = (probability: number) => {
  if (probability >= 0.9) return 'danger'
  if (probability >= 0.7) return 'warning'
  if (probability >= 0.5) return 'success'
  return 'info'
}

// Tab 切换事件
const handleTabClick = (tab: any) => {
  const tabName = tab.paneName || tab.name

  // 等待 DOM 更新后渲染对应的图表
  nextTick(() => {
    if (tabName === 'western') {
      renderWesternChart()
      // 调用 resize 确保图表正确显示
      setTimeout(() => {
        westernChart?.resize()
      }, 100)
    } else if (tabName === 'tcm') {
      renderTcmChart()
      // 调用 resize 确保图表正确显示
      setTimeout(() => {
        tcmChart?.resize()
      }, 100)
    }
  })
}

// 渲染西医诊断图表
const renderWesternChart = () => {
  if (!westernChartRef.value || !report.value?.westernDiagnosis?.diagnosis) return

  // 延迟一帧确保 DOM 完全渲染
  setTimeout(() => {
    if (!westernChart && westernChartRef.value) {
      westernChart = echarts.init(westernChartRef.value)
    }

    if (!westernChart || !report.value?.westernDiagnosis?.diagnosis) return

    const diagnosis = report.value.westernDiagnosis.diagnosis
    const data = diagnosis.map((d: any) => ({
      name: d.symptom,
      value: Number((d.probability * 100).toFixed(1))
    }))

    const option: EChartsOption = {
      tooltip: {
        trigger: 'axis',
        axisPointer: { type: 'shadow' },
        formatter: '{b}: {c}%'
      },
      grid: {
        left: '3%',
        right: '4%',
        bottom: '3%',
        containLabel: true
      },
      xAxis: {
        type: 'category',
        data: data.map((d: any) => d.name),
        axisLabel: {
          interval: 0,
          rotate: 30,
          fontSize: 12
        }
      },
      yAxis: {
        type: 'value',
        max: 100,
        axisLabel: {
          formatter: '{value}%'
        }
      },
      series: [
        {
          name: '诊断概率',
          type: 'bar',
          data: data.map((d: any) => ({
            value: d.value,
            itemStyle: {
              color: d.value >= 70 ? '#409EFF' : '#67C23A'
            }
          })),
          barWidth: '50%',
          label: {
            show: true,
            position: 'top',
            formatter: '{c}%',
            fontSize: 12
          }
        }
      ]
    }

    westernChart.setOption(option)
  }, 100)
}

// 渲染中医诊断图表
const renderTcmChart = () => {
  if (!tcmChartRef.value || !report.value?.tcmDiagnosis?.data) return

  // 延迟一帧确保 DOM 完全渲染
  setTimeout(() => {
    if (!tcmChart && tcmChartRef.value) {
      tcmChart = echarts.init(tcmChartRef.value)
    }

    if (!tcmChart || !report.value?.tcmDiagnosis?.data) return

    const data = report.value.tcmDiagnosis.data.map((item: any) => ({
      name: item.zhengming,
      value: Number((item.p * 100).toFixed(1))
    }))

    const option: EChartsOption = {
      tooltip: {
        trigger: 'axis',
        axisPointer: { type: 'shadow' },
        formatter: '{b}: {c}%'
      },
      grid: {
        left: '3%',
        right: '4%',
        bottom: '3%',
        containLabel: true
      },
      xAxis: {
        type: 'category',
        data: data.map((d: any) => d.name),
        axisLabel: {
          interval: 0,
          rotate: 30,
          fontSize: 12
        }
      },
      yAxis: {
        type: 'value',
        max: 100,
        axisLabel: {
          formatter: '{value}%'
        }
      },
      series: [
        {
          name: '证候概率',
          type: 'bar',
          data: data.map((d: any) => ({
            value: d.value,
            itemStyle: {
              color: d.value >= 70 ? '#E6A23C' : '#F56C6C'
            }
          })),
          barWidth: '50%',
          label: {
            show: true,
            position: 'top',
            formatter: '{c}%',
            fontSize: 12
          }
        }
      ]
    }

    tcmChart.setOption(option)
  }, 100)
}

// 加载报告详情
const loadReport = async () => {
  const reportId = route.params.id as string
  if (!reportId) return

  loading.value = true
  activeTab.value = 'western'

  try {
    const res = await getAiDiagnosisReportDetailApi(Number(reportId))
    report.value = res.data

    // 等待 DOM 更新后渲染当前 tab 的图表
    await nextTick()
    setTimeout(() => {
      renderWesternChart()
    }, 300)
  } catch (error) {
    ElMessage.error('加载报告详情失败')
    console.error('加载报告详情失败:', error)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  loadReport()
})

// 清理图表实例
onUnmounted(() => {
  westernChart?.dispose()
  tcmChart?.dispose()
})
</script>

<style scoped lang="scss">
.report-detail {
  padding: 0;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.symptoms-content {
  line-height: 1.8;
}

.checklist-content {
  padding: 12px 0;

  .question-item {
    margin-bottom: 16px;

    &:last-child {
      margin-bottom: 0;
    }
  }

  .options-grid {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }

  .option-tag {
    padding: 6px 12px;
    border-radius: 4px;
    background-color: #f5f7fa;
    color: #909399;
    border: 1px solid #dcdfe6;

    &.selected {
      background-color: #ecf5ff;
      color: #409eff;
      border-color: #b3d8ff;
      font-weight: 500;
    }
  }
}

.diagnosis-tabs-wrapper {
  margin-top: 16px;
}

.diagnosis-tabs {
  :deep(.el-tabs__header) {
    margin-bottom: 16px;
    background-color: #fff;
    border-radius: 4px;
  }

  :deep(.el-tabs__nav) {
    border: none;
  }

  :deep(.el-tabs__item) {
    border: 1px solid #dcdfe6;
    border-bottom: none;
    margin-right: 4px;

    &:hover {
      color: #409eff;
    }

    &.is-active {
      background-color: #fff;
      border-color: #409eff;
      color: #409eff;
    }
  }

  :deep(.el-tabs__content) {
    overflow: visible;
  }

  :deep(.el-tab-pane) {
    padding: 0;
  }
}

.chart-section {
  margin-bottom: 24px;
  padding: 20px;
  background-color: #fff;
  border-radius: 4px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
}

.content-section {
  margin-bottom: 24px;
  padding: 20px;
  background-color: #fff;
  border-radius: 4px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);

  &:last-child {
    margin-bottom: 0;
  }
}

.section-title {
  font-size: 16px;
  font-weight: 600;
  margin-bottom: 16px;
  padding-bottom: 8px;
  border-bottom: 2px solid #f0f0f0;
  color: #303133;
}

.chart-container {
  width: 100%;
  height: 400px;
  background-color: #fff;
  border-radius: 4px;
}

.diagnosis-list {
  margin-bottom: 24px;

  &:last-child {
    margin-bottom: 0;
  }
}

.diagnosis-group {
  padding: 20px;
  margin-bottom: 24px;
  border-radius: 8px;
  background: linear-gradient(135deg, #f0f9ff 0%, #ffffff 100%);
  border: 1px solid #e1f0ff;
  box-shadow: 0 2px 8px rgba(64, 158, 255, 0.08);

  &:last-child {
    margin-bottom: 0;
  }
}

.western-item {
  border-left-color: #409eff;
}

.tcm-item {
  border-left-color: #e6a23c;
  background: linear-gradient(135deg, #fff9f0 0%, #ffffff 100%);
  border: 1px solid #ffe6cc;
  box-shadow: 0 2px 8px rgba(230, 162, 60, 0.08);
}

.diagnosis-info {
  margin-bottom: 16px;

  &:last-child {
    margin-bottom: 0;
  }
}

.medication-section {
  padding-left: 16px;
  border-left: 2px solid #e1f0ff;
}

.medication-title {
  font-size: 14px;
  font-weight: 600;
  color: #409eff;
  margin-bottom: 12px;
}

.tcm-therapy-section {
  padding-left: 16px;
  border-left: 2px solid #ffe6cc;
}

.diagnosis-header-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}

.diagnosis-name {
  font-size: 16px;
  font-weight: 600;
  color: #303133;
}

.diagnosis-reason {
  color: #606266;
  line-height: 1.6;
  display: flex;
  align-items: flex-start;
  gap: 6px;
}

.tcm-details {
  margin-top: 12px;
  padding: 12px;
  background-color: #fff9f0;
  border-radius: 4px;

  p {
    margin: 8px 0;
    color: #606266;
    line-height: 1.6;

    &:first-child {
      margin-top: 0;
    }

    &:last-child {
      margin-bottom: 0;
    }

    strong {
      color: #e6a23c;
      margin-right: 8px;
    }
  }
}

.prescription-box {
  margin-top: 16px;
  padding: 16px;
  background: linear-gradient(135deg, #fff9f0 0%, #fff 100%);
  border-radius: 8px;
  border: 1px solid #e6a23c;

  .prescription-title {
    font-size: 14px;
    color: #909399;
    margin-bottom: 8px;
  }

  .prescription-name {
    font-size: 16px;
    font-weight: 600;
    color: #e6a23c;
    margin-bottom: 8px;
  }

  .prescription-usage {
    font-size: 14px;
    color: #606266;
    line-height: 1.6;
  }
}

.error-card {
  border: 2px solid #f56c6c;
  background-color: #fef0f0;
}
</style>
