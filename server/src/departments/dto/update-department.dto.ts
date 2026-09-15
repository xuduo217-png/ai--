import {
  IsOptional,
  IsString,
  MaxLength,
  IsBoolean,
  IsNumber,
} from 'class-validator';

/**
 * 更新科室 DTO
 * 用于更新科室信息，所有字段都是可选的
 */
export class UpdateDepartmentDto {
  /**
   * 所属医院ID
   * 可选字段，更新时可以更改科室所属医院
   */
  @IsOptional()
  @IsNumber()
  hospitalId?: number;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
