import {
  IsString,
  IsInt,
  IsArray,
  IsOptional,
  Min,
  IsBoolean,
  IsIn,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

/**
 * 自查表答案快照选项
 */
export class SelfCheckOptionSnapshot {
  @IsInt()
  @Min(1)
  optionId: number;

  @IsString()
  optionText: string;

  @IsOptional()
  @IsString()
  image?: string;

  @IsBoolean()
  selected: boolean;
}

/**
 * 自查表答案快照问题
 */
export class SelfCheckQuestionSnapshot {
  @IsInt()
  @Min(1)
  questionId: number;

  @IsString()
  questionText: string;

  @IsIn(['SINGLE', 'MULTIPLE', 'TEXT'])
  questionType: 'SINGLE' | 'MULTIPLE' | 'TEXT';

  @IsInt()
  sortOrder: number;

  /**
   * 选项列表（使用 @Type 装饰器进行类型转换）
   */
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SelfCheckOptionSnapshot)
  options: SelfCheckOptionSnapshot[];
}

/**
 * 自查表答案快照列表
 */
export class SelfCheckListSnapshot {
  @IsInt()
  @Min(1)
  listId: number;

  @IsString()
  listName: string;

  @IsIn(['PUBLIC', 'SPECIFIC'])
  listType: 'PUBLIC' | 'SPECIFIC';

  @IsOptional()
  @IsInt()
  petCategoryId: number;

  /**
   * 问题列表（使用 @Type 装饰器进行类型转换）
   */
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SelfCheckQuestionSnapshot)
  questions: SelfCheckQuestionSnapshot[];
}

/**
 * 基础信息
 */
export class BasicInfo {
  /**
   * 体温（°C）
   */
  @IsOptional()
  bodyTemperature?: string;

  /**
   * 心率（次/分钟）
   */
  @IsOptional()
  heartRate?: string;

  /**
   * 呼吸频率（次/分钟）
   */
  @IsOptional()
  breathe?: string;
}

/**
 * 创建 AI 问诊报告 DTO
 */
export class CreateReportDto {
  /**
   * 宠物 ID
   */
  @IsInt()
  @Min(1)
  petId: number;

  /**
   * 用户输入的症状描述
   */
  @IsString()
  symptoms: string;

  /**
   * 自查表答案快照（使用 @Type 装饰器进行类型转换）
   */
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SelfCheckListSnapshot)
  selfCheckSnapshot: SelfCheckListSnapshot[];

  /**
   * 基础信息（体温、心率、呼吸频率）（使用 @Type 装饰器进行类型转换）
   */
  @IsOptional()
  @ValidateNested()
  @Type(() => BasicInfo)
  basicInfo?: BasicInfo;

  /**
   * 诊断图片URL列表
   * 用户上传的患处照片
   */
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  diagnosisImages?: string[];
}
