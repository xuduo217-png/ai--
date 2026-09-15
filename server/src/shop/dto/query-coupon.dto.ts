import { IsOptional, IsInt, Min, Max, IsString, IsEnum, ValidateIf } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { CouponType, CouponScope } from '../entities/coupon.entity';

export class QueryCouponDto {
  @ApiProperty({ description: '页码', required: false, default: 1 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Type(() => Number)
  page?: number = 1;

  @ApiProperty({ description: '每页数量', required: false, default: 10 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Type(() => Number)
  limit?: number = 10;

  @ApiProperty({ description: '优惠券名称（模糊搜索）', required: false })
  @IsOptional()
  @IsString()
  name?: string;

  @ApiProperty({ description: '优惠券类型', enum: CouponType, required: false })
  @IsOptional()
  @IsEnum(CouponType, { message: 'type must be one of the following values: FULL_REDUCTION, DISCOUNT, DIRECT_DISCOUNT' })
  @ValidateIf(o => o.type !== '')
  type?: CouponType;

  @ApiProperty({ description: '使用范围', enum: CouponScope, required: false })
  @IsOptional()
  @IsEnum(CouponScope, { message: 'scope must be one of the following values: ALL, SPECIFIC' })
  @ValidateIf(o => o.scope !== '')
  scope?: CouponScope;

  @ApiProperty({ description: '启用状态（0-启用，1-禁用）', required: false })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1)
  @Type(() => Number)
  isEnabled?: number;
}
