import { PartialType } from '@nestjs/swagger';
import { CreatePetCategoryDto } from './create-pet-category.dto';

/**
 * 更新宠物类别 DTO
 * 所有字段都是可选的
 */
export class UpdatePetCategoryDto extends PartialType(CreatePetCategoryDto) {}
