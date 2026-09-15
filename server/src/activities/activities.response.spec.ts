import {
  ArgumentsHost,
  CallHandler,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { lastValueFrom, of } from 'rxjs';
import { createBusinessException, ErrorCode } from '../common/constants/error-codes';
import { BusinessExceptionFilter } from '../common/filters/business-exception';
import { HttpExceptionFilter } from '../common/filters/http-exception.filter';
import { ResponseInterceptor } from '../common/interceptors/response.interceptor';
import { ActivitiesController } from './activities.controller';
import { ActivitiesService } from './activities.service';

/**
 * 执行统一响应拦截器
 * 用于验证 rnapp 依赖的活动操作态响应外层结构不会回退。
 *
 * @param {unknown} data - 控制器原始返回值
 * @returns {Promise<any>} 拦截后的统一响应
 */
async function runInterceptor(data: unknown): Promise<any> {
  const interceptor = new ResponseInterceptor();
  const callHandler: CallHandler = {
    handle: () => of(data),
  };

  return lastValueFrom(
    interceptor.intercept({} as ExecutionContext, callHandler),
  );
}

/**
 * 执行业务异常过滤器
 * 用于验证活动报名失败时的错误响应结构是否稳定。
 *
 * @param {Error} exception - 控制器抛出的业务异常
 * @param {string} url - 请求路径
 * @param {string} method - HTTP 方法
 * @returns {{ status: jest.Mock; json: jest.Mock }} 断言用响应对象
 */
function runBusinessExceptionFilter(
  exception: Error,
  url: string,
  method: string,
) {
  const filter = new BusinessExceptionFilter();
  const json = jest.fn();
  const status = jest.fn().mockReturnValue({ json });
  const host = {
    switchToHttp: () => ({
      getResponse: () => ({ status }),
      getRequest: () => ({ url, method }),
    }),
  } as ArgumentsHost;

  filter.catch(exception as any, host);

  return {
    status,
    json,
  };
}

/**
 * 执行 HTTP 异常过滤器
 * 用于验证未登录等通用 HTTP 错误在当前异常链路下的响应结构是否稳定。
 *
 * @param {Error} exception - 控制器抛出的 HTTP 异常
 * @param {string} url - 请求路径
 * @param {string} method - HTTP 方法
 * @returns {{ status: jest.Mock; json: jest.Mock }} 断言用响应对象
 */
function runHttpExceptionFilter(
  exception: Error,
  url: string,
  method: string,
) {
  const filter = new HttpExceptionFilter();
  const json = jest.fn();
  const status = jest.fn().mockReturnValue({ json });
  const host = {
    switchToHttp: () => ({
      getResponse: () => ({ status }),
      getRequest: () => ({ url, method }),
    }),
  } as ArgumentsHost;

  filter.catch(exception as any, host);

  return {
    status,
    json,
  };
}

describe('Activities Response Contract', () => {
  let controller: ActivitiesController;

  const mockActivitiesService = {
    findAll: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    remove: jest.fn(),
    getRegistrations: jest.fn(),
    getParticipants: jest.fn(),
    findUserActivities: jest.fn(),
    findOneUser: jest.fn(),
    register: jest.fn(),
    vote: jest.fn(),
  };

  const mockRequest = {
    user: { id: 8 },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [ActivitiesController],
      providers: [
        {
          provide: ActivitiesService,
          useValue: mockActivitiesService,
        },
      ],
    }).compile();

    controller = module.get<ActivitiesController>(ActivitiesController);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should keep success-message-data contract stable for activity register', async () => {
    mockActivitiesService.register.mockResolvedValue({
      registrationId: 12,
      registeredAt: 1770201000000,
    });

    const rawResult = await controller.register(
      '1',
      { phone: '13800138000' },
      mockRequest,
    );
    const wrappedResult = await runInterceptor(rawResult);

    expect(wrappedResult).toEqual({
      code: 0,
      data: {
        success: true,
        message: '报名成功',
        data: {
          registrationId: 12,
          registeredAt: 1770201000000,
        },
      },
      message: '报名成功',
      meta: {
        timestamp: expect.any(String),
      },
    });
  });

  it('should keep duplicate-register error contract stable', async () => {
    mockActivitiesService.register.mockRejectedValue(
      createBusinessException(
        ErrorCode.BUSINESS_INVALID_PARAM,
        '您已经报名过该活动',
      ),
    );

    let thrownError: Error | undefined;

    try {
      await controller.register(
        '1',
        { phone: '13800138000' },
        mockRequest,
      );
    } catch (error) {
      thrownError = error as Error;
    }

    expect(thrownError).toBeInstanceOf(Error);

    const { status, json } = runBusinessExceptionFilter(
      thrownError as Error,
      '/activities/app/1/register',
      'POST',
    );

    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith({
      success: false,
      statusCode: 400,
      message: '您已经报名过该活动',
      code: '3000',
      error: 'BUSINESS_ERROR',
      timestamp: expect.any(String),
      path: '/activities/app/1/register',
      method: 'POST',
    });
  });

  it('should keep activity-not-found error contract stable', async () => {
    mockActivitiesService.register.mockRejectedValue(
      createBusinessException(ErrorCode.ACTIVITY_NOT_FOUND, '活动不存在'),
    );

    let thrownError: Error | undefined;

    try {
      await controller.register(
        '999',
        { phone: '13800138000' },
        mockRequest,
      );
    } catch (error) {
      thrownError = error as Error;
    }

    expect(thrownError).toBeInstanceOf(Error);

    const { status, json } = runBusinessExceptionFilter(
      thrownError as Error,
      '/activities/app/999/register',
      'POST',
    );

    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith({
      success: false,
      statusCode: 400,
      message: '活动不存在',
      code: '3701',
      error: 'BUSINESS_ERROR',
      timestamp: expect.any(String),
      path: '/activities/app/999/register',
      method: 'POST',
    });
  });

  it('should keep unauthorized error contract stable for activity register', () => {
    const { status, json } = runHttpExceptionFilter(
      new UnauthorizedException(),
      '/activities/app/12/register',
      'POST',
    );

    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        code: 401,
        statusCode: 401,
        timestamp: expect.any(String),
        path: '/activities/app/12/register',
        method: 'POST',
        message: 'Unauthorized',
        error: 'UnauthorizedException',
      }),
    );
  });
});
