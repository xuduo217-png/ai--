import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

/**
 * 医生手机号登录 DTO
 */
export class LoginDoctorPhoneDto {
  @ApiProperty({
    description: '手机号',
    example: '13800138000',
  })
  @IsString()
  @IsNotEmpty()
  phone: string;

  @ApiProperty({
    description: '密码',
    example: 'password123',
  })
  @IsString()
  @IsNotEmpty()
  password: string;
}
