import { Injectable, Logger, Optional } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { randomUUID } from "crypto";
import { DataSource, EntityManager, In, LessThan, Repository } from "typeorm";
import {
  AlipayService,
  AlipayTransferResult,
} from "../payment/alipay.service";
import { User } from "../users/entities/user.entity";
import {
  createBusinessException,
  ErrorCode,
} from "../common/constants/error-codes";
import {
  NotificationScene,
  NotificationSenderService,
} from "../notifications/notification-sender.service";
import {
  AdminWalletWithdrawalQueryDto,
  CreateWalletWithdrawalDto,
  WalletWithdrawalQueryDto,
} from "./dto/wallet-withdrawal.dto";
import {
  RelatedType,
  WalletTransaction,
  WalletTransactionStatus,
  WalletTransactionType,
} from "./entities/wallet-transaction.entity";
import {
  WalletWithdrawal,
  WalletWithdrawalPayeeIdentityType,
  WalletWithdrawalStatus,
} from "./entities/wallet-withdrawal.entity";
import {
  WalletWithdrawalActorType,
  WalletWithdrawalLog,
} from "./entities/wallet-withdrawal-log.entity";
import { WalletPiiService } from "./wallet-pii.service";
import {
  WalletWithdrawalConfigService,
  WalletWithdrawalRules,
} from "./wallet-withdrawal-config.service";

const ACTIVE_WITHDRAWAL_STATUSES = [
  WalletWithdrawalStatus.PENDING_REVIEW,
  WalletWithdrawalStatus.PROCESSING,
];
const DAILY_LIMIT_STATUSES = [
  WalletWithdrawalStatus.PENDING_REVIEW,
  WalletWithdrawalStatus.PROCESSING,
  WalletWithdrawalStatus.SUCCEEDED,
];

@Injectable()
export class WalletWithdrawalService {
  private readonly logger = new Logger(WalletWithdrawalService.name);

  constructor(
    @InjectRepository(WalletWithdrawal)
    private readonly withdrawalRepository: Repository<WalletWithdrawal>,
    private readonly dataSource: DataSource,
    private readonly configService: WalletWithdrawalConfigService,
    private readonly piiService: WalletPiiService,
    private readonly alipayService: AlipayService,
    @Optional()
    private readonly notificationSender?: NotificationSenderService,
  ) {}

  async getUserConfig(userId: number) {
    const rules = await this.configService.getRules();
    const user = await this.dataSource.getRepository(User).findOne({
      where: { id: userId },
      select: ["id", "balance"],
    });
    if (!user) {
      throw createBusinessException(ErrorCode.USER_NOT_FOUND);
    }
    const [dailyUsedCents, activeCount] = await Promise.all([
      this.getDailyUsedCents(this.dataSource.manager, userId),
      this.withdrawalRepository.count({
        where: { userId, status: In(ACTIVE_WITHDRAWAL_STATUSES) },
      }),
    ]);

    return {
      enabled: this.configService.isEnabled(rules),
      availableBalance: this.fromCents(this.toCents(user.balance)),
      minAmount: this.fromCents(rules.minAmountCents),
      maxAmountPerRequest: this.fromCents(rules.maxAmountPerRequestCents),
      remainingDailyAmount: this.fromCents(
        Math.max(0, rules.maxAmountPerDayCents - dailyUsedCents),
      ),
      hasActiveWithdrawal: activeCount > 0,
      unavailableReason: this.configService.getUnavailableReason(rules),
    };
  }

