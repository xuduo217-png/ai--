import { Queue } from 'bull';
import { InjectQueue } from '@nestjs/bull';

/**
 * 西医诊断队列配置
 * 用于处理西医诊断的异步任务
 */
export const WESTERN_DIAGNOSIS_QUEUE = 'western-diagnosis';

/**
 * 西医诊断队列注入 Token
 */
export const WESTERN_DIAGNOSIS_QUEUE_TOKEN = 'BULL_QUEUE:WESTERN_DIAGNOSIS';
