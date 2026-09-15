import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsOptional, IsInt, Min } from 'class-validator';

/**
 * 创建宠物类别 DTO
 */
export class CreatePetCategoryDto {
  @ApiProperty({
    description: '分类名称',
    example: '金毛',
    maxLength: 100,
  })
  @IsString({ message: '分类名称必须是字符串' })
  @IsNotEmpty({ message: '分类名称不能为空' })
  name: string;

  @ApiProperty({
    description: '父级分类ID（一级分类为null）',
    example: null,
    required: false,
  })
  @IsOptional()
  @IsInt({ message: '父级分类ID必须是整数' })
  @Min(1, { message: '父级分类ID必须大于0' })
  parentId?: number | null;

  @ApiProperty({
    description: '排序序号（越小越靠前）',
    example: 1,
    default: 0,
  })
  @IsInt({ message: '排序必须是整数' })
  @Min(0, { message: '排序不能为负数' })
  sortOrder: number;
}
