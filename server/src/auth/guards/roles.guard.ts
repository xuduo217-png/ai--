import {
  Injectable,
  CanActivate,
  ExecutionContext,
  Logger,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';

@Injectable()
export class RolesGuard implements CanActivate {
  private readonly logger = new Logger(RolesGuard.name);

  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>('roles', [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredRoles) {
      return true;
    }

    const { user } = context.switchToHttp().getRequest();
    // 兼容 role 和 type 两种字段，并统一转为大写进行比较
    const userRole = (user?.role || user?.type)?.toUpperCase();
    this.logger.debug(`Required roles: ${JSON.stringify(requiredRoles)}`);
    // 只记录必要的字段，避免泄露敏感信息
    this.logger.debug(`User role: ${userRole}, User ID: ${user?.id || user?.sub}`);

    const hasRole = requiredRoles.some(
      (role) => userRole === role.toUpperCase(),
    );
    this.logger.debug(`Has role: ${hasRole}`);

    return hasRole;
  }
}
