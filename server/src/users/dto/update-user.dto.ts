import {
  IsOptional,
  IsString,
  IsEmail,
  MinLength,
  IsEnum,
  IsIn,
} from 'class-validator';
import { UserRole } from '../entities/user.entity';

export class UpdateUserDto {
  @IsOptional()
  @IsString()
  username?: string;

  @IsOptional()
  @IsString()
  @MinLength(6)
  password?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;

  @IsOptional()
  @IsString()
  avatar?: string;

  @IsOptional()
  @IsString()
  phone?: string;

  @IsOptional()
  @IsIn([0, 1, 2])
  gender?: 0 | 1 | 2;

  @IsOptional()
  isActive?: boolean;
}
