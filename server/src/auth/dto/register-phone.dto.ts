import {
  IsNotEmpty,
  IsString,
  IsPhoneNumber,
  MinLength,
  Length,
} from 'class-validator';

export class RegisterPhoneDto {
  @IsNotEmpty()
  @IsString()
  @IsPhoneNumber('CN')
  phone: string;

  @IsNotEmpty()
  @IsString()
  @MinLength(6, { message: '密码长度不能少于6位' })
  password: string;

  @IsNotEmpty()
  @IsString()
  @Length(6, 6, { message: '验证码必须是6位数字' })
  code: string;
}
