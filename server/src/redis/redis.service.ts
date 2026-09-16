import { Injectable, Logger, OnModuleDestroy } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import Redis from "ioredis";

/**
 * Redis 服务
 * 提供缓存、临时存储、会话管理等功能
 */
@Injectable()
export class RedisService implements OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private readonly client: Redis;

  constructor(private configService: ConfigService) {
    // 创建 Redis 客户端实例
    this.client = new Redis({
      host: this.configService.get("REDIS_HOST", "localhost"),
      port: this.configService.get("REDIS_PORT", 6379),
      password: this.configService.get("REDIS_PASSWORD"),
      db: this.configService.get<number>("REDIS_DB", 0),
      // 启用键空间通知以支持过期事件
      enableReadyCheck: true,
      lazyConnect: false,
    });

    // 连接成功事件
    this.client.on("connect", () => {
      this.logger.log("Redis 连接成功");
    });

    // 连接就绪事件
    this.client.on("ready", () => {
      this.logger.log("Redis 就绪");
    });

    // 连接错误事件
    this.client.on("error", (err) => {
      this.logger.error("Redis 连接错误", err);
    });

    // 连接关闭事件
    this.client.on("close", () => {
      this.logger.warn("Redis 连接关闭");
    });

    // 重新连接事件
    this.client.on("reconnecting", () => {
      this.logger.log("Redis 正在重新连接...");
    });
  }

  /**
   * 设置键值对
   * @param key 键
   * @param value 值
   * @param ttl 过期时间（秒），可选
   */
  async set(key: string, value: string, ttl?: number): Promise<void> {
    if (ttl) {
      // 设置带过期时间的键值
      await this.client.setex(key, ttl, value);
    } else {
      // 设置永久键值
      await this.client.set(key, value);
    }
  }

  /**
   * 获取值
   * @param key 键
   * @returns 值，不存在返回 null
   */
  async get(key: string): Promise<string | null> {
    return this.client.get(key);
  }

  /**
   * 从列表左侧推入元素
   * @param key 列表键
   * @param value 元素值
   * @returns 列表长度
   */
  async lpush(key: string, value: string): Promise<number> {
    return this.client.lpush(key, value);
  }

  /**
   * 获取列表范围内的元素
   * @param key 列表键
   * @param start 起始位置（0 表示第一个元素）
   * @param stop 结束位置（-1 表示到最后一个元素）
   * @returns 元素数组
   */
  async lrange(key: string, start: number, stop: number): Promise<string[]> {
    return this.client.lrange(key, start, stop);
  }

  /** 更新列表指定位置的元素。 */
  async lset(key: string, index: number, value: string): Promise<void> {
    await this.client.lset(key, index, value);
  }

  /**
   * 删除键
   * @param keys 键（支持多个）
   * @returns 删除的键数量
   */
  async del(...keys: string[]): Promise<number> {
    return this.client.del(...keys);
  }

  /**
   * 设置哈希字段
   * @param key 哈希键
   * @param field 字段名
   * @param value 字段值
   * @returns 添加的字段数量（1 表示新增，0 表示更新）
   */
  async hset(key: string, field: string, value: string): Promise<number> {
    return this.client.hset(key, field, value);
  }

  /**
   * 获取哈希字段值
   * @param key 哈希键
   * @param field 字段名
   * @returns 字段值，不存在返回 null
   */
  async hget(key: string, field: string): Promise<string | null> {
    return this.client.hget(key, field);
  }

  /**
   * 批量获取哈希字段值
   * @param key 哈希键
   * @param fields 字段名数组
   * @returns 字段值数组
   */
  async hmget(key: string, ...fields: string[]): Promise<(string | null)[]> {
    return this.client.hmget(key, ...fields);
  }

  /**
   * 删除哈希字段
   * @param key 哈希键
   * @param fields 字段名数组
   * @returns 删除的字段数量
   */
  async hdel(key: string, ...fields: string[]): Promise<number> {
    return this.client.hdel(key, ...fields);
  }

  /**
   * 获取哈希所有字段和值
   * @param key 哈希键
   * @returns 字段和值的对象
   */
  async hgetall(key: string): Promise<Record<string, string>> {
    return this.client.hgetall(key);
  }

  /**
   * 增加哈希字段值
   * @param key 哈希键
   * @param field 字段名
   * @param increment 增量（可以是负数）
   * @returns 增加后的字段值
   */
  async hincrby(
    key: string,
    field: string,
    increment: number,
  ): Promise<number> {
    return this.client.hincrby(key, field, increment);
  }

  /**
   * 添加成员到有序集合
   * @param key 有序集合键
   * @param score 分数
   * @param member 成员
   * @returns 添加的成员数量
   */
  async zadd(key: string, score: number, member: string): Promise<number> {
    return this.client.zadd(key, score, member);
  }

  /**
   * 获取有序集合指定范围的成员
   * @param key 有序集合键
   * @param start 开始索引
   * @param stop 结束索引
   * @returns 成员数组
   */
  async zrange(key: string, start: number, stop: number): Promise<string[]> {
    return this.client.zrange(key, start, stop);
  }

  /**
   * 获取有序集合成员数量
   * @param key 有序集合键
   * @returns 成员数量
   */
  async zcard(key: string): Promise<number> {
    return this.client.zcard(key);
  }

  /**
   * 从有序集合中移除成员
   * @param key 有序集合键
   * @param members 成员数组
   * @returns 移除的成员数量
   */
  async zrem(key: string, ...members: string[]): Promise<number> {
    if (members.length === 0) {
      return 0;
    }

    return this.client.zrem(key, ...members);
  }

  /**
   * 扫描键（游标遍历）
   * @param cursor 游标（首次传 '0'）
   * @param pattern 匹配模式
   * @param count 每次扫描数量（建议值）
   */
  async scan(
    cursor: string,
    pattern: string,
    count: number = 100,
  ): Promise<[string, string[]]> {
    return this.client.scan(cursor, "MATCH", pattern, "COUNT", count);
  }

  /**
   * 检查键是否存在
   * @param key 键
   * @returns 存在的键数量（0 或 1）
   */
  async exists(key: string): Promise<number> {
    return this.client.exists(key);
  }

  /**
   * 设置过期时间
   * @param key 键
   * @param seconds 过期时间（秒）
   * @returns 设置成功返回 1，键不存在返回 0
   */
  async expire(key: string, seconds: number): Promise<number> {
    return this.client.expire(key, seconds);
  }

  /**
   * 获取列表长度
   * @param key 列表键
   * @returns 列表长度
   */
  async llen(key: string): Promise<number> {
    return this.client.llen(key);
  }

  /**
   * 模块销毁时关闭 Redis 连接
   */
  async onModuleDestroy(): Promise<void> {
    await this.client.quit();
    this.logger.log("Redis 连接已关闭");
  }
}
