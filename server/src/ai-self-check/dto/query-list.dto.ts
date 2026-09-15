import { IsOptional, IsEnum, IsString, IsInt } from 'class-validator';
import { Transform } from 'class-transformer';
import { PaginationDto } from '../../common/dto/pagination.dto';

/**
 * 查询自查表列表 DTO
 */
export class QueryListDto extends PaginationDto {
  /**
   * 类型筛选：公共项/特定项
   */
  @IsOptional()
  @IsEnum(['PUBLIC', 'SPECIFIC'])
  type?: 'PUBLIC' | 'SPECIFIC';

  /**
   * 分类ID筛选
   */
  @IsOptional()
  @Transform(({ value }) => (value ? parseInt(value) : undefined))
  @IsInt()
  categoryId?: number;

  /**
   * 状态筛选
   */
  @IsOptional()
  @IsEnum(['ACTIVE', 'INACTIVE'])
  status?: 'ACTIVE' | 'INACTIVE';

  /**
   * 关键词搜索（标题）
   */
  @IsOptional()
  @IsString()
  keyword?: string;
}
