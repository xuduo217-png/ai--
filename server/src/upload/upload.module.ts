import { Module } from '@nestjs/common';
import { MulterModule } from '@nestjs/platform-express';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BullModule } from '@nestjs/bull';
import { UploadService } from './upload.service';
import { UploadController } from './upload.controller';
import { FileRecord } from './entities/file-record.entity';
import { VideoTranscodeProcessor } from './video-transcode.processor';
import { VIDEO_TRANSCODE_QUEUE } from './video-transcode.queue';
import { CosStorageService } from './cos-storage.service';

@Module({
  imports: [
    MulterModule.registerAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => ({
        dest: configService.get<string>('UPLOAD_DEST') || './uploads',
      }),
      inject: [ConfigService],
    }),
    TypeOrmModule.forFeature([FileRecord]),
    BullModule.registerQueue({
      name: VIDEO_TRANSCODE_QUEUE,
      defaultJobOptions: {
        attempts: 2,
        backoff: {
          type: 'fixed',
          delay: 30 * 1000,
        },
        timeout: 15 * 60 * 1000,
        removeOnComplete: true,
        removeOnFail: false,
      },
    }),
  ],
  controllers: [UploadController],
  providers: [UploadService, CosStorageService, VideoTranscodeProcessor],
  exports: [UploadService],
})
export class UploadModule {}
