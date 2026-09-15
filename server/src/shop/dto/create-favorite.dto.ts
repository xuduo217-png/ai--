import { ApiProperty } from '@nestjs/swagger';
import { IsInt, IsPositive, IsNotEmpty } from 'class-validator';

/**
 * 创建收藏 DTO
 */
export class CreateFavoriteDto {
  @ApiProperty({
    description: '商品ID',
    example: 1,
  })
  @IsInt({ message: '商品 ID 必须是整数' })
  @IsPositive({ message: '商品 ID 必须是正整数' })
  @IsNotEmpty({ message: '商品 ID 不能为空' })
  productId: number;
}
