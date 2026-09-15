import { ApiProperty } from '@nestjs/swagger';
import {
  IsString,
  IsNumber,
  IsEnum,
  IsOptional,
  IsObject,
  Min,
  IsArray,
} from 'class-validator';
import { SkuStatus } from '../entities/product-sku.entity';

/**
 * 创建商品 SKU DTO
 */
export class CreateProductSkuDto {
  @ApiProperty({ description: 'SKU 名称', example: '红色-L' })
  @IsString()
  name: string;

  @ApiProperty({
    description: 'SKU 规格（JSON 格式）',
    example: { 颜色: '红色', 尺寸: 'L' },
  })
  @IsObject()
  specs: Record<string, string>;

  @ApiProperty({ description: 'SKU 价格', example: 99.99 })
  @IsNumber()
  @Min(0)
  price: number;

  @ApiProperty({
    description: 'SKU 原价（可选）',
    required: false,
    example: 129.99,
  })
  @IsOptional()
  @IsNumber()
  @Min(0)
  originalPrice?: number;

  @ApiProperty({ description: 'SKU 库存', default: 0 })
  @IsNumber()
  @Min(0)
  stock?: number;

  @ApiProperty({
    description: 'SKU 状态',
    enum: SkuStatus,
    default: SkuStatus.ACTIVE,
  })
  @IsOptional()
  @IsEnum(SkuStatus)
  status?: SkuStatus;

  @ApiProperty({ description: 'SKU 图片（可选）', required: false })
  @IsOptional()
  @IsString()
  image?: string;

  @ApiProperty({ description: 'SKU 编码（可选）', required: false })
  @IsOptional()
  @IsString()
  skuCode?: string;
}

/**
 * 批量创建 SKU DTO
 */
export class CreateProductSkuBatchDto {
  @ApiProperty({ description: 'SKU 列表', type: [CreateProductSkuDto] })
  @IsArray()
  skus: CreateProductSkuDto[];
}
