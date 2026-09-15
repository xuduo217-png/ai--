import {
  IsNotEmpty,
  IsString,
  MaxLength,
  IsInt,
  IsOptional,
  IsBoolean,
  Min,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateAutoReplyDto {
  @ApiProperty({
    description: '自动回复内容',
    example: '您好，很高兴为您服务！请问有什么可以帮您的？',
    maxLength: 500,
  })
  @IsNotEmpty()
  @IsString()
  @MaxLength(500)
  content: string;

  @ApiProperty({
    description: '排序顺序（从1开始，按顺序发送）',
    example: 1,
    minimum: 1,
  })
  @IsNotEmpty()
  @IsInt()
  @Min(1)
  sortOrder: number;

  @ApiPropertyOptional({
    description: '是否启用',
    example: true,
    default: true,
  })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

export class UpdateAutoReplyDto {
  @ApiPropertyOptional({
    description: '自动回复内容',
    example: '我们的医生会尽快回复您，请耐心等待。',
    maxLength: 500,
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  content?: string;

  @ApiPropertyOptional({
    description: '排序顺序',
    example: 2,
    minimum: 1,
  })
  @IsOptional()
  @IsInt()
  @Min(1)
  sortOrder?: number;

  @ApiPropertyOptional({
    description: '是否启用',
    example: true,
  })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
