import {
  IsNotEmpty,
  IsString,
  IsEnum,
  IsInt,
  Min,
  Max,
  IsOptional,
  MaxLength,
  IsNumber,
  IsArray,
} from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { CouponType, CouponScope, ClaimType } from '../entities/coupon.entity';

export class CreateCouponDto {
  @ApiProperty({ description: '优惠券名称' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  name: string;

  @ApiProperty({ description: '优惠券描述', required: false })
  @IsString()
  @IsOptional()
  @MaxLength(500)
  description?: string;

  @ApiProperty({ description: '优惠券类型', enum: CouponType })
  @IsEnum(CouponType)
  @IsNotEmpty()
  type: CouponType;

  @ApiProperty({ description: '满减门槛（元）', example: 100 })
  @IsNumber()
  @Min(0)
  @IsNotEmpty()
  minAmount: number;

  @ApiProperty({ description: '优惠值', example: 20 })
  @IsNumber()
  @Min(0)
  @IsNotEmpty()
  discountValue: number;

  @ApiProperty({ description: '最大优惠金额（折扣券专用）', required: false })
  @IsNumber()
  @IsOptional()
  @Min(0)
  maxDiscount?: number;

  @ApiProperty({ description: '发放总量', example: 1000 })
  @IsInt()
  @Min(0)
  @IsNotEmpty()
  stock: number;

  @ApiProperty({ description: '每人限领数量', example: 1 })
  @IsInt()
  @Min(1)
  @IsOptional()
  perUserLimit?: number = 1;

  @ApiProperty({ description: '有效期开始时间' })
  @IsString()
  @IsNotEmpty()
  validFrom: string;

  @ApiProperty({ description: '有效期结束时间' })
  @IsString()
  @IsNotEmpty()
  validAt: string;

  @ApiProperty({
    description: '使用范围',
    enum: CouponScope,
    default: CouponScope.ALL
  })
  @IsEnum(CouponScope)
  @IsOptional()
  scope?: CouponScope = CouponScope.ALL;

  @ApiProperty({
    description: '指定商品ID列表（scope为SPECIFIC时必填）',
    required: false,
    type: [Number]
  })
  @IsArray()
  @IsInt({ each: true })
  @IsOptional()
  productIds?: number[];

  @ApiProperty({ description: '最低订单金额限制（元）', default: 0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  minOrderAmount?: number = 0;

  @ApiProperty({
    description: '是否可叠加使用（0-否，1-是）',
    default: 0
  })
  @IsInt()
  @Min(0)
  @Max(1)
  @IsOptional()
  canStack?: number = 0;

  @ApiProperty({
    description: '启用状态（0-启用，1-禁用）',
    default: 0
  })
  @IsInt()
  @Min(0)
  @Max(1)
  @IsOptional()
  isEnabled?: number = 0;

  @ApiProperty({
    description: '领取方式',
    enum: ClaimType,
    required: false
  })
  @IsEnum(ClaimType)
  @IsOptional()
  claimType?: ClaimType;
}
