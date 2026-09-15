import { IsOptional, IsInt, IsString, IsEnum } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { LostFoundRecordType } from '../entities/lost-found.entity';

/**
 * 查询走失招领列表 DTO
 */
export class QueryLostFoundDto extends PaginationDto {
  @ApiPropertyOptional({
    description: '筛选记录类型：LOST=走失，ADOPTION=领养',
    enum: LostFoundRecordType,
    example: LostFoundRecordType.LOST,
  })
  @IsOptional()
  @IsEnum(LostFoundRecordType, { message: '记录类型不正确' })
  recordType?: LostFoundRecordType;

  @ApiPropertyOptional({ description: '筛选是否已找回：0=未找回, 1=已找回', example: 0 })
  @IsOptional()
  @Type(() => Number)
  isFound?: 0 | 1;

  @ApiPropertyOptional({ description: '筛选是否置顶：0=未置顶, 1=已置顶', example: 0 })
  @IsOptional()
  @Type(() => Number)
  isPinned?: 0 | 1;

  @ApiPropertyOptional({ description: '筛选宠物ID', example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  petId?: number;

  @ApiPropertyOptional({ description: '筛选发布者ID', example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  publisherId?: number;

  @ApiPropertyOptional({ description: '搜索关键词（描述、联系人）', example: '金毛' })
  @IsOptional()
  @IsString()
  keyword?: string;
}
