import {
  IsNotEmpty,
  IsString,
  IsPhoneNumber,
  IsIn,
  IsOptional,
} from 'class-validator';

export class SendSmsDto {
  @IsNotEmpty()
  @IsString()
  @IsPhoneNumber('CN')
  phone: string;

  @IsNotEmpty()
  @IsString()
  @IsIn(['register', 'reset_password', 'login'], {
    message: '类型必须是 register、reset_password 或 login',
  })
  type: 'register' | 'reset_password' | 'login';

  @IsOptional()
  @IsString()
  @IsIn(['user', 'doctor'], {
    message: '账号类型必须是 user 或 doctor',
  })
  accountType?: 'user' | 'doctor';
}
