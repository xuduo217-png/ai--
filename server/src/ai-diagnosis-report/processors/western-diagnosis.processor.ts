import { Processor, Process } from '@nestjs/bull';
import { Logger, Inject } from '@nestjs/common';
import { Job } from 'bull';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { HttpService } from '@nestjs/axios';
import {
  diagnosisComplete,
  diagnosisResult,
  requestDiagnosis,
} from './diagnosis-response';
import { AiDiagnosisReport } from '../entities/ai-diagnosis-report.entity';
import { WESTERN_DIAGNOSIS_QUEUE } from '../queues/western-diagnosis.queue';
import { AiDiagnosisLoggerService } from '../logger/ai-diagnosis-logger.service';

/**
 * 西医诊断队列处理器
 * 调用第三方西医诊断接口并保存结果
 */
@Processor(WESTERN_DIAGNOSIS_QUEUE)
export class WesternDiagnosisProcessor {
  private readonly logger = new Logger(WesternDiagnosisProcessor.name);

  constructor(
    @InjectRepository(AiDiagnosisReport)
    private readonly reportRepository: Repository<AiDiagnosisReport>,
    private readonly httpService: HttpService,
    @Inject(AiDiagnosisLoggerService)
    private readonly aiDiagnosisLogger: AiDiagnosisLoggerService,
  ) {}

  /**
   * 处理西医诊断任务
   * 调用第三方 API 并保存结果
   * 任务名称: 'diagnose'（与 service 中添加任务时指定的名称一致）
   */
  @Process('diagnose')
  async handleDiagnosis(job: Job<{ reportId: number; symptoms: string }>) {
    const { reportId, symptoms } = job.data;
    const startTime = Date.now();

    this.logger.log(`开始处理西医诊断任务: reportId=${reportId}`);

    // 记录任务开始
    await this.aiDiagnosisLogger.logInfo(
      reportId,
      'WESTERN',
      '西医诊断任务开始',
      {
        jobId: job.id,
        symptoms:
          symptoms.substring(0, 100) + (symptoms.length > 100 ? '...' : ''),
        symptomsLength: symptoms.length,
      },
    );

    try {
      // 获取 AI 诊断接口配置
      const baseUrl =
        process.env.AI_DIAGNOSIS_BASE_URL || 'http://152.32.128.33:18082';
      const timeout = parseInt(process.env.AI_DIAGNOSIS_TIMEOUT || '30000', 10);
      const apiUrl = `${baseUrl}/api/v1/vet/diagnose`;

      // 记录 API 调用开始
      await this.aiDiagnosisLogger.logInfo(
        reportId,
        'WESTERN',
        '准备调用第三方 API',
        {
          apiUrl,
          timeout: `${timeout}ms`,
        },
      );

      // 调用第三方西医诊断接口
      const requestData = {
        description: symptoms,
      };

      const previous = await this.reportRepository.findOne({
        where: { id: reportId },
      });
      const data = await requestDiagnosis(
        this.httpService,
        apiUrl,
        requestData,
        timeout,
        true,
        async (progress) => {
          await this.reportRepository.update(reportId, {
            westernDiagnosis: progress,
          });
        },
        previous?.westernDiagnosis,
      );

      const duration = Date.now() - startTime;

      this.logger.log(`西医诊断成功: reportId=${reportId}, 耗时=${duration}ms`);

      // 记录 API 调用成功
      await this.aiDiagnosisLogger.logApiCall(
        reportId,
        'WESTERN',
        apiUrl,
        requestData,
        data,
        duration,
      );

      // 更新报告状态和结果
      await this.reportRepository.update(reportId, {
        westernDiagnosis: diagnosisResult(data, true), // 保留增量评估和接口声明
        westernJobId: job.id.toString(),
      });

      // 记录数据库更新成功
      await this.aiDiagnosisLogger.logSuccess(
        reportId,
        'WESTERN',
        '西医诊断结果已保存到数据库',
        {
          jobId: job.id.toString(),
          hasDiagnosis: !!data,
          duration: `${duration}ms`,
        },
      );

      // 尝试完成报告（如果两个诊断都成功）
      await this.tryCompleteReport(reportId);

      return { success: true, data };
    } catch (error) {
      const duration = Date.now() - startTime;
      this.logger.error(
        `西医诊断失败: reportId=${reportId}, error=${error.message}`,
      );

      // 记录错误
      await this.aiDiagnosisLogger.logError(
        reportId,
        'WESTERN',
        '西医诊断失败',
        error,
        {
          duration: `${duration}ms`,
          jobAttempts: job.attemptsMade,
        },
      );

      // 标记西医诊断失败
      await this.markWesternFailed(reportId, error.message);

      throw error; // 抛出错误以触发重试
    }
  }

  /**
   * 尝试完成报告（两个诊断都成功）
   */
  private async tryCompleteReport(reportId: number) {
    const report = await this.reportRepository.findOne({
      where: { id: reportId },
    });

    if (
      report &&
      diagnosisComplete(report.westernDiagnosis) &&
      diagnosisComplete(report.tcmDiagnosis)
    ) {
      await this.reportRepository.update(reportId, {
        status: 'COMPLETED',
        completedAt: new Date(),
      });
      this.logger.log(`报告已完成: reportId=${reportId}`);
    }
  }

  /**
   * 标记西医诊断失败
   * 立即将报告标记为失败状态，避免前端长时间轮询
   */
  private async markWesternFailed(reportId: number, errorMessage: string) {
    try {
      this.logger.log(`开始标记西医诊断失败: reportId=${reportId}`);

      const report = await this.reportRepository.findOne({
        where: { id: reportId },
      });

      if (!report) {
        this.logger.error(`报告不存在，无法标记失败: reportId=${reportId}`);
        return;
      }

      const updates: Partial<AiDiagnosisReport> = {
        errorMessage: errorMessage,
        failureReason: 'WESTERN_FAILED',
        retryCount: report.retryCount + 1,
        status: 'FAILED', // 立即标记为失败，让前端停止轮询
      };

      // 如果中医也已经失败，则更新失败原因
      if (!report.tcmDiagnosis) {
        updates.failureReason = 'BOTH_FAILED';
      }

      await this.reportRepository.update(reportId, updates);

      this.logger.error(
        `✅ 西医诊断失败，报告已标记为失败: reportId=${reportId}, status=${updates.status}, reason=${updates.failureReason}`,
      );
    } catch (error) {
      this.logger.error(
        `❌ 标记西医诊断失败时出错: reportId=${reportId}, error=${error.message}`,
        error.stack,
      );
    }
  }
}
