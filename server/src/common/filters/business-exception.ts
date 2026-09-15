import { HttpException, HttpStatus } from '@nestjs/common';

/**
 * 业务异常类
 * 用于自定义业务逻辑错误，包含错误码和错误消息
 */
export class BusinessException extends HttpException {
  constructor(
    message: string,
    public code: string,
    status: number = HttpStatus.BAD_REQUEST,
  ) {
    super(
      {
        statusCode: status,
        message,
        code,
        error: 'BUSINESS_ERROR',
      },
      status,
    );
  }
}

/**
 * 业务异常过滤器
 * 专门处理 BusinessException 类型异常
 */
import { ExceptionFilter, Catch, ArgumentsHost } from '@nestjs/common';
import { Request, Response } from 'express';
import { buildErrorResponse, sendErrorResponse } from './error-response';

@Catch(BusinessException)
export class BusinessExceptionFilter implements ExceptionFilter {
  catch(exception: BusinessException, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const status = exception.getStatus();
    const exceptionResponse = exception.getResponse() as any;

    const errorResponse = buildErrorResponse(request, {
      statusCode: status,
      message: exceptionResponse.message,
      code: exception.code,
      error: exceptionResponse.error,
    });

    // 记录业务逻辑错误（非系统错误，级别较低）
    console.warn(
      `[${new Date().toISOString()}] ${request.method} ${request.url} - Business Error [${exception.code}]: ${exceptionResponse.message}`,
    );

    sendErrorResponse(response, errorResponse);
  }
}
