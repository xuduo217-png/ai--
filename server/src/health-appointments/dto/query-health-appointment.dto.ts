import { IsOptional, IsEnum, IsNumber, IsString } from 'class-validator';
import { Type } from 'class-transformer';
import { PaginationDto } from '../../common/dto/pagination.dto';
import {
  HealthAppointmentType,
  HealthAppointmentStatus,
} from '../entities/health-appointment.entity';

/**
 * 查询健康预约 DTO
 */
export class QueryHealthAppointmentDto extends PaginationDto {
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  petId?: number;

  @IsOptional()
  @IsString()
  petName?: string; // 宠物名称（模糊搜索）

  @IsOptional()
  @IsString()
  ownerPhone?: string; // 主人手机号（精确匹配）

  @IsOptional()
  @IsEnum(HealthAppointmentType)
  type?: HealthAppointmentType;

  @IsOptional()
  @Type(() => String)
  status?: HealthAppointmentStatus | HealthAppointmentStatus[] | string; // 支持单个状态、状态数组或逗号分隔的字符串

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  hospitalId?: number;
}
