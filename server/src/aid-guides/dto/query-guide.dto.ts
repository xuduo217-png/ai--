import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsNumber, IsEnum, IsString } from 'class-validator';
import { Type } from 'class-transformer';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { GuideStatus } from './create-guide.dto';

/**
 * 查询急救指南 DTO
 */
export class QueryGuideDto extends PaginationDto {
  @ApiProperty({ description: '分类 ID', required: false })
  @IsOptional()
  @IsNumber()
  @Type(() => Number)
  categoryId?: number;

  @ApiProperty({ enum: GuideStatus, description: '指南状态', required: false })
  @IsOptional()
  @IsEnum(GuideStatus)
  status?: GuideStatus;

  @ApiProperty({ description: '搜索关键词', required: false })
  @IsOptional()
  @IsString()
  keyword?: string;
}
