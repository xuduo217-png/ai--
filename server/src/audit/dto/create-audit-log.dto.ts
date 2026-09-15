import {
  IsNotEmpty,
  IsInt,
  IsEnum,
  IsOptional,
  IsString,
  IsIP,
  MaxLength,
  IsObject,
} from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { AuditAction } from '../entities/audit-log.entity';

export class CreateAuditLogDto {
  @ApiProperty({ description: '操作者用户 ID' })
  @IsNotEmpty()
  @IsInt()
  userId: number;

  @ApiProperty({ description: '目标用户 ID' })
  @IsNotEmpty()
  @IsInt()
  targetUserId: number;

  @ApiProperty({ description: '操作类型', enum: AuditAction })
  @IsNotEmpty()
  @IsEnum(AuditAction)
  action: AuditAction;

  @ApiProperty({ description: '旧值（JSON 对象）', required: false })
  @IsOptional()
  @IsObject()
  oldValues?: Record<string, any>;

  @ApiProperty({ description: '新值（JSON 对象）', required: false })
  @IsOptional()
  @IsObject()
  newValues?: Record<string, any>;

  @ApiProperty({ description: 'IP 地址' })
  @IsNotEmpty()
  @IsIP()
  ipAddress: string;

  @ApiProperty({ description: 'User Agent', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  userAgent?: string;
}
