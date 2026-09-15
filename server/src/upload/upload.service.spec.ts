import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { execFile } from 'child_process';
import { ConfigService } from '@nestjs/config';
import sharp = require('sharp');
import { UploadService } from './upload.service';
import { FileStatus } from './entities/file-record.entity';
import { CosStorageService } from './cos-storage.service';
import { VideoTranscodeProcessor } from './video-transcode.processor';

jest.mock('uuid', () => ({
  v4: () => 'mock-uuid',
}));

jest.mock('child_process', () => ({
  execFile: jest.fn(),
}));

const LEGACY_SKIP_THRESHOLD = 2 * 1024 * 1024;
const MP4_SIGNATURE = Buffer.from(
  '00000018667479706d703432000000006d70343269736f6d',
  'hex',
);
const HEIC_SIGNATURE = Buffer.from(
  '00000018667479706865696300000000686569636d696631',
  'hex',
);
const createPatternBuffer = (width: number, height: number): Buffer => {
  const buffer = Buffer.alloc(width * height * 3);

  for (let index = 0; index < buffer.length; index += 3) {
    buffer[index] = index % 256;
    buffer[index + 1] = Math.floor(index / 2) % 256;
    buffer[index + 2] = Math.floor(index / 3) % 256;
  }

  return buffer;
};

