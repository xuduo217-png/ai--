import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ForbiddenException,
  Logger,
  Optional,
} from "@nestjs/common";
import { InjectQueue } from "@nestjs/bull";
import { execFile } from "child_process";
import { ConfigService } from "@nestjs/config";
import { randomUUID } from "crypto";
import { extname } from "path";
import { diskStorage } from "multer";
import type { MulterOptions } from "@nestjs/platform-express/multer/interfaces/multer-options.interface";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import {
  FileRecord,
  FileStatus,
  FileType,
} from "./entities/file-record.entity";
import { QueryFilesDto } from "./dto/query-files.dto";
import { PaginatedResult } from "../common/dto/pagination.dto";
import * as fs from "fs";
import * as path from "path";
import sharp = require("sharp");
import type { Queue } from "bull";
import {
  VIDEO_TRANSCODE_JOB,
  VIDEO_TRANSCODE_QUEUE,
  VideoTranscodeJobData,
} from "./video-transcode.queue";
import { CosStorageService } from "./cos-storage.service";

export type UploadFileKind = "image" | "video" | "audio" | "pdf";

type DetectedUploadType = {
  extension: string;
  kind: UploadFileKind;
  mimeType: string;
};

const SUPPORTED_UPLOAD_TYPES: Record<string, DetectedUploadType> = {
  "image/jpeg": { extension: "jpg", kind: "image", mimeType: "image/jpeg" },
  "image/png": { extension: "png", kind: "image", mimeType: "image/png" },
  "image/gif": { extension: "gif", kind: "image", mimeType: "image/gif" },
  "image/webp": { extension: "webp", kind: "image", mimeType: "image/webp" },
  "application/pdf": {
    extension: "pdf",
    kind: "pdf",
    mimeType: "application/pdf",
  },
  "video/mp4": { extension: "mp4", kind: "video", mimeType: "video/mp4" },
  "video/x-m4v": {
    extension: "m4v",
    kind: "video",
    mimeType: "video/mp4",
  },
  "video/quicktime": {
    extension: "mov",
    kind: "video",
    mimeType: "video/quicktime",
  },
  "video/mpeg": {
    extension: "mpeg",
    kind: "video",
    mimeType: "video/mpeg",
  },
  "video/vnd.avi": {
    extension: "avi",
    kind: "video",
    mimeType: "video/x-msvideo",
  },
  "video/x-ms-asf": {
    extension: "wmv",
    kind: "video",
    mimeType: "video/x-ms-wmv",
  },
  "video/webm": {
    extension: "webm",
    kind: "video",
    mimeType: "video/webm",
  },
  "audio/mpeg": {
    extension: "mp3",
    kind: "audio",
    mimeType: "audio/mpeg",
  },
  "audio/mp4": {
    extension: "m4a",
    kind: "audio",
    mimeType: "audio/mp4",
  },
  "audio/x-m4a": {
    extension: "m4a",
    kind: "audio",
    mimeType: "audio/x-m4a",
  },
  "audio/aac": {
    extension: "aac",
    kind: "audio",
    mimeType: "audio/aac",
  },
  "audio/amr": {
    extension: "amr",
    kind: "audio",
    mimeType: "audio/amr",
  },
  "audio/ogg": {
    extension: "ogg",
    kind: "audio",
    mimeType: "audio/ogg",
  },
  "audio/ogg; codecs=opus": {
    extension: "ogg",
    kind: "audio",
    mimeType: "audio/ogg",
  },
  "audio/wav": {
    extension: "wav",
    kind: "audio",
    mimeType: "audio/wav",
  },
  "audio/webm": {
    extension: "webm",
    kind: "audio",
    mimeType: "audio/webm",
  },
};

const ALL_UPLOAD_KINDS: readonly UploadFileKind[] = [
  "image",
  "video",
  "audio",
  "pdf",
];

const VIDEO_TRANSCODE_FORMATS: Readonly<Record<string, "mp4" | "mov">> = {
  "video/mp4": "mp4",
  "video/quicktime": "mov",
};
const VIDEO_TRANSCODE_TIMEOUT_MS = 15 * 60 * 1000;
const VIDEO_TRANSCODE_MAX_BUFFER = 10 * 1024 * 1024;

const startsWithBytes = (buffer: Buffer, signature: readonly number[]) => {
  return signature.every((value, index) => buffer[index] === value);
};

const asciiAt = (buffer: Buffer, start: number, length: number) => {
  return buffer.subarray(start, start + length).toString("ascii");
};

