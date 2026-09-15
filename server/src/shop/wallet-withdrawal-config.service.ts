import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { AlipayService } from "../payment/alipay.service";
import { SystemConfig } from "../system-configs/entities/system-config.entity";
import { UpdateWalletWithdrawalConfigDto } from "./dto/wallet-withdrawal.dto";
import { WalletPiiService } from "./wallet-pii.service";
import {
  createBusinessException,
  ErrorCode,
} from "../common/constants/error-codes";

export const WALLET_WITHDRAWAL_CONFIG_KEY = "wallet_withdrawal";

export interface WalletWithdrawalRules {
  businessEnabled: boolean;
  minAmountCents: number;
  maxAmountPerRequestCents: number;
  maxAmountPerDayCents: number;
}

const DEFAULT_RULES: WalletWithdrawalRules = {
  businessEnabled: false,
  minAmountCents: 100,
  maxAmountPerRequestCents: 5_000_000,
  maxAmountPerDayCents: 5_000_000,
};

@Injectable()
export class WalletWithdrawalConfigService {
  constructor(
    @InjectRepository(SystemConfig)
    private readonly configRepository: Repository<SystemConfig>,
    private readonly alipayService: AlipayService,
    private readonly piiService: WalletPiiService,
  ) {}

  async getRules(): Promise<WalletWithdrawalRules> {
    const config = await this.configRepository.findOne({
      where: { configKey: WALLET_WITHDRAWAL_CONFIG_KEY },
    });
    const value = config?.configValue || {};
    const minAmountCents = this.parseAmount(value.minAmount, DEFAULT_RULES.minAmountCents);
    const maxAmountPerRequestCents = this.parseAmount(
      value.maxAmountPerRequest,
      DEFAULT_RULES.maxAmountPerRequestCents,
    );
    const maxAmountPerDayCents = this.parseAmount(
      value.maxAmountPerDay,
      DEFAULT_RULES.maxAmountPerDayCents,
    );

    return {
      businessEnabled: value.businessEnabled === true,
      minAmountCents,
      maxAmountPerRequestCents: Math.max(maxAmountPerRequestCents, minAmountCents),
      maxAmountPerDayCents: Math.max(maxAmountPerDayCents, minAmountCents),
    };
  }

  async getAdminConfig() {
    const rules = await this.getRules();
    return {
      businessEnabled: rules.businessEnabled,
      minAmount: rules.minAmountCents / 100,
      maxAmountPerRequest: rules.maxAmountPerRequestCents / 100,
      maxAmountPerDay: rules.maxAmountPerDayCents / 100,
      transferConfigured: this.alipayService.isTransferConfigured(),
      piiEncryptionConfigured: this.piiService.isConfigured(),
      unavailableReason: this.getUnavailableReason(rules),
    };
  }

  async update(dto: UpdateWalletWithdrawalConfigDto) {
    const values = [
      this.parseRequiredAmount(dto.minAmount),
      this.parseRequiredAmount(dto.maxAmountPerRequest),
      this.parseRequiredAmount(dto.maxAmountPerDay),
    ];
    if (values[1] < values[0] || values[2] < values[0]) {
      throw createBusinessException(
        ErrorCode.BUSINESS_INVALID_PARAM,
        "单笔和单日上限不能低于最低提现金额",
      );
    }
    const configValue = {
      businessEnabled: dto.businessEnabled,
      minAmount: (values[0] / 100).toFixed(2),
      maxAmountPerRequest: (values[1] / 100).toFixed(2),
      maxAmountPerDay: (values[2] / 100).toFixed(2),
    };
    let config = await this.configRepository.findOne({
      where: { configKey: WALLET_WITHDRAWAL_CONFIG_KEY },
    });
    if (!config) {
      config = this.configRepository.create({
        configKey: WALLET_WITHDRAWAL_CONFIG_KEY,
        configValue,
        description: "支付宝钱包提现规则",
      });
    } else {
      config.configValue = configValue;
    }
    await this.configRepository.save(config);
    return this.getAdminConfig();
  }

  isEnabled(rules: WalletWithdrawalRules): boolean {
    return (
      rules.businessEnabled &&
      this.alipayService.isTransferConfigured() &&
      this.piiService.isConfigured()
    );
  }

  getUnavailableReason(rules: WalletWithdrawalRules): string | null {
    if (!rules.businessEnabled) return "支付宝提现服务暂未开放";
    if (!this.piiService.isConfigured()) return "支付宝提现暂未配置";
    if (!this.alipayService.isTransferConfigured()) {
      return this.alipayService.getTransferConfigurationError() || "支付宝提现暂未配置";
    }
    return null;
  }

  private parseAmount(value: unknown, fallback: number): number {
    if (typeof value !== "string" && typeof value !== "number") return fallback;
    const cents = Math.round(Number(value) * 100);
    return Number.isSafeInteger(cents) && cents > 0 ? cents : fallback;
  }

  private parseRequiredAmount(value: string): number {
    const cents = Math.round(Number(value) * 100);
    if (!Number.isSafeInteger(cents) || cents <= 0) {
      throw createBusinessException(
        ErrorCode.BUSINESS_INVALID_PARAM,
        "提现金额配置必须大于 0",
      );
    }
    return cents;
  }
}
