import {
  IsEmail,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';
import { UserRole } from '../entities/user.entity';

/**
 * 创建用户 DTO
 * 用于管理员创建新用户
 */
export class CreateUserDto {
  @IsOptional()
  @IsString()
  username?: string;

  @IsNotEmpty()
  @IsString()
  @MinLength(6, { message: '密码长度至少 6 位' })
  password: string;

  @IsOptional()
  @IsEmail({}, { message: '邮箱格式不正确' })
  email?: string;

  @IsNotEmpty()
  @IsString()
  phone: string;

  @IsEnum(UserRole)
  @IsOptional()
  role?: UserRole;

  @IsOptional()
  @IsString()
  avatar?: string;

  @IsOptional()
  hospitalId?: number;
}
