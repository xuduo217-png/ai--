import { PartialType } from '@nestjs/mapped-types';
import { CreateArticleDto } from './create-article.dto';

/**
 * 更新健康知识文章 DTO
 * 所有字段都是可选的
 */
export class UpdateHealthArticleDto extends PartialType(CreateArticleDto) {}
