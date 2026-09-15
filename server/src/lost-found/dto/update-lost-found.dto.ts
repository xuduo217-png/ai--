import { PartialType, OmitType } from '@nestjs/swagger';
import { CreateLostFoundDto } from './create-lost-found.dto';

/**
 * 更新走失招领信息 DTO
 * 所有字段都是可选的
 */
export class UpdateLostFoundDto extends PartialType(
  OmitType(CreateLostFoundDto, [] as const),
) {}
