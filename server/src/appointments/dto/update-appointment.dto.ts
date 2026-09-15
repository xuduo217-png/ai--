import {
  IsOptional,
  IsDateString,
  IsString,
  MaxLength,
  IsEnum,
  IsNumber,
} from 'class-validator';
import {
  AppointmentStatus,
  AppointmentType,
} from '../entities/appointment.entity';

export class UpdateAppointmentDto {
  @IsOptional()
  @IsDateString()
  appointmentTime?: string;

  @IsOptional()
  @IsEnum(AppointmentType)
  type?: AppointmentType;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  symptoms?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  diagnosis?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  treatment?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;

  @IsOptional()
  @IsNumber()
  doctorId?: number;

  @IsOptional()
  @IsEnum(AppointmentStatus)
  status?: AppointmentStatus;

  @IsOptional()
  @IsDateString()
  nextAppointmentTime?: string;
}
