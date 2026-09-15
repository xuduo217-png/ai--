import { Injectable, ServiceUnavailableException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import COS from "cos-nodejs-sdk-v5";

const DEFAULT_BUCKET = "gdcw-1386217335";
const DEFAULT_REGION = "ap-chengdu";
const UPLOAD_PREFIX = "uploads/";

@Injectable()
export class CosStorageService {
  private readonly bucket: string;
  private readonly region: string;
  private readonly secretId?: string;
  private readonly secretKey?: string;
  private readonly cos: COS;

  constructor(private readonly configService: ConfigService) {
    this.bucket =
      this.configService.get<string>("COS_BUCKET")?.trim() || DEFAULT_BUCKET;
    this.region =
      this.configService.get<string>("COS_REGION")?.trim() || DEFAULT_REGION;
    this.secretId = this.configService.get<string>("COS_SECRET_ID")?.trim();
    this.secretKey = this.configService.get<string>("COS_SECRET_KEY")?.trim();
    this.cos = new COS({
      SecretId: this.secretId,
      SecretKey: this.secretKey,
      Protocol: "https:",
    });
  }

  toObjectKey(filePath: string): string {
    let normalizedPath = filePath.trim();

    if (/^https?:\/\//i.test(normalizedPath)) {
      normalizedPath = new URL(normalizedPath).pathname;
    }

    normalizedPath = normalizedPath
      .replace(/\\/g, "/")
      .replace(/^\/+/, "")
      .replace(/\/{2,}/g, "/");

    if (!normalizedPath) {
      throw new Error("COS 对象路径不能为空");
    }

    if (normalizedPath.split("/").some((segment) => segment === "..")) {
      throw new Error("COS 对象路径不能包含上级目录");
    }

    return normalizedPath.startsWith(UPLOAD_PREFIX)
      ? normalizedPath
      : `${UPLOAD_PREFIX}${normalizedPath}`;
  }

  toRelativeUrl(filePath: string): string {
    return `/${this.toObjectKey(filePath)}`;
  }

  async uploadLocalFile(
    localPath: string,
    objectPath: string,
    contentType?: string,
  ): Promise<void> {
    this.assertConfigured();
    await this.cos.uploadFile({
      Bucket: this.bucket,
      Region: this.region,
      Key: this.toObjectKey(objectPath),
      FilePath: localPath,
      ContentType: contentType,
      StorageClass: "STANDARD",
    });
  }

  async deleteObjects(
    filePaths: Array<string | null | undefined>,
  ): Promise<void> {
    this.assertConfigured();
    const objectKeys = [
      ...new Set(
        filePaths
          .filter(
            (item): item is string =>
              typeof item === "string" && item.trim().length > 0,
          )
          .map((item) => this.toObjectKey(item)),
      ),
    ];

    for (const objectKey of objectKeys) {
      await this.cos.deleteObject({
        Bucket: this.bucket,
        Region: this.region,
        Key: objectKey,
      });
    }
  }

  async objectExists(filePath: string): Promise<boolean> {
    this.assertConfigured();
    try {
      await this.cos.headObject({
        Bucket: this.bucket,
        Region: this.region,
        Key: this.toObjectKey(filePath),
      });
      return true;
    } catch (error) {
      const cosError = error as COS.CosSdkError;
      if (cosError?.statusCode === 404 || cosError?.code === "NoSuchKey") {
        return false;
      }
      throw error;
    }
  }

  private assertConfigured(): void {
    if (!this.secretId || !this.secretKey) {
      throw new ServiceUnavailableException(
        "腾讯云 COS 凭证未配置，请设置 COS_SECRET_ID 和 COS_SECRET_KEY",
      );
    }
  }
}
