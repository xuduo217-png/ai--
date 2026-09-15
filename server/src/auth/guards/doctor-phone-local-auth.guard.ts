import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/**
 * 医生手机号本地认证守卫
 * 使用 doctor-phone-local 策略进行认证
 */
@Injectable()
export class DoctorPhoneLocalAuthGuard extends AuthGuard(
  'doctor-phone-local',
) {}
