import {
  IsNotEmpty,
  IsString,
  IsPhoneNumber,
  MinLength,
  Length,
  IsIn,
  IsOptional,
} from 'class-validator';

export class ResetPasswordDto {
  @IsNotEmpty()
  @IsString()
  @IsPhoneNumber('CN')
  phone: string;

  @IsNotEmpty()
  @IsString()
  @Length(6, 6, { message: '验证码必须是6位数字' })
  code: string;

  @IsNotEmpty()
  @IsString()
  @MinLength(6, { message: '新密码长度不能少于6位' })
  newPassword: string;

  @IsOptional()
  @IsString()
  @IsIn(['user', 'doctor'], {
    message: '账号类型必须是 user 或 doctor',
  })
  accountType?: 'user' | 'doctor';
}
