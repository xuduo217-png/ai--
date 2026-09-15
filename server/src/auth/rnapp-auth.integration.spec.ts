import {
  INestApplication,
  Module,
  UnauthorizedException,
  ValidationPipe,
} from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { ConfigService } from '@nestjs/config';
import { ResponseInterceptor } from '../common/interceptors/response.interceptor';
import { QueryExceptionFilter } from '../common/filters/query-exception.filter';
import { BusinessExceptionFilter } from '../common/filters/business-exception';
import { HttpExceptionFilter } from '../common/filters/http-exception.filter';
import { ActivitiesController } from '../activities/activities.controller';
import { ActivitiesService } from '../activities/activities.service';
import { CharityController } from '../charity/charity.controller';
import { CharityService } from '../charity/charity.service';
import { JwtStrategy } from './strategies/jwt.strategy';
import { UsersService } from '../users/users.service';
import { DoctorsService } from '../doctors/doctors.service';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from './guards/optional-jwt-auth.guard';
import { RolesGuard } from './guards/roles.guard';
import { AuthSessionService } from './auth-session.service';

/**
 * 局部 mock uuid，避免 Jest 在当前仓库配置下解析 ESM 版本时报语法错误。
 */
jest.mock('uuid', () => ({
  v4: jest.fn(() => 'mocked-session-id'),
}));

const mockUsersService = {
  findOne: jest.fn(),
  findByUsername: jest.fn(),
  findByPhone: jest.fn(),
};

const mockDoctorsService = {
  findOne: jest.fn(),
};

const mockAuthSessionService = {
  assertSession: jest.fn().mockResolvedValue(undefined),
};

const mockActivitiesService = {
  findAll: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
  remove: jest.fn(),
  getRegistrations: jest.fn(),
  findUserActivities: jest.fn(),
  findOneUser: jest.fn(),
  register: jest.fn(),
};

const mockCharityService = {
  findAll: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
  remove: jest.fn(),
  getStats: jest.fn(),
  getParticipants: jest.fn(),
  publishArticle: jest.fn(),
  updateArticle: jest.fn(),
  getPublishedArticle: jest.fn(),
  findUserActivities: jest.fn(),
  findOne: jest.fn(),
  checkIn: jest.fn(),
  getUserRecords: jest.fn(),
  getArticles: jest.fn(),
};

/**
 * 仅用于集成测试的最小模块
 * 保留真实 JwtAuthGuard、路由层与异常过滤链，避免拉起完整 AppModule。
 */
@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.register({
      secret: 'test-secret',
      signOptions: { expiresIn: '100y' },
    }),
  ],
  controllers: [ActivitiesController, CharityController],
  providers: [
    JwtStrategy,
    JwtAuthGuard,
    OptionalJwtAuthGuard,
    RolesGuard,
    {
      provide: ActivitiesService,
      useValue: mockActivitiesService,
    },
    {
      provide: CharityService,
      useValue: mockCharityService,
    },
    {
      provide: UsersService,
      useValue: mockUsersService,
    },
    {
      provide: DoctorsService,
      useValue: mockDoctorsService,
    },
    {
      provide: ConfigService,
      useValue: {
        get: (key: string) => (key === 'JWT_SECRET' ? 'test-secret' : undefined),
      },
    },
    {
      provide: AuthSessionService,
      useValue: mockAuthSessionService,
    },
  ],
})
class RnappAuthIntegrationTestModule {}

