import {
  IsNotEmpty,
  IsString,
  IsOptional,
  MaxLength,
  IsNumber,
  IsBoolean,
} from 'class-validator';

/**
 * 创建科室 DTO
 * 用于创建新的科室，必须关联到医院
 */
export class CreateDepartmentDto {
  /**
   * 所属医院ID
   * 必填字段，每个科室必须属于一个医院
   */
  @IsNumber()
  @IsNotEmpty()
  hospitalId: number;

  @IsNotEmpty()
  @IsString()
  @MaxLength(50)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  /**
   * 是否启用
   * 可选字段，默认为 true
   */
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
