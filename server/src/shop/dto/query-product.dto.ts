import { IsOptional, IsEnum, IsString, IsNumber } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { ProductCategory } from '../entities/product.entity';
import { PublishSource } from '../entities/product.entity';

/**
 * 查询商品 DTO
 * 支持分页、搜索、筛选
 */
export class QueryProductDto extends PaginationDto {
  @ApiPropertyOptional({ description: '商品名称（模糊搜索）', example: '狗粮' })
  @IsString()
  @IsOptional()
  keyword?: string;

  @ApiPropertyOptional({ description: '商品分类', enum: ProductCategory })
  @IsEnum(ProductCategory)
  @IsOptional()
  category?: ProductCategory;

  @ApiPropertyOptional({ description: '发布来源', enum: PublishSource })
  @IsEnum(PublishSource)
  @IsOptional()
  publishSource?: PublishSource;

  @ApiPropertyOptional({ description: '是否上架', example: 'true' })
  @IsString()
  @IsOptional()
  isActive?: string;

  @ApiPropertyOptional({ description: '分类 ID' })
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  categoryId?: number;

  @ApiPropertyOptional({ description: '最低价格' })
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  minPrice?: number;

  @ApiPropertyOptional({ description: '最高价格' })
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  maxPrice?: number;

  @ApiPropertyOptional({ description: '发布者 ID' })
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  publishedBy?: number;
}
