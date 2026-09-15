import { ApiProperty } from '@nestjs/swagger';
import {
  IsString,
  IsOptional,
  IsEnum,
  IsInt,
  Min,
  IsArray,
  ValidateNested,
  IsObject,
} from 'class-validator';
import { Type } from 'class-transformer';
import { CategoryStatus } from '../entities/category.entity';

/**
 * 创建商品分类 DTO
 */
export class CreateProductCategoryDto {
  @ApiProperty({ description: '分类名称', example: '狗粮' })
  @IsString()
  name: string;

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
    default: CategoryStatus.ACTIVE,
  })
  @IsOptional()
  @IsEnum(CategoryStatus)
  status?: CategoryStatus;

  @ApiProperty({ description: '排序顺序（数字越小越靠前）', default: 0 })
  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @ApiProperty({ description: '父分类ID（null 表示根分类）', required: false })
  @IsOptional()
  @IsInt()
  parentId?: number;
}
