import { IsNotEmpty, IsNumber, IsString, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

/**
 * 设置物流信息 DTO
 */
export class UpdateShippingDto {
  @ApiProperty({ description: '物流公司ID', example: 1 })
  @IsNotEmpty({ message: '物流公司不能为空' })
  @IsNumber()
  logisticsId: number;

  @ApiProperty({
    description: '物流单号',
    example: 'SF1234567890',
  })
  @IsNotEmpty({ message: '物流单号不能为空' })
  @IsString()
  @MaxLength(100, { message: '物流单号最多100个字符' })
  trackingNumber: string;
}
