import { PartialType } from '@nestjs/swagger';
import { CreateCharityDto } from './create-charity.dto';

/**
 * 更新公益 DTO
 * 继承 CreateCharityDto 并使所有字段变为可选
 */
export class UpdateCharityDto extends PartialType(CreateCharityDto) {}
