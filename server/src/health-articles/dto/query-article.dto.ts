import { IsOptional, IsString, IsNumber, IsEnum } from 'class-validator';
import { Type } from 'class-transformer';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { ArticleStatus } from '../entities/health-article.entity';

/**
 * 查询健康知识文章列表 DTO
 */
export class QueryArticleDto extends PaginationDto {
  @IsOptional()
  @IsString()
  keyword?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  categoryId?: number;

  @IsOptional()
  @IsEnum(ArticleStatus, { message: '无效的文章状态' })
  status?: ArticleStatus;

  @IsOptional()
  @IsString()
  sortBy?:
    | 'createdAt'
    | 'updatedAt'
    | 'publishedAt'
    | 'viewCount'
    | 'likeCount' = 'createdAt';
}
