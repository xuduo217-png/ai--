import {
  IsNotEmpty,
  IsInt,
  IsString,
  IsNumber,
  MaxLength,
  IsOptional,
  Min,
  IsBoolean,
  IsArray,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreatePackageDto {
  @ApiProperty({
    description: '套餐名称',
    example: '月度会员',
    maxLength: 100,
  })
  @IsNotEmpty()
  @IsString()
  @MaxLength(100)
  name: string;

  @ApiPropertyOptional({
    description: '套餐描述',
    example: '30天全时段医生咨询服务，性价比最高',
    maxLength: 500,
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @ApiProperty({
    description: '服务天数',
    example: 30,
    minimum: 1,
  })
  @IsNotEmpty()
  @IsInt()
  @Min(1)
  durationDays: number;

  @ApiProperty({
    description: '价格（元）',
    example: 29.9,
    minimum: 0,
  })
  @IsNotEmpty()
  @IsNumber()
  @Min(0)
  price: number;

  @ApiPropertyOptional({
    description: '原价（元）',
    example: 59.9,
    minimum: 0,
  })
  @IsOptional()
  @IsNumber()
  @Min(0)
  originalPrice?: number;

  @ApiProperty({
    description: '排序顺序',
    example: 1,
    minimum: 0,
  })
  @IsNotEmpty()
  @IsInt()
  @Min(0)
  sortOrder: number;

  @ApiPropertyOptional({
    description: '套餐特性列表',
    example: ['30天无限次咨询', '专业医生回复', '12小时内响应', '专属客服'],
    type: [String],
  })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  features?: string[];

  @ApiPropertyOptional({
    description: '是否启用',
    example: true,
    default: true,
  })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

export class UpdatePackageDto {
  @ApiPropertyOptional({
    description: '套餐名称',
    example: '季度会员',
    maxLength: 100,
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

  @ApiPropertyOptional({
    description: '套餐描述',
    example: '90天长期健康咨询服务',
    maxLength: 500,
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @ApiPropertyOptional({
    description: '服务天数',
    example: 90,
    minimum: 1,
  })
  @IsOptional()
  @IsInt()
  @Min(1)
  durationDays?: number;

  @ApiPropertyOptional({
    description: '价格（元）',
    example: 79.9,
    minimum: 0,
  })
  @IsOptional()
  @IsNumber()
  @Min(0)
  price?: number;

  @ApiPropertyOptional({
    description: '原价（元）',
    example: 159.9,
    minimum: 0,
  })
  @IsOptional()
  @IsNumber()
  @Min(0)
  originalPrice?: number;

  @ApiPropertyOptional({
    description: '排序顺序',
    example: 2,
    minimum: 0,
  })
  @IsOptional()
  @IsInt()
  sortOrder?: number;

  @ApiPropertyOptional({
    description: '套餐特性列表',
    example: ['90天无限次咨询', '专业医生回复', '8小时内响应'],
    type: [String],
  })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  features?: string[];

  @ApiPropertyOptional({
    description: '是否启用',
    example: true,
  })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
