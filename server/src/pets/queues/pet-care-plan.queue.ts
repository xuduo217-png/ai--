import { Queue } from 'bull';
import { InjectQueue } from '@nestjs/bull';

/**
 * 宠物护理计划队列名称
 */
export const PET_CARE_PLAN_QUEUE = 'pet-care-plan';

/**
 * 宠物护理计划队列注入 Token
 */
export const PET_CARE_PLAN_QUEUE_TOKEN = 'BULL_QUEUE:PET_CARE_PLAN';
