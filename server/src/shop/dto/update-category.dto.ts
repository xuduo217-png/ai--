import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsOptional, IsEnum, IsInt, Min } from 'class-validator';
import { CategoryStatus } from '../entities/category.entity';

/**
 * 更新商品分类 DTO
 */
export class UpdateProductCategoryDto {
  @ApiProperty({ description: '分类名称', required: false })
  @IsOptional()
  @IsString()
  name?: string;

  @ApiProperty({ description: '分类图标', required: false })
  @IsOptional()
  @IsString()
  icon?: string;

  @ApiProperty({ description: '分类图片', required: false })
  @IsOptional()
  @IsString()
  image?: string;

  @ApiProperty({ description: '分类描述', required: false })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({
    description: '分类状态',
    enum: CategoryStatus,
    required: false,
  })
  @IsOptional()
  @IsEnum(CategoryStatus)
  status?: CategoryStatus;

  @ApiProperty({ description: '排序顺序（数字越小越靠前）', required: false })
  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @ApiProperty({ description: '父分类ID', required: false })
  @IsOptional()
  @IsInt()
  parentId?: number;
}
