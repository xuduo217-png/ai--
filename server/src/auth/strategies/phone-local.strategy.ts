import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy } from 'passport-local';
import { AuthService } from '../auth.service';

@Injectable()
export class PhoneLocalStrategy extends PassportStrategy(
  Strategy,
  'phone-local',
) {
  constructor(private authService: AuthService) {
    super({
      usernameField: 'phone',
      passwordField: 'password',
    });
  }

  async validate(phone: string, password: string): Promise<any> {
    const user = await this.authService.validateUserByPhone(phone, password);
    if (!user) {
      throw new UnauthorizedException('手机号或密码错误');
    }
    return user;
  }
}
