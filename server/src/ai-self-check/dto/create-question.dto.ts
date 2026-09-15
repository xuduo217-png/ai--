import {
  IsString,
  IsEnum,
  IsBoolean,
  IsInt,
  IsOptional,
  Min,
  ArrayMinSize,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

/**
 * 选项 DTO
 */
class OptionDto {
  /**
   * 选项描述
   */
  @IsString()
  optionText: string;

  /**
   * 选项表现图片（可选）
   */
  @IsOptional()
  @IsString()
  optionImage?: string;

  /**
   * 排序序号
   */
  @IsInt()
  @Min(0)
  sortOrder: number;
}

/**
 * 创建问题 DTO
 */
export class CreateQuestionDto {
  /**
   * 所属自查表ID
   */
  @IsInt()
  listId: number;

  /**
   * 问题描述
   */
  @IsString()
  questionText: string;

  /**
   * 问题类型：单选/多选/填空
   */
  @IsEnum(['SINGLE', 'MULTIPLE', 'TEXT'])
  questionType: 'SINGLE' | 'MULTIPLE' | 'TEXT';

  /**
   * 是否必填
   */
  @IsBoolean()
  required: boolean;

  /**
   * 排序序号
   */
  @IsInt()
  @Min(0)
  sortOrder: number;

  /**
   * 选项列表（仅选择题需要）
   */
  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => OptionDto)
  options?: OptionDto[];
}
