import {
  IsOptional,
  IsString,
  IsInt,
  Min,
  Max,
  IsBoolean,
  IsNumber,
  IsPhoneNumber,
} from 'class-validator';
import { Type, Transform } from 'class-transformer';
import { PaginationDto } from '../../common/dto/pagination.dto';

/**
 * 查询医生列表 DTO
 * 支持分页、筛选、排序
 */
export class QueryDoctorDto extends PaginationDto {
  // ========== 搜索条件 ==========

  /**
   * 姓名模糊搜索
   */
  @IsOptional()
  @IsString()
  name?: string;

  /**
   * 手机号精确搜索
   */
  @IsOptional()
  @IsPhoneNumber('CN')
  @IsString()
  phone?: string;

  /**
   * 专长模糊搜索
   */
  @IsOptional()
  @IsString()
  specialty?: string;

  // ========== 筛选条件 ==========

  /**
   * 按医院筛选
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  hospitalId?: number;

  /**
   * 按科室筛选
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  departmentId?: number;

  /**
   * 按在职状态筛选
   */
  @IsOptional()
  @IsBoolean()
  @Transform(({ value }) => value === 'true' || value === '1' || value === true || value === 1)
  isActive?: boolean;

  /**
   * 按金牌医师筛选
   */
  @IsOptional()
  @IsBoolean()
  @Transform(({ value }) => value === 'true' || value === '1' || value === true || value === 1)
  isGoldDoctor?: boolean;

  /**
   * 最低评分筛选
   */
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0, { message: '评分最小为 0' })
  @Max(5, { message: '评分最大为 5' })
  minRating?: number;

  /**
   * 最低经验年限筛选
   */
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0, { message: '经验年限不能为负数' })
  @Max(50, { message: '经验年限最多 50 年' })
  minExperience?: number;

  // ========== 排序条件 ==========

  /**
   * 排序字段
   */
  @IsOptional()
  @IsString()
  sortBy?:
    | 'createdAt'
    | 'updatedAt'
    | 'name'
    | 'rating'
    | 'experience'
    | 'consultationCount' = 'createdAt';
}
