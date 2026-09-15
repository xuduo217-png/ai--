import {
  IsNotEmpty,
  IsInt,
  IsString,
  IsEnum,
  IsOptional,
  IsNumber,
  Min,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { RefundType } from '../entities/refund.entity';

/**
 * 创建退款 DTO
 */
export class CreateRefundDto {
  @ApiProperty({ description: '支付记录ID', example: 1 })
  @IsInt()
  @IsNotEmpty()
  paymentId: number;

  @ApiProperty({ description: '退款金额（单位：元）', example: 99.99 })
  @IsNumber()
  @Min(0.01, { message: '退款金额必须大于0' })
  @IsNotEmpty()
  refundAmount: number;

  @ApiProperty({ description: '退款类型', enum: RefundType })
  @IsEnum(RefundType)
  @IsOptional()
  type?: RefundType;

  @ApiProperty({ description: '退款原因', example: '商品质量问题' })
  @IsString()
  @IsOptional()
  reason?: string;

  @ApiPropertyOptional({ description: '扩展信息', example: { orderId: 123 } })
  @IsOptional()
  metadata?: Record<string, any>;
}

/**
 * 退款响应 DTO
 */
export interface CreateRefundResponse {
  refundId: number;
  refundNo: string;
  paymentId: number;
  refundAmount: number;
  status: string;
  channel: string;
  thirdPartyRefundNo?: string;
  createdAt: Date;
}
