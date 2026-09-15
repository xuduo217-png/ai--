import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsOptional, IsNumber, IsEnum, IsNotEmpty } from 'class-validator';

/**
 * 指南状态枚举
 */
export enum GuideStatus {
  DRAFT = 'DRAFT',
  PUBLISHED = 'PUBLISHED',
}

/**
 * 创建急救指南 DTO
 */
export class CreateGuideDto {
  @ApiProperty({ description: '指南标题', example: '宠物心肺复苏步骤' })
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiProperty({ description: '指南图标 URL', required: false })
  @IsOptional()
  @IsString()
  icon?: string;

  @ApiProperty({ description: '指南内容（HTML 富文本）', example: '<p>步骤1：...</p>' })
  @IsString()
  @IsNotEmpty()
  content: string;

  @ApiProperty({ description: '所属分类 ID', example: 1 })
  @IsNumber()
  @IsNotEmpty()
  categoryId: number;

  @ApiProperty({ description: '排序权重', default: 0 })
  @IsOptional()
  @IsNumber()
  sortOrder?: number;

  @ApiProperty({ enum: GuideStatus, description: '指南状态', default: GuideStatus.DRAFT })
  @IsOptional()
  @IsEnum(GuideStatus)
  status?: GuideStatus;
}
