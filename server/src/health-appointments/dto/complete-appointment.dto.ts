import { IsDateString, IsString, IsOptional, MaxLength } from 'class-validator';

/**
 * 完成健康预约 DTO
 * 用于完成预约时更新宠物健康记录
 */
export class CompleteAppointmentDto {
  /**
   * 下次预约日期（可选）
   * 如果提供，将更新宠物表的对应下次预约时间字段
   */
  @IsOptional()
  @IsDateString()
  nextAppointmentDate?: string;

  /**
   * 本次操作内容（可选）
   * 如：接种疫苗、驱虫处理、体检项目等
   */
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  operationContent?: string;

  /**
   * 详情内容（可选）
   * 支持富文本格式，记录详细的操作过程和结果
   */
  @IsOptional()
  @IsString()
  detailContent?: string;

  /**
   * 备注（可选）
   */
  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}
