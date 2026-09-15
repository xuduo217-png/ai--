import { Injectable, UnauthorizedException, Logger } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { UsersService } from '../../users/users.service';
import { DoctorsService } from '../../doctors/doctors.service';
import { AuthSessionService } from '../auth-session.service';

/**
 * JWT 验证策略
 * 根据 token 中的 type 字段区分用户和医生，从不同的表中查询数据
 */
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  private readonly logger = new Logger(JwtStrategy.name);

  constructor(
    private configService: ConfigService,
    private usersService: UsersService,
    private doctorsService: DoctorsService,
    private authSessionService: AuthSessionService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      // Token 统一签发为超长有效期，但过期 token 仍应在网关层被拒绝，
      // 这样移动端登录失效处理才能稳定收到 401。
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('JWT_SECRET'),
    });
  }

  async validate(payload: any) {
    // 从 token 中提取用户类型和 ID
    const type = payload.type; // 'user' 或 'doctor'
    const sub = payload.sub; // 用户 ID
    const sid = payload.sid;

    await this.authSessionService.assertSession(type, sub, sid);

    let user: any = null;

    try {
      // 根据 type 字段从不同的表中查询用户
      if (type === 'doctor') {
        // 医生：从医生表查询
        user = await this.doctorsService.findOne(sub);
        if (!user) {
          throw new UnauthorizedException('医生不存在');
        }
        if (user.isActive === false) {
          throw new UnauthorizedException('医生账号已停用');
        }
        // 返回医生信息，添加 type 字段标识
        const { password, ...result } = user;
        return { ...result, type: 'doctor', sid };
      } else {
        // 普通用户：从用户表查询
        // 优先使用 ID 查询，如果失败则尝试使用 username 查询（兼容旧 token）
        user = await this.usersService.findOne(sub);

        if (!user && payload.username) {
          user = await this.usersService.findByUsername(payload.username);
        }
        if (!user && payload.phone) {
          user = await this.usersService.findByPhone(payload.phone);
        }

        if (!user) {
          throw new UnauthorizedException('用户不存在');
        }

        if (user.isActive === false) {
          throw new UnauthorizedException('账号已注销或停用');
        }

        // 返回用户信息，添加 type 字段标识
        const { password, ...result } = user;
        const finalUser = { ...result, type: 'user', sid };

        return finalUser;
      }
    } catch (error) {
      throw error;
    }
  }
}
