import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateLostFoundCommentDto {
  @ApiProperty({
    description: '评论内容',
    example: '看到相似的狗狗可以第一时间联系我',
    maxLength: 1000,
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(1000, { message: '评论内容不能超过 1000 字符' })
  content: string;

  @ApiPropertyOptional({
    description: '父评论ID（用于回复评论）',
    example: 12,
  })
  @Type(() => Number)
  @IsInt()
  @IsOptional()
  parentId?: number;
}
