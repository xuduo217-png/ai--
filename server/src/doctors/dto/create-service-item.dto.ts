import {
  IsNotEmpty,
  IsString,
  IsNumber,
  Min,
  IsOptional,
  MaxLength,
  IsBoolean,
} from 'class-validator';

/**
 * 创建收费项 DTO
 */
export class CreateServiceItemDto {
  /**
   * 服务名称（如：图文咨询、电话咨询）
   */
  @IsNotEmpty({ message: '服务名称不能为空' })
  @IsString()
  @MaxLength(100, { message: '服务名称最多 100 个字符' })
  name: string;

  /**
   * 服务时长（分钟）
   */
  @IsNotEmpty({ message: '服务时长不能为空' })
  @IsNumber({}, { message: '服务时长必须为数字' })
  @Min(1, { message: '服务时长至少为 1 分钟' })
  duration: number;

  /**
   * 服务价格（元）
   */
  @IsNotEmpty({ message: '服务价格不能为空' })
  @IsNumber({}, { message: '服务价格必须为数字' })
  @Min(0, { message: '服务价格不能为负数' })
  price: number;

  /**
   * 服务描述
   */
  @IsOptional()
  @IsString()
  @MaxLength(500, { message: '服务描述最多 500 个字符' })
  description?: string;

  /**
   * 排序序号
   */
  @IsOptional()
  @IsNumber()
  sortOrder?: number;

  /**
   * 是否启用
   */
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
