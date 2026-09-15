import {
  INestApplication,
  Module,
  ValidationPipe,
} from '@nestjs/common';
import { PassportModule } from '@nestjs/passport';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { VerificationCodeType } from './entities/verification-code.entity';
import { PhoneLocalStrategy } from './strategies/phone-local.strategy';
import { DoctorPhoneLocalStrategy } from './strategies/doctor-phone-local.strategy';
import { LocalStrategy } from './strategies/local.strategy';
import { ResponseInterceptor } from '../common/interceptors/response.interceptor';
import { QueryExceptionFilter } from '../common/filters/query-exception.filter';
import { BusinessExceptionFilter } from '../common/filters/business-exception';
import { HttpExceptionFilter } from '../common/filters/http-exception.filter';

jest.mock('uuid', () => ({
  v4: jest.fn(() => 'mocked-session-id'),
}));

const mockAuthService = {
  validateUser: jest.fn(),
  validateUserByPhone: jest.fn(),
  validateDoctorByPhone: jest.fn(),
  login: jest.fn(),
  loginWithPhone: jest.fn(),
  loginDoctorWithPhone: jest.fn(),
  sendVerificationCode: jest.fn(),
  verifyCodeWithoutConsume: jest.fn(),
  register: jest.fn(),
  registerWithPhone: jest.fn(),
  buildUserLoginResult: jest.fn(),
  loginWithSms: jest.fn(),
  resetPassword: jest.fn(),
  logout: jest.fn(),
};

@Module({
  imports: [PassportModule.register({ defaultStrategy: 'phone-local' })],
  controllers: [AuthController],
  providers: [
    LocalStrategy,
    PhoneLocalStrategy,
    DoctorPhoneLocalStrategy,
    {
      provide: AuthService,
      useValue: mockAuthService,
    },
  ],
})
class AuthLoginContractTestModule {}

describe('Auth login contract', () => {
  let app: INestApplication;

  beforeEach(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AuthLoginContractTestModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        transform: true,
        whitelist: true,
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
    await app.close();
  });

  it('wraps login success into the standard 200 success envelope', async () => {
    mockAuthService.validateUserByPhone.mockResolvedValue({
      id: 8,
      phone: '13800138000',
    });
    mockAuthService.loginWithPhone.mockResolvedValue({
      access_token: 'mock-token',
      user: {
        id: 8,
        phone: '13800138000',
      },
    });

    const response = await request(app.getHttpServer())
      .post('/auth/login/phone')
      .send({
        phone: '13800138000',
        password: '123456',
      })
      .expect(200);

    expect(response.body).toEqual({
      code: 0,
      data: {
        access_token: 'mock-token',
        user: {
          id: 8,
          phone: '13800138000',
        },
      },
      message: 'Success',
      meta: {
        timestamp: expect.any(String),
      },
    });
  });

  it('keeps login failure in HTTP 200 and surfaces the business message', async () => {
    mockAuthService.validateUserByPhone.mockResolvedValue(null);

    const response = await request(app.getHttpServer())
      .post('/auth/login/phone')
      .send({
        phone: '13800138000',
        password: 'wrong-password',
      })
      .expect(200);

    expect(response.body).toEqual(
      expect.objectContaining({
        success: false,
        code: 401,
        statusCode: 401,
        message: '手机号或密码错误',
        error: 'Unauthorized',
        path: '/auth/login/phone',
        method: 'POST',
      }),
    );
  });
});

