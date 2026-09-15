import { IsOptional, IsString, IsInt, IsIn, Min, IsBoolean } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { ActivityStatus } from '../entities/activity.entity';
import { Transform, Type } from 'class-transformer';

/**
 * 查询活动 DTO
 */
export type DeleteStatus = 'active' | 'deleted' | 'all';

export class QueryActivityDto {
  @ApiPropertyOptional({ description: '页码', example: 1, default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({ description: '每页数量', example: 10, default: 10 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  pageSize?: number = 10;

  @ApiPropertyOptional({ description: '医院ID', example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  hospitalId?: number;

  @ApiPropertyOptional({ description: '开始日期筛选（YYYY-MM-DD）', example: '2026-02-01' })
  @IsOptional()
  @IsString()
  startDate?: string;

  @ApiPropertyOptional({
    description: '活动状态',
    enum: ActivityStatus,
    example: ActivityStatus.ONGOING
  })
  @IsOptional()
  @IsString()
  status?: ActivityStatus;

  @ApiPropertyOptional({ description: '搜索关键词（活动名称）', example: '健康' })
  @IsOptional()
  @IsString()
  keyword?: string;

  @ApiPropertyOptional({ description: '是否展示到首页', example: true })
  @IsOptional()
  @Transform(({ value }) => {
    if (value === undefined || value === null || value === '') return undefined;
    return value === true || value === 'true' || value === '1' || value === 1;
  })
  @IsBoolean()
  showOnHome?: boolean;

  @ApiPropertyOptional({
    description: '删除状态筛选：active=未删除，deleted=已删除，all=全部',
    enum: ['active', 'deleted', 'all'],
    default: 'active',
  })
  @IsOptional()
  @IsIn(['active', 'deleted', 'all'])
  deleteStatus?: DeleteStatus = 'active';
}
