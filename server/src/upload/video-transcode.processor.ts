import { OnQueueFailed, Process, Processor } from '@nestjs/bull';
import { Logger } from '@nestjs/common';
import type { Job } from 'bull';
import { UploadService } from './upload.service';
import {
  VIDEO_TRANSCODE_JOB,
  VIDEO_TRANSCODE_QUEUE,
  VideoTranscodeJobData,
} from './video-transcode.queue';

@Processor(VIDEO_TRANSCODE_QUEUE)
export class VideoTranscodeProcessor {
  private readonly logger = new Logger(VideoTranscodeProcessor.name);

  constructor(private readonly uploadService: UploadService) {}

  @Process({ name: VIDEO_TRANSCODE_JOB, concurrency: 1 })
  async handleTranscode(job: Job<VideoTranscodeJobData>) {
    this.logger.log(`开始压缩视频: fileRecordId=${job.data.fileRecordId}`);
    const result = await this.uploadService.compressStoredVideo(
      job.data.fileRecordId,
      job.data.localPath,
    );
    this.logger.log(
      `视频压缩任务结束: fileRecordId=${job.data.fileRecordId}, status=${result.status}`,
    );
    return result;
  }

  @OnQueueFailed()
  handleFailed(job: Job<VideoTranscodeJobData>, error: Error) {
    const maxAttempts = job.opts.attempts ?? 1;
    if (job.attemptsMade < maxAttempts) {
      return;
    }

    this.uploadService.cleanupPendingVideoFile(job.data.localPath);
    this.logger.error(
      `视频压缩最终失败，已清理本地临时文件: fileRecordId=${job.data.fileRecordId}, ${error.message}`,
    );
  }
}
