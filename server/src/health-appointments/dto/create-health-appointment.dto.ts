import {
  IsNotEmpty,
  IsNumber,
  IsDateString,
  IsString,
  IsOptional,
  MaxLength,
  IsEnum,
  IsIn,
} from 'class-validator';
import { HealthAppointmentType } from '../entities/health-appointment.entity';

/**
 * 时间槽位常量
 */
export const TIME_SLOTS = [
  '09:00-10:00',
  '10:00-11:00',
  '11:00-12:00',
  '13:00-14:00',
  '14:00-15:00',
  '15:00-16:00',
  '16:00-17:00',
  '17:00-18:00',
];

/**
 * 创建健康预约 DTO
 */
export class CreateHealthAppointmentDto {
  @IsNotEmpty()
  @IsNumber()
  petId: number;

  @IsNotEmpty()
  @IsNumber()
  hospitalId: number;

  @IsNotEmpty()
  @IsEnum(HealthAppointmentType)
  type: HealthAppointmentType;

  @IsNotEmpty()
  @IsDateString()
  appointmentDate: string;

  @IsNotEmpty()
  @IsString()
  @IsIn(TIME_SLOTS, {
    message: `时间槽位必须是以下之一: ${TIME_SLOTS.join(', ')}`,
  })
  timeSlot: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}
