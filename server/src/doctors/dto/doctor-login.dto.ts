import { IsNotEmpty, IsString, MinLength } from 'class-validator';

/**
 * 医生登录 DTO
 */
export class DoctorLoginDto {
  /**
   * 登录用户名
   */
  @IsNotEmpty()
  @IsString()
  username: string;

  /**
   * 登录密码
   */
  @IsNotEmpty()
  @IsString()
  @MinLength(6, { message: '密码长度至少 6 位' })
  password: string;
}
