import { IsNotEmpty, IsInt, IsOptional, Min, IsBoolean } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreatePaymentConfigDto {
  @ApiPropertyOptional({
    description: '医生ID（null表示全局默认配置）',
    example: null,
  })
  @IsOptional()
  @IsInt()
  doctorId?: number;

  @ApiProperty({
    description: '最大免费自动回复次数',
    example: 3,
    minimum: 0,
    default: 3,
  })
  @IsNotEmpty()
  @IsInt()
  @Min(0)
  maxFreeReplies: number;

  @ApiPropertyOptional({
    description: '是否启用付费聊天',
    example: true,
    default: true,
  })
  @IsOptional()
  @IsBoolean()
  enableChatPayment?: boolean;

  @ApiPropertyOptional({
    description: '是否启用自动回复',
    example: true,
    default: true,
  })
  @IsOptional()
  @IsBoolean()
  autoReplyEnabled?: boolean;

  @ApiPropertyOptional({
    description: '是否启用',
    example: true,
    default: true,
  })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

export class UpdatePaymentConfigDto {
  @ApiPropertyOptional({
    description: '最大免费自动回复次数',
    example: 5,
    minimum: 0,
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  maxFreeReplies?: number;

  @ApiPropertyOptional({
    description: '是否启用付费聊天',
    example: true,
  })
  @IsOptional()
  @IsBoolean()
  enableChatPayment?: boolean;

  @ApiPropertyOptional({
    description: '是否启用自动回复',
    example: true,
  })
  @IsOptional()
  @IsBoolean()
  autoReplyEnabled?: boolean;

  @ApiPropertyOptional({
    description: '是否启用',
    example: true,
  })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
