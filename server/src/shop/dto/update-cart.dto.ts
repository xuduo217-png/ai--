import { ApiProperty } from '@nestjs/swagger';
import { IsInt, IsPositive } from 'class-validator';

/**
 * 更新购物车 DTO
 */
export class UpdateCartDto {
  @ApiProperty({
    description: '数量',
    example: 2,
    minimum: 1,
  })
  @IsInt({ message: '数量必须是整数' })
  @IsPositive({ message: '数量必须是正整数' })
  quantity: number;
}
