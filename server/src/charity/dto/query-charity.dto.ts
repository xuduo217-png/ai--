import { IsOptional, IsEnum, IsIn, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { CharityStatus } from '../entities/charity.entity';
import { PaginationDto } from '../../common/dto/pagination.dto';

export type DeleteStatus = 'active' | 'deleted' | 'all';

/**
 * 查询公益 DTO
 * 支持状态筛选、关键词搜索和分页
 */
export class QueryCharityDto extends PaginationDto {
  @ApiPropertyOptional({ description: '公益状态', enum: CharityStatus })
  @IsOptional()
  @IsEnum(CharityStatus)
  status?: CharityStatus;

  @ApiPropertyOptional({ description: '关键词搜索(公益名称)', example: '签到' })
  @IsOptional()
  @IsString()
  keyword?: string;

  @ApiPropertyOptional({
    description: '删除状态筛选：active=未删除，deleted=已删除，all=全部',
    enum: ['active', 'deleted', 'all'],
    default: 'active',
  })
  @IsOptional()
  @IsIn(['active', 'deleted', 'all'])
  deleteStatus?: DeleteStatus = 'active';
}
