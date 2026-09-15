import {
  IsOptional,
  IsInt,
  IsString,
  IsEnum,
  Min,
  IsDateString,
} from 'class-validator';
import { Type } from 'class-transformer';

/**
 * 查询 AI 问诊报告列表 DTO
 */
export class QueryReportsDto {
  /**
   * 页码
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  /**
   * 每页大小
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  pageSize?: number = 10;

  /**
   * 报告 ID
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  id?: number;

  /**
   * 用户 ID（管理员/医生可筛选）
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  userId?: number;

  /**
   * 用户手机号（模糊搜索）
   */
  @IsOptional()
  @IsString()
  userPhone?: string;

  /**
   * 宠物 ID
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  petId?: number;

  /**
   * 状态筛选
   */
  @IsOptional()
  @IsEnum(['PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'TIMEOUT'])
  status?: 'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED' | 'TIMEOUT';

  /**
   * 关键词搜索（症状描述）
   */
  @IsOptional()
  @IsString()
  keyword?: string;

  /**
   * 开始日期（YYYY-MM-DD）
   */
  @IsOptional()
  @IsDateString()
  startDate?: string;

  /**
   * 结束日期（YYYY-MM-DD）
   */
  @IsOptional()
  @IsDateString()
  endDate?: string;
}
