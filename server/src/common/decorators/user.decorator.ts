import { createParamDecorator, ExecutionContext } from '@nestjs/common';

/**
 * 从请求中获取用户信息
 * 如果请求中包含有效的 JWT token，则返回用户对象；否则返回 undefined
 * 用于需要可选认证的接口
 */
export const GetUser = createParamDecorator(
  (data: unknown, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    return request.user;
  },
);
