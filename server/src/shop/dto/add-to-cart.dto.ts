import { ApiProperty } from '@nestjs/swagger';
import { IsInt, IsPositive, IsNotEmpty, IsOptional } from 'class-validator';

/**
 * 添加到购物车 DTO
 */
export class AddToCartDto {
  @ApiProperty({
    description: '商品ID',
    example: 1,
  })
  @IsInt({ message: '商品 ID 必须是整数' })
  @IsPositive({ message: '商品 ID 必须是正整数' })
  @IsNotEmpty({ message: '商品 ID 不能为空' })
  productId: number;

  @ApiProperty({
    description: 'SKU ID',
    example: 1,
    required: false,
  })
  @IsOptional()
  @IsInt({ message: 'SKU ID 必须是整数' })
  @IsPositive({ message: 'SKU ID 必须是正整数' })
  skuId?: number;

  @ApiProperty({
    description: '数量',
    example: 1,
    default: 1,
  })
  @IsInt({ message: '数量必须是整数' })
  @IsPositive({ message: '数量必须是正整数' })
  @IsNotEmpty({ message: '数量不能为空' })
  quantity: number;
}
