import {
  IsNotEmpty,
  IsString,
  IsOptional,
  MaxLength,
  IsNumber,
  IsEnum,
} from 'class-validator';
import { ArticleStatus } from '../entities/health-article.entity';

/**
 * 创建健康知识文章 DTO
 */
export class CreateArticleDto {
  @IsNotEmpty({ message: '文章标题不能为空' })
  @IsString()
  @MaxLength(200, { message: '标题最多 200 个字符' })
  title: string;

  @IsNotEmpty({ message: '文章摘要不能为空' })
  @IsString()
  @MaxLength(500, { message: '摘要最多 500 个字符' })
  summary: string;

  @IsNotEmpty({ message: '文章内容不能为空' })
  @IsString()
  content: string;

  @IsOptional()
  @IsString()
  coverImage?: string;

  @IsNotEmpty({ message: '分类 ID 不能为空' })
  @IsNumber()
  categoryId: number;

  @IsOptional()
  @IsEnum(ArticleStatus, { message: '无效的文章状态' })
  status?: ArticleStatus;
}
