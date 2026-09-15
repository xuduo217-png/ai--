import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { UsersModule } from '../users/users.module';
import { DoctorsModule } from '../doctors/doctors.module';
import { SmsModule } from '../sms/sms.module';
import { ShopModule } from '../shop/shop.module';
import { JwtStrategy } from './strategies/jwt.strategy';
import { LocalStrategy } from './strategies/local.strategy';
import { PhoneLocalStrategy } from './strategies/phone-local.strategy';
import { DoctorPhoneLocalStrategy } from './strategies/doctor-phone-local.strategy';
import { VerificationCode } from './entities/verification-code.entity';
import { LoginHistory } from './entities/login-history.entity';
import { LoginHistoryService } from './login-history.service';
import { LoginHistoryController } from './login-history.controller';
import { RedisModule } from '../redis/redis.module';
import { AuthSessionService } from './auth-session.service';

@Module({
  imports: [
    UsersModule,
    DoctorsModule,
    SmsModule,
    ShopModule,
    RedisModule,
    PassportModule,
    TypeOrmModule.forFeature([VerificationCode, LoginHistory]),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_SECRET') || 'default-secret',
        signOptions: {
          // 设置为 100 年，实际上 token 不会过期
          expiresIn: '100y',
        },
      }),
      inject: [ConfigService],
    }),
  ],
  controllers: [AuthController, LoginHistoryController],
  providers: [
    AuthService,
    AuthSessionService,
    LoginHistoryService,
    JwtStrategy,
    LocalStrategy,
    PhoneLocalStrategy,
    DoctorPhoneLocalStrategy,
  ],
  exports: [AuthService, AuthSessionService, LoginHistoryService],
})
export class AuthModule {}
