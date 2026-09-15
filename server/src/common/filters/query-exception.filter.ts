import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpStatus,
} from '@nestjs/common';
import { QueryFailedError } from 'typeorm';
import { Request, Response } from 'express';
import { buildErrorResponse, sendErrorResponse } from './error-response';

@Catch(QueryFailedError)
export class QueryExceptionFilter implements ExceptionFilter {
  catch(exception: QueryFailedError, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    // 获取数据库错误信息
    const driverError = exception.driverError as any;

    let message = '数据库操作失败';
    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let errorCode = 'DATABASE_ERROR';

    // 处理常见的数据库错误
    if (driverError) {
      // MySQL 唯一键冲突 (errno: 1062)
      if (driverError.errno === 1062 || driverError.code === 'ER_DUP_ENTRY') {
        message = '数据已存在，请勿重复提交';
        status = HttpStatus.CONFLICT;
        errorCode = 'DUPLICATE_ENTRY';
      }
      // MySQL 外键约束失败 (errno: 1452)
      else if (
        driverError.errno === 1452 ||
        driverError.code === 'ER_NO_REFERENCED_ROW_2'
      ) {
        message = '关联数据不存在，无法完成操作';
        status = HttpStatus.BAD_REQUEST;
        errorCode = 'FOREIGN_KEY_CONSTRAINT';
      }
      // MySQL 字段不能为空 (errno: 1048)
      else if (
        driverError.errno === 1048 ||
        driverError.code === 'ER_BAD_NULL_ERROR'
      ) {
        message = '必填字段不能为空';
        status = HttpStatus.BAD_REQUEST;
        errorCode = 'FIELD_REQUIRED';
      }
      // 其他数据库错误
      else {
        console.error('Database error:', driverError);
        message = driverError.message || message;
      }
    }

    const errorResponse = buildErrorResponse(request, {
      statusCode: status,
      message,
      code: errorCode,
      error: errorCode,
    });

    // 记录错误日志
    console.error(
      `[${new Date().toISOString()}] ${request.method} ${request.url} - Database Error:`,
      exception.message,
    );

    sendErrorResponse(response, errorResponse);
  }
}
