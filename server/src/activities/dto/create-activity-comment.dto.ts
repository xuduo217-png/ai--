import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsNotEmpty, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class CreateActivityCommentDto {
  @ApiProperty({
    description: '评论内容',
    example: '这个选手太可爱了，支持一下',
    maxLength: 1000,
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(1000, { message: '评论内容不能超过 1000 字符' })
  content: string;

  @ApiPropertyOptional({
    description: '父评论ID（用于回复评论）',
    example: 31,
  })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @IsOptional()
  parentId?: number;
}
