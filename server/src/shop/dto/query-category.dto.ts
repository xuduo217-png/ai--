import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsEnum, IsInt } from 'class-validator';
import { Type } from 'class-transformer';
import { CategoryStatus } from '../entities/category.entity';

/**
 * 查询商品分类 DTO
 */
export class QueryCategoryDto {
  @ApiProperty({
    description: '分类状态',
    enum: CategoryStatus,
    required: false,
  })
  @IsOptional()
  @IsEnum(CategoryStatus)
  status?: CategoryStatus;

  @ApiProperty({ description: '父分类ID（null 查询根分类）', required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  parentId?: number;

  @ApiProperty({ description: '是否包含子分类', required: false })
  @IsOptional()
  includeChildren?: boolean;

  @ApiProperty({ description: '页码', required: false, default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  page?: number;

  @ApiProperty({ description: '每页数量', required: false, default: 10 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  pageSize?: number;
}
