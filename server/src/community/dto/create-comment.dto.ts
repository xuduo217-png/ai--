import { IsString, IsNotEmpty, IsOptional, IsInt, MaxLength } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

/**
 * 创建评论 DTO
 */
export class CreateCommentDto {
  /**
   * 评论内容
   */
  @ApiProperty({
    description: '评论内容',
    example: '好可爱！',
    maxLength: 1000
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(1000, { message: '评论内容不能超过 1000 字符' })
  content: string;

  /**
   * 父评论ID（用于回复评论）
   * 如果不传，表示是顶层评论
   */
  @ApiPropertyOptional({
    description: '父评论ID（用于回复评论）',
    example: 123
  })
  @Type(() => Number)
  @IsInt()
  @IsOptional()
  parentId?: number;
}