  async create(
    userId: number,
    idempotencyKey: string,
    dto: CreateWalletWithdrawalDto,
  ) {
    const existing = await this.withdrawalRepository.findOne({
      where: { userId, idempotencyKey },
    });
    if (existing) return this.toPublic(existing);

    const rules = await this.configService.getRules();
    this.assertServiceEnabled(rules);
    const amountCents = this.parseRequestedAmount(dto.amount, rules);

    const saved = await this.dataSource.transaction(async (manager) => {
      const user = await manager
        .createQueryBuilder(User, "user")
        .where("user.id = :userId", { userId })
        .setLock("pessimistic_write")
        .getOne();
      if (!user) {
        throw createBusinessException(ErrorCode.USER_NOT_FOUND);
      }

      const duplicate = await manager.findOne(WalletWithdrawal, {
        where: { userId, idempotencyKey },
      });
      if (duplicate) return duplicate;

      const activeCount = await manager.count(WalletWithdrawal, {
        where: { userId, status: In(ACTIVE_WITHDRAWAL_STATUSES) },
      });
      if (activeCount > 0) {
        throw createBusinessException(ErrorCode.WITHDRAWAL_ACTIVE_EXISTS);
      }

      const dailyUsedCents = await this.getDailyUsedCents(manager, userId);
      if (dailyUsedCents + amountCents > rules.maxAmountPerDayCents) {
        throw createBusinessException(
          ErrorCode.WITHDRAWAL_LIMIT_EXCEEDED,
          "提现金额超过今日剩余额度",
        );
      }

      const balanceBeforeCents = this.toCents(user.balance);
      if (balanceBeforeCents < amountCents) {
        throw createBusinessException(ErrorCode.INSUFFICIENT_BALANCE);
      }
      const frozenBeforeCents = this.toCents(user.withdrawalFrozenBalance);
      user.balance = this.fromCents(balanceBeforeCents - amountCents);
      user.withdrawalFrozenBalance = this.fromCents(
        frozenBeforeCents + amountCents,
      );
      await manager.save(user);

      let withdrawal = manager.create(WalletWithdrawal, {
        withdrawalNo: this.generateWithdrawalNo(),
        idempotencyKey,
        userId,
        walletTransactionId: null,
        amount: this.fromCents(amountCents),
        status: WalletWithdrawalStatus.PENDING_REVIEW,
        payeeIdentityType:
          WalletWithdrawalPayeeIdentityType.ALIPAY_LOGON_ID,
        payeeAccountEncrypted: this.piiService.encrypt(dto.alipayAccount),
        payeeAccountMasked: this.piiService.maskAlipayAccount(dto.alipayAccount),
        payeeNameEncrypted: this.piiService.encrypt(dto.payeeRealName),
        payeeNameMasked: this.piiService.maskRealName(dto.payeeRealName),
        encryptionKeyVersion: "v1",
      });
      withdrawal = await manager.save(withdrawal);

      const walletTransaction = await manager.save(
        manager.create(WalletTransaction, {
          userId,
          type: WalletTransactionType.EXPENSE,
          amount: this.fromCents(amountCents),
          balanceBefore: this.fromCents(balanceBeforeCents),
          balanceAfter: this.fromCents(balanceBeforeCents - amountCents),
          relatedType: RelatedType.WITHDRAW,
          relatedId: withdrawal.id,
          status: WalletTransactionStatus.PENDING,
          remark: "支付宝提现申请",
        }),
      );
      withdrawal.walletTransactionId = walletTransaction.id;
      await manager.save(withdrawal);
      await this.appendLog(manager, withdrawal, {
        fromStatus: null,
        action: "created",
        actorType: WalletWithdrawalActorType.USER,
        actorId: userId,
      });
      return withdrawal;
    });

    await this.notify(saved, NotificationScene.WALLET_WITHDRAWAL_SUBMITTED);
    return this.toPublic(saved);
  }

  async listForUser(userId: number, query: WalletWithdrawalQueryDto) {
    const [items, total] = await this.withdrawalRepository.findAndCount({
      where: {
        userId,
        ...(query.status ? { status: query.status } : {}),
      },
      order: { createdAt: "DESC" },
      skip: (query.page - 1) * query.limit,
      take: query.limit,
    });
    return {
      data: items.map((item) => this.toPublic(item)),
      total,
      page: query.page,
      limit: query.limit,
    };
  }

  async getForUser(userId: number, id: number) {
    const withdrawal = await this.withdrawalRepository.findOne({
      where: { id, userId },
    });
    if (!withdrawal) {
      throw createBusinessException(ErrorCode.WITHDRAWAL_NOT_FOUND);
    }
    return this.toPublic(withdrawal);
  }