describe('AuthService verification code contract', () => {
  const phone = '13800138000';

  let usersService: {
    findByPhone: jest.Mock;
    update: jest.Mock;
  };
  let doctorsService: {
    findByPhone: jest.Mock;
    update: jest.Mock;
  };
  let smsService: {
    sendVerificationCode: jest.Mock;
  };
  let verificationCodeRepository: {
    count: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
  };
  let service: AuthService;

  beforeEach(() => {
    usersService = {
      findByPhone: jest.fn(),
      update: jest.fn().mockResolvedValue({ id: 1, phone }),
    };
    doctorsService = {
      findByPhone: jest.fn(),
      update: jest.fn().mockResolvedValue({ id: 2, phone }),
    };
    smsService = {
      sendVerificationCode: jest.fn().mockResolvedValue({
        code: '123456',
        expiresIn: 120,
      }),
    };
    verificationCodeRepository = {
      count: jest.fn().mockResolvedValue(0),
      create: jest.fn((entity) => entity),
      save: jest.fn().mockResolvedValue(undefined),
    };

    service = new AuthService(
      usersService as any,
      doctorsService as any,
      {} as any,
      {} as any,
      smsService as any,
      { get: jest.fn() } as any,
      {} as any,
      verificationCodeRepository as any,
    );
  });

  it('rejects register code requests when the phone is already registered', async () => {
    usersService.findByPhone.mockResolvedValue({
      id: 1,
      phone,
    });

    await expect(
      service.sendVerificationCode(phone, VerificationCodeType.REGISTER),
    ).rejects.toThrow('手机号已被注册');

    expect(smsService.sendVerificationCode).not.toHaveBeenCalled();
    expect(verificationCodeRepository.save).not.toHaveBeenCalled();
  });

  it('defaults to resetting a user password and consumes a reset-password code', async () => {
    usersService.findByPhone.mockResolvedValue({ id: 1, phone });
    const verifyCodeSpy = jest
      .spyOn(service, 'verifyCode')
      .mockResolvedValue(true);

    await service.resetPassword(phone, '123456', 'newPassword123');

    expect(verifyCodeSpy).toHaveBeenCalledWith(
      phone,
      '123456',
      VerificationCodeType.RESET_PASSWORD,
    );
    expect(usersService.update).toHaveBeenCalledWith(1, {
      password: 'newPassword123',
    });
    expect(doctorsService.update).not.toHaveBeenCalled();
  });

  it('resets a doctor password when accountType is doctor', async () => {
    doctorsService.findByPhone.mockResolvedValue({ id: 2, phone });
    jest.spyOn(service, 'verifyCode').mockResolvedValue(true);

    await service.resetPassword(
      phone,
      '123456',
      'newPassword123',
      'doctor',
    );

    expect(doctorsService.update).toHaveBeenCalledWith(2, {
      password: 'newPassword123',
    });
    expect(usersService.update).not.toHaveBeenCalled();
  });

  it('does not update a user password when the reset user does not exist', async () => {
    usersService.findByPhone.mockResolvedValue(null);
    jest.spyOn(service, 'verifyCode').mockResolvedValue(true);

    await expect(
      service.resetPassword(phone, '123456', 'newPassword123'),
    ).rejects.toThrow('用户不存在');

    expect(usersService.update).not.toHaveBeenCalled();
    expect(doctorsService.update).not.toHaveBeenCalled();
  });

  it('does not update a doctor password when the reset doctor does not exist', async () => {
    doctorsService.findByPhone.mockResolvedValue(null);
    jest.spyOn(service, 'verifyCode').mockResolvedValue(true);

    await expect(
      service.resetPassword(phone, '123456', 'newPassword123', 'doctor'),
    ).rejects.toThrow('医生不存在');

    expect(usersService.update).not.toHaveBeenCalled();
    expect(doctorsService.update).not.toHaveBeenCalled();
  });

  it('rejects reset-password user code requests when the user does not exist', async () => {
    usersService.findByPhone.mockResolvedValue(null);

    await expect(
      service.sendVerificationCode(
        phone,
        VerificationCodeType.RESET_PASSWORD,
        'user',
      ),
    ).rejects.toThrow('用户不存在');

    expect(smsService.sendVerificationCode).not.toHaveBeenCalled();
    expect(verificationCodeRepository.save).not.toHaveBeenCalled();
  });

  it('rejects reset-password doctor code requests when the doctor does not exist', async () => {
    doctorsService.findByPhone.mockResolvedValue(null);

    await expect(
      service.sendVerificationCode(
        phone,
        VerificationCodeType.RESET_PASSWORD,
        'doctor',
      ),
    ).rejects.toThrow('医生不存在');

    expect(smsService.sendVerificationCode).not.toHaveBeenCalled();
    expect(verificationCodeRepository.save).not.toHaveBeenCalled();
  });

  it('rejects reset-password verification when the user does not exist even with the super code', async () => {
    usersService.findByPhone.mockResolvedValue(null);

    await expect(
      service.verifyCodeWithoutConsume(
        phone,
        '000000',
        VerificationCodeType.RESET_PASSWORD,
        'user',
      ),
    ).rejects.toThrow('用户不存在');

    expect(verificationCodeRepository.save).not.toHaveBeenCalled();
  });

  it('rejects reset-password verification when the doctor does not exist even with the super code', async () => {
    doctorsService.findByPhone.mockResolvedValue(null);

    await expect(
      service.verifyCodeWithoutConsume(
        phone,
        '000000',
        VerificationCodeType.RESET_PASSWORD,
        'doctor',
      ),
    ).rejects.toThrow('医生不存在');

    expect(usersService.findByPhone).not.toHaveBeenCalled();
    expect(verificationCodeRepository.save).not.toHaveBeenCalled();
  });
});
