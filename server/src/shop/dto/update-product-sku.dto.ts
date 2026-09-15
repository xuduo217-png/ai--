import { ApiProperty } from '@nestjs/swagger';
import {
  IsString,
  IsNumber,
  IsEnum,
  IsOptional,
  IsObject,
  Min,
} from 'class-validator';
import { SkuStatus } from '../entities/product-sku.entity';

/**
 * 更新商品 SKU DTO
 */
export class UpdateProductSkuDto {
  @ApiProperty({ description: 'SKU ID（更新时需要传入）', required: false })
  @IsOptional()
  @IsNumber()
  id?: number;

  @ApiProperty({ description: 'SKU 名称', required: false })
  @IsOptional()
  @IsString()
  name?: string;

  @ApiProperty({
    description: 'SKU 规格（JSON 格式）',
    required: false,
    example: { 颜色: '红色', 尺寸: 'L' },
  })
  @IsOptional()
  @IsObject()
  specs?: Record<string, string>;

  @ApiProperty({ description: 'SKU 价格', required: false })
  @IsOptional()
  @IsNumber()
  @Min(0)
  price?: number;

  @ApiProperty({ description: 'SKU 原价', required: false })
  @IsOptional()
  @IsNumber()
  @Min(0)
  originalPrice?: number;

  @ApiProperty({ description: 'SKU 库存', required: false })
  @IsOptional()
  @IsNumber()
  @Min(0)
  stock?: number;

  @ApiProperty({ description: 'SKU 状态', enum: SkuStatus, required: false })
  @IsOptional()
  @IsEnum(SkuStatus)
  status?: SkuStatus;

  @ApiProperty({ description: 'SKU 图片', required: false })
  @IsOptional()
  @IsString()
  image?: string;

  @ApiProperty({ description: 'SKU 编码', required: false })
  @IsOptional()
  @IsString()
  skuCode?: string;
}
