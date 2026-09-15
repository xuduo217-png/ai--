import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AiDiagnosisReportController } from './ai-diagnosis-report.controller';
import { AiDiagnosisReportService } from './ai-diagnosis-report.service';
import { AiDiagnosisReport } from './entities/ai-diagnosis-report.entity';
import { User } from '../users/entities/user.entity';
import { Pet } from '../pets/entities/pet.entity';
import { AiDiagnosisReportQueueModule } from './ai-diagnosis-report.queue.module';
import { AiDiagnosisLoggerModule } from './logger/ai-diagnosis-logger.module';

/**
 * AI 问诊报告模块
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([AiDiagnosisReport, User, Pet]),
    AiDiagnosisReportQueueModule,
    AiDiagnosisLoggerModule,
  ],
  controllers: [AiDiagnosisReportController],
  providers: [AiDiagnosisReportService],
  exports: [AiDiagnosisReportService],
})
export class AiDiagnosisReportModule {}
