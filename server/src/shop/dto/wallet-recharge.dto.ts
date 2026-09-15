import { Type } from "class-transformer";
import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min,
} from "class-validator";
import { WALLET_AMOUNT_PATTERN } from "./wallet-withdrawal.dto";
import { WalletRechargeStatus } from "../entities/wallet-recharge.entity";

export class CreateWalletRechargeDto {
  @IsString()
  @Matches(WALLET_AMOUNT_PATTERN, { message: "金额格式无效，最多保留两位小数" })
  amount: string;
}

export class WalletRechargeQueryDto {
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

  @IsOptional()
  @IsEnum(WalletRechargeStatus)
  status?: WalletRechargeStatus;
}
