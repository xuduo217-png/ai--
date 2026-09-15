import { ConfigService } from '@nestjs/config';
import { TypeOrmModuleOptions } from '@nestjs/typeorm';
import { join } from 'path';

type ConfigReader = Pick<ConfigService, 'get'>;

function getNumberConfig(
  configService: ConfigReader,
  key: string,
  fallback: number,
): number {
  const rawValue = configService.get<string | number | undefined>(key);
  const parsedValue = Number(rawValue);
  return Number.isFinite(parsedValue) ? parsedValue : fallback;
}

function getBooleanConfig(
  configService: ConfigReader,
  key: string,
  fallback: boolean,
): boolean {
  const rawValue = configService.get<string | boolean | undefined>(key);

  if (typeof rawValue === 'boolean') {
    return rawValue;
  }

  if (typeof rawValue === 'string') {
    const normalized = rawValue.trim().toLowerCase();
    if (normalized === 'true') {
      return true;
    }
    if (normalized === 'false') {
      return false;
    }
  }

  return fallback;
}

/**
 * 远端 MySQL 在社区主页这类高频短查询场景下更容易暴露空闲连接回收与连接复用问题，
 * 这里显式固定连接池与 keepalive 参数，降低 read ETIMEDOUT 发生概率。
 */
export function createDatabaseOptions(
  configService: ConfigReader,
): TypeOrmModuleOptions {
  const poolSize = getNumberConfig(configService, 'DB_POOL_SIZE', 20);

  return {
    type: 'mysql',
    host: configService.get('DB_HOST', 'localhost'),
    port: getNumberConfig(configService, 'DB_PORT', 3306),
    username: configService.get('DB_USERNAME', 'root'),
    password: configService.get('DB_PASSWORD', ''),
    database: configService.get('DB_DATABASE', 'pet_hospitals'),
    entities: [join(__dirname, '..', '**', '*.entity{.ts,.js}')],
    // 生产配置目前可能仍使用 development 标识，任何环境都禁止自动改表。
    synchronize: false,
    logging: configService.get('NODE_ENV') !== 'production',
    retryAttempts: getNumberConfig(configService, 'DB_RETRY_ATTEMPTS', 3),
    retryDelay: getNumberConfig(configService, 'DB_RETRY_DELAY', 3000),
    poolSize,
    connectTimeout: getNumberConfig(configService, 'DB_CONNECT_TIMEOUT', 10000),
    extra: {
      waitForConnections: getBooleanConfig(
        configService,
        'DB_WAIT_FOR_CONNECTIONS',
        true,
      ),
      maxIdle: getNumberConfig(
        configService,
        'DB_MAX_IDLE',
        Math.min(poolSize, 10),
      ),
      idleTimeout: getNumberConfig(configService, 'DB_IDLE_TIMEOUT', 60000),
      queueLimit: getNumberConfig(configService, 'DB_QUEUE_LIMIT', 0),
      enableKeepAlive: getBooleanConfig(
        configService,
        'DB_ENABLE_KEEP_ALIVE',
        true,
      ),
      keepAliveInitialDelay: getNumberConfig(
        configService,
        'DB_KEEP_ALIVE_INITIAL_DELAY',
        0,
      ),
    },
  };
}
