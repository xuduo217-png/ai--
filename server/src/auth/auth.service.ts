import {
  Injectable,
  BadRequestException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan } from 'typeorm';
import { UsersService } from '../users/users.service';
import { DoctorsService } from '../doctors/doctors.service';
import { CouponService } from '../shop/coupon.service';
import { User } from '../users/entities/user.entity';
import {
  VerificationCode,
  VerificationCodeType,
} from './entities/verification-code.entity';
import { SmsService } from '../sms/sms.service';
import { AuthSessionPrincipalType, AuthSessionService } from './auth-session.service';

type ResetPasswordAccountType = 'user' | 'doctor';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  /**
   * 超级验证码（默认值）
   * 业务规则：当环境变量未配置时，默认启用 000000 作为联调兜底验证码
   */
  private readonly defaultSuperVerificationCode = '000000';
  /**
   * 当前生效的超级验证码
   */
  private readonly superVerificationCode: string;
  /**
   * 验证码发送频控窗口（毫秒）
   * 业务规则：2 分钟内最多发送 2 次，防止短信轰炸和接口滥用
   */
  private readonly sendCodeWindowMs = 2 * 60 * 1000;
  /**
   * 验证码发送频控上限
   */
  private readonly sendCodeMaxCount = 2;

  constructor(
    private usersService: UsersService,
    private doctorsService: DoctorsService,
    private couponService: CouponService,
    private jwtService: JwtService,
    private smsService: SmsService,
    private configService: ConfigService,
    private authSessionService: AuthSessionService,
    @InjectRepository(VerificationCode)
    private verificationCodeRepository: Repository<VerificationCode>,
  ) {
    this.superVerificationCode =
      this.configService.get<string>('SMS_SUPER_CODE')?.trim() ||
      this.defaultSuperVerificationCode;
  }

  async validateUser(
    username: string,
    password: string,
  ): Promise<Omit<User, 'password'> | null> {
    const user = await this.usersService.validateUser(username, password);
    if (user) {
      const { password, ...result } = user;
      return result;
    }
    return null;
  }

  async login(user: Omit<User, 'password'>) {
    await this.usersService.updateLastLogin(user.id);
    return this.buildUserLoginResult(user);
  }

  async register(username: string, password: string, email: string) {
    // 使用邮箱注册，需要额外的 phone 参数
    // 这里使用 username 作为默认 phone
    const user = await this.usersService.create({
      username,
      password,
      email,
      phone: username, // 暂时使用 username 作为 phone
    });
    const { password: _, ...result } = user;
    return result;
  }

  async validateUserByPhone(
    phone: string,
    password: string,
  ): Promise<Omit<User, 'password'> | null> {
    const user = await this.usersService.validateUserByPhone(phone, password);
    if (user) {
      const { password, ...result } = user;
      return result;
    }
    return null;
  }

  async loginWithPhone(phone: string, password: string) {
    const user = await this.validateUserByPhone(phone, password);
    if (!user) {
      throw new BadRequestException('手机号或密码错误');
    }

    // 更新最后登录时间
    await this.usersService.updateLastLogin(user.id);
    return this.buildUserLoginResult(user);
  }

  /**
   * 医生手机号+密码登录
   */
  async loginDoctorWithPhone(phone: string, password: string) {
    const doctor = await this.doctorsService.validateDoctorByPhone(
      phone,
      password,
    );
    return this.buildDoctorLoginResult(doctor);
  }

  /**
   * 验证医生手机号+密码（用于 Strategy）
   * 与 DoctorsService.validateDoctorByPhone 的区别：
   * 这个方法捕获异常并返回 null，供 Passport Strategy 使用
   */
  async validateDoctorByPhone(phone: string, password: string): Promise<any> {
    try {
      return await this.doctorsService.validateDoctorByPhone(phone, password);
    } catch (error) {
      return null;
    }
  }

  async sendVerificationCode(
    phone: string,
    type: VerificationCodeType,
    accountType: ResetPasswordAccountType = 'user',
  ) {
    if (type === VerificationCodeType.REGISTER) {
      const existingUser = await this.usersService.findByPhone(phone);
      if (existingUser) {
        throw new ConflictException('手机号已被注册');
      }
    }

    if (type === VerificationCodeType.RESET_PASSWORD) {
      await this.assertResetPasswordTargetExists(phone, accountType);
    }

    // 检查频率限制：同一手机号 2 分钟内最多 2 条（跨业务类型统一限制）
    const windowStart = new Date(Date.now() - this.sendCodeWindowMs);
    const recentCodes = await this.verificationCodeRepository.count({
      where: {
        phone,
        createdAt: MoreThan(windowStart) as any,
      },
    });

    if (recentCodes >= this.sendCodeMaxCount) {
      throw new BadRequestException('发送过于频繁，请2分钟后再试');
    }

    // 生成并发送验证码
    const { code, expiresIn } = await this.smsService.sendVerificationCode(
      phone,
      type,
    );

    // 保存验证码记录
    const expiredAt = new Date(Date.now() + expiresIn * 1000);
    const verificationCode = this.verificationCodeRepository.create({
      phone,
      code,
      type,
      expiredAt,
      used: false,
    });
    await this.verificationCodeRepository.save(verificationCode);

    return {
      message: '验证码已发送',
      expiresIn,
    };
  }

  async verifyCode(
    phone: string,
    code: string,
    type: VerificationCodeType,
  ): Promise<boolean> {
    return this.validateVerificationCode(phone, code, type, true);
  }

  /**
   * 仅校验验证码是否有效（不消费验证码）
   * 用于注册流程“下一步”前置校验，避免无效验证码进入设置密码页
   */
  async verifyCodeWithoutConsume(
    phone: string,
    code: string,
    type: VerificationCodeType,
    accountType: ResetPasswordAccountType = 'user',
  ): Promise<boolean> {
    if (type === VerificationCodeType.RESET_PASSWORD) {
      await this.assertResetPasswordTargetExists(phone, accountType);
    }

    return this.validateVerificationCode(phone, code, type, false);
  }

  /**
   * 验证验证码（支持“仅校验”与“校验并消费”两种模式）
   * 业务规则：
   * 1. 只允许最新验证码有效，旧验证码作废
   * 2. 默认消费验证码，防止重复使用
   */
  private async validateVerificationCode(
    phone: string,
    code: string,
    type: VerificationCodeType,
    shouldConsume: boolean,
  ): Promise<boolean> {
    // 超级验证码用于测试/联调兜底，命中后直接放行，不依赖数据库记录
    if (code === this.superVerificationCode) {
      this.logger.warn(
        `[超级验证码放行] phone=${phone}, type=${type}, consume=${shouldConsume}`,
      );
      return true;
    }

    // 只允许最新验证码参与校验，旧验证码即使未过期也视为无效
    const latestVerificationCode = await this.verificationCodeRepository.findOne({
      where: { phone, type, used: false },
      order: { createdAt: 'DESC' },
    });

    if (!latestVerificationCode) {
      throw new BadRequestException('验证码错误或已过期');
    }

    if (latestVerificationCode.expiredAt < new Date()) {
      throw new BadRequestException('验证码已过期');
    }

    if (latestVerificationCode.code !== code) {
      throw new BadRequestException('验证码错误');
    }

    // 仅校验时不消费验证码，供前置检查使用
    if (!shouldConsume) {
      return true;
    }

    // 使用原子更新防止并发场景下同一验证码被重复消费
    const usedAt = new Date();
    const updateResult = await this.verificationCodeRepository.update(
      {
        id: latestVerificationCode.id,
        used: false,
      },
      {
        used: true,
        usedAt,
      },
    );

    if (!updateResult.affected) {
      throw new BadRequestException('验证码已失效，请重新获取');
    }

    return true;
  }

  async registerWithPhone(phone: string, password: string, code: string) {
    // 验证验证码
    await this.verifyCode(phone, code, VerificationCodeType.REGISTER);

    // 创建用户
    const user = await this.usersService.createWithPhone(phone, password);

    // 验证手机号
    await this.usersService.verifyPhone(phone);

    // 自动为新用户领取优惠券
    try {
      const claimedCoupons = await this.couponService.claimCouponsForNewUser(user.id);

      if (claimedCoupons.length > 0) {
        this.logger.log(`用户 ${user.id} 注册成功，自动领取了 ${claimedCoupons.length} 张优惠券`);
      }
    } catch (error) {
      // 领取优惠券失败不影响注册流程
      this.logger.error(`自动领取优惠券失败:`, error);
    }

    const { password: _, ...result } = user;
    return result;
  }

  async loginWithSms(phone: string, code: string) {
    // 验证验证码（使用 LOGIN 类型）
    await this.verifyCode(phone, code, VerificationCodeType.LOGIN);

    // 查找用户
    const user = await this.usersService.findByPhone(phone);
    if (!user) {
      throw new BadRequestException('用户不存在，请先注册');
    }

    // 更新最后登录时间
    await this.usersService.updateLastLogin(user.id);
    return this.buildUserLoginResult(user);
  }

  async resetPassword(
    phone: string,
    code: string,
    newPassword: string,
    accountType: ResetPasswordAccountType = 'user',
  ) {
    const target = await this.assertResetPasswordTargetExists(
      phone,
      accountType,
    );

    // 验证验证码并消费，防止同一验证码重复改密
    await this.verifyCode(phone, code, VerificationCodeType.RESET_PASSWORD);

    if (accountType === 'doctor') {
      await this.doctorsService.update(target.id, { password: newPassword });
    } else {
      await this.usersService.update(target.id, { password: newPassword });
    }

    return { message: '密码重置成功' };
  }

  private async assertResetPasswordTargetExists(
    phone: string,
    accountType: ResetPasswordAccountType,
  ): Promise<{ id: number }> {
    if (accountType === 'doctor') {
      const doctor = await this.doctorsService.findByPhone(phone);
      if (!doctor) {
        throw new BadRequestException('医生不存在');
      }
      return doctor;
    }

    const user = await this.usersService.findByPhone(phone);
    if (!user) {
      throw new BadRequestException('用户不存在');
    }
    return user;
  }

  /**
   * 撤销当前登录会话
   */
  async logout(user: { id: number; type?: AuthSessionPrincipalType; sid?: string }) {
    await this.authSessionService.revokeSession(user.type || 'user', user.id, user.sid);
    return { message: '退出登录成功' };
  }

  /**
   * 生成用户登录结果
   * 业务规则：所有用户登录入口必须走同一套 sid 签发逻辑，确保单点登录约束一致。
   */
  async buildUserLoginResult(user: Omit<User, 'password'>) {
    const sid = await this.authSessionService.issueSession('user', user.id);
    const payload = this.buildAuthPayload('user', user.id, sid, {
      username: user.username,
      phone: user.phone,
      role: user.role,
    });

    return {
      access_token: this.jwtService.sign(payload),
      user: {
        id: user.id,
        phone: user.phone,
        username: user.username,
        email: user.email,
        role: user.role,
        verified: user.verified,
      },
    };
  }

  /**
   * 生成医生登录结果
   * 业务规则：医生与普通用户共享单点登录策略，但 Redis key 必须按 type 隔离。
   */
  async buildDoctorLoginResult(doctor: any) {
    const sid = await this.authSessionService.issueSession('doctor', doctor.id);
    const payload = this.buildAuthPayload('doctor', doctor.id, sid, {
      phone: doctor.phone,
      role: 'DOCTOR',
    });

    return {
      access_token: this.jwtService.sign(payload),
      doctor: {
        id: doctor.id,
        phone: doctor.phone,
        username: doctor.username,
        name: doctor.name,
        specialty: doctor.specialty,
        hospitalId: doctor.hospitalId,
        departmentId: doctor.departmentId,
        avatar: doctor.avatar,
      },
    };
  }

  /**
   * 构建 JWT 载荷
   */
  private buildAuthPayload(
    type: AuthSessionPrincipalType,
    principalId: number,
    sid: string,
    extraPayload: Record<string, unknown>,
  ) {
    return {
      ...extraPayload,
      sub: principalId,
      type,
      sid,
    };
  }
}