  async listForAdmin(query: AdminWalletWithdrawalQueryDto) {
    const builder = this.withdrawalRepository
      .createQueryBuilder("withdrawal")
      .leftJoinAndSelect("withdrawal.user", "user")
      .orderBy("withdrawal.createdAt", "DESC");
    if (query.withdrawalNo) {
      builder.andWhere("withdrawal.withdrawalNo LIKE :withdrawalNo", {
        withdrawalNo: `%${query.withdrawalNo}%`,
      });
    }
    if (query.userId) {
      builder.andWhere("withdrawal.userId = :userId", { userId: query.userId });
    }
    if (query.phone) {
      builder.andWhere("user.phone LIKE :phone", { phone: `%${query.phone}%` });
    }
    if (query.status) {
      builder.andWhere("withdrawal.status = :status", { status: query.status });
    }
    if (query.startDate) {
      builder.andWhere("withdrawal.createdAt >= :startDate", {
        startDate: new Date(query.startDate),
      });
    }
    if (query.endDate) {
      builder.andWhere("withdrawal.createdAt <= :endDate", {
        endDate: new Date(query.endDate),
      });
    }
    builder.skip((query.page - 1) * query.limit).take(query.limit);
    const [items, total] = await builder.getManyAndCount();
    return {
      data: items.map((item) => ({
        ...this.toPublic(item),
        user: item.user
          ? { id: item.user.id, phone: item.user.phone, username: item.user.username }
          : null,
      })),
      total,
      page: query.page,
      limit: query.limit,
    };
  }

