import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy } from 'passport-local';
import { AuthService } from '../auth.service';

/**
 * 医生手机号本地认证策略
 * 用于医生通过手机号+密码登录
 */
@Injectable()
export class DoctorPhoneLocalStrategy extends PassportStrategy(
  Strategy,
  'doctor-phone-local',
) {
  constructor(private authService: AuthService) {
    super({
      usernameField: 'phone',
      passwordField: 'password',
    });
  }

  async validate(phone: string, password: string): Promise<any> {
    const doctor = await this.authService.validateDoctorByPhone(
      phone,
      password,
    );
    if (!doctor) {
      throw new UnauthorizedException('手机号或密码错误');
    }
    return doctor;
  }
}
