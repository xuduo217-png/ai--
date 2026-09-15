import { Module, OnModuleInit } from '@nestjs/common';
import { BullModule } from '@nestjs/bull';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HttpModule } from '@nestjs/axios';
import { AiDiagnosisReport } from './entities/ai-diagnosis-report.entity';
import { WesternDiagnosisProcessor } from './processors/western-diagnosis.processor';
import { TcmDiagnosisProcessor } from './processors/tcm-diagnosis.processor';
import { WESTERN_DIAGNOSIS_QUEUE, TCM_DIAGNOSIS_QUEUE } from './queues';
import { AiDiagnosisLoggerModule } from './logger/ai-diagnosis-logger.module';
import { Logger } from '@nestjs/common';

/**
 * AI 问诊报告队列模块
 * 负责西医和中医诊断的异步处理
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([AiDiagnosisReport]),
    HttpModule,
    AiDiagnosisLoggerModule,
    BullModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        redis: {
          host: configService.get('REDIS_HOST', 'localhost'),
          port: configService.get<number>('REDIS_PORT', 6379),
          password: configService.get('REDIS_PASSWORD', ''),
          db: configService.get<number>('REDIS_DB', 0),
        },
      }),
    }),
    BullModule.registerQueue(
      {
        name: WESTERN_DIAGNOSIS_QUEUE,
        defaultJobOptions: {
          attempts: 3,
          backoff: {
            type: 'fixed',
            delay: 5 * 60 * 1000,
          },
          timeout: 8 * 60 * 60 * 1000,
          removeOnComplete: false,
          removeOnFail: false,
        },
      },
      {
        name: TCM_DIAGNOSIS_QUEUE,
        defaultJobOptions: {
          attempts: 3,
          backoff: {
            type: 'fixed',
            delay: 5 * 60 * 1000,
          },
          timeout: 8 * 60 * 60 * 1000,
          removeOnComplete: false,
          removeOnFail: false,
        },
      },
    ),
  ],
  providers: [WesternDiagnosisProcessor, TcmDiagnosisProcessor],
  exports: [BullModule],
})
export class AiDiagnosisReportQueueModule implements OnModuleInit {
  private readonly logger = new Logger(AiDiagnosisReportQueueModule.name);

  onModuleInit() {
    this.logger.log(`✅ AI 诊断队列模块已启动`);
    this.logger.log(`   - 西医诊断队列: ${WESTERN_DIAGNOSIS_QUEUE}`);
    this.logger.log(`   - 中医诊断队列: ${TCM_DIAGNOSIS_QUEUE}`);
    this.logger.log(
      `   - 处理器: WesternDiagnosisProcessor, TcmDiagnosisProcessor`,
    );
  }
}
