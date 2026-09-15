import { PartialType, OmitType } from '@nestjs/mapped-types';
import { CreateQuestionDto } from './create-question.dto';

/**
 * 更新问题 DTO
 * 不允许修改 listId 字段
 */
export class UpdateQuestionDto extends PartialType(
  OmitType(CreateQuestionDto, ['listId'] as const),
) {}
