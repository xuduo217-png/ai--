import {
  Controller,
  Post,
  Body,
  UseGuards,
  Request,
  Get,
  UsePipes,
  ValidationPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { LocalAuthGuard } from './guards/local-auth.guard';
import { PhoneLocalAuthGuard } from './guards/phone-local-auth.guard';
import { DoctorPhoneLocalAuthGuard } from './guards/doctor-phone-local-auth.guard';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { RegisterDto } from './dto/register.dto';
import { LoginPhoneDto } from './dto/login-phone.dto';
import { LoginSmsDto } from './dto/login-sms.dto';
import { RegisterPhoneDto } from './dto/register-phone.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { LoginDoctorPhoneDto } from './dto/login-doctor-phone.dto';
import { VerifyCodeDto } from './dto/verify-code.dto';
import { SendSmsDto } from '../sms/dto/send-sms.dto';
import { VerificationCodeType } from './entities/verification-code.entity';
import { Public } from './decorators/public.decorator';

@ApiTags('auth')
@Controller('auth')
@UsePipes(
  new ValidationPipe({
    transform: true,
    whitelist: true,
  }),
)
export class AuthController {
  constructor(private authService: AuthService) {}

  @UseGuards(LocalAuthGuard)
  @Post('login')
  @HttpCode(HttpStatus.OK)
  async login(@Request() req) {
    return this.authService.login(req.user);
  }

  @Public()
  @Post('register')
  async register(@Body() registerDto: RegisterDto) {
    return this.authService.register(
      registerDto.username,
      registerDto.password,
      registerDto.email,
    );
  }

  @Public()
  @Post('send-code')
  @ApiOperation({ summary: '发送短信验证码' })
  async sendCode(@Body() sendSmsDto: SendSmsDto) {
    const codeType =
      sendSmsDto.type === 'reset_password'
        ? VerificationCodeType.RESET_PASSWORD
        : sendSmsDto.type === 'login'
          ? VerificationCodeType.LOGIN
          : VerificationCodeType.REGISTER;
    return this.authService.sendVerificationCode(
      sendSmsDto.phone,
      codeType,
      sendSmsDto.accountType,
    );
  }

  @Public()
  @Post('verify-code')
  @ApiOperation({ summary: '校验短信验证码（不消费）' })
  async verifyCode(@Body() verifyCodeDto: VerifyCodeDto) {
    const codeType =
      verifyCodeDto.type === 'reset_password'
        ? VerificationCodeType.RESET_PASSWORD
        : verifyCodeDto.type === 'login'
          ? VerificationCodeType.LOGIN
          : VerificationCodeType.REGISTER;

    await this.authService.verifyCodeWithoutConsume(
      verifyCodeDto.phone,
      verifyCodeDto.code,
      codeType,
      verifyCodeDto.accountType,
    );

    return { message: '验证码校验通过' };
  }

  @Public()
  @Post('register/phone')
  @ApiOperation({ summary: '手机号注册' })
  async registerWithPhone(@Body() registerPhoneDto: RegisterPhoneDto) {
    const user = await this.authService.registerWithPhone(
      registerPhoneDto.phone,
      registerPhoneDto.password,
      registerPhoneDto.code,
    );
    return this.authService.buildUserLoginResult(user);
  }

  @UseGuards(PhoneLocalAuthGuard)
  @Post('login/phone')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: '手机号+密码登录' })
  async loginWithPhone(
    @Request() req,
    @Body() loginPhoneDto: LoginPhoneDto,
  ) {
    return this.authService.loginWithPhone(req.user.phone, loginPhoneDto.password);
  }

  @UseGuards(DoctorPhoneLocalAuthGuard)
  @Post('login/doctor/phone')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: '医生手机号+密码登录' })
  async loginDoctorWithPhone(
    @Request() req,
    @Body() loginDoctorPhoneDto: LoginDoctorPhoneDto,
  ) {
    return this.authService.loginDoctorWithPhone(
      req.user.phone,
      loginDoctorPhoneDto.password,
    );
  }

  @Public()
  @Post('login/sms')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: '短信验证码登录' })
  async loginWithSms(@Body() loginSmsDto: LoginSmsDto) {
    return this.authService.loginWithSms(loginSmsDto.phone, loginSmsDto.code);
  }

  @Public()
  @Post('reset-password')
  @ApiOperation({ summary: '重置密码' })
  async resetPassword(@Body() resetPasswordDto: ResetPasswordDto) {
    return this.authService.resetPassword(
      resetPasswordDto.phone,
      resetPasswordDto.code,
      resetPasswordDto.newPassword,
      resetPasswordDto.accountType,
    );
  }

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @Get('profile')
  @ApiOperation({ summary: '获取当前用户信息' })
  getProfile(@Request() req) {
    return req.user;
  }

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @Post('logout')
  @ApiOperation({ summary: '退出登录' })
  async logout(@Request() req) {
    return this.authService.logout(req.user);
  }
}
