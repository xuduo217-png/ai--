import {
  IsNotEmpty,
  IsString,
  IsOptional,
  IsPhoneNumber,
  IsNumber,
  Min,
  Max,
  IsEmail,
  IsEnum,
  MaxLength,
  ValidateNested,
  IsBoolean,
} from 'class-validator';
import { HospitalStatus } from '../entities/hospital.entity';
import { Type } from 'class-transformer';

export class BusinessHoursDto {
  @IsOptional()
  @IsString()
  open?: string;

  @IsOptional()
  @IsString()
  close?: string;

  @IsOptional()
  isClosed?: boolean;
}

export class CreateHospitalDto {
  @IsNotEmpty()
  @IsString()
  @MaxLength(100)
  name: string;

  @IsOptional()
  @IsString()
  logo?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @IsNotEmpty()
  @IsString()
  province: string;

  @IsNotEmpty()
  @IsString()
  city: string;

  @IsNotEmpty()
  @IsString()
  county: string;

  @IsNotEmpty()
  @IsString()
  @MaxLength(500)
  address: string;

  @IsNotEmpty()
  @IsString()
  phone: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  businessHours?: {
    monday?: BusinessHoursDto;
    tuesday?: BusinessHoursDto;
    wednesday?: BusinessHoursDto;
    thursday?: BusinessHoursDto;
    friday?: BusinessHoursDto;
    saturday?: BusinessHoursDto;
    sunday?: BusinessHoursDto;
  };

  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;

  @IsOptional()
  @IsEnum(HospitalStatus)
  status?: HospitalStatus;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean; // 前端使用的布尔值字段

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  facilities?: string;
}
