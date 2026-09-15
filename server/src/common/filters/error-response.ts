import { HttpStatus } from '@nestjs/common';
import { Request, Response } from 'express';

export interface ErrorResponseOptions {
  statusCode: number;
  message: string | string[];
  error: string;
  code?: string | number;
  validationErrors?: string[];
}

export const buildErrorResponse = (
  request: Request,
  options: ErrorResponseOptions,
) => {
  const normalizedMessage = Array.isArray(options.message)
    ? options.message[0] || '请求失败'
    : options.message;

  return {
    success: false,
    code: options.code ?? options.statusCode,
    statusCode: options.statusCode,
    message: normalizedMessage,
    error: options.error,
    validationErrors: options.validationErrors,
    timestamp: new Date().toISOString(),
    path: request.url,
    method: request.method,
  };
};

export const sendErrorResponse = (response: Response, payload: unknown) => {
  response.status(HttpStatus.OK).json(payload);
};
