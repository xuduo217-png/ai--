import {
  IsNotEmpty,
  IsDateString,
  IsEnum,
  IsOptional,
  IsNumber,
} from 'class-validator';
import { SchedulePeriod } from '../entities/schedule.entity';

export class CreateScheduleDto {
  @IsNotEmpty()
  @IsDateString()
  date: string;

  @IsNotEmpty()
  @IsEnum(SchedulePeriod)
  period: SchedulePeriod;

  @IsOptional()
  isAvailable?: boolean;

  @IsNotEmpty()
  @IsNumber()
  doctorId: number;
}
