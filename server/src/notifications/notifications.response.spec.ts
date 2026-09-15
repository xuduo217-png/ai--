import {
  ArgumentsHost,
  CallHandler,
  ExecutionContext,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { lastValueFrom, of } from 'rxjs';
import { ResponseInterceptor } from '../common/interceptors/response.interceptor';
import { HttpExceptionFilter } from '../common/filters/http-exception.filter';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { NotificationType } from './entities/notification.entity';

/**
 * 执行统一响应拦截器
 * 用于验证 rnapp 依赖的 notifications 成功响应外层结构不会回退。
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
 * 执行 HTTP 异常过滤器
 * 用于验证全局异常过滤链下的错误响应结构是否稳定。
 *
 * @param {NotFoundException} exception - 控制器抛出的 HTTP 异常
 * @param {string} url - 请求路径
 * @param {string} method - HTTP 方法
 * @returns {{ status: jest.Mock; json: jest.Mock }} 断言用响应对象
 */
function runHttpExceptionFilter(
  exception: NotFoundException,
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

  filter.catch(exception, host);

  return {
    status,
    json,
  };
}

describe('Notifications Response Contract', () => {
  let controller: NotificationsController;

  const mockNotificationsService = {
    findAll: jest.fn(),
    getUnreadCount: jest.fn(),
    findOne: jest.fn(),
    markAsRead: jest.fn(),
    markAllAsRead: jest.fn(),
  };

  const mockRequest = {
    user: { id: 1 },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [NotificationsController],
      providers: [
        {
          provide: NotificationsService,
          useValue: mockNotificationsService,
        },
      ],
    }).compile();

    controller = module.get<NotificationsController>(NotificationsController);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should keep top-level data and pagination for notifications list', async () => {
    mockNotificationsService.findAll.mockResolvedValue({
      data: [
        {
          id: 1,
          userId: 1,
          type: NotificationType.SYSTEM,
          title: '系统通知',
          content: '您的预约已成功',
          isRead: false,
          createdAt: 1770201000000,
          updatedAt: 1770201000000,
          readAt: null,
        },
      ],
      total: 12,
      page: 2,
      pageSize: 20,
    });

    const rawResult = await controller.findAll(mockRequest, {
      page: 2,
      pageSize: 20,
    });
    const wrappedResult = await runInterceptor(rawResult);

    expect(wrappedResult).toEqual({
      code: 0,
      data: [
        expect.objectContaining({
          id: 1,
          title: '系统通知',
        }),
      ],
      message: 'Success',
      meta: {
        timestamp: expect.any(String),
      },
      pagination: {
        total: 12,
        page: 2,
        pageSize: 20,
        limit: 20,
        totalPages: 1,
      },
    });
  });

  it('should wrap unread count into top-level data', async () => {
    mockNotificationsService.getUnreadCount.mockResolvedValue({ count: 5 });

    const rawResult = await controller.getUnreadCount(mockRequest);
    const wrappedResult = await runInterceptor(rawResult);

    expect(wrappedResult).toEqual({
      code: 0,
      data: { count: 5 },
      message: 'Success',
      meta: {
        timestamp: expect.any(String),
      },
    });
  });

  it('should keep not-found error contract stable for notification detail', async () => {
    mockNotificationsService.findOne.mockRejectedValue(
      new NotFoundException('Notification not found'),
    );

    let thrownError: NotFoundException | undefined;

    try {
      await controller.findOne(mockRequest, '999');
    } catch (error) {
      thrownError = error as NotFoundException;
    }

    expect(thrownError).toBeInstanceOf(NotFoundException);

    const { status, json } = runHttpExceptionFilter(
      thrownError as NotFoundException,
      '/notifications/999',
      'GET',
    );

    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith({
      success: false,
      code: 404,
      statusCode: 404,
      timestamp: expect.any(String),
      path: '/notifications/999',
      method: 'GET',
      message: 'Notification not found',
      error: 'Not Found',
    });
  });

  it('should keep unauthorized error contract stable for unread-count', () => {
    const { status, json } = runHttpExceptionFilter(
      new UnauthorizedException(),
      '/notifications/unread-count',
      'GET',
    );

    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        code: 401,
        statusCode: 401,
        timestamp: expect.any(String),
        path: '/notifications/unread-count',
        method: 'GET',
        message: 'Unauthorized',
        error: 'UnauthorizedException',
      }),
    );
  });

  it('should keep notification detail inside top-level data', async () => {
    mockNotificationsService.findOne.mockResolvedValue({
      id: 101,
      userId: 1,
      type: NotificationType.ANNOUNCEMENT,
      title: '公益活动回顾已发布',
      content: '点击查看公益回顾内容。',
      isRead: true,
      createdAt: 1770201000000,
      updatedAt: 1770201200000,
      readAt: 1770201200000,
    });

    const rawResult = await controller.findOne(mockRequest, '101');
    const wrappedResult = await runInterceptor(rawResult);

    expect(wrappedResult).toEqual({
      code: 0,
      data: expect.objectContaining({
        id: 101,
        title: '公益活动回顾已发布',
        isRead: true,
      }),
      message: 'Success',
      meta: {
        timestamp: expect.any(String),
      },
    });
  });

  it('should wrap markAsRead success into top-level data', async () => {
    mockNotificationsService.markAsRead.mockResolvedValue({ success: true });

    const rawResult = await controller.markAsRead(mockRequest, '1');
    const wrappedResult = await runInterceptor(rawResult);

    expect(wrappedResult).toEqual({
      code: 0,
      data: { success: true },
      message: 'Success',
      meta: {
        timestamp: expect.any(String),
      },
    });
  });

  it('should keep unauthorized error contract stable for markAsRead', () => {
    const { status, json } = runHttpExceptionFilter(
      new UnauthorizedException(),
      '/notifications/1/read',
      'PUT',
    );

    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        code: 401,
        statusCode: 401,
        timestamp: expect.any(String),
        path: '/notifications/1/read',
        method: 'PUT',
        message: 'Unauthorized',
        error: 'UnauthorizedException',
      }),
    );
  });

  it('should wrap markAllAsRead success into top-level data', async () => {
    mockNotificationsService.markAllAsRead.mockResolvedValue({
      success: true,
      updatedCount: 3,
    });

    const rawResult = await controller.markAllAsRead(mockRequest);
    const wrappedResult = await runInterceptor(rawResult);

    expect(wrappedResult).toEqual({
      code: 0,
      data: {
        success: true,
        updatedCount: 3,
      },
      message: 'Success',
      meta: {
        timestamp: expect.any(String),
      },
    });
  });

  it('should keep unauthorized error contract stable for markAllAsRead', () => {
    const { status, json } = runHttpExceptionFilter(
      new UnauthorizedException(),
      '/notifications/read-all',
      'PUT',
    );

    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        code: 401,
        statusCode: 401,
        timestamp: expect.any(String),
        path: '/notifications/read-all',
        method: 'PUT',
        message: 'Unauthorized',
        error: 'UnauthorizedException',
      }),
    );
  });
});
