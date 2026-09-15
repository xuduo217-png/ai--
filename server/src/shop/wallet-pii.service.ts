import { Injectable } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import {
  createCipheriv,
  createDecipheriv,
  randomBytes,
} from "crypto";
import {
  createBusinessException,
  ErrorCode,
} from "../common/constants/error-codes";

const ENCRYPTION_VERSION = "v1";

@Injectable()
export class WalletPiiService {
  constructor(private readonly configService: ConfigService) {}

  isConfigured(): boolean {
    return this.readKey() !== null;
  }

  encrypt(plaintext: string): string {
    const key = this.requireKey();
    const iv = randomBytes(12);
    const cipher = createCipheriv("aes-256-gcm", key, iv);
    const ciphertext = Buffer.concat([
      cipher.update(plaintext, "utf8"),
      cipher.final(),
    ]);
    const authTag = cipher.getAuthTag();
    return [
      ENCRYPTION_VERSION,
      iv.toString("base64"),
      authTag.toString("base64"),
      ciphertext.toString("base64"),
    ].join(":");
  }

  decrypt(payload: string): string {
    const key = this.requireKey();
    const [version, ivValue, tagValue, ciphertextValue, ...extra] =
      payload.split(":");
    if (
      version !== ENCRYPTION_VERSION ||
      !ivValue ||
      !tagValue ||
      !ciphertextValue ||
      extra.length > 0
    ) {
      throw createBusinessException(
        ErrorCode.CONFIGURATION_ERROR,
        "提现敏感信息密文格式无效",
      );
    }

    try {
      const decipher = createDecipheriv(
        "aes-256-gcm",
        key,
        Buffer.from(ivValue, "base64"),
      );
      decipher.setAuthTag(Buffer.from(tagValue, "base64"));
      return Buffer.concat([
        decipher.update(Buffer.from(ciphertextValue, "base64")),
        decipher.final(),
      ]).toString("utf8");
    } catch {
      throw createBusinessException(
        ErrorCode.CONFIGURATION_ERROR,
        "提现敏感信息解密失败",
      );
    }
  }

  maskAlipayAccount(account: string): string {
    const atIndex = account.indexOf("@");
    if (atIndex > 0) {
      return `${account[0]}***${account.slice(atIndex)}`;
    }
    if (account.length <= 4) {
      return `${account[0] || "*"}***`;
    }
    return `${account.slice(0, 3)}****${account.slice(-4)}`;
  }

  maskRealName(name: string): string {
    const characters = Array.from(name);
    if (characters.length <= 1) return "*";
    return `${characters[0]}${"*".repeat(characters.length - 1)}`;
  }

  private requireKey(): Buffer {
    const key = this.readKey();
    if (!key) {
      throw createBusinessException(
        ErrorCode.CONFIGURATION_ERROR,
        "提现敏感信息加密密钥未配置",
      );
    }
    return key;
  }

  private readKey(): Buffer | null {
    const rawValue = this.configService
      .get<string>("WALLET_PII_ENCRYPTION_KEY")
      ?.trim();
    if (!rawValue) return null;

    if (/^[0-9a-fA-F]{64}$/.test(rawValue)) {
      return Buffer.from(rawValue, "hex");
    }

    try {
      const decoded = Buffer.from(rawValue, "base64");
      return decoded.length === 32 ? decoded : null;
    } catch {
      return null;
    }
  }
}