const detectUploadType = async (
  filePath: string,
  declaredMimeType = "",
): Promise<DetectedUploadType | undefined> => {
  const file = await fs.promises.open(filePath, "r");
  try {
    const header = Buffer.alloc(4100);
    const { bytesRead } = await file.read(header, 0, header.length, 0);
    const bytes = header.subarray(0, bytesRead);

    if (startsWithBytes(bytes, [0xff, 0xd8, 0xff])) {
      return SUPPORTED_UPLOAD_TYPES["image/jpeg"];
    }
    if (
      startsWithBytes(bytes, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
    ) {
      return SUPPORTED_UPLOAD_TYPES["image/png"];
    }
    if (
      asciiAt(bytes, 0, 6) === "GIF87a" ||
      asciiAt(bytes, 0, 6) === "GIF89a"
    ) {
      return SUPPORTED_UPLOAD_TYPES["image/gif"];
    }
    if (asciiAt(bytes, 0, 4) === "RIFF" && asciiAt(bytes, 8, 4) === "WEBP") {
      return SUPPORTED_UPLOAD_TYPES["image/webp"];
    }
    if (asciiAt(bytes, 0, 5) === "%PDF-") {
      return SUPPORTED_UPLOAD_TYPES["application/pdf"];
    }
    if (asciiAt(bytes, 4, 4) === "ftyp") {
      const brand = asciiAt(bytes, 8, 4);
      const unsupportedImageBrands = new Set([
        "avif",
        "avis",
        "heic",
        "heix",
        "hevc",
        "hevx",
        "mif1",
        "msf1",
      ]);
      if (
        unsupportedImageBrands.has(brand.toLowerCase()) ||
        brand.toLowerCase().startsWith("3gp") ||
        brand.toLowerCase().startsWith("3g2")
      ) {
        return undefined;
      }
      if (["M4A ", "M4B ", "F4A ", "F4B "].includes(brand)) {
        return SUPPORTED_UPLOAD_TYPES["audio/x-m4a"];
      }
      if (brand === "qt  ") {
        return SUPPORTED_UPLOAD_TYPES["video/quicktime"];
      }
      if (["M4V ", "M4P "].includes(brand)) {
        return SUPPORTED_UPLOAD_TYPES["video/x-m4v"];
      }
      return SUPPORTED_UPLOAD_TYPES["video/mp4"];
    }
    if (
      startsWithBytes(bytes, [0x00, 0x00, 0x01, 0xba]) ||
      startsWithBytes(bytes, [0x00, 0x00, 0x01, 0xb3])
    ) {
      return SUPPORTED_UPLOAD_TYPES["video/mpeg"];
    }
    if (asciiAt(bytes, 0, 4) === "RIFF" && asciiAt(bytes, 8, 4) === "AVI ") {
      return SUPPORTED_UPLOAD_TYPES["video/vnd.avi"];
    }
    if (
      startsWithBytes(
        bytes,
        [
          0x30, 0x26, 0xb2, 0x75, 0x8e, 0x66, 0xcf, 0x11, 0xa6, 0xd9, 0x00,
          0xaa, 0x00, 0x62, 0xce, 0x6c,
        ],
      )
    ) {
      return SUPPORTED_UPLOAD_TYPES["video/x-ms-asf"];
    }
    if (startsWithBytes(bytes, [0x1a, 0x45, 0xdf, 0xa3])) {
      if (declaredMimeType.trim().toLowerCase() === "audio/webm") {
        return SUPPORTED_UPLOAD_TYPES["audio/webm"];
      }
      return SUPPORTED_UPLOAD_TYPES["video/webm"];
    }
    if (
      asciiAt(bytes, 0, 3) === "ID3" ||
      (bytes[0] === 0xff &&
        (bytes[1] & 0xe0) === 0xe0 &&
        (bytes[1] & 0x06) !== 0)
    ) {
      return SUPPORTED_UPLOAD_TYPES["audio/mpeg"];
    }
    if (bytes[0] === 0xff && (bytes[1] & 0xf6) === 0xf0) {
      return SUPPORTED_UPLOAD_TYPES["audio/aac"];
    }
    if (asciiAt(bytes, 0, 6) === "#!AMR\n") {
      return SUPPORTED_UPLOAD_TYPES["audio/amr"];
    }
    if (asciiAt(bytes, 0, 4) === "OggS") {
      return SUPPORTED_UPLOAD_TYPES["audio/ogg"];
    }
    if (asciiAt(bytes, 0, 4) === "RIFF" && asciiAt(bytes, 8, 4) === "WAVE") {
      return SUPPORTED_UPLOAD_TYPES["audio/wav"];
    }
    return undefined;
  } finally {
    await file.close();
  }
};

const getMulterOptions = (configService: ConfigService): MulterOptions => {
  const uploadDest = configService.get<string>("UPLOAD_DEST") || "./uploads";
  const maxFileSize = configService.get<number>("MAX_FILE_SIZE") || 838860800; // 800MB (支持大视频上传)

  return {
    storage: diskStorage({
      destination: uploadDest,
      filename: (_req, _file, cb) => {
        cb(null, randomUUID());
      },
    }),
    limits: {
      fileSize: maxFileSize,
    },
    // MIME 由客户端声明，可能为空或错误。落盘后统一按文件头做最终校验。
    fileFilter: (_req, _file, cb) => cb(null, true),
  };
};

@Injectable()
export class UploadService {
  private uploadDest: string;
  private readonly logger = new Logger(UploadService.name);

  constructor(
    private configService: ConfigService,
    @InjectRepository(FileRecord)
    private fileRecordRepository: Repository<FileRecord>,
    private readonly cosStorageService: CosStorageService,
    @Optional()
    @InjectQueue(VIDEO_TRANSCODE_QUEUE)
    private readonly videoTranscodeQueue?: Queue<VideoTranscodeJobData>,
  ) {
    this.uploadDest =
      this.configService.get<string>("UPLOAD_DEST") || "./uploads";
  }

  static getMulterOptionsStatic(configService: ConfigService) {
    return getMulterOptions(configService);
  }

  /**
   * 构建上传文件访问地址
   * 业务规则：保留子目录层级，避免缩略图等派生资源丢失真实目录信息。
   */
  getFileUrl(filePath: string): string {
    return this.cosStorageService.toRelativeUrl(filePath);
  }

  /**
   * 保存文件记录到数据库
   */
  async saveFileRecord(
    file: Express.Multer.File,
    userId: number,
    metadata?: {
      category?: string;
      description?: string;
      tags?: string;
      compress?: boolean;
      generateThumbnail?: boolean;
    },
    clientThumbnailFile?: Express.Multer.File,
    allowedKinds: readonly UploadFileKind[] = ALL_UPLOAD_KINDS,
  ): Promise<FileRecord> {
    try {
      await this.validateAndNormalizeUploadedFile(file, allowedKinds);
      if (clientThumbnailFile) {
        await this.validateAndNormalizeUploadedFile(clientThumbnailFile, [
          "image",
        ]);
      }
    } catch (error) {
      this.removeUploadedFile(file);
      this.removeUploadedFile(clientThumbnailFile);
      throw error;
    }

    const uploadedObjectPaths: string[] = [];
    const generatedLocalPaths: string[] = [];
    let thumbnailPath: string | undefined;
    let thumbnailMimeType = "image/jpeg";
    try {
      let fileType: FileType;
      if (file.mimetype.startsWith("image/")) {
        fileType = FileType.IMAGE;
      } else if (file.mimetype === "application/pdf") {
        fileType = FileType.PDF;
      } else {
        fileType = FileType.DOCUMENT;
      }

      let width: number | undefined;
      let height: number | undefined;
      let isCompressed = false;

      if (fileType === FileType.IMAGE && file.path) {
        const processResult = await this.processImage(file.path, {
          compress: metadata?.compress !== false,
          generateThumbnail: metadata?.generateThumbnail !== false,
        });

        thumbnailPath = processResult.thumbnailPath;
        width = processResult.width;
        height = processResult.height;
        isCompressed = processResult.isCompressed;
        if (processResult.compressedPath) {
          generatedLocalPaths.push(processResult.compressedPath);
        }

        if (isCompressed) {
          file.size = fs.statSync(file.path).size;
        }
      } else if (this.isVideoFile(file.mimetype) && file.path) {
        if (clientThumbnailFile?.path) {
          thumbnailPath = this.persistUploadedVideoThumbnail(
            file,
            clientThumbnailFile,
          );
          thumbnailMimeType = clientThumbnailFile.mimetype;
        } else {
          const processResult = await this.processVideo(file.path, {
            generateThumbnail: metadata?.generateThumbnail !== false,
          });
          thumbnailPath = processResult.thumbnailPath;
        }
      }

      const storedPath = this.getStoredPathForLocalFile(file.path);
      const storedThumbnailPath = thumbnailPath
        ? this.getStoredPathForLocalFile(thumbnailPath)
        : undefined;

      await this.cosStorageService.uploadLocalFile(
        file.path,
        storedPath,
        file.mimetype,
      );
      uploadedObjectPaths.push(storedPath);

      if (thumbnailPath && storedThumbnailPath) {
        await this.cosStorageService.uploadLocalFile(
          thumbnailPath,
          storedThumbnailPath,
          thumbnailMimeType,
        );
        uploadedObjectPaths.push(storedThumbnailPath);
      }

      const fileRecord = this.fileRecordRepository.create({
        userId,
        filename: file.filename,
        originalName: file.originalname,
        size: file.size,
        mimeType: file.mimetype,
        fileType,
        path: storedPath,
        category: metadata?.category,
        description: metadata?.description,
        tags: metadata?.tags,
        thumbnailPath: storedThumbnailPath,
        width,
        height,
        isCompressed,
      });

      const savedRecord = await this.fileRecordRepository.save(fileRecord);
      const shouldKeepLocalVideo =
        this.isVideoFile(file.mimetype) &&
        metadata?.compress !== false &&
        (await this.enqueueVideoTranscode(savedRecord, file.path));

      this.removeLocalPaths([
        thumbnailPath,
        clientThumbnailFile?.path,
        ...generatedLocalPaths,
      ]);
      if (!shouldKeepLocalVideo) {
        this.removeLocalPaths([file.path]);
      }

      return savedRecord;
    } catch (error) {
      await this.cleanupUploadedObjects(uploadedObjectPaths);
      this.removeLocalPaths([
        file.path,
        clientThumbnailFile?.path,
        thumbnailPath,
        ...generatedLocalPaths,
      ]);
      throw error;
    }
  }

  private async enqueueVideoTranscode(
    fileRecord: FileRecord,
    localPath: string,
  ): Promise<boolean> {
    if (!this.videoTranscodeQueue || !fileRecord.id) {
      return false;
    }

    if (!VIDEO_TRANSCODE_FORMATS[fileRecord.mimeType]) {
      this.logger.log(`跳过不支持的后台视频压缩格式: ${fileRecord.mimeType}`);
      return false;
    }

    try {
      await this.videoTranscodeQueue.add(
        VIDEO_TRANSCODE_JOB,
        { fileRecordId: fileRecord.id, localPath },
        { jobId: `video-transcode-${fileRecord.id}` },
      );
      this.logger.log(`视频压缩任务已入队: fileRecordId=${fileRecord.id}`);
      return true;
    } catch (error) {
      // 原视频已经上传 COS，入队失败不影响本次上传结果。
      this.logger.error(
        `视频压缩任务入队失败: fileRecordId=${fileRecord.id}`,
        error instanceof Error ? error.stack : String(error),
      );
      return false;
    }
  }

  async compressStoredVideo(
    fileRecordId: number,
    localPath?: string,
  ): Promise<{
    status: "compressed" | "skipped";
    originalSize?: number;
    compressedSize?: number;
    reason?: string;
  }> {
    const fileRecord = await this.fileRecordRepository.findOne({
      where: { id: fileRecordId },
    });
    const isDeleted =
      fileRecord?.isDeleted === true ||
      (fileRecord?.isDeleted as unknown) === FileStatus.DELETED;
    if (!fileRecord || isDeleted) {
      this.removeLocalPaths([localPath]);
      return { status: "skipped", reason: "文件记录不存在或已删除" };
    }
    if (fileRecord.isCompressed) {
      this.removeLocalPaths([localPath]);
      return { status: "skipped", reason: "视频已经压缩" };
    }

    const outputFormat = VIDEO_TRANSCODE_FORMATS[fileRecord.mimeType];
    if (!outputFormat) {
      this.removeLocalPaths([localPath]);
      return { status: "skipped", reason: "视频格式暂不支持压缩" };
    }

    const filePath = path.resolve(localPath || fileRecord.path);
    const uploadRoot = path.resolve(this.uploadDest);
    const relativePath = path.relative(uploadRoot, filePath);
    if (
      relativePath.startsWith("..") ||
      path.isAbsolute(relativePath) ||
      !fs.existsSync(filePath)
    ) {
      return { status: "skipped", reason: "视频文件不存在或路径无效" };
    }

    const originalSize = fs.statSync(filePath).size;
    const outputPath = path.join(
      path.dirname(filePath),
      `${path.basename(filePath, extname(filePath))}.transcoding-${randomUUID()}.${outputFormat}`,
    );

    try {
      await this.runVideoTranscode(filePath, outputPath, outputFormat);
      if (!fs.existsSync(outputPath)) {
        throw new Error("ffmpeg 未输出压缩文件");
      }

      const compressedSize = fs.statSync(outputPath).size;
      if (compressedSize <= 0) {
        throw new Error("ffmpeg 输出了空文件");
      }
      if (compressedSize >= originalSize) {
        fs.rmSync(outputPath, { force: true });
        this.removeLocalPaths([filePath]);
        this.logger.log(
          `视频压缩结果未变小，COS 保留原文件: ${originalSize} -> ${compressedSize} 字节`,
        );
        return {
          status: "skipped",
          originalSize,
          compressedSize,
          reason: "压缩结果未变小",
        };
      }

      await this.cosStorageService.uploadLocalFile(
        outputPath,
        fileRecord.path || this.getFileUrl(fileRecord.filename),
        fileRecord.mimeType,
      );
      await this.fileRecordRepository.update(fileRecord.id, {
        size: compressedSize,
        isCompressed: true,
      });
      this.removeLocalPaths([outputPath, filePath]);
      this.logger.log(
        `视频压缩成功: fileRecordId=${fileRecord.id}, ${originalSize} -> ${compressedSize} 字节`,
      );
      return { status: "compressed", originalSize, compressedSize };
    } catch (error) {
      if (fs.existsSync(outputPath)) {
        fs.rmSync(outputPath, { force: true });
      }
      this.logger.error(
        `视频压缩失败，COS 与本地均保留原文件: fileRecordId=${fileRecord.id}`,
        error instanceof Error ? error.stack : String(error),
      );
      throw error;
    }
  }

  private getStoredPathForLocalFile(localPath: string): string {
    const uploadRoot = path.resolve(this.uploadDest);
    const resolvedPath = path.resolve(localPath);
    const relativePath = path.relative(uploadRoot, resolvedPath);

    if (
      !relativePath ||
      relativePath.startsWith("..") ||
      path.isAbsolute(relativePath)
    ) {
      throw new BadRequestException("上传文件路径无效");
    }

    return this.cosStorageService.toRelativeUrl(relativePath);
  }

  private async cleanupUploadedObjects(objectPaths: string[]): Promise<void> {
    if (objectPaths.length === 0) {
      return;
    }

    try {
      await this.cosStorageService.deleteObjects(objectPaths);
    } catch (error) {
      this.logger.error(
        `COS 上传回滚失败: ${objectPaths.join(", ")}`,
        error instanceof Error ? error.stack : String(error),
      );
    }
  }

  cleanupPendingVideoFile(localPath?: string): void {
    this.removeLocalPaths([localPath]);
  }

  private removeLocalPaths(localPaths: Array<string | null | undefined>): void {
    const uploadRoot = path.resolve(this.uploadDest);
    const uniquePaths = new Set(
      localPaths.filter(
        (localPath): localPath is string => typeof localPath === "string",
      ),
    );

    for (const localPath of uniquePaths) {
      const resolvedPath = path.resolve(localPath);
      const relativePath = path.relative(uploadRoot, resolvedPath);
      if (
        !relativePath ||
        relativePath.startsWith("..") ||
        path.isAbsolute(relativePath)
      ) {
        continue;
      }

      try {
        if (fs.existsSync(resolvedPath)) {
          fs.rmSync(resolvedPath, { force: true });
        }
      } catch (error) {
        this.logger.warn(
          `清理上传临时文件失败: ${resolvedPath}, ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    }
  }

  private async runVideoTranscode(
    inputPath: string,
    outputPath: string,
    outputFormat: "mp4" | "mov",
  ): Promise<void> {
    await new Promise<void>((resolve, reject) => {
      execFile(
        "ffmpeg",
        [
          "-hide_banner",
          "-loglevel",
          "error",
          "-nostdin",
          "-y",
          "-i",
          inputPath,
          "-map",
          "0:v:0",
          "-map",
          "0:a:0?",
          "-vf",
          "scale='min(1280,iw)':'min(1280,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2",
          "-fpsmax",
          "30",
          "-c:v",
          "libx264",
          "-preset",
          "veryfast",
          "-crf",
          "24",
          "-maxrate",
          "2500k",
          "-bufsize",
          "5000k",
          "-pix_fmt",
          "yuv420p",
          "-tag:v",
          "avc1",
          "-c:a",
          "aac",
          "-b:a",
          "128k",
          "-ac",
          "2",
          "-movflags",
          "+faststart",
          "-f",
          outputFormat,
          outputPath,
        ],
        {
          timeout: VIDEO_TRANSCODE_TIMEOUT_MS,
          maxBuffer: VIDEO_TRANSCODE_MAX_BUFFER,
        },
        (error) => {
          if (error) {
            reject(error);
            return;
          }
          resolve();
        },
      );
    });
  }

  private persistUploadedVideoThumbnail(
    videoFile: Express.Multer.File,
    thumbnailFile: Express.Multer.File,
  ): string {
    if (!thumbnailFile.mimetype?.startsWith("image/")) {
      throw new BadRequestException("视频缩略图必须是图片文件");
    }

    const thumbnailsDir = path.join(this.uploadDest, "thumbnails");
    if (!fs.existsSync(thumbnailsDir)) {
      fs.mkdirSync(thumbnailsDir, { recursive: true });
    }

    const videoBaseName = path.basename(
      videoFile.filename || videoFile.path,
      extname(videoFile.filename || videoFile.path),
    );
    const thumbnailExtension =
      extname(thumbnailFile.filename || thumbnailFile.path || "") ||
      extname(thumbnailFile.path || "") ||
      ".jpg";
    const thumbnailPath = path.join(
      thumbnailsDir,
      `${videoBaseName}_video_cover${thumbnailExtension.toLowerCase()}`,
    );

    if (fs.existsSync(thumbnailPath)) {
      fs.rmSync(thumbnailPath, { force: true });
    }

    fs.renameSync(thumbnailFile.path, thumbnailPath);
    this.logger.log(`已使用客户端上传的视频缩略图: ${thumbnailPath}`);

    return thumbnailPath;
  }

  /**
   * 查询文件记录列表
   */
  async getFileRecords(
    query: QueryFilesDto,
    userId?: number,
  ): Promise<PaginatedResult<FileRecord>> {
    const {
      page,
      pageSize,
      sortOrder,
      sortBy,
      category,
      mimeType,
      fileType,
      originalName,
      tags,
      minSize,
      maxSize,
    } = query;

    const queryBuilder =
      this.fileRecordRepository.createQueryBuilder("fileRecord");

    // 如果指定了 userId，只查询该用户的文件
    if (userId) {
      queryBuilder.andWhere("fileRecord.userId = :userId", { userId });
    }

    // 只查询未删除的文件
    queryBuilder.andWhere("fileRecord.isDeleted = :isDeleted", {
      isDeleted: false,
    });

    // 应用筛选条件
    if (category) {
      queryBuilder.andWhere("fileRecord.category = :category", { category });
    }

    if (mimeType) {
      queryBuilder.andWhere("fileRecord.mimeType = :mimeType", { mimeType });
    }

    if (fileType) {
      queryBuilder.andWhere("fileRecord.fileType = :fileType", { fileType });
    }

    if (originalName) {
      queryBuilder.andWhere("fileRecord.originalName LIKE :originalName", {
        originalName: `%${originalName}%`,
      });
    }

    if (tags) {
      queryBuilder.andWhere("fileRecord.tags LIKE :tags", {
        tags: `%${tags}%`,
      });
    }

    if (minSize !== undefined) {
      queryBuilder.andWhere("fileRecord.size >= :minSize", { minSize });
    }

    if (maxSize !== undefined) {
      queryBuilder.andWhere("fileRecord.size <= :maxSize", { maxSize });
    }

    // 应用排序
    const order = sortOrder === "ASC" ? "ASC" : "DESC";
    queryBuilder.orderBy(`fileRecord.${sortBy}`, order);

    // 应用分页
    const skip = (page - 1) * pageSize;
    queryBuilder.skip(skip).take(pageSize);

    // 关联用户信息
    queryBuilder.leftJoinAndSelect("fileRecord.user", "user");

    const [data, total] = await queryBuilder.getManyAndCount();

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 获取单个文件记录
   */
  async getFileRecord(id: number, userId?: number): Promise<FileRecord> {
    const fileRecord = await this.fileRecordRepository.findOne({
      where: { id },
      relations: ["user"],
    });

    if (!fileRecord) {
      throw new NotFoundException("文件记录不存在");
    }

    if (fileRecord.isDeleted) {
      throw new NotFoundException("文件已被删除");
    }

    // 如果指定了 userId，检查权限
    if (userId && fileRecord.userId !== userId) {
      throw new ForbiddenException("无权访问此文件");
    }

    return fileRecord;
  }

  /**
   * 删除文件（软删除）
   */
  async deleteFile(id: number, userId: number): Promise<void> {
    const fileRecord = await this.getFileRecord(id, userId);

    await this.cosStorageService.deleteObjects([
      fileRecord.path || this.getFileUrl(fileRecord.filename),
      fileRecord.thumbnailPath,
    ]);

    fileRecord.isDeleted = true as any;
    fileRecord.deletedAt = new Date();
    await this.fileRecordRepository.save(fileRecord);
  }

  /**
   * 获取文件统计信息
   */
  async getFileStats(userId?: number): Promise<{
    total: number;
    totalSize: number;
    byType: Record<string, number>;
    byCategory: Record<string, number>;
  }> {
    const queryBuilder =
      this.fileRecordRepository.createQueryBuilder("fileRecord");

    if (userId) {
      queryBuilder.andWhere("fileRecord.userId = :userId", { userId });
    }

    queryBuilder.andWhere("fileRecord.isDeleted = :isDeleted", {
      isDeleted: false,
    });

    const files = await queryBuilder.getMany();

    const total = files.length;
    const totalSize = files.reduce((sum, file) => sum + Number(file.size), 0);

    const byType: Record<string, number> = {};
    const byCategory: Record<string, number> = {};

    files.forEach((file) => {
      // 统计文件类型
      const type = file.fileType || "unknown";
      byType[type] = (byType[type] || 0) + 1;

      // 统计分类
      const category = file.category || "uncategorized";
      byCategory[category] = (byCategory[category] || 0) + 1;
    });

    return {
      total,
      totalSize,
      byType,
      byCategory,
    };
  }

  /**
   * 判断是否为图片文件
   */
  private isImageFile(mimeType: string): boolean {
    return mimeType.startsWith("image/");
  }

  /**
   * 判断是否为视频文件
   */
  private isVideoFile(mimeType: string): boolean {
    return mimeType.startsWith("video/");
  }

  private async validateAndNormalizeUploadedFile(
    file: Express.Multer.File,
    allowedKinds: readonly UploadFileKind[],
  ): Promise<void> {
    const supported = await detectUploadType(file.path, file.mimetype);

    if (!supported || !allowedKinds.includes(supported.kind)) {
      const expectedImagesOnly =
        allowedKinds.length === 1 && allowedKinds[0] === "image";
      throw new BadRequestException(
        expectedImagesOnly
          ? "图片格式不受支持，仅支持 JPG、PNG、GIF、WebP"
          : "文件格式不受支持，仅支持 MP4、MOV、MPEG、AVI、WMV、WebM、MP3、M4A、AAC、AMR、OGG、WAV 和 PDF",
      );
    }

    if (supported.kind === "image") {
      try {
        const metadata = await sharp(file.path).metadata();
        if (!metadata.width || !metadata.height) {
          throw new Error("图片缺少有效尺寸");
        }
      } catch {
        throw new BadRequestException(
          "图片内容无效或已损坏，仅支持 JPG、PNG、GIF、WebP",
        );
      }
    }

    const currentExtension = extname(file.filename || file.path);
    const safeExtension = `.${supported.extension}`;
    if (currentExtension.toLowerCase() !== safeExtension) {
      const currentPath = file.path;
      const normalizedFilename = `${path.basename(
        file.filename,
        currentExtension,
      )}${safeExtension}`;
      const normalizedPath = path.join(
        path.dirname(currentPath),
        normalizedFilename,
      );
      fs.renameSync(currentPath, normalizedPath);
      file.filename = normalizedFilename;
      file.path = normalizedPath;
    }

    file.mimetype = supported.mimeType;
  }

  private removeUploadedFile(file?: Express.Multer.File): void {
    if (file?.path && fs.existsSync(file.path)) {
      fs.rmSync(file.path, { force: true });
    }
  }

  /**
   * 获取图片元数据（尺寸、格式等）
   */
  private async getImageMetadata(
    filePath: string,
  ): Promise<{ width: number; height: number; format: string }> {
    try {
      const metadata = await sharp(filePath).metadata();
      return {
        width: metadata.width || 0,
        height: metadata.height || 0,
        format: metadata.format || "unknown",
      };
    } catch (error) {
      this.logger.error(`获取图片元数据失败: ${error.message}`);
      return { width: 0, height: 0, format: "unknown" };
    }
  }

  private resolveCompressionFormat(
    filePath: string,
    detectedFormat?: string,
  ): string {
    const fileExt = extname(filePath).toLowerCase().replace(".", "");
    if (fileExt === "jpg" || fileExt === "jpeg") return "jpeg";
    if (fileExt === "png") return "png";
    if (fileExt === "webp") return "webp";
    if (fileExt === "gif") return "gif";

    const normalizedDetectedFormat = (detectedFormat || "").toLowerCase();
    if (normalizedDetectedFormat === "jpg") return "jpeg";
    if (
      normalizedDetectedFormat === "jpeg" ||
      normalizedDetectedFormat === "png" ||
      normalizedDetectedFormat === "webp" ||
      normalizedDetectedFormat === "gif"
    ) {
      return normalizedDetectedFormat;
    }

    return "unknown";
  }

  private getExtensionByFormat(format?: string): string {
    const normalizedFormat = (format || "").toLowerCase();
    if (normalizedFormat === "jpeg" || normalizedFormat === "jpg") {
      return ".jpg";
    }
    if (normalizedFormat === "png") {
      return ".png";
    }
    if (normalizedFormat === "webp") {
      return ".webp";
    }
    if (normalizedFormat === "gif") {
      return ".gif";
    }
    return ".jpg";
  }

  /**
   * 压缩图片
   * 规则：
   * - 宽高限制: 1600px
   * - 保留原图格式（jpg/png/webp）
   * - 自动旋转（根据 EXIF）
   * - 若压缩后不比原图小，则回退原图
   * - 动图（gif / animated webp）跳过压缩，避免破坏动效
   *
   * 返回值说明：
   * - success: true=压缩成功, false=压缩失败
   * - skipped: true=跳过压缩（不支持或收益不明显）, false=执行了压缩
   * - size: 压缩后的文件大小（如果跳过压缩，则是原文件大小）
   * - error: 错误信息（如果失败）
   */
  private async compressImage(
    inputPath: string,
    outputPath: string,
  ): Promise<{
    success: boolean;
    skipped: boolean;
    size: number;
    error?: string;
  }> {
    try {
      const stats = fs.statSync(inputPath);
      const metadata = await sharp(inputPath, { animated: true }).metadata();
      const format = this.resolveCompressionFormat(inputPath, metadata.format);
      const isAnimated = (metadata.pages || 1) > 1;

      if (isAnimated) {
        this.logger.log(`检测到动图，跳过压缩: ${inputPath}`);
        return { success: true, skipped: true, size: stats.size };
      }

      if (!["jpeg", "png", "webp"].includes(format)) {
        this.logger.log(`不支持的图片格式，跳过压缩: ${inputPath}`);
        return { success: true, skipped: true, size: stats.size };
      }

      const pipeline = sharp(inputPath).rotate().resize(1600, 1600, {
        withoutEnlargement: true, // 不放大小图
        fit: "inside", // 保持比例，适应指定尺寸
      });

      if (format === "jpeg") {
        await pipeline
          .jpeg({ quality: 72, mozjpeg: true, progressive: true })
          .toFile(outputPath);
      } else if (format === "png") {
        await pipeline
          .png({ quality: 75, compressionLevel: 9, palette: true, effort: 8 })
          .toFile(outputPath);
      } else {
        await pipeline
          .webp({ quality: 72, alphaQuality: 72, effort: 6 })
          .toFile(outputPath);
      }

      const compressedStats = fs.statSync(outputPath);
      if (compressedStats.size >= stats.size) {
        if (fs.existsSync(outputPath)) {
          fs.unlinkSync(outputPath);
        }
        this.logger.log(
          `压缩结果未变小，保留原图: ${stats.size} -> ${compressedStats.size} 字节`,
        );
        return { success: true, skipped: true, size: stats.size };
      }

      this.logger.log(
        `图片压缩成功: ${stats.size} -> ${compressedStats.size} 字节`,
      );

      return { success: true, skipped: false, size: compressedStats.size };
    } catch (error) {
      this.logger.error(`图片压缩失败: ${error.message}`);
      return { success: false, skipped: false, size: 0, error: error.message };
    }
  }

  /**
   * 生成缩略图
   * 规则：
   * - 尺寸: 150x150
   * - 裁剪模式: cover（居中裁剪）
   * - 质量: 60%
   */
  private async generateThumbnail(
    inputPath: string,
    thumbnailPath: string,
  ): Promise<{ success: boolean; error?: string }> {
    try {
      await sharp(inputPath)
        .resize(150, 150, {
          fit: "cover", // 居中裁剪
          position: "center",
        })
        .jpeg({ quality: 60 })
        .toFile(thumbnailPath);

      this.logger.log(`缩略图生成成功: ${thumbnailPath}`);
      return { success: true };
    } catch (error) {
      this.logger.error(`缩略图生成失败: ${error.message}`);
      return { success: false, error: error.message };
    }
  }

  /**
   * 生成视频缩略图
   * 规则：
   * - 优先截取 1 秒附近的画面，尽量避开黑场首帧
   * - 视频过短时回退到 0 秒
   * - 输出统一为 jpg，作为前端视频预览兜底资源
   */
  private async generateVideoThumbnailFrame(
    inputPath: string,
    thumbnailPath: string,
    second: number,
  ): Promise<{ success: boolean; error?: string }> {
    try {
      await new Promise<void>((resolve, reject) => {
        execFile(
          "ffmpeg",
          [
            "-y",
            "-ss",
            second.toFixed(3),
            "-i",
            inputPath,
            "-frames:v",
            "1",
            thumbnailPath,
          ],
          (error) => {
            if (error) {
              reject(error);
              return;
            }

            resolve();
          },
        );
      });

      if (!fs.existsSync(thumbnailPath)) {
        throw new Error("ffmpeg 未输出缩略图文件");
      }

      this.logger.log(`视频缩略图生成成功: ${thumbnailPath}`);
      return { success: true };
    } catch (error) {
      this.logger.warn(`视频缩略图生成失败(${second}s): ${error.message}`);
      return { success: false, error: error.message };
    }
  }

  /**
   * 处理视频（生成缩略图）
   */
  async processVideo(
    filePath: string,
    options: {
      generateThumbnail?: boolean;
    } = {},
  ): Promise<{
    thumbnailPath?: string;
  }> {
    const result: {
      thumbnailPath?: string;
    } = {};

    if (options.generateThumbnail === false) {
      return result;
    }

    const thumbnailsDir = path.join(this.uploadDest, "thumbnails");
    if (!fs.existsSync(thumbnailsDir)) {
      fs.mkdirSync(thumbnailsDir, { recursive: true });
    }

    const filename = path.basename(filePath, extname(filePath));
    const thumbnailPath = path.join(
      thumbnailsDir,
      `${filename}_video_cover.jpg`,
    );

    const primaryResult = await this.generateVideoThumbnailFrame(
      filePath,
      thumbnailPath,
      1,
    );

    if (!primaryResult.success) {
      const fallbackResult = await this.generateVideoThumbnailFrame(
        filePath,
        thumbnailPath,
        0,
      );

      if (!fallbackResult.success) {
        return result;
      }
    }

    result.thumbnailPath = thumbnailPath;
    return result;
  }

  /**
   * 处理图片（压缩 + 生成缩略图）
   */
  async processImage(
    filePath: string,
    options: {
      compress?: boolean;
      generateThumbnail?: boolean;
    } = {},
  ): Promise<{
    compressedPath?: string;
    thumbnailPath?: string;
    width?: number;
    height?: number;
    isCompressed: boolean;
  }> {
    const result: any = {
      isCompressed: false,
    };

    // 获取图片元数据
    const metadata = await this.getImageMetadata(filePath);
    result.width = metadata.width;
    result.height = metadata.height;

    // 创建缩略图目录
    const thumbnailsDir = path.join(this.uploadDest, "thumbnails");
    if (!fs.existsSync(thumbnailsDir)) {
      fs.mkdirSync(thumbnailsDir, { recursive: true });
    }

    const filename = path.basename(filePath, extname(filePath));

    // 压缩图片
    if (options.compress !== false) {
      const fileExtension = extname(filePath).toLowerCase();
      const outputExtension =
        fileExtension || this.getExtensionByFormat(metadata.format);

      const compressedPath = path.join(
        this.uploadDest,
        "original",
        `${filename}${outputExtension}`,
      );

      // 创建 original 目录
      const originalDir = path.join(this.uploadDest, "original");
      if (!fs.existsSync(originalDir)) {
        fs.mkdirSync(originalDir, { recursive: true });
      }

      const compressResult = await this.compressImage(filePath, compressedPath);

      // 只有在真正执行了压缩（不是跳过）且成功时，才设置 compressedPath
      if (compressResult.success && !compressResult.skipped) {
        result.compressedPath = compressedPath;
        result.isCompressed = true;

        // 用压缩后的图片替换原文件
        if (fs.existsSync(compressedPath)) {
          fs.copyFileSync(compressedPath, filePath);
        }
      } else if (compressResult.skipped) {
        // 如果跳过压缩，标记为未压缩
        result.isCompressed = false;
        this.logger.log(`图片跳过压缩，使用原文件: ${filePath}`);
      }
    }

    // 生成缩略图时，使用原文件路径（因为压缩后已经覆盖了原文件）
    if (options.generateThumbnail !== false) {
      const thumbnailPath = path.join(thumbnailsDir, `${filename}_150x150.jpg`);

      // 使用原文件路径生成缩略图
      // 注意：如果执行了压缩，此时 filePath 已经被压缩文件覆盖
      const thumbnailResult = await this.generateThumbnail(
        filePath,
        thumbnailPath,
      );
      if (thumbnailResult.success) {
        result.thumbnailPath = thumbnailPath;
      }
    }

    return result;
  }

  /**
   * 检查文件是否存在
   * @param filePath 文件路径，可以是相对路径（如 xxx.jpg）或 URL 路径（如 /uploads/xxx.jpg）
   */
  async fileExists(filePath: string): Promise<boolean> {
    return this.cosStorageService.objectExists(filePath);
  }

  /**
   * 批量处理图片上传
   */
  async processBatchUpload(
    files: Express.Multer.File[],
    userId: number,
    options: {
      compress?: boolean;
      generateThumbnail?: boolean;
      category?: string;
    } = {},
  ): Promise<
    Array<{
      filename: string;
      success: boolean;
      data?: any;
      error?: string;
    }>
  > {
    const results = [];

    for (const file of files) {
      try {
        const fileRecord = await this.saveFileRecord(
          file,
          userId,
          options,
          undefined,
          ["image"],
        );

        const response: any = {
          filename: file.filename,
          success: true,
          data: {
            url: fileRecord.path,
            filename: file.filename,
            originalName: file.originalname,
            size: fileRecord.size,
            id: fileRecord.id,
          },
        };

        // 添加图片额外信息
        if (fileRecord.width && fileRecord.height) {
          response.data.width = fileRecord.width;
          response.data.height = fileRecord.height;
        }

        if (fileRecord.thumbnailPath) {
          response.data.thumbnail = fileRecord.thumbnailPath;
        }

        results.push(response);
      } catch (error) {
        this.logger.error(`文件处理失败: ${file.originalname}`, error.message);
        results.push({
          filename: file.originalname,
          success: false,
          error: error.message || "文件处理失败",
        });
      }
    }

    return results;
  }
}
