import {
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export enum AdjustUserBalanceType {
  INCREASE = 'increase',
  DECREASE = 'decrease',
}

export class AdjustUserBalanceDto {
  @ApiProperty({
    description: '调整类型',
    enum: AdjustUserBalanceType,
    example: AdjustUserBalanceType.INCREASE,
  })
  @IsEnum(AdjustUserBalanceType)
  @IsNotEmpty()
  type: AdjustUserBalanceType;

  @ApiProperty({
    description: '调整金额，单位元',
    example: 20.5,
  })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;

  @ApiPropertyOptional({
    description: '调整备注',
    example: '后台补偿',
  })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  remark?: string;
}
