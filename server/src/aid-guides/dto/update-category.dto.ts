import { PartialType } from '@nestjs/swagger';
import { CreateAidGuideCategoryDto } from './create-category.dto';

/**
 * 更新急救指南分类 DTO
 */
export class UpdateAidGuideCategoryDto extends PartialType(CreateAidGuideCategoryDto) {}
