import {
  IsNotEmpty,
  IsString,
  IsOptional,
  MaxLength,
  IsBoolean,
  IsNumber,
  Min,
} from 'class-validator';

/**
 * 创建健康知识分类 DTO
 */
export class CreateHealthCategoryDto {
  @IsNotEmpty({ message: '分类名称不能为空' })
  @IsString()
  @MaxLength(50, { message: '分类名称最多 50 个字符' })
  name: string;

  @IsOptional()
  @IsString()
  icon?: string;

  @IsOptional()
  @IsNumber()
  @Min(0, { message: '排序权重不能为负数' })
  sortOrder?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
