import { PartialType, OmitType } from '@nestjs/mapped-types';
import { CreateListDto } from './create-list.dto';

/**
 * 更新自查表 DTO
 * 不允许修改 type 字段
 */
export class UpdateListDto extends PartialType(
  OmitType(CreateListDto, ['type'] as const),
) {}
