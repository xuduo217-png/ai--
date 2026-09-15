import { Transform, Type } from "class-transformer";
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from "class-validator";
import {
  RelatedType,
  WalletTransactionStatus,
  WalletTransactionType,
} from "../entities/wallet-transaction.entity";
import { WalletWithdrawalStatus } from "../entities/wallet-withdrawal.entity";

export const WALLET_AMOUNT_PATTERN =
  /^(?:0\.(?:0[1-9]|[1-9]\d?)|[1-9]\d{0,7}(?:\.\d{1,2})?)$/;
const SAFE_PII_PATTERN = /^[^\u0000-\u001f\u007f]+$/;

export class CreateWalletWithdrawalDto {
  @IsString()
  @Matches(WALLET_AMOUNT_PATTERN, { message: "金额格式无效，最多保留两位小数" })
  amount: string;

  @Transform(({ value }) => (typeof value === "string" ? value.trim() : value))
  @IsString()
  @MinLength(5)
  @MaxLength(128)
  @Matches(SAFE_PII_PATTERN, { message: "支付宝账号不能包含控制字符" })
  alipayAccount: string;

  @Transform(({ value }) => (typeof value === "string" ? value.trim() : value))
  @IsString()
  @MinLength(2)
  @MaxLength(64)
  @Matches(SAFE_PII_PATTERN, { message: "实名姓名不能包含控制字符" })
  payeeRealName: string;
}

export class WalletPageQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit = 10;
}

export class WalletTransactionQueryDto extends WalletPageQueryDto {
  @IsOptional()
  @IsEnum(WalletTransactionType)
  type?: WalletTransactionType;

  @IsOptional()
  @IsEnum(WalletTransactionStatus)
  status?: WalletTransactionStatus;

  @IsOptional()
  @IsEnum(RelatedType)
  relatedType?: RelatedType;
}

export class WalletWithdrawalQueryDto extends WalletPageQueryDto {
  @IsOptional()
  @IsEnum(WalletWithdrawalStatus)
  status?: WalletWithdrawalStatus;
}

export class AdminWalletWithdrawalQueryDto extends WalletWithdrawalQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(40)
  withdrawalNo?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  userId?: number;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  phone?: string;

  @IsOptional()
  @IsDateString()
  startDate?: string;

  @IsOptional()
  @IsDateString()
  endDate?: string;
}

export class RejectWalletWithdrawalDto {
  @Transform(({ value }) => (typeof value === "string" ? value.trim() : value))
  @IsString()
  @MinLength(2)
  @MaxLength(500)
  @Matches(SAFE_PII_PATTERN, { message: "拒绝原因不能包含控制字符" })
  reason: string;
}

export class UpdateWalletWithdrawalConfigDto {
  @IsBoolean()
  businessEnabled: boolean;

  @IsString()
  @Matches(WALLET_AMOUNT_PATTERN)
  minAmount: string;

  @IsString()
  @Matches(WALLET_AMOUNT_PATTERN)
  maxAmountPerRequest: string;

  @IsString()
  @Matches(WALLET_AMOUNT_PATTERN)
  maxAmountPerDay: string;
}
