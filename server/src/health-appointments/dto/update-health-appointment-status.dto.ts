import { IsNotEmpty, IsEnum, IsOptional, IsNumber } from 'class-validator';
import { HealthAppointmentStatus } from '../entities/health-appointment.entity';

/**
 * 更新健康预约状态 DTO
 */
export class UpdateHealthAppointmentStatusDto {
  @IsNotEmpty()
  @IsEnum(HealthAppointmentStatus)
  status: HealthAppointmentStatus;

  @IsOptional()
  @IsNumber()
  doctorId?: number; // 医生ID（关联 doctors 表）
}
