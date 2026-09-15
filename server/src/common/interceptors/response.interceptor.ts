import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
  StreamableFile,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

/**
 * 归一化正整数分页字段
 * 兼容历史接口返回的 `pageSize` / `limit` 两种命名，避免 NaN 透出到客户端。
 */
function toPositiveNumber(value: unknown): number | undefined {
  const parsedValue = Number(value);

  if (!Number.isFinite(parsedValue) || parsedValue <= 0) {
    return undefined;
  }

  return parsedValue;
}

/**
 * 统一构建分页响应
 * 保持现有 `pagination` 结构不变，同时补齐 `pageSize` 与 `limit` 双字段。
 */
function buildPagination(data: any) {
  if (data?.total === undefined || data?.page === undefined) {
    return undefined;
  }

  const normalizedPageSize = toPositiveNumber(data.pageSize ?? data.limit);
  const normalizedTotalPages =
    toPositiveNumber(data.totalPages) ??
    (normalizedPageSize ? Math.ceil(Number(data.total) / normalizedPageSize) : undefined);

  return {
    total: data.total,
    page: data.page,
    pageSize: normalizedPageSize,
    limit: normalizedPageSize,
    totalPages: normalizedTotalPages,
  };
}

/**
 * 判断是否需要保留业务层显式声明的成功载荷
 * 典型场景是 `{ success, message, data }`，rnapp 会直接消费这层结构。
 */
function shouldPreserveBusinessPayload(data: any): boolean {
  return (
    !!data &&
    typeof data === 'object' &&
    'success' in data &&
    'data' in data
  );
}

/**
 * 统一响应格式拦截器
 * 自动将响应数据包装成标准格式
 */
@Injectable()
export class ResponseInterceptor implements NestInterceptor {
  /**
   * 拦截控制器响应并包装为统一成功结构
   * 分页响应会被归一化，确保客户端稳定拿到 `pagination.pageSize/limit/totalPages`。
   */
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    return next.handle().pipe(
      map((data) => {
        // 如果是 StreamableFile（文件下载），直接返回
        if (data instanceof StreamableFile) {
          return data;
        }

        // 如果已经是标准响应格式，直接返回
        if (
          data &&
          typeof data === 'object' &&
          'code' in data &&
          'data' in data
        ) {
          return data;
        }

        // 构建标准响应格式 (兼容前端期望的格式)
        const shouldPreservePayload = shouldPreserveBusinessPayload(data);
        const result: any = {
          code: 0, // 前端期望的成功码
          data: shouldPreservePayload
            ? data
            : data?.data !== undefined
              ? data.data
              : data,
          message: data?.message || 'Success',
          meta: {
            timestamp: new Date().toISOString(),
            ...data?.meta,
          },
        };

        // 如果是分页结果，添加分页信息
        const pagination = buildPagination(data);
        if (pagination) {
          result.pagination = pagination;
        }

        return result;
      }),
    );
  }
}
