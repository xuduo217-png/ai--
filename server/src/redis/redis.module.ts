import { Module, Global } from '@nestjs/common';
import { RedisService } from './redis.service';

/**
 * Redis 模块
 * 提供缓存、临时存储等功能
 * 使用 @Global() 装饰器使模块在整个应用中可用
 */
@Global()
@Module({
  providers: [RedisService],
  exports: [RedisService],
})
export class RedisModule {}
