/**
 * AI 诊断日志服务
 * 将 AI 诊断过程中的关键信息记录到独立的日志文件
 * 用于调试和追踪 AI 诊断流程
 */

import { Injectable } from '@nestjs/common';
import { promises as fs } from 'fs';
import { join } from 'path';

/**
 * 日志级别
 */
enum LogLevel {
  INFO = 'INFO',
  SUCCESS = 'SUCCESS',
  ERROR = 'ERROR',
  WARNING = 'WARNING',
}

/**
 * 日志条目
 */
interface LogEntry {
  timestamp: string;
  level: LogLevel;
  reportId: number;
  type: 'WESTERN' | 'TCM' | 'REPORT';
  message: string;
  data?: any;
  error?: string;
  stackTrace?: string;
}

/**
 * AI 诊断日志服务
 */
@Injectable()
export class AiDiagnosisLoggerService {
  private readonly logDir: string;
  private readonly logFilePath: string;

  constructor() {
    // 日志文件路径：logs/ai-diagnosis/ai-diagnosis-YYYY-MM-DD.log
    this.logDir = join(process.cwd(), 'logs', 'ai-diagnosis');
    this.logFilePath = join(
      this.logDir,
      `ai-diagnosis-${new Date().toISOString().split('T')[0]}.log`,
    );
  }

  /**
   * 初始化日志目录
   */
  private async ensureLogDir(): Promise<void> {
    try {
      await fs.mkdir(this.logDir, { recursive: true });
    } catch (error) {
      console.error('创建日志目录失败:', error);
    }
  }

  /**
   * 写入日志到文件
   * @param entry 日志条目
   */
  private async writeLog(entry: LogEntry): Promise<void> {
    try {
      await this.ensureLogDir();

      // 格式化日志条目
      const logLine = JSON.stringify(entry) + '\n';

      // 追加写入文件
      await fs.appendFile(this.logFilePath, logLine, 'utf8');
    } catch (error) {
      console.error('写入日志失败:', error);
    }
  }

  /**
   * 记录信息日志
   * @param reportId 报告 ID
   * @param type 类型（西医/中医/报告）
   * @param message 消息
   * @param data 附加数据
   */
  async logInfo(
    reportId: number,
    type: 'WESTERN' | 'TCM' | 'REPORT',
    message: string,
    data?: any,
  ): Promise<void> {
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level: LogLevel.INFO,
      reportId,
      type,
      message,
      data,
    };
    await this.writeLog(entry);
  }

  /**
   * 记录成功日志
   * @param reportId 报告 ID
   * @param type 类型
   * @param message 消息
   * @param data 附加数据
   */
  async logSuccess(
    reportId: number,
    type: 'WESTERN' | 'TCM' | 'REPORT',
    message: string,
    data?: any,
  ): Promise<void> {
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level: LogLevel.SUCCESS,
      reportId,
      type,
      message,
      data,
    };
    await this.writeLog(entry);
  }

  /**
   * 记录错误日志
   * @param reportId 报告 ID
   * @param type 类型
   * @param message 消息
   * @param error 错误对象
   * @param data 附加数据
   */
  async logError(
    reportId: number,
    type: 'WESTERN' | 'TCM' | 'REPORT',
    message: string,
    error?: Error | string,
    data?: any,
  ): Promise<void> {
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level: LogLevel.ERROR,
      reportId,
      type,
      message,
      data,
      error: error instanceof Error ? error.message : error,
      stackTrace: error instanceof Error ? error.stack : undefined,
    };
    await this.writeLog(entry);
  }

  /**
   * 记录警告日志
   * @param reportId 报告 ID
   * @param type 类型
   * @param message 消息
   * @param data 附加数据
   */
  async logWarning(
    reportId: number,
    type: 'WESTERN' | 'TCM' | 'REPORT',
    message: string,
    data?: any,
  ): Promise<void> {
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level: LogLevel.WARNING,
      reportId,
      type,
      message,
      data,
    };
    await this.writeLog(entry);
  }

  /**
   * 记录 API 调用（专门用于记录第三方 API 调用）
   * @param reportId 报告 ID
   * @param type 类型
   * @param apiUrl API 地址
   * @param requestData 请求数据
   * @param responseData 响应数据
   * @param duration 耗时（毫秒）
   */
  async logApiCall(
    reportId: number,
    type: 'WESTERN' | 'TCM',
    apiUrl: string,
    requestData: any,
    responseData: any,
    duration: number,
  ): Promise<void> {
    await this.logSuccess(reportId, type, 'API 调用成功', {
      apiUrl,
      requestData,
      responseData,
      duration: `${duration}ms`,
    });
  }

  /**
   * 记录 API 调用失败
   * @param reportId 报告 ID
   * @param type 类型
   * @param apiUrl API 地址
   * @param requestData 请求数据
   * @param error 错误信息
   * @param duration 耗时（毫秒）
   */
  async logApiError(
    reportId: number,
    type: 'WESTERN' | 'TCM',
    apiUrl: string,
    requestData: any,
    error: Error | string,
    duration: number,
  ): Promise<void> {
    await this.logError(reportId, type, 'API 调用失败', error, {
      apiUrl,
      requestData,
      duration: `${duration}ms`,
    });
  }
}
