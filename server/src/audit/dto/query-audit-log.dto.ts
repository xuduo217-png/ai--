import {
  IsOptional,
  IsInt,
  IsEnum,
  IsString,
  IsDateString,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';
import { PaginationDto, SortOrder } from '../../common/dto/pagination.dto';
import { AuditAction } from '../entities/audit-log.entity';

export class QueryAuditLogDto extends PaginationDto {
  @ApiProperty({ description: '操作者用户 ID', required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  userId?: number;

  @ApiProperty({ description: '目标用户 ID', required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  targetUserId?: number;

  @ApiProperty({ description: '操作类型', enum: AuditAction, required: false })
  @IsOptional()
  @IsEnum(AuditAction)
  action?: AuditAction;

  @ApiProperty({
    description: '开始日期',
    required: false,
    example: '2024-01-01',
  })
  @IsOptional()
  @IsDateString()
  startDate?: string;

  @ApiProperty({
    description: '结束日期',
    required: false,
    example: '2024-12-31',
  })
  @IsOptional()
  @IsDateString()
  endDate?: string;

  @ApiProperty({ description: 'IP 地址', required: false })
  @IsOptional()
  @IsString()
  ipAddress?: string;

  @ApiProperty({
    description: '排序字段',
    required: false,
    enum: ['createdAt', 'action', 'targetUserId'],
    default: 'createdAt',
  })
  @IsOptional()
  @IsString()
  sortBy?: 'createdAt' | 'action' | 'targetUserId' = 'createdAt';

  @ApiProperty({
    description: '排序顺序',
    required: false,
    enum: SortOrder,
    default: SortOrder.DESC,
  })
  @IsOptional()
  sortOrder?: SortOrder = SortOrder.DESC;
}
