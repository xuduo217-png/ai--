import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsOptional, IsNumber, IsBoolean } from 'class-validator';

/**
 * 创建急救指南分类 DTO
 */
export class CreateAidGuideCategoryDto {
  @ApiProperty({ description: '分类名称', example: '心肺复苏' })
  @IsString()
  name: string;

  @ApiProperty({ description: '分类图标 URL', required: false })
  @IsOptional()
  @IsString()
  icon?: string;

  @ApiProperty({ description: '排序权重', default: 0 })
  @IsOptional()
  @IsNumber()
  sortOrder?: number;

  @ApiProperty({ description: '是否启用', default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
