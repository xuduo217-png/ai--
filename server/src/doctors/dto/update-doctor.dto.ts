import {
  IsOptional,
  IsString,
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
 * 更新医生信息 DTO
 * 所有字段都是可选的，支持部分更新
 */
export class UpdateDoctorDto {
  // ========== 账号信息 ==========

  /**
   * 登录用户名
   */
  @IsOptional()
  @IsString()
  @MaxLength(50, { message: '用户名最多 50 个字符' })
  username?: string;

  /**
   * 登录密码（如需修改密码时提供）
   */
  @IsOptional()
  @IsString()
  @MinLength(6, { message: '密码长度至少 6 位' })
  password?: string;

  /**
   * 手机号
   */
  @IsOptional()
  @IsPhoneNumber('CN')
  @IsString()
  phone?: string;

  // ========== 基本信息 ==========

  /**
   * 医生姓名
   */
  @IsOptional()
  @IsString()
  @MaxLength(50, { message: '姓名最多 50 个字符' })
  name?: string;

  /**
   * 头像 URL
   */
  @IsOptional()
  @IsString()
  avatar?: string;

  /**
   * 专业领域/专长
   */
  @IsOptional()
  @IsString()
  @MaxLength(100, { message: '专长最多 100 个字符' })
  specialty?: string;

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
   * 评分（0-5）
   */
  @IsOptional()
  @IsNumber()
  @Min(0, { message: '评分最小为 0' })
  @Max(5, { message: '评分最大为 5' })
  rating?: number;

  /**
   * 是否为金牌医师
   */
  @IsOptional()
  @IsBoolean()
  isGoldDoctor?: boolean;

  /**
   * 已支付咨询订单数（兼容历史数据维护，读取时以订单实时统计为准）
   */
  @IsOptional()
  @IsNumber()
  @Min(0, { message: '咨询次数不能为负数' })
  consultationCount?: number;

  /**
   * 是否在职
   */
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  /**
   * 最后登录时间
   */
  @IsOptional()
  lastLoginAt?: Date;

  // ========== 关联信息 ==========

  /**
   * 所属医院 ID
   */
  @IsOptional()
  @IsNumber()
  hospitalId?: number;

  /**
   * 所属科室 ID
   */
  @IsOptional()
  @IsNumber()
  departmentId?: number;

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
}
