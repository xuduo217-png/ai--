import { IsNotEmpty, IsString, IsPhoneNumber, Length } from 'class-validator';

export class LoginSmsDto {
  @IsNotEmpty()
  @IsString()
  @IsPhoneNumber('CN')
  phone: string;

  @IsNotEmpty()
  @IsString()
  @Length(6, 6, { message: '验证码必须是6位数字' })
  code: string;
}
