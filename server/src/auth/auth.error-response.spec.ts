import {
  BadRequestException,
  Controller,
  Get,
  Body,
  HttpCode,
  HttpStatus,
  INestApplication,
  Post,
  UnauthorizedException,
  UseInterceptors,
  ValidationPipe,
} from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';

import { AuthService } from './auth.service';
import { ResponseInterceptor } from '../common/interceptors/response.interceptor';
import { BusinessExceptionFilter } from '../common/filters/business-exception';
import { HttpExceptionFilter } from '../common/filters/http-exception.filter';
import { QueryExceptionFilter } from '../common/filters/query-exception.filter';

jest.mock('uuid', () => ({
  v4: jest.fn(() => 'mocked-session-id'),
}));

@Controller('auth')
@UseInterceptors(ResponseInterceptor)
class AuthLoginContractController {
  constructor(private readonly authService: AuthService) {}

  @Post('login/phone')
  @HttpCode(HttpStatus.OK)
  async loginWithPhone(@Body() body: { phone: string; password: string }) {
    if (body.password === 'wrong123') {
      throw new UnauthorizedException('手机号或密码错误');
    }

    return this.authService.loginWithPhone(body.phone, body.password);
  }
}

@Controller('auth-error-contract')
@UseInterceptors(ResponseInterceptor)
class ErrorContractController {
  @Get('business')
  getBusinessError() {
    throw new BadRequestException('业务失败示例');
  }

  @Get('unauthorized')
  getUnauthorizedError() {
    throw new UnauthorizedException('未登录');
  }
}

describe('Auth error response contract', () => {
  let app: INestApplication;

  const authServiceMock = {
    login: jest.fn(),
    register: jest.fn(),
    sendVerificationCode: jest.fn(),
    verifyCodeWithoutConsume: jest.fn(),
    registerWithPhone: jest.fn(),
    loginWithPhone: jest.fn(),
    loginDoctorWithPhone: jest.fn(),
    loginWithSms: jest.fn(),
    resetPassword: jest.fn(),
    logout: jest.fn(),
    buildUserLoginResult: jest.fn(),
  };

  const createApp = async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      controllers: [AuthLoginContractController, ErrorContractController],
      providers: [
        { provide: AuthService, useValue: authServiceMock },
      ],
    }).compile();

    const nestApp = moduleFixture.createNestApplication();
    nestApp.useGlobalPipes(
      new ValidationPipe({
        transform: true,
        whitelist: true,
      }),
    );
    nestApp.useGlobalInterceptors(new ResponseInterceptor());
    nestApp.useGlobalFilters(
      new QueryExceptionFilter(),
      new BusinessExceptionFilter(),
      new HttpExceptionFilter(),
    );
    await nestApp.init();
    return nestApp;
  };

  afterEach(async () => {
    jest.clearAllMocks();
    if (app) {
      await app.close();
    }
  });

  it('returns HTTP 200 with business failure fields when login credentials are invalid', async () => {
    app = await createApp();

    const response = await request(app.getHttpServer())
      .post('/auth/login/phone')
      .send({ phone: '13800000000', password: 'wrong123' });

    expect(response.status).toBe(200);
    expect(response.body).toEqual(
      expect.objectContaining({
        success: false,
        code: expect.any(Number),
        statusCode: 401,
        message: '手机号或密码错误',
        error: 'Unauthorized',
      }),
    );
  });

  it('keeps successful login responses in the standard success envelope', async () => {
    authServiceMock.loginWithPhone.mockResolvedValue({
      access_token: 'token-1',
      user: {
        id: 1,
        phone: '13800000000',
        username: 'tester',
        role: 'user',
        verified: true,
      },
    });
    app = await createApp();

    const response = await request(app.getHttpServer())
      .post('/auth/login/phone')
      .send({ phone: '13800000000', password: 'pass123' });

    expect(response.status).toBe(200);
    expect(response.body).toEqual(
      expect.objectContaining({
        code: 0,
        message: 'Success',
        data: expect.objectContaining({
          access_token: 'token-1',
        }),
      }),
    );
  });

  it('returns HTTP 200 with explicit failure fields for typical business exceptions', async () => {
    app = await createApp();

    const response = await request(app.getHttpServer()).get(
      '/auth-error-contract/business',
    );

    expect(response.status).toBe(200);
    expect(response.body).toEqual(
      expect.objectContaining({
        success: false,
        code: expect.any(Number),
        statusCode: 400,
        message: '业务失败示例',
      }),
    );
  });
});
