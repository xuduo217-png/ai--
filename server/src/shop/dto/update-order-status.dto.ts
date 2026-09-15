import { IsNotEmpty, IsEnum, IsOptional, IsString } from 'class-validator';
import { OrderStatus } from '../entities/order.entity';
import { ApiProperty } from '@nestjs/swagger';

export class UpdateOrderStatusDto {
  @ApiProperty({ description: '订单状态', enum: OrderStatus })
  @IsNotEmpty()
  @IsEnum(OrderStatus)
  status: OrderStatus;

  @ApiProperty({ description: '取消原因（取消订单时必填）', required: false })
  @IsOptional()
  @IsString()
  cancelReason?: string;
}
