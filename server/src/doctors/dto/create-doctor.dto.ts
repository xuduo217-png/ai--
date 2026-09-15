import {
  IsNotEmpty,
  IsString,
  IsOptional,
  MaxLength,
  IsNumber,
  Min,
  Max,
  IsArray,
  IsBoolean,
  MinLength,
  IsPhoneNumber,
} from 'class-validator';

/**
 * 创建医生 DTO
 * 包含账号信息、基本信息、关联信息等
 */
export class CreateDoctorDto {
  // ========== 账号信息（必填） ==========

  /**
   * 登录用户名
   */
  @IsNotEmpty()
  @IsString()
  @MaxLength(50, { message: '用户名最多 50 个字符' })
  username: string;

  /**
   * 登录密码
   */
  @IsNotEmpty()
  @IsString()
  @MinLength(6, { message: '密码长度至少 6 位' })
  password: string;

  /**
   * 手机号
   */
  @IsNotEmpty()
  @IsPhoneNumber('CN')
  @IsString()
  phone: string;

  // ========== 基本信息 ==========

  /**
   * 医生姓名
   */
  @IsNotEmpty()
  @IsString()
  @MaxLength(50, { message: '姓名最多 50 个字符' })
  name: string;

  /**
   * 头像 URL
   */
  @IsOptional()
  @IsString()
  avatar?: string;

  /**
   * 专业领域/专长
   */
  @IsNotEmpty()
  @IsString()
  @MaxLength(100, { message: '专长最多 100 个字符' })
  specialty: string;

  /**
   * 医生简介
   */
  @IsOptional()
  @IsString()
  @MaxLength(2000, { message: '简介最多 2000 个字符' })
  description?: string;

  /**
   * 从业经验（年）
   */
  @IsOptional()
  @IsNumber()
  @Min(0, { message: '经验年限不能为负数' })
  @Max(50, { message: '经验年限最多 50 年' })
  experience?: number;

  /**
   * 是否为金牌医师
   */
  @IsOptional()
  @IsBoolean()
  isGoldDoctor?: boolean;

  // ========== 关联信息 ==========

  /**
   * 所属医院 ID
   */
  @IsNotEmpty()
  @IsNumber()
  hospitalId: number;

  /**
   * 所属科室 ID
   */
  @IsNotEmpty()
  @IsNumber()
  departmentId: number;

  // ========== 其他信息 ==========

  /**
   * 资质证书
   */
  @IsOptional()
  @IsString()
  @MaxLength(1000, { message: '资质信息最多 1000 个字符' })
  qualifications?: string;

  /**
   * 标签数组
   */
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(50, { each: true, message: '每个标签最多 50 个字符' })
  tags?: string[];

  /**
   * 是否在职
   */
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
