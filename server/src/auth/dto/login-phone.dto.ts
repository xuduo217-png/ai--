import {
  IsNotEmpty,
  IsString,
  IsPhoneNumber,
  MinLength,
} from 'class-validator';

export class LoginPhoneDto {
  @IsNotEmpty()
  @IsString()
  @IsPhoneNumber('CN')
  phone: string;

  @IsNotEmpty()
  @IsString()
  @MinLength(6, { message: '密码长度不能少于6位' })
  password: string;
}
