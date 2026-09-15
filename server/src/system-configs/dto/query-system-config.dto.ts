import { IsOptional, IsInt, Min, IsString } from 'class-validator';
import { Type } from 'class-transformer';
import { PaginationDto } from '../../common/dto/pagination.dto';

/**
 * 查询系统配置 DTO（支持分页）
 */
export class QuerySystemConfigDto extends PaginationDto {
  @IsOptional()
  @IsString()
  configKey?: string;
}
