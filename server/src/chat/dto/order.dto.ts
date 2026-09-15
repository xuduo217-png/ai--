import {
  IsNotEmpty,
  IsInt,
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
  IsIn,
  MaxLength,
} from 'class-validator';
import { OrderStatus } from '../entities/chat-order.entity';
import { PaymentChannel } from '../../payment/entities/payment.entity';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { PaginationDto } from '../../common/dto/pagination.dto';

/**
 * 创建聊天订单 DTO
 */
export class CreateChatOrderDto {
  @ApiProperty({
    description: '医生ID',
    example: 1,
  })
  @IsNotEmpty()
  @IsInt()
  doctorId: number;

  @ApiProperty({
    description: '收费项ID（医生服务项）',
    example: 2,
  })
  @IsNotEmpty()
  @IsInt()
  serviceItemId: number;

  @ApiProperty({
    description: '支付渠道',
    enum: [PaymentChannel.ALIPAY, PaymentChannel.BALANCE],
    example: PaymentChannel.ALIPAY,
  })
  @IsIn([PaymentChannel.ALIPAY, PaymentChannel.BALANCE])
  paymentChannel: PaymentChannel;

  @ApiProperty({
    description: '客户端生成的幂等键，同一次支付重试必须保持不变',
    example: '550e8400-e29b-41d4-a716-446655440000',
  })
  @IsUUID('4')
  idempotencyKey: string;

  @ApiPropertyOptional({
    description: '当前聊天页的临时会话ID，仅在当前页直接付费时传入',
    example: '550e8400-e29b-41d4-a716-446655440000',
  })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  conversationId?: string;
}

export class QueryOrderDto extends PaginationDto {
  @ApiPropertyOptional({
    description: '订单状态',
    enum: OrderStatus,
    example: OrderStatus.PAID,
  })
  @IsOptional()
  @IsEnum(OrderStatus)
  status?: OrderStatus;

  @ApiPropertyOptional({
    description: '排序字段',
    enum: ['createdAt', 'serviceEndAt', 'amount'],
    example: 'createdAt',
    default: 'createdAt',
  })
  @IsOptional()
  @IsString()
  sortBy?: 'createdAt' | 'serviceEndAt' | 'amount' = 'createdAt';
}
