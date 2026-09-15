import { PartialType } from '@nestjs/mapped-types';
import { CreateHealthCategoryDto } from './create-category.dto';

/**
 * 更新健康知识分类 DTO
 * 所有字段都是可选的
 */
export class UpdateHealthCategoryDto extends PartialType(
  CreateHealthCategoryDto,
) {}
