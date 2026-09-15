import { Test, TestingModule } from '@nestjs/testing';
import { RedisService } from './redis.service';
import { ConfigService } from '@nestjs/config';

describe('RedisService', () => {
  let service: RedisService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RedisService,
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string) => {
              const config = {
                REDIS_HOST: 'localhost',
                REDIS_PORT: 6379,
                REDIS_PASSWORD: '',
              };
              return config[key] || null;
            }),
          },
        },
      ],
    }).compile();

    service = module.get<RedisService>(RedisService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should set and get value', async () => {
    await service.set('test_key', 'test_value', 60);
    const value = await service.get('test_key');
    expect(value).toBe('test_value');
  });

  it('should push to list and get range', async () => {
    await service.lpush('test_list', 'item1');
    await service.lpush('test_list', 'item2');
    const items = await service.lrange('test_list', 0, -1);
    expect(items).toEqual(['item2', 'item1']);
  });

  it('should delete key', async () => {
    await service.set('test_key', 'test_value', 60);
    await service.del('test_key');
    const value = await service.get('test_key');
    expect(value).toBeNull();
  });

  afterEach(async () => {
    // 清理测试数据
    if (service) {
      await service.del('test_key', 'test_list');
    }
  });
});
