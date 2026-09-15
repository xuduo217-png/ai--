import {
  ArgumentsHost,
  CallHandler,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { lastValueFrom, of } from 'rxjs';
import { BusinessExceptionFilter } from '../common/filters/business-exception';
import { createBusinessException, ErrorCode } from '../common/constants/error-codes';
import { HttpExceptionFilter } from '../common/filters/http-exception.filter';
import { ResponseInterceptor } from '../common/interceptors/response.interceptor';
import { CharityDonationPaymentMethod } from './dto/donate-charity.dto';
import { CharityController } from './charity.controller';
import { CharityService } from './charity.service';

/**
 * 执行统一响应拦截器
 * 用于验证 rnapp 依赖的 charity 成功响应外层结构不会回退。
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
 * 用于验证公益接口在业务错误下的错误响应结构是否稳定。
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

describe('Charity Response Contract', () => {
  let controller: CharityController;

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
    donate: jest.fn(),
    getUserRecords: jest.fn(),
    getDonationRecords: jest.fn(),
    getArticles: jest.fn(),
  };

  const mockRequest = {
    user: { id: 8 },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [CharityController],
      providers: [
        {
          provide: CharityService,
          useValue: mockCharityService,
        },
      ],
    }).compile();

    controller = module.get<CharityController>(CharityController);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should keep top-level data and stable pagination for charity records', async () => {
    mockCharityService.getUserRecords.mockResolvedValue({
      data: [
        {
          id: 91,
          charityId: 12,
          userId: 8,
          checkInDate: '2026-03-11',
          checkInTime: '2026-03-11T08:30:00.000Z',
          taskType: 'checkin',
          taskEvidence: null,
          createdAt: '2026-03-11T08:30:00.000Z',
        },
      ],
      total: 23,
      page: 2,
      pageSize: 10,
    });

    const rawResult = await controller.getUserRecords('12', '2', '10', mockRequest);
    const wrappedResult = await runInterceptor(rawResult);

    expect(wrappedResult).toEqual({
      code: 0,
      data: [
        expect.objectContaining({
          id: 91,
          charityId: 12,
          userId: 8,
        }),
      ],
      message: 'Success',
      meta: {
        timestamp: expect.any(String),
      },
      pagination: {
        total: 23,
        page: 2,
        pageSize: 10,
        limit: 10,
        totalPages: 3,
      },
    });
  });

  it('should keep success-message contract stable for charity check-in success', async () => {
    mockCharityService.checkIn.mockResolvedValue({
      success: true,
      totalCheckIns: 4,
      message: '签到成功',
      isCompleted: false,
    });

    const rawResult = await controller.checkIn(
      '12',
      {},
      mockRequest,
    );
    const wrappedResult = await runInterceptor(rawResult);

    expect(wrappedResult).toEqual({
      code: 0,
      data: {
        success: true,
        totalCheckIns: 4,
        message: '签到成功',
        isCompleted: false,
      },
      message: '签到成功',
      meta: {
        timestamp: expect.any(String),
      },
    });
  });

  it('should keep success-false contract stable when charity is already checked in today', async () => {
    mockCharityService.checkIn.mockResolvedValue({
      success: false,
      alreadyChecked: true,
      totalCheckIns: 4,
      message: '您今天已经打过卡了，明天再来吧！',
      isCompleted: false,
    });

    const rawResult = await controller.checkIn(
      '12',
      {},
      mockRequest,
    );
    const wrappedResult = await runInterceptor(rawResult);

    expect(wrappedResult).toEqual({
      code: 0,
      data: {
        success: false,
        alreadyChecked: true,
        totalCheckIns: 4,
        message: '您今天已经打过卡了，明天再来吧！',
        isCompleted: false,
      },
      message: '您今天已经打过卡了，明天再来吧！',
      meta: {
        timestamp: expect.any(String),
      },
    });
  });

  it('should keep success-message contract stable for charity donation success', async () => {
    mockCharityService.donate.mockResolvedValue({
      success: true,
      message: '捐款成功',
      donationAmount: 20.5,
      donatedAmount: 540.5,
      balanceBefore: 100,
      balanceAfter: 79.5,
    });

    const rawResult = await controller.donate(
      '12',
      { amount: 20.5, paymentMethod: CharityDonationPaymentMethod.BALANCE },
      mockRequest,
    );
    const wrappedResult = await runInterceptor(rawResult);

    expect(wrappedResult).toEqual({
      code: 0,
      data: {
        success: true,
        message: '捐款成功',
        donationAmount: 20.5,
        donatedAmount: 540.5,
        balanceBefore: 100,
        balanceAfter: 79.5,
      },
      message: '捐款成功',
      meta: {
        timestamp: expect.any(String),
      },
    });
  });

  it('should keep charity-not-found error contract stable for charity check-in', async () => {
    mockCharityService.checkIn.mockRejectedValue(
      createBusinessException(ErrorCode.CHARITY_NOT_FOUND),
    );

    let thrownError: Error | undefined;

    try {
      await controller.checkIn('999', {}, mockRequest);
    } catch (error) {
      thrownError = error as Error;
    }

    expect(thrownError).toBeInstanceOf(Error);

    const { status, json } = runBusinessExceptionFilter(
      thrownError as Error,
      '/charity/999/checkin',
      'POST',
    );

    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith({
      success: false,
      statusCode: 400,
      message: '公益不存在',
      code: '3301',
      error: 'BUSINESS_ERROR',
      timestamp: expect.any(String),
      path: '/charity/999/checkin',
      method: 'POST',
    });
  });

  it('should keep unauthorized error contract stable for charity check-in', () => {
    const { status, json } = runHttpExceptionFilter(
      new UnauthorizedException(),
      '/charity/12/checkin',
      'POST',
    );

    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        code: 401,
        statusCode: 401,
        timestamp: expect.any(String),
        path: '/charity/12/checkin',
        method: 'POST',
        message: 'Unauthorized',
        error: 'UnauthorizedException',
      }),
    );
  });

  it('should keep charity-not-found error contract stable for charity records', async () => {
    mockCharityService.getUserRecords.mockRejectedValue(
      createBusinessException(ErrorCode.CHARITY_NOT_FOUND),
    );

    let thrownError: Error | undefined;

    try {
      await controller.getUserRecords('999', '1', '10', mockRequest);
    } catch (error) {
      thrownError = error as Error;
    }

    expect(thrownError).toBeInstanceOf(Error);

    const { status, json } = runBusinessExceptionFilter(
      thrownError as Error,
      '/charity/999/records',
      'GET',
    );

    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith({
      success: false,
      statusCode: 400,
      message: '公益不存在',
      code: '3301',
      error: 'BUSINESS_ERROR',
      timestamp: expect.any(String),
      path: '/charity/999/records',
      method: 'GET',
    });
  });

  it('should keep unauthorized error contract stable for charity records', () => {
    const { status, json } = runHttpExceptionFilter(
      new UnauthorizedException(),
      '/charity/12/records',
      'GET',
    );

    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        code: 401,
        statusCode: 401,
        timestamp: expect.any(String),
        path: '/charity/12/records',
        method: 'GET',
        message: 'Unauthorized',
        error: 'UnauthorizedException',
      }),
    );
  });

  it('should keep donation-record pagination contract stable', async () => {
    mockCharityService.getDonationRecords.mockResolvedValue({
      data: [
        {
          id: 91,
          charityId: 12,
          userId: 8,
          userName: '爱心人士',
          userAvatar: '/uploads/avatar1.jpg',
          checkInDate: null,
          checkInTime: '2026-03-11T08:30:00.000Z',
          donationAmount: 20.5,
          createdAt: '2026-03-11T08:30:00.000Z',
        },
      ],
      total: 23,
      page: 2,
      pageSize: 10,
      totalPages: 3,
    });

    const rawResult = await controller.getDonationRecords('12', '2', '10');
    const wrappedResult = await runInterceptor(rawResult);

    expect(wrappedResult).toEqual({
      code: 0,
      data: [
        expect.objectContaining({
          id: 91,
          charityId: 12,
          userId: 8,
          donationAmount: 20.5,
        }),
      ],
      message: 'Success',
      meta: {
        timestamp: expect.any(String),
      },
      pagination: {
        total: 23,
        page: 2,
        pageSize: 10,
        limit: 10,
        totalPages: 3,
      },
    });
  });
});