describe('RNApp Auth Contract (integration)', () => {
  let app: INestApplication;
  /**
   * 生成签名错误的 JWT
   * 用于模拟真实运行链路里 JwtStrategy 校验失败的场景。
   *
   * @returns {string} 非法签名的 JWT
   */
  const createInvalidSignedToken = (): string => {
    const jsonwebtoken = require('jsonwebtoken');

    return jsonwebtoken.sign(
      {
        sub: 8,
        type: 'user',
        phone: '13800138000',
        sid: 'sid-1',
      },
      'wrong-secret',
    );
  };

  /**
   * 生成已过期的 JWT
   * 用于验证 Passport 在进入 JwtStrategy.validate 之前就会拒绝过期 token。
   *
   * @returns {string} 已过期的 JWT
   */
  const createExpiredToken = (): string => {
    const jsonwebtoken = require('jsonwebtoken');

    return jsonwebtoken.sign(
      {
        sub: 8,
        type: 'user',
        phone: '13800138000',
        sid: 'sid-1',
      },
      'test-secret',
      { expiresIn: -1 },
    );
  };

  /**
   * 生成签名正确的 JWT
   * 用于覆盖 JwtStrategy.validate 中“用户不存在/失效”的分支。
   *
   * @returns {string} 签名正确的 JWT
   */
  const createValidToken = (): string => {
    const jsonwebtoken = require('jsonwebtoken');

    return jsonwebtoken.sign(
      {
        sub: 8,
        type: 'user',
        phone: '13800138000',
        sid: 'sid-1',
      },
      'test-secret',
      { expiresIn: '1h' },
    );
  };

  beforeEach(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [RnappAuthIntegrationTestModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        transform: true,
        whitelist: true,
        transformOptions: {
          enableImplicitConversion: true,
        },
      }),
    );
    app.useGlobalFilters(
      new QueryExceptionFilter(),
      new BusinessExceptionFilter(),
      new HttpExceptionFilter(),
    );
    app.useGlobalInterceptors(new ResponseInterceptor());

    await app.init();
  });

  afterEach(async () => {
    jest.clearAllMocks();
    mockAuthSessionService.assertSession.mockResolvedValue(undefined);
    await app.close();
  });

  it('should keep business-failure contract stable for activities register without token', async () => {
    const response = await request(app.getHttpServer())
      .post('/activities/app/1/register')
      .send({ phone: '13800138000' })
      .expect(200);

    expect(response.body).toEqual(
      expect.objectContaining({
        success: false,
        code: 401,
        statusCode: 401,
        timestamp: expect.any(String),
        path: '/activities/app/1/register',
        method: 'POST',
        message: 'Unauthorized',
        error: 'UnauthorizedException',
      }),
    );
    expect(mockActivitiesService.register).not.toHaveBeenCalled();
  });

  it('should keep business-failure contract stable for activities register with invalid jwt', async () => {
    const response = await request(app.getHttpServer())
      .post('/activities/app/1/register')
      .set('Authorization', `Bearer ${createInvalidSignedToken()}`)
      .send({ phone: '13800138000' })
      .expect(200);

    expect(response.body).toEqual(
      expect.objectContaining({
        success: false,
        code: 401,
        statusCode: 401,
        timestamp: expect.any(String),
        path: '/activities/app/1/register',
        method: 'POST',
        message: 'Unauthorized',
        error: 'UnauthorizedException',
      }),
    );
    expect(mockActivitiesService.register).not.toHaveBeenCalled();
  });

  it('should keep business-failure contract stable for activities register with expired jwt', async () => {
    const response = await request(app.getHttpServer())
      .post('/activities/app/1/register')
      .set('Authorization', `Bearer ${createExpiredToken()}`)
      .send({ phone: '13800138000' })
      .expect(200);

    expect(response.body).toEqual(
      expect.objectContaining({
        success: false,
        code: 401,
        statusCode: 401,
        timestamp: expect.any(String),
        path: '/activities/app/1/register',
        method: 'POST',
        message: 'Unauthorized',
        error: 'UnauthorizedException',
      }),
    );
    expect(mockUsersService.findOne).not.toHaveBeenCalled();
    expect(mockActivitiesService.register).not.toHaveBeenCalled();
  });

  it('should keep business-failure contract stable for charity check-in without token', async () => {
    const response = await request(app.getHttpServer())
      .post('/charity/1/checkin')
      .send({})
      .expect(200);

    expect(response.body).toEqual(
      expect.objectContaining({
        success: false,
        code: 401,
        statusCode: 401,
        timestamp: expect.any(String),
        path: '/charity/1/checkin',
        method: 'POST',
        message: 'Unauthorized',
        error: 'UnauthorizedException',
      }),
    );
    expect(mockCharityService.checkIn).not.toHaveBeenCalled();
  });

  it('should keep business-failure contract stable when jwt is valid but user no longer exists', async () => {
    mockUsersService.findOne.mockResolvedValue(undefined);

    const response = await request(app.getHttpServer())
      .post('/charity/1/checkin')
      .set('Authorization', `Bearer ${createValidToken()}`)
      .send({})
      .expect(200);

    expect(response.body).toEqual(
      expect.objectContaining({
        success: false,
        code: 401,
        statusCode: 401,
        timestamp: expect.any(String),
        path: '/charity/1/checkin',
        method: 'POST',
        message: '用户不存在',
        error: 'Unauthorized',
      }),
    );
    expect(mockUsersService.findOne).toHaveBeenCalledWith(8);
    expect(mockCharityService.checkIn).not.toHaveBeenCalled();
  });

  it('should keep business-failure contract stable when sid is revoked', async () => {
    mockAuthSessionService.assertSession.mockRejectedValueOnce(
      new UnauthorizedException('账号已在其他设备登录，请重新登录'),
    );

    const response = await request(app.getHttpServer())
      .post('/charity/1/checkin')
      .set('Authorization', `Bearer ${createValidToken()}`)
      .send({})
      .expect(200);

    expect(response.body).toEqual(
      expect.objectContaining({
        success: false,
        code: 401,
        statusCode: 401,
        timestamp: expect.any(String),
        path: '/charity/1/checkin',
        method: 'POST',
        message: '账号已在其他设备登录，请重新登录',
      }),
    );
    expect(mockCharityService.checkIn).not.toHaveBeenCalled();
  });
});
