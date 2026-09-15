import { Processor, Process, OnQueueActive, OnQueueCompleted, OnQueueFailed } from '@nestjs/bull';
import { BadGatewayException, Logger } from '@nestjs/common';
import { Job } from 'bull';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PET_CARE_PLAN_QUEUE } from '../queues';
import { Pet } from '../entities/pet.entity';

const DEFAULT_AI_DIAGNOSIS_BASE_URL = 'http://129.204.9.209:18082';

/**
 * 宠物护理计划队列处理器
 * 负责处理护理计划的异步生成任务
 */
@Processor(PET_CARE_PLAN_QUEUE)
export class PetCarePlanProcessor {
  private readonly logger = new Logger(PetCarePlanProcessor.name);

  constructor(
    @InjectRepository(Pet)
    private readonly petRepository: Repository<Pet>,
    private readonly httpService: HttpService,
  ) { }

  /**
   * 处理护理计划生成任务
   */
  @Process('generate')
  async handleGenerate(job: Job) {
    const { petId, params } = job.data;

    this.logger.log(`[护理计划] 开始处理宠物 ${petId} 的护理计划生成任务`);

    try {
      // 1. 调用 AI 接口
      const response = await this.callPetCarePlanAPI(params);

      // 2. 验证响应数据
      if (
        !response.data ||
        !response.data.nutrition_plan ||
        !response.data.care_plan
      ) {
        throw new BadGatewayException('AI 接口返回数据格式错误');
      }

      // 3. 更新宠物护理计划
      await this.petRepository.update(petId, {
        carePlan: response.data,
        carePlanStatus: 'COMPLETED',
        carePlanGeneratedAt: new Date(),
        carePlanError: null,
      });

      this.logger.log(`[护理计划] 宠物 ${petId} 护理计划生成成功`);

      return { success: true, petId };
    } catch (error) {
      // 4. 错误处理
      const errorMessage = this.classifyError(error);

      await this.petRepository.update(petId, {
        carePlanStatus: 'FAILED',
        carePlanError: errorMessage,
      });

      this.logger.error(`[护理计划] 宠物 ${petId} 生成失败: ${errorMessage}`);

      throw error; // 触发 Bull 重试机制
    }
  }

  /**
   * 调用宠物护理计划 AI 接口
   * POST /api/v1/pet-care/plan
   */
  private async callPetCarePlanAPI(params: any): Promise<any> {
    // 统一读取 AI 服务配置，生产环境可通过环境变量覆盖默认地址。
    const baseUrl =
      process.env.AI_DIAGNOSIS_BASE_URL || DEFAULT_AI_DIAGNOSIS_BASE_URL;
    const timeout = parseInt(process.env.AI_DIAGNOSIS_TIMEOUT || '30000', 10);
    const apiUrl = `${baseUrl}/api/v1/pet-care/plan`;

    try {
      // 保留 Axios 原始错误，便于 classifyError 精准识别 ETIMEDOUT/ECONNREFUSED 等网络异常。
      const { data } = await firstValueFrom(
        this.httpService.post(apiUrl, params, {
          timeout,
          headers: {
            'Content-Type': 'application/json',
          },
        }),
      );

      return data;
    } catch (error) {
      this.logger.error('[护理计划] AI 接口调用异常', error.stack);
      throw error;
    }
  }

  /**
   * 错误分类和消息格式化
   */
  private classifyError(error: any): string {
    // AI 接口超时
    if (
      error.code === 'ECONNABORTED' ||
      error.code === 'ETIMEDOUT' ||
      error.cause?.code === 'ETIMEDOUT' ||
      error.message?.includes('timeout') ||
      error.message?.includes('ETIMEDOUT')
    ) {
      return 'AI 服务响应超时，请稍后重试';
    }

    // AI 接口返回错误
    if (error.response?.data?.message) {
      return error.response.data.message;
    }

    // 网络错误
    if (
      error.code === 'ECONNREFUSED' ||
      error.code === 'ECONNRESET' ||
      error.cause?.code === 'ECONNREFUSED' ||
      error.cause?.code === 'ECONNRESET'
    ) {
      return '无法连接到 AI 服务';
    }

    // 数据格式错误
    if (error.message?.includes('数据格式错误')) {
      return error.message;
    }

    // 默认错误
    return error.message || '未知错误';
  }

  /**
   * 任务激活时
   */
  @OnQueueActive()
  onActive(job: Job) {
    this.logger.log(`[护理计划] 任务 ${job.id} 正在处理中...`);
  }

  /**
   * 任务完成时
   */
  @OnQueueCompleted()
  onCompleted(job: Job) {
    this.logger.log(`[护理计划] 任务 ${job.id} 已完成`);
  }

  /**
   * 任务失败时
   */
  @OnQueueFailed()
  onFailed(job: Job, error: Error) {
    this.logger.error(`[护理计划] 任务 ${job.id} 失败: ${error.message}`);
  }
}