  async getForAdmin(id: number) {
    const withdrawal = await this.withdrawalRepository.findOne({
      where: { id },
      relations: ["user", "logs"],
    });
    if (!withdrawal) {
      throw createBusinessException(ErrorCode.WITHDRAWAL_NOT_FOUND);
    }
    return {
      ...this.toPublic(withdrawal),
      user: withdrawal.user
        ? {
            id: withdrawal.user.id,
            phone: withdrawal.user.phone,
            username: withdrawal.user.username,
          }
        : null,
      logs: [...(withdrawal.logs || [])]
        .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime())
        .map(({ id: logId, fromStatus, toStatus, action, actorType, actorId, externalCode, description, createdAt }) => ({
          id: logId,
          fromStatus,
          toStatus,
          action,
          actorType,
          actorId,
          externalCode,
          description,
          createdAt,
        })),
    };
  }

  async reject(id: number, adminId: number, reason: string) {
    const withdrawal = await this.dataSource.transaction(async (manager) => {
      const current = await this.lockWithdrawal(manager, id);
      this.assertStatus(current, WalletWithdrawalStatus.PENDING_REVIEW);
      const user = await this.lockUser(manager, current.userId);
      const amountCents = this.toCents(current.amount);
      this.releaseFrozenBalance(user, amountCents, true);
      await manager.save(user);

      const fromStatus = current.status;
      current.status = WalletWithdrawalStatus.REJECTED;
      current.reviewedBy = adminId;
      current.reviewedAt = new Date();
      current.rejectReason = reason;
      current.completedAt = new Date();
      await manager.save(current);
      await manager.update(
        WalletTransaction,
        { id: current.walletTransactionId },
        { status: WalletTransactionStatus.REJECTED, rejectReason: reason },
      );
      await this.appendLog(manager, current, {
        fromStatus,
        action: "rejected",
        actorType: WalletWithdrawalActorType.ADMIN,
        actorId: adminId,
        description: reason,
      });
      return current;
    });
    await this.notify(withdrawal, NotificationScene.WALLET_WITHDRAWAL_REJECTED);
    return this.toPublic(withdrawal);
  }

  async approve(id: number, adminId: number) {
    const rules = await this.configService.getRules();
    this.assertServiceEnabled(rules);

    const withdrawal = await this.dataSource.transaction(async (manager) => {
      const current = await this.lockWithdrawal(manager, id);
      this.assertStatus(current, WalletWithdrawalStatus.PENDING_REVIEW);
      const fromStatus = current.status;
      current.status = WalletWithdrawalStatus.PROCESSING;
      current.outBizNo = current.outBizNo || `WD_${current.withdrawalNo}`;
      current.reviewedBy = adminId;
      current.reviewedAt = new Date();
      current.processingAt = new Date();
      await manager.save(current);
      await this.appendLog(manager, current, {
        fromStatus,
        action: "approved_for_transfer",
        actorType: WalletWithdrawalActorType.ADMIN,
        actorId: adminId,
      });
      return current;
    });

    const result = await this.alipayService.createTransfer({
      outBizNo: withdrawal.outBizNo!,
      amount: this.fromCents(this.toCents(withdrawal.amount)).toFixed(2),
      payeeAccount: this.piiService.decrypt(withdrawal.payeeAccountEncrypted),
      payeeName: this.piiService.decrypt(withdrawal.payeeNameEncrypted),
      orderTitle: `钱包提现 ${withdrawal.withdrawalNo}`,
    });
    return this.handleExternalResult(withdrawal.id, result, {
      actorType: WalletWithdrawalActorType.ADMIN,
      actorId: adminId,
      action: "transfer_result",
    });
  }

  async reconcile(id: number, actorId?: number) {
    const withdrawal = await this.withdrawalRepository.findOne({ where: { id } });
    if (!withdrawal) {
      throw createBusinessException(ErrorCode.WITHDRAWAL_NOT_FOUND);
    }
    this.assertStatus(withdrawal, WalletWithdrawalStatus.PROCESSING);
    if (!withdrawal.outBizNo) {
      throw createBusinessException(
        ErrorCode.WITHDRAWAL_STATUS_INVALID,
        "提现单缺少支付宝业务单号",
      );
    }
    const result = await this.alipayService.queryTransfer(withdrawal.outBizNo);
    return this.handleExternalResult(withdrawal.id, result, {
      actorType: actorId
        ? WalletWithdrawalActorType.ADMIN
        : WalletWithdrawalActorType.SYSTEM,
      actorId: actorId || null,
      action: "reconciled",
    });
  }

  async reconcilePending() {
    const cutoff = new Date(Date.now() - 2 * 60 * 1000);
    const withdrawals = await this.withdrawalRepository.find({
      where: {
        status: WalletWithdrawalStatus.PROCESSING,
        processingAt: LessThan(cutoff),
      },
      take: 100,
      order: { processingAt: "ASC" },
    });
    let resolved = 0;
    let unknown = 0;
    for (const withdrawal of withdrawals) {
      try {
        const result = await this.reconcile(withdrawal.id);
        if (result.status === WalletWithdrawalStatus.PROCESSING) unknown++;
        else resolved++;
      } catch {
        unknown++;
        this.logger.warn(`Wallet withdrawal reconciliation failed: ${withdrawal.id}`);
      }
    }
    return { total: withdrawals.length, resolved, unknown };
  }

  private async handleExternalResult(
    id: number,
    result: AlipayTransferResult,
    actor: {
      actorType: WalletWithdrawalActorType;
      actorId: number | null;
      action: string;
    },
  ) {
    if (result.state === "unknown") {
      const withdrawal = await this.dataSource.transaction(async (manager) => {
        const current = await this.lockWithdrawal(manager, id);
        if (current.status !== WalletWithdrawalStatus.PROCESSING) return current;
        current.alipayStatus = result.externalStatus;
        current.failureCode = result.failureCode || null;
        current.failureMessage = result.failureMessage || null;
        await manager.save(current);
        await this.appendLog(manager, current, {
          fromStatus: current.status,
          ...actor,
          externalCode: result.externalStatus,
          description: result.failureMessage || "支付宝结果待确认",
        });
        return current;
      });
      return this.toPublic(withdrawal);
    }

    const withdrawal = await this.dataSource.transaction(async (manager) => {
      const current = await this.lockWithdrawal(manager, id);
      if (current.status !== WalletWithdrawalStatus.PROCESSING) return current;
      const user = await this.lockUser(manager, current.userId);
      const amountCents = this.toCents(current.amount);
      const fromStatus = current.status;
      const succeeded = result.state === "success";
      this.releaseFrozenBalance(user, amountCents, !succeeded);
      await manager.save(user);

      current.status = succeeded
        ? WalletWithdrawalStatus.SUCCEEDED
        : WalletWithdrawalStatus.FAILED;
      current.alipayStatus = result.externalStatus;
      current.alipayOrderId = result.alipayOrderId || current.alipayOrderId;
      current.payFundOrderId = result.payFundOrderId || current.payFundOrderId;
      current.failureCode = result.failureCode || null;
      current.failureMessage = result.failureMessage || null;
      current.completedAt = new Date();
      current.failedAt = succeeded ? null : new Date();
      await manager.save(current);
      await manager.update(
        WalletTransaction,
        { id: current.walletTransactionId },
        {
          status: succeeded
            ? WalletTransactionStatus.APPROVED
            : WalletTransactionStatus.REJECTED,
          rejectReason: succeeded ? null : result.failureMessage || "支付宝转账失败",
        },
      );
      await this.appendLog(manager, current, {
        fromStatus,
        ...actor,
        externalCode: result.externalStatus,
        description: result.failureMessage || null,
      });
      return current;
    });
    await this.notify(
      withdrawal,
      withdrawal.status === WalletWithdrawalStatus.SUCCEEDED
        ? NotificationScene.WALLET_WITHDRAWAL_SUCCEEDED
        : NotificationScene.WALLET_WITHDRAWAL_FAILED,
    );
    return this.toPublic(withdrawal);
  }

  private assertServiceEnabled(rules: WalletWithdrawalRules) {
    if (!this.configService.isEnabled(rules)) {
      throw createBusinessException(
        ErrorCode.WITHDRAWAL_DISABLED,
        this.configService.getUnavailableReason(rules) || undefined,
      );
    }
  }

  private parseRequestedAmount(amount: string, rules: WalletWithdrawalRules) {
    const cents = this.toCents(amount);
    if (cents < rules.minAmountCents) {
      throw createBusinessException(
        ErrorCode.WITHDRAWAL_AMOUNT_INVALID,
        `最低提现金额为 ${this.fromCents(rules.minAmountCents).toFixed(2)} 元`,
      );
    }
    if (cents > rules.maxAmountPerRequestCents) {
      throw createBusinessException(
        ErrorCode.WITHDRAWAL_LIMIT_EXCEEDED,
        "提现金额超过单笔上限",
      );
    }
    return cents;
  }

  private async getDailyUsedCents(manager: EntityManager, userId: number) {
    const { start, end } = this.getShanghaiDayRange();
    const result = await manager
      .createQueryBuilder(WalletWithdrawal, "withdrawal")
      .select("COALESCE(SUM(withdrawal.amount), 0)", "total")
      .where("withdrawal.userId = :userId", { userId })
      .andWhere("withdrawal.status IN (:...statuses)", {
        statuses: DAILY_LIMIT_STATUSES,
      })
      .andWhere("withdrawal.createdAt >= :start", { start })
      .andWhere("withdrawal.createdAt < :end", { end })
      .getRawOne();
    return this.toCents(result?.total || 0);
  }

  private getShanghaiDayRange(now = new Date()) {
    const offsetMs = 8 * 60 * 60 * 1000;
    const local = new Date(now.getTime() + offsetMs);
    const startMs =
      Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate()) -
      offsetMs;
    return { start: new Date(startMs), end: new Date(startMs + 86_400_000) };
  }

  private async lockWithdrawal(manager: EntityManager, id: number) {
    const withdrawal = await manager
      .createQueryBuilder(WalletWithdrawal, "withdrawal")
      .where("withdrawal.id = :id", { id })
      .setLock("pessimistic_write")
      .getOne();
    if (!withdrawal) {
      throw createBusinessException(ErrorCode.WITHDRAWAL_NOT_FOUND);
    }
    return withdrawal;
  }

  private async lockUser(manager: EntityManager, userId: number) {
    const user = await manager
      .createQueryBuilder(User, "user")
      .where("user.id = :userId", { userId })
      .setLock("pessimistic_write")
      .getOne();
    if (!user) throw createBusinessException(ErrorCode.USER_NOT_FOUND);
    return user;
  }

  private releaseFrozenBalance(user: User, amountCents: number, refund: boolean) {
    const frozenCents = this.toCents(user.withdrawalFrozenBalance);
    if (frozenCents < amountCents) {
      throw createBusinessException(
        ErrorCode.DATABASE_ERROR,
        "提现冻结余额异常，请人工核对",
      );
    }
    user.withdrawalFrozenBalance = this.fromCents(frozenCents - amountCents);
    if (refund) {
      user.balance = this.fromCents(this.toCents(user.balance) + amountCents);
    }
  }

  private assertStatus(
    withdrawal: WalletWithdrawal,
    expected: WalletWithdrawalStatus,
  ) {
    if (withdrawal.status !== expected) {
      throw createBusinessException(ErrorCode.WITHDRAWAL_STATUS_INVALID);
    }
  }

  private async appendLog(
    manager: EntityManager,
    withdrawal: WalletWithdrawal,
    input: {
      fromStatus: WalletWithdrawalStatus | null;
      action: string;
      actorType: WalletWithdrawalActorType;
      actorId: number | null;
      externalCode?: string | null;
      description?: string | null;
    },
  ) {
    await manager.save(
      manager.create(WalletWithdrawalLog, {
        withdrawalId: withdrawal.id,
        fromStatus: input.fromStatus,
        toStatus: withdrawal.status,
        action: input.action,
        actorType: input.actorType,
        actorId: input.actorId,
        externalCode: input.externalCode || null,
        description: input.description?.slice(0, 500) || null,
      }),
    );
  }

  private async notify(
    withdrawal: WalletWithdrawal,
    scene: NotificationScene,
  ) {
    if (!this.notificationSender) return;
    try {
      await this.notificationSender.send(withdrawal.userId, scene, {
        withdrawalId: withdrawal.id,
        withdrawalNo: withdrawal.withdrawalNo,
        amount: this.fromCents(this.toCents(withdrawal.amount)).toFixed(2),
        reason: withdrawal.rejectReason || withdrawal.failureMessage,
      });
    } catch {
      this.logger.warn(`Wallet withdrawal notification failed: ${withdrawal.id}`);
    }
  }

  private generateWithdrawalNo() {
    const date = new Date(Date.now() + 8 * 60 * 60 * 1000)
      .toISOString()
      .slice(0, 10)
      .replace(/-/g, "");
    return `W${date}${randomUUID().replace(/-/g, "").slice(0, 18).toUpperCase()}`;
  }

  private toCents(value: number | string | null | undefined): number {
    const text = String(value ?? "0").trim();
    if (/^\d+(?:\.\d{1,2})?$/.test(text)) {
      const [integer, decimal = ""] = text.split(".");
      const cents = Number(integer) * 100 + Number(decimal.padEnd(2, "0"));
      if (Number.isSafeInteger(cents)) return cents;
    }
    throw createBusinessException(ErrorCode.WITHDRAWAL_AMOUNT_INVALID);
  }

  private fromCents(cents: number): number {
    return Number((cents / 100).toFixed(2));
  }

  private toPublic(withdrawal: WalletWithdrawal) {
    return {
      id: withdrawal.id,
      withdrawalNo: withdrawal.withdrawalNo,
      amount: this.fromCents(this.toCents(withdrawal.amount)),
      status: withdrawal.status,
      payeeIdentityType: withdrawal.payeeIdentityType,
      payeeAccountMasked: withdrawal.payeeAccountMasked,
      payeeNameMasked: withdrawal.payeeNameMasked,
      outBizNo: withdrawal.outBizNo,
      alipayOrderId: withdrawal.alipayOrderId,
      payFundOrderId: withdrawal.payFundOrderId,
      alipayStatus: withdrawal.alipayStatus,
      failureCode: withdrawal.failureCode,
      failureMessage: withdrawal.failureMessage,
      rejectReason: withdrawal.rejectReason,
      reviewedBy: withdrawal.reviewedBy,
      reviewedAt: withdrawal.reviewedAt,
      processingAt: withdrawal.processingAt,
      completedAt: withdrawal.completedAt,
      failedAt: withdrawal.failedAt,
      createdAt: withdrawal.createdAt,
      updatedAt: withdrawal.updatedAt,
    };
  }
}
