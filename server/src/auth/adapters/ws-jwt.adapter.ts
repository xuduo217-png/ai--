import { Injectable, UnauthorizedException, Logger } from '@nestjs/common';
import { ExecutionContext } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { UsersService } from '../../users/users.service';
import { DoctorsService } from '../../doctors/doctors.service';

/**
 * WebSocket JWT 认证守卫
 * 验证 WebSocket 连接的 JWT token，并将用户信息注入到 handshake 中
 */
@Injectable()
export class WsJwtGuard {
  private readonly logger = new Logger(WsJwtGuard.name);

  constructor(
    private jwtService: JwtService,
    private configService: ConfigService,
    private usersService: UsersService,
    private doctorsService: DoctorsService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const client = context.switchToWs().getClient();
    const token = client.handshake.auth.token;

    this.logger.log(
      `[WsJwtGuard] 验证 WebSocket token: ${token ? '存在' : '不存在'}`,
    );

    if (!token) {
      throw new UnauthorizedException('Missing token');
    }

    try {
      // 手动验证 token
      const payload = this.jwtService.verify(token, {
        secret: this.configService.get<string>('JWT_SECRET'),
      });

      this.logger.log(
        `[WsJwtGuard] Token 验证成功，payload:`,
        JSON.stringify(payload),
      );

      // 根据 type 字段查询用户
      const type = payload.type; // 'user' 或 'doctor'
      const sub = payload.sub; // 用户 ID

      let user: any = null;

      if (type === 'doctor') {
        this.logger.log(`[WsJwtGuard] 从医生表查询用户，sub=${sub}`);
        user = await this.doctorsService.findOne(sub);
        if (!user) {
          throw new UnauthorizedException('医生不存在');
        }
        const { password, ...result } = user;
        user = { ...result, type: 'doctor' };
      } else {
        this.logger.log(`[WsJwtGuard] 从用户表查询用户，sub=${sub}`);
        user = await this.usersService.findOne(sub);

        if (!user && payload.username) {
          this.logger.log(
            `[WsJwtGuard] 尝试用 username 查找: ${payload.username}`,
          );
          user = await this.usersService.findByUsername(payload.username);
        }
        if (!user && payload.phone) {
          this.logger.log(`[WsJwtGuard] 尝试用 phone 查找: ${payload.phone}`);
          user = await this.usersService.findByPhone(payload.phone);
        }

        if (!user) {
          throw new UnauthorizedException('用户不存在');
        }
        const { password, ...result } = user;
        user = { ...result, type: 'user' };
      }

      // 将用户信息注入到 client.handshake，供 ChatGateway 使用
      client.handshake.user = user;
      this.logger.log(`[WsJwtGuard] 用户信息已注入到 handshake:`, {
        id: user.id,
        type: user.type,
        username: user.username,
      });

      return true;
    } catch (error) {
      this.logger.error(`[WsJwtGuard] Token 验证失败:`, error.message);
      throw new UnauthorizedException('Invalid token');
    }
  }
}
