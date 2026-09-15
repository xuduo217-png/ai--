import {
  IsNotEmpty,
  IsString,
  IsPhoneNumber,
  Length,
  IsIn,
  IsOptional,
} from 'class-validator';

/**
 * 验证码校验请求参数
 * 用于“下一步”前的前置验码，只做有效性检查，不会消费验证码
 */
export class VerifyCodeDto {
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
  @IsIn(['register', 'login', 'reset_password'], {
    message: '验证码类型必须是 register、login 或 reset_password',
  })
  type: 'register' | 'login' | 'reset_password';

  @IsOptional()
  @IsString()
  @IsIn(['user', 'doctor'], {
    message: '账号类型必须是 user 或 doctor',
  })
  accountType?: 'user' | 'doctor';
}
