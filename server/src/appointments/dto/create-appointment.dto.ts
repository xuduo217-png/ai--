import {
  IsNotEmpty,
  IsNumber,
  IsDateString,
  IsString,
  IsOptional,
  MaxLength,
  IsEnum,
} from 'class-validator';
import { AppointmentType } from '../entities/appointment.entity';

export class CreateAppointmentDto {
  @IsNotEmpty()
  @IsNumber()
  petId: number;

  @IsNotEmpty()
  @IsNumber()
  hospitalId: number;

  @IsNotEmpty()
  @IsDateString()
  appointmentTime: string;

  @IsNotEmpty()
  @IsEnum(AppointmentType)
  type: AppointmentType;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  symptoms?: string;
}
