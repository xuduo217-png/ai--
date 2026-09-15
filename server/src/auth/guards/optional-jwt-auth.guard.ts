import { Injectable, ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/**
 * 可选 JWT 认证守卫
 * 即使没有 token 也能访问，但如果提供了 token 则会验证并填充 req.user
 * 用于需要识别用户但不强制要求登录的接口
 */
@Injectable()
export class OptionalJwtAuthGuard extends AuthGuard('jwt') {
  canActivate(context: ExecutionContext) {
    // 先让父类尝试验证 JWT
    return super.canActivate(context);
  }

  // 重写 handleRequest，使其在认证失败时不抛出异常
  handleRequest(err, user, info, context) {
    // 如果 Passport 认证成功，user 会包含用户信息
    // 如果 Passport 认证失败或没有 token，user 会是 null
    // 无论哪种情况，我们都继续执行，不抛出异常
    if (err || !user) {
      // 认证失败或没有 token，不抛出异常，直接返回
      // req.user 会保持 undefined
      return;
    }
    // 认证成功，返回用户信息，这会被赋值给 req.user
    return user;
  }
}
