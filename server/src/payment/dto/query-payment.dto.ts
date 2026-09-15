import { IsOptional, IsEnum, IsInt, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { PaginationDto } from '../../common/dto/pagination.dto';
import {
  PaymentStatus,
  PaymentChannel,
  BusinessType,
} from '../entities/payment.entity';

/**
 * 查询支付记录 DTO
 * 支持分页、筛选、排序
 */
export class QueryPaymentDto extends PaginationDto {
  @ApiPropertyOptional({
    description: '支付单号',
    example: 'PAY2023010112000012345',
  })
  @IsString()
  @IsOptional()
  paymentNo?: string;

  @ApiPropertyOptional({ description: '商户订单号', example: 'shop_order_123' })
  @IsString()
  @IsOptional()
  outTradeNo?: string;

  @ApiPropertyOptional({ description: '支付状态', enum: PaymentStatus })
  @IsEnum(PaymentStatus)
  @IsOptional()
  status?: PaymentStatus;

  @ApiPropertyOptional({ description: '支付渠道', enum: PaymentChannel })
  @IsEnum(PaymentChannel)
  @IsOptional()
  channel?: PaymentChannel;

  @ApiPropertyOptional({ description: '业务类型', enum: BusinessType })
  @IsEnum(BusinessType)
  @IsOptional()
  businessType?: BusinessType;

  @ApiPropertyOptional({ description: '业务ID（订单ID等）', example: 123 })
  @IsInt()
  @IsOptional()
  businessId?: number;

  @ApiPropertyOptional({ description: '用户ID', example: 1 })
  @IsInt()
  @IsOptional()
  userId?: number;

  @ApiPropertyOptional({
    description: '第三方交易号',
    example: '2023010122001412345678901234',
  })
  @IsString()
  @IsOptional()
  transactionId?: string;

  @ApiPropertyOptional({
    description: '开始时间（YYYY-MM-DD）',
    example: '2024-01-01',
  })
  @IsString()
  @IsOptional()
  startDate?: string;

  @ApiPropertyOptional({
    description: '结束时间（YYYY-MM-DD）',
    example: '2024-12-31',
  })
  @IsString()
  @IsOptional()
  endDate?: string;

  @ApiPropertyOptional({ description: '最小金额', example: 10 })
  @IsInt()
  @IsOptional()
  minAmount?: number;

  @ApiPropertyOptional({ description: '最大金额', example: 1000 })
  @IsInt()
  @IsOptional()
  maxAmount?: number;
}