describe('UploadService processImage', () => {
  let tempRoot: string;
  let uploadDest: string;
  let service: UploadService;
  let cosStorageService: {
    toRelativeUrl: jest.Mock;
    uploadLocalFile: jest.Mock;
    deleteObjects: jest.Mock;
    objectExists: jest.Mock;
  };

  beforeEach(() => {
    tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'upload-service-'));
    uploadDest = path.join(tempRoot, 'uploads');
    fs.mkdirSync(uploadDest, { recursive: true });
    cosStorageService = {
      toRelativeUrl: jest.fn((filePath: string) => {
        const normalized = filePath.replace(/\\/g, '/').replace(/^\/+/, '');
        return normalized.startsWith('uploads/')
          ? `/${normalized}`
          : `/uploads/${normalized}`;
      }),
      uploadLocalFile: jest.fn().mockResolvedValue(undefined),
      deleteObjects: jest.fn().mockResolvedValue(undefined),
      objectExists: jest.fn().mockResolvedValue(true),
    };

    service = new UploadService(
      {
        get: (key: string) => {
          if (key === 'UPLOAD_DEST') {
            return uploadDest;
          }

          return undefined;
        },
      } as ConfigService,
      {
        create: jest.fn(),
        save: jest.fn(),
      } as any,
      cosStorageService as any,
    );
  });

  afterEach(() => {
    fs.rmSync(tempRoot, { recursive: true, force: true });
    jest.clearAllMocks();
  });

  const createOversizedPng = async (filename: string) => {
    const filePath = path.join(uploadDest, filename);
    const width = 2400;
    const height = 2400;
    const buffer = createPatternBuffer(width, height);

    await sharp(buffer, { raw: { width, height, channels: 3 } })
      .png({ compressionLevel: 0 })
      .toFile(filePath);

    return filePath;
  };

  const createHighResolutionJpegBelowLegacyThreshold = async (
    filename: string,
  ) => {
    const width = 2400;
    const height = 2400;
    const buffer = createPatternBuffer(width, height);

    for (const quality of [75, 70, 65, 60]) {
      const filePath = path.join(uploadDest, `${quality}-${filename}`);

      await sharp(buffer, { raw: { width, height, channels: 3 } })
        .jpeg({ quality })
        .toFile(filePath);

      const size = fs.statSync(filePath).size;
      if (size < LEGACY_SKIP_THRESHOLD) {
        return filePath;
      }
    }

    throw new Error(
      'Failed to create a JPEG sample below the legacy compression threshold',
    );
  };

  it('keeps oversized PNG uploads in a valid PNG format after compression', async () => {
    const filePath = await createOversizedPng('oversized.png');
    const beforeSize = fs.statSync(filePath).size;
    const options: any = {
      compress: true,
      generateThumbnail: false,
      mimeType: 'image/png',
    };

    expect(beforeSize).toBeGreaterThan(LEGACY_SKIP_THRESHOLD);

    const result = await service.processImage(filePath, options);
    const afterSize = fs.statSync(filePath).size;
    const signature = fs.readFileSync(filePath).subarray(0, 8).toString('hex');
    const metadata = await sharp(filePath).metadata();

    expect(result.isCompressed).toBe(true);
    expect(afterSize).toBeLessThan(beforeSize);
    expect(signature).toBe('89504e470d0a1a0a');
    expect(metadata.format).toBe('png');
  });

  it('compresses large-dimension JPEG uploads even when they are already below 2MB', async () => {
    const filePath = await createHighResolutionJpegBelowLegacyThreshold(
      'high-resolution.jpg',
    );
    const beforeSize = fs.statSync(filePath).size;
    const beforeMetadata = await sharp(filePath).metadata();
    const options: any = {
      compress: true,
      generateThumbnail: false,
      mimeType: 'image/jpeg',
    };

    expect(beforeSize).toBeLessThan(LEGACY_SKIP_THRESHOLD);
    expect(beforeMetadata.width).toBeGreaterThan(1600);

    const result = await service.processImage(filePath, options);
    const afterSize = fs.statSync(filePath).size;
    const afterMetadata = await sharp(filePath).metadata();

    expect(result.isCompressed).toBe(true);
    expect(afterSize).toBeLessThan(beforeSize);
    expect(afterMetadata.width).toBeLessThanOrEqual(1600);
    expect(afterMetadata.height).toBeLessThanOrEqual(1600);
  });

  it('generates and stores a thumbnail for video uploads', async () => {
    const repository = {
      create: jest.fn((value) => value),
      save: jest.fn(async (value) => value),
    };

    service = new UploadService(
      {
        get: (key: string) => {
          if (key === 'UPLOAD_DEST') {
            return uploadDest;
          }

          return undefined;
        },
      } as ConfigService,
      repository as any,
      cosStorageService as any,
    );

    const videoPath = path.join(uploadDest, 'demo.mp4');
    const expectedThumbnailPath = path.join(
      uploadDest,
      'thumbnails',
      'demo_video_cover.jpg',
    );

    fs.writeFileSync(videoPath, MP4_SIGNATURE);

    (execFile as unknown as jest.Mock).mockImplementation(
      (
        _command: string,
        _args: string[],
        callback: (
          error: Error | null,
          stdout?: string,
          stderr?: string,
        ) => void,
      ) => {
        fs.mkdirSync(path.dirname(expectedThumbnailPath), { recursive: true });
        fs.writeFileSync(expectedThumbnailPath, 'thumbnail');
        callback(null, '', '');
        return {} as any;
      },
    );

    const result = await (service as any).saveFileRecord(
      {
        mimetype: 'video/mp4',
        path: videoPath,
        filename: 'demo.mp4',
        originalname: 'demo.mp4',
        size: 1024,
      } as Express.Multer.File,
      1001,
      {
        generateThumbnail: true,
      },
    );

    expect(execFile).toHaveBeenCalled();
    expect(result.thumbnailPath).toBe(
      '/uploads/thumbnails/demo_video_cover.jpg',
    );
    expect(fs.existsSync(expectedThumbnailPath)).toBe(false);
    expect(repository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        path: '/uploads/demo.mp4',
        thumbnailPath: '/uploads/thumbnails/demo_video_cover.jpg',
      }),
    );
    expect(cosStorageService.uploadLocalFile).toHaveBeenCalledWith(
      expectedThumbnailPath,
      '/uploads/thumbnails/demo_video_cover.jpg',
      'image/jpeg',
    );
  });

  it('prefers the client uploaded thumbnail for video uploads', async () => {
    const repository = {
      create: jest.fn((value) => value),
      save: jest.fn(async (value) => value),
    };

    service = new UploadService(
      {
        get: (key: string) => {
          if (key === 'UPLOAD_DEST') {
            return uploadDest;
          }

          return undefined;
        },
      } as ConfigService,
      repository as any,
      cosStorageService as any,
    );

    const videoPath = path.join(uploadDest, 'demo.mp4');
    const thumbnailUploadPath = path.join(uploadDest, 'raw-thumb.jpg');
    const expectedThumbnailPath = path.join(
      uploadDest,
      'thumbnails',
      'demo_video_cover.jpg',
    );

    fs.writeFileSync(videoPath, MP4_SIGNATURE);
    await sharp({
      create: {
        width: 32,
        height: 32,
        channels: 3,
        background: '#336699',
      },
    })
      .jpeg()
      .toFile(thumbnailUploadPath);

    const result = await (service as any).saveFileRecord(
      {
        mimetype: 'video/mp4',
        path: videoPath,
        filename: 'demo.mp4',
        originalname: 'demo.mp4',
        size: 1024,
      } as Express.Multer.File,
      1001,
      {
        generateThumbnail: true,
      },
      {
        mimetype: 'image/jpeg',
        path: thumbnailUploadPath,
        filename: 'raw-thumb.jpg',
        originalname: 'raw-thumb.jpg',
        size: 256,
      } as Express.Multer.File,
    );

    expect(execFile).not.toHaveBeenCalled();
    expect(result.thumbnailPath).toBe(
      '/uploads/thumbnails/demo_video_cover.jpg',
    );
    expect(fs.existsSync(expectedThumbnailPath)).toBe(false);
    expect(fs.existsSync(thumbnailUploadPath)).toBe(false);
    expect(repository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        path: '/uploads/demo.mp4',
        thumbnailPath: '/uploads/thumbnails/demo_video_cover.jpg',
      }),
    );
  });

  it('queues supported video uploads for background compression', async () => {
    const repository = {
      create: jest.fn((value) => value),
      save: jest.fn(async (value) => ({ ...value, id: 42 })),
    };
    const queue = {
      add: jest.fn().mockResolvedValue({ id: 'video-transcode-42' }),
    };
    service = new UploadService(
      {
        get: (key: string) => (key === 'UPLOAD_DEST' ? uploadDest : undefined),
      } as ConfigService,
      repository as any,
      cosStorageService as any,
      queue as any,
    );
    const videoPath = path.join(uploadDest, 'queued.mp4');
    fs.writeFileSync(videoPath, MP4_SIGNATURE);

    await service.saveFileRecord(
      {
        mimetype: 'video/mp4',
        path: videoPath,
        filename: 'queued.mp4',
        originalname: 'queued.mp4',
        size: MP4_SIGNATURE.length,
      } as Express.Multer.File,
      1001,
      { compress: true, generateThumbnail: false },
      undefined,
      ['video'],
    );

    expect(queue.add).toHaveBeenCalledWith(
      'transcode',
      { fileRecordId: 42, localPath: videoPath },
      { jobId: 'video-transcode-42' },
    );
    expect(fs.existsSync(videoPath)).toBe(true);
  });

  it('does not queue video compression when compress is false', async () => {
    const repository = {
      create: jest.fn((value) => value),
      save: jest.fn(async (value) => ({ ...value, id: 43 })),
    };
    const queue = { add: jest.fn() };
    service = new UploadService(
      {
        get: (key: string) => (key === 'UPLOAD_DEST' ? uploadDest : undefined),
      } as ConfigService,
      repository as any,
      cosStorageService as any,
      queue as any,
    );
    const videoPath = path.join(uploadDest, 'uncompressed.mp4');
    fs.writeFileSync(videoPath, MP4_SIGNATURE);

    await service.saveFileRecord(
      {
        mimetype: 'video/mp4',
        path: videoPath,
        filename: 'uncompressed.mp4',
        originalname: 'uncompressed.mp4',
        size: MP4_SIGNATURE.length,
      } as Express.Multer.File,
      1001,
      { compress: false, generateThumbnail: false },
      undefined,
      ['video'],
    );

    expect(queue.add).not.toHaveBeenCalled();
  });

  it('atomically replaces a stored video when compression makes it smaller', async () => {
    const videoPath = path.join(uploadDest, 'large.mp4');
    const originalContent = Buffer.concat([
      MP4_SIGNATURE,
      Buffer.alloc(512, 1),
    ]);
    const compressedContent = Buffer.concat([
      MP4_SIGNATURE,
      Buffer.alloc(32, 2),
    ]);
    fs.writeFileSync(videoPath, originalContent);
    const repository = {
      findOne: jest.fn().mockResolvedValue({
        id: 44,
        path: '/uploads/large.mp4',
        mimeType: 'video/mp4',
        isCompressed: false,
        isDeleted: false,
      }),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    service = new UploadService(
      {
        get: (key: string) => (key === 'UPLOAD_DEST' ? uploadDest : undefined),
      } as ConfigService,
      repository as any,
      cosStorageService as any,
    );
    (execFile as unknown as jest.Mock).mockImplementation(
      (
        _command: string,
        args: string[],
        _options: object,
        callback: Function,
      ) => {
        fs.writeFileSync(args.at(-1)!, compressedContent);
        callback(null, '', '');
        return {} as any;
      },
    );

    const result = await service.compressStoredVideo(44, videoPath);

    expect(result).toEqual({
      status: 'compressed',
      originalSize: originalContent.length,
      compressedSize: compressedContent.length,
    });
    expect(fs.existsSync(videoPath)).toBe(false);
    expect(cosStorageService.uploadLocalFile).toHaveBeenCalledWith(
      expect.stringContaining('.transcoding-'),
      '/uploads/large.mp4',
      'video/mp4',
    );
    expect(repository.update).toHaveBeenCalledWith(44, {
      size: compressedContent.length,
      isCompressed: true,
    });
    expect(execFile).toHaveBeenCalledWith(
      'ffmpeg',
      expect.arrayContaining(['libx264', '+faststart']),
      expect.objectContaining({ timeout: 15 * 60 * 1000 }),
      expect.any(Function),
    );
  });

  it('compresses an active video when the enum-backed delete status is returned', async () => {
    const videoPath = path.join(uploadDest, 'active-status.mp4');
    const originalContent = Buffer.concat([
      MP4_SIGNATURE,
      Buffer.alloc(256, 1),
    ]);
    const compressedContent = Buffer.concat([
      MP4_SIGNATURE,
      Buffer.alloc(16, 2),
    ]);
    fs.writeFileSync(videoPath, originalContent);
    const repository = {
      findOne: jest.fn().mockResolvedValue({
        id: 47,
        path: '/uploads/active-status.mp4',
        mimeType: 'video/mp4',
        isCompressed: false,
        isDeleted: FileStatus.ACTIVE,
      }),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    service = new UploadService(
      {
        get: (key: string) => (key === 'UPLOAD_DEST' ? uploadDest : undefined),
      } as ConfigService,
      repository as any,
      cosStorageService as any,
    );
    (execFile as unknown as jest.Mock).mockImplementation(
      (
        _command: string,
        args: string[],
        _options: object,
        callback: Function,
      ) => {
        fs.writeFileSync(args.at(-1)!, compressedContent);
        callback(null, '', '');
        return {} as any;
      },
    );

    const result = await service.compressStoredVideo(47, videoPath);

    expect(result.status).toBe('compressed');
    expect(fs.existsSync(videoPath)).toBe(false);
    expect(repository.update).toHaveBeenCalledWith(47, {
      size: compressedContent.length,
      isCompressed: true,
    });
  });

  it('keeps the original video when the compressed output is not smaller', async () => {
    const videoPath = path.join(uploadDest, 'already-small.mp4');
    const originalContent = Buffer.concat([MP4_SIGNATURE, Buffer.alloc(32, 1)]);
    fs.writeFileSync(videoPath, originalContent);
    const repository = {
      findOne: jest.fn().mockResolvedValue({
        id: 45,
        path: '/uploads/already-small.mp4',
        mimeType: 'video/mp4',
        isCompressed: false,
        isDeleted: false,
      }),
      update: jest.fn(),
    };
    service = new UploadService(
      {
        get: (key: string) => (key === 'UPLOAD_DEST' ? uploadDest : undefined),
      } as ConfigService,
      repository as any,
      cosStorageService as any,
    );
    (execFile as unknown as jest.Mock).mockImplementation(
      (
        _command: string,
        args: string[],
        _options: object,
        callback: Function,
      ) => {
        fs.writeFileSync(
          args.at(-1)!,
          Buffer.alloc(originalContent.length + 1),
        );
        callback(null, '', '');
        return {} as any;
      },
    );

    const result = await service.compressStoredVideo(45, videoPath);

    expect(result.status).toBe('skipped');
    expect(result.reason).toBe('压缩结果未变小');
    expect(fs.existsSync(videoPath)).toBe(false);
    expect(cosStorageService.uploadLocalFile).not.toHaveBeenCalled();
    expect(repository.update).not.toHaveBeenCalled();
    expect(
      fs.readdirSync(uploadDest).some((name) => name.includes('.transcoding-')),
    ).toBe(false);
  });

  it('keeps the original video and removes temporary output when ffmpeg fails', async () => {
    const videoPath = path.join(uploadDest, 'failed.mp4');
    const originalContent = Buffer.concat([MP4_SIGNATURE, Buffer.alloc(64, 1)]);
    fs.writeFileSync(videoPath, originalContent);
    const repository = {
      findOne: jest.fn().mockResolvedValue({
        id: 46,
        path: '/uploads/failed.mp4',
        mimeType: 'video/mp4',
        isCompressed: false,
        isDeleted: false,
      }),
      update: jest.fn(),
    };
    service = new UploadService(
      {
        get: (key: string) => (key === 'UPLOAD_DEST' ? uploadDest : undefined),
      } as ConfigService,
      repository as any,
      cosStorageService as any,
    );
    (execFile as unknown as jest.Mock).mockImplementation(
      (
        _command: string,
        args: string[],
        _options: object,
        callback: Function,
      ) => {
        fs.writeFileSync(args.at(-1)!, 'partial output');
        callback(new Error('ffmpeg failed'));
        return {} as any;
      },
    );

    await expect(service.compressStoredVideo(46, videoPath)).rejects.toThrow(
      'ffmpeg failed',
    );

    expect(fs.readFileSync(videoPath)).toEqual(originalContent);
    expect(repository.update).not.toHaveBeenCalled();
    expect(
      fs.readdirSync(uploadDest).some((name) => name.includes('.transcoding-')),
    ).toBe(false);
  });

  it('rejects spoofed image MIME content and removes the uploaded file', async () => {
    const filePath = path.join(uploadDest, 'payload.html');
    fs.writeFileSync(filePath, '<script>alert(1)</script>');

    await expect(
      service.saveFileRecord(
        {
          mimetype: 'image/jpeg',
          path: filePath,
          filename: 'payload.html',
          originalname: 'payload.html',
          size: fs.statSync(filePath).size,
        } as Express.Multer.File,
        1001,
        undefined,
        undefined,
        ['image'],
      ),
    ).rejects.toThrow('图片格式不受支持');

    expect(fs.existsSync(filePath)).toBe(false);
  });

  it('normalizes an allowed image to its detected safe extension', async () => {
    const repository = {
      create: jest.fn((value) => value),
      save: jest.fn(async (value) => value),
    };
    service = new UploadService(
      {
        get: (key: string) => (key === 'UPLOAD_DEST' ? uploadDest : undefined),
      } as ConfigService,
      repository as any,
      cosStorageService as any,
    );
    const originalPath = path.join(uploadDest, 'photo.html');
    await sharp({
      create: {
        width: 2,
        height: 2,
        channels: 3,
        background: '#ffffff',
      },
    })
      .jpeg()
      .toFile(originalPath);
    const file = {
      mimetype: 'application/octet-stream',
      path: originalPath,
      filename: 'photo.html',
      originalname: 'photo.html',
      size: fs.statSync(originalPath).size,
    } as Express.Multer.File;

    await service.saveFileRecord(
      file,
      1001,
      { compress: false, generateThumbnail: false },
      undefined,
      ['image'],
    );

    expect(file.filename).toBe('photo.jpg');
    expect(file.path).toBe(path.join(uploadDest, 'photo.jpg'));
    expect(fs.existsSync(originalPath)).toBe(false);
    expect(fs.existsSync(file.path)).toBe(false);
    expect(cosStorageService.uploadLocalFile).toHaveBeenCalledWith(
      file.path,
      '/uploads/photo.jpg',
      'image/jpeg',
    );
    expect(repository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        filename: 'photo.jpg',
        mimeType: 'image/jpeg',
      }),
    );
  });

  it('removes COS objects and local files when the database write fails', async () => {
    const repository = {
      create: jest.fn((value) => value),
      save: jest.fn().mockRejectedValue(new Error('database unavailable')),
    };
    service = new UploadService(
      {
        get: (key: string) => (key === 'UPLOAD_DEST' ? uploadDest : undefined),
      } as ConfigService,
      repository as any,
      cosStorageService as any,
    );
    const filePath = path.join(uploadDest, 'rollback.jpg');
    await sharp({
      create: {
        width: 2,
        height: 2,
        channels: 3,
        background: '#ffffff',
      },
    })
      .jpeg()
      .toFile(filePath);

    await expect(
      service.saveFileRecord(
        {
          mimetype: 'image/jpeg',
          path: filePath,
          filename: 'rollback.jpg',
          originalname: 'rollback.jpg',
          size: fs.statSync(filePath).size,
        } as Express.Multer.File,
        1001,
        { compress: false, generateThumbnail: false },
        undefined,
        ['image'],
      ),
    ).rejects.toThrow('database unavailable');

    expect(cosStorageService.deleteObjects).toHaveBeenCalledWith([
      '/uploads/rollback.jpg',
    ]);
    expect(fs.existsSync(filePath)).toBe(false);
  });

  it('rejects a real video on image-only upload paths', async () => {
    const filePath = path.join(uploadDest, 'video.mp4');
    fs.writeFileSync(filePath, MP4_SIGNATURE);

    await expect(
      service.saveFileRecord(
        {
          mimetype: 'video/mp4',
          path: filePath,
          filename: 'video.mp4',
          originalname: 'video.mp4',
          size: MP4_SIGNATURE.length,
        } as Express.Multer.File,
        1001,
        undefined,
        undefined,
        ['image'],
      ),
    ).rejects.toThrow('图片格式不受支持');

    expect(fs.existsSync(filePath)).toBe(false);
  });

  it('rejects HEIC content instead of treating its ISO container as MP4', async () => {
    const filePath = path.join(uploadDest, 'photo.heic');
    fs.writeFileSync(filePath, HEIC_SIGNATURE);

    await expect(
      service.saveFileRecord(
        {
          mimetype: 'application/octet-stream',
          path: filePath,
          filename: 'photo.heic',
          originalname: 'photo.heic',
          size: HEIC_SIGNATURE.length,
        } as Express.Multer.File,
        1001,
        undefined,
        undefined,
        ['video', 'audio', 'pdf'],
      ),
    ).rejects.toThrow('文件格式不受支持');

    expect(fs.existsSync(filePath)).toBe(false);
  });

  it('lets generic browser MIME values reach real content validation', () => {
    const options = UploadService.getMulterOptionsStatic({
      get: () => undefined,
    } as unknown as ConfigService);
    const callback = jest.fn();

    options.fileFilter(
      {} as any,
      { mimetype: 'application/octet-stream' } as Express.Multer.File,
      callback,
    );

    expect(callback).toHaveBeenCalledWith(null, true);
  });
});

