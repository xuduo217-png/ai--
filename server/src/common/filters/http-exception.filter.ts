import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { buildErrorResponse, sendErrorResponse } from './error-response';

@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const status = exception.getStatus();
    const exceptionResponse = exception.getResponse();

    // 处理不同类型的异常响应
    let message: string | string[] = exception.message;
    let error = exception.name;
    let code: string | number | undefined = status;
    let validationErrors: string[] | undefined;

    if (typeof exceptionResponse === 'string') {
      message = exceptionResponse;
    } else if (typeof exceptionResponse === 'object') {
      const responseObj = exceptionResponse as any;
      message = responseObj.message || exception.message;
      code = responseObj.code ?? code;
      error = responseObj.error || exception.name;

      // 如果是验证错误，包含详细错误信息
      if (responseObj.error && Array.isArray(responseObj.message)) {
        validationErrors = responseObj.message;
      }
    }

    const errorResponse = buildErrorResponse(request, {
      statusCode: status,
      message,
      code,
      error,
      validationErrors,
    });

    // 记录错误日志
    this.logError(request, errorResponse);

    sendErrorResponse(response, errorResponse);
  }

  private logError(request: Request, errorResponse: any): void {
    const { method, url } = request;
    const { statusCode, message } = errorResponse;

    console.error(
      `[${new Date().toISOString()}] ${method} ${url} - ${statusCode}: ${message}`,
    );
  }
}
