import { IsOptional, IsDateString, IsEnum, IsBoolean } from 'class-validator';
import { SchedulePeriod } from '../entities/schedule.entity';

export class UpdateScheduleDto {
  @IsOptional()
  @IsDateString()
  date?: string;

  @IsOptional()
  @IsEnum(SchedulePeriod)
  period?: SchedulePeriod;

  @IsOptional()
  @IsBoolean()
  isAvailable?: boolean;
}