describe('CosStorageService integration contract', () => {
  const createService = () =>
    new CosStorageService({
      get: (key: string) =>
        ({
          COS_SECRET_ID: 'secret-id',
          COS_SECRET_KEY: 'secret-key',
          COS_BUCKET: 'gdcw-1386217335',
          COS_REGION: 'ap-chengdu',
        })[key],
    } as ConfigService);

  it('keeps migrated upload paths as stable COS object keys', () => {
    const service = createService();

    expect(service.toObjectKey('/uploads/nested/photo.jpg')).toBe(
      'uploads/nested/photo.jpg',
    );
    expect(service.toRelativeUrl('photo.jpg')).toBe('/uploads/photo.jpg');
    expect(() => service.toObjectKey('../private.txt')).toThrow(
      'COS 对象路径不能包含上级目录',
    );
  });

  it('uses the configured private-write bucket for local file uploads', async () => {
    const service = createService();
    const uploadFile = jest.fn().mockResolvedValue({});
    (service as any).cos = { uploadFile };

    await service.uploadLocalFile(
      '/tmp/photo.jpg',
      '/uploads/photo.jpg',
      'image/jpeg',
    );

    expect(uploadFile).toHaveBeenCalledWith(
      expect.objectContaining({
        Bucket: 'gdcw-1386217335',
        Region: 'ap-chengdu',
        Key: 'uploads/photo.jpg',
        FilePath: '/tmp/photo.jpg',
      }),
    );
  });
});

describe('VideoTranscodeProcessor cleanup', () => {
  it('keeps the local video while Bull still has a retry left', () => {
    const uploadService = {
      cleanupPendingVideoFile: jest.fn(),
    };
    const processor = new VideoTranscodeProcessor(uploadService as any);

    processor.handleFailed(
      {
        data: { fileRecordId: 42, localPath: '/tmp/video.mp4' },
        attemptsMade: 1,
        opts: { attempts: 2 },
      } as any,
      new Error('ffmpeg failed'),
    );

    expect(uploadService.cleanupPendingVideoFile).not.toHaveBeenCalled();
  });

  it('removes the local video after the final failed attempt', () => {
    const uploadService = {
      cleanupPendingVideoFile: jest.fn(),
    };
    const processor = new VideoTranscodeProcessor(uploadService as any);

    processor.handleFailed(
      {
        data: { fileRecordId: 42, localPath: '/tmp/video.mp4' },
        attemptsMade: 2,
        opts: { attempts: 2 },
      } as any,
      new Error('ffmpeg failed'),
    );

    expect(uploadService.cleanupPendingVideoFile).toHaveBeenCalledWith(
      '/tmp/video.mp4',
    );
  });
});
