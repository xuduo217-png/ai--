import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { randomUUID } from "crypto";
import { Repository } from "typeorm";
import { PaymentService } from "../payment/payment.service";
import {
  BusinessType,
  PaymentChannel,
  PaymentMethod,
  PaymentStatus,
} from "../payment/entities/payment.entity";
import { equals, toNumber } from "../common/utils/currency.util";
import {
  CreateWalletRechargeDto,
  WalletRechargeQueryDto,
} from "./dto/wallet-recharge.dto";
import {
  WalletRecharge,
  WalletRechargeStatus,
} from "./entities/wallet-recharge.entity";

export const WALLET_RECHARGE_MIN_AMOUNT = 1;
export const WALLET_RECHARGE_MAX_AMOUNT = 50_000;
export const WALLET_RECHARGE_PRESETS = [10, 50, 100, 200] as const;

@Injectable()
export class WalletRechargeService {
  constructor(
    @InjectRepository(WalletRecharge)
    private readonly rechargeRepository: Repository<WalletRecharge>,
    private readonly paymentService: PaymentService,
  ) {}

  getConfig() {
    return {
      enabled: true,
      minAmount: WALLET_RECHARGE_MIN_AMOUNT,
      maxAmount: WALLET_RECHARGE_MAX_AMOUNT,
      presets: [...WALLET_RECHARGE_PRESETS],
      unavailableReason: null,
    };
  }

  async create(
    userId: number,
    idempotencyKey: string,
    body: CreateWalletRechargeDto,
  ) {
    const amount = toNumber(body.amount);
    if (
      !Number.isFinite(amount) ||
      amount < WALLET_RECHARGE_MIN_AMOUNT ||
      amount > WALLET_RECHARGE_MAX_AMOUNT
    ) {
      throw new BadRequestException(
        `充值金额必须在 ${WALLET_RECHARGE_MIN_AMOUNT.toFixed(2)} 至 ${WALLET_RECHARGE_MAX_AMOUNT.toFixed(2)} 元之间`,
      );
    }

    let recharge = await this.rechargeRepository.findOne({
      where: { userId, idempotencyKey },
    });
    if (recharge && !equals(recharge.amount, amount)) {
      throw new BadRequestException("幂等键已用于其他充值金额");
    }

    if (!recharge) {
      const created = this.rechargeRepository.create({
        rechargeNo: this.generateRechargeNo(),
        idempotencyKey,
        userId,
        paymentNo: null,
        walletTransactionId: null,
        amount,
        status: WalletRechargeStatus.PENDING,
        expiredAt: null,
        paidAt: null,
        failedAt: null,
        failureMessage: null,
      });
      try {
        recharge = await this.rechargeRepository.save(created);
      } catch (error) {
        recharge = await this.rechargeRepository.findOne({
          where: { userId, idempotencyKey },
        });
        if (!recharge || !equals(recharge.amount, amount)) throw error;
      }
    }

    if (recharge.status === WalletRechargeStatus.SUCCEEDED) {
      return this.toResponse(recharge);
    }
    if (
      recharge.status === WalletRechargeStatus.CLOSED ||
      recharge.status === WalletRechargeStatus.FAILED
    ) {
      throw new BadRequestException("当前充值单已失效，请重新发起充值");
    }

    const payment = await this.paymentService.createPayment({
      channel: PaymentChannel.ALIPAY,
      method: PaymentMethod.APP,
      amount,
      userId,
      businessType: BusinessType.WALLET_RECHARGE,
      businessId: recharge.id,
      subject: "钱包充值",
      body: `钱包充值 ¥${amount.toFixed(2)}`,
      description: "钱包余额充值",
      expireIn: 900,
      outTradeNo: `wallet_recharge_${recharge.id}`,
      metadata: { rechargeNo: recharge.rechargeNo },
    });

    recharge.paymentNo = payment.paymentNo;
    recharge.expiredAt = payment.expiredAt;
    recharge.failureMessage = null;
    recharge = await this.rechargeRepository.save(recharge);
    return this.toResponse(recharge, payment.paymentParams.alipayOrderString);
  }

  async listForUser(userId: number, query: WalletRechargeQueryDto) {
    const { page = 1, limit = 10, status } = query;
    const where = status ? { userId, status } : { userId };
    const [items, total] = await this.rechargeRepository.findAndCount({
      where,
      order: { createdAt: "DESC" },
      skip: (page - 1) * limit,
      take: limit,
    });
    return {
      data: items.map((item) => this.toResponse(item)),
      total,
      page,
      limit,
    };
  }

  async getForUser(userId: number, id: number) {
    let recharge = await this.findOwned(userId, id);
    if (
      recharge.status === WalletRechargeStatus.PENDING &&
      recharge.paymentNo
    ) {
      const payment = await this.paymentService.queryPaymentStatus(
        recharge.paymentNo,
        userId,
        "USER",
      );
      recharge = await this.findOwned(userId, id);
      if (
        recharge.status === WalletRechargeStatus.PENDING &&
        [PaymentStatus.CLOSED, PaymentStatus.FAILED].includes(payment.status)
      ) {
        recharge.status =
          payment.status === PaymentStatus.CLOSED
            ? WalletRechargeStatus.CLOSED
            : WalletRechargeStatus.FAILED;
        recharge.failedAt = new Date();
        recharge.failureMessage =
          payment.status === PaymentStatus.CLOSED ? "支付已关闭" : "支付失败";
        recharge = await this.rechargeRepository.save(recharge);
      }
    }
    return this.toResponse(recharge);
  }

  private async findOwned(userId: number, id: number) {
    const recharge = await this.rechargeRepository.findOne({
      where: { id, userId },
    });
    if (!recharge) throw new NotFoundException("充值记录不存在");
    return recharge;
  }

  private toResponse(
    recharge: WalletRecharge,
    alipayOrderString: string | null = null,
  ) {
    return {
      id: recharge.id,
      rechargeNo: recharge.rechargeNo,
      amount: toNumber(recharge.amount),
      status: recharge.status,
      paymentNo: recharge.paymentNo,
      alipayOrderString,
      expiredAt: recharge.expiredAt,
      paidAt: recharge.paidAt,
      failureMessage: recharge.failureMessage,
      createdAt: recharge.createdAt,
      updatedAt: recharge.updatedAt,
    };
  }

  private generateRechargeNo(): string {
    const timestamp = Date.now().toString();
    const random = randomUUID().replace(/-/g, "").substring(0, 8).toUpperCase();
    return `RC${timestamp}${random}`;
  }
}
