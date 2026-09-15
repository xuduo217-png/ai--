/**
 * AI 诊断日志模块
 */
import { Module } from '@nestjs/common';
import { AiDiagnosisLoggerService } from './ai-diagnosis-logger.service';

@Module({
  providers: [AiDiagnosisLoggerService],
  exports: [AiDiagnosisLoggerService],
})
export class AiDiagnosisLoggerModule {}
