import {
  IsNotEmpty,
  IsNumber,
  IsString,
  IsOptional,
  MaxLength,
  IsDateString,
} from 'class-validator';

export class ConfirmAppointmentDto {
  @IsNotEmpty()
  @IsNumber()
  doctorId: number;

  @IsNotEmpty()
  @IsDateString()
  appointmentTime: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  symptoms?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;

  @IsOptional()
  @IsDateString()
  nextAppointmentTime?: string;
}
