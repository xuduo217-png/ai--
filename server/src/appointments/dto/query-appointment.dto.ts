import {
  IsOptional,
  IsEnum,
  IsString,
  IsInt,
  IsDateString,
  Min,
} from 'class-validator';
import {
  AppointmentStatus,
  AppointmentType,
} from '../entities/appointment.entity';
import { Type } from 'class-transformer';
import { PaginationDto } from '../../common/dto/pagination.dto';

export class QueryAppointmentDto extends PaginationDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  hospitalId?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  doctorId?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  userId?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  petId?: number;

  @IsOptional()
  @IsEnum(AppointmentStatus)
  status?: AppointmentStatus;

  @IsOptional()
  @IsEnum(AppointmentType)
  type?: AppointmentType;

  @IsOptional()
  @IsDateString()
  startDate?: string;

  @IsOptional()
  @IsDateString()
  endDate?: string;

  @IsOptional()
  @IsString()
  keyword?: string;

  @IsOptional()
  @IsString()
  sortBy?: 'createdAt' | 'appointmentTime' | 'updatedAt' = 'createdAt';
}
