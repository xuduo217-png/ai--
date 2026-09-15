import { PartialType } from '@nestjs/swagger';
import { CreateGuideDto } from './create-guide.dto';

/**
 * 更新急救指南 DTO
 */
export class UpdateGuideDto extends PartialType(CreateGuideDto) {}
