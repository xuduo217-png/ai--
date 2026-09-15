import { CallHandler, ExecutionContext } from '@nestjs/common';
import { lastValueFrom, of } from 'rxjs';
import { ResponseInterceptor } from './response.interceptor';

/**
 * 执行统一响应拦截器
 * 用于验证分页字段会被稳定归一化到前端约定的成功响应结构中。
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

describe('ResponseInterceptor', () => {
  it('should normalize pagination when service returns pageSize', async () => {
    const result = await runInterceptor({
      data: [{ id: 1 }],
      total: 25,
      page: 2,
      pageSize: 10,
    });

    expect(result).toEqual({
      code: 0,
      data: [{ id: 1 }],
      message: 'Success',
      meta: {
        timestamp: expect.any(String),
      },
      pagination: {
        total: 25,
        page: 2,
        pageSize: 10,
        limit: 10,
        totalPages: 3,
      },
    });
  });

  it('should normalize pagination when service returns limit', async () => {
    const result = await runInterceptor({
      data: [{ id: 2 }],
      total: 20,
      page: 1,
      limit: 5,
      totalPages: 4,
    });

    expect(result).toEqual({
      code: 0,
      data: [{ id: 2 }],
      message: 'Success',
      meta: {
        timestamp: expect.any(String),
      },
      pagination: {
        total: 20,
        page: 1,
        pageSize: 5,
        limit: 5,
        totalPages: 4,
      },
    });
  });

  it('should preserve explicit business payload when success and data are both present', async () => {
    const result = await runInterceptor({
      success: true,
      message: '报名成功',
      data: {
        registrationId: 12,
      },
    });

    expect(result).toEqual({
      code: 0,
      data: {
        success: true,
        message: '报名成功',
        data: {
          registrationId: 12,
        },
      },
      message: '报名成功',
      meta: {
        timestamp: expect.any(String),
      },
    });
  });
});
