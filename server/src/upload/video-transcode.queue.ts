export const VIDEO_TRANSCODE_QUEUE = 'video-transcode';
export const VIDEO_TRANSCODE_JOB = 'transcode';

export interface VideoTranscodeJobData {
  fileRecordId: number;
  localPath: string;
}
