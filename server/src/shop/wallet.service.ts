import {
  Injectable,
  NotFoundException,
  Logger,
  Optional,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository, DataSource, EntityManager, In } from "typeorm";
import { User } from "../users/entities/user.entity";
import {
  WalletTransaction,
  WalletTransactionType,
  WalletTransactionStatus,
  RelatedType,
} from "./entities/wallet-transaction.entity";
import {
  Order,
  OrderType,
  SettlementStatus,
} from "./entities/order.entity";
import { Product, PublishSource } from "./entities/product.entity";
import { add, subtract, toNumber } from "../common/utils/currency.util";
import {
  createBusinessException,
  ErrorCode,
} from "../common/constants/error-codes";
import {
  NotificationScene,
  NotificationSenderService,
} from "../notifications/notification-sender.service";
import { WalletWithdrawal } from "./entities/wallet-withdrawal.entity";
import { WalletTransactionQueryDto } from "./dto/wallet-withdrawal.dto";

@Injectable()
export class WalletService {
  private readonly logger = new Logger(WalletService.name);

  private resolveProductImage(product?: Product | null, productImage?: string) {
    if (productImage) {
      return productImage;
    }

    if (product?.images?.length) {
      return product.images[0];
    }

    return product?.image;
  }

  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(WalletTransaction)
    private walletTransactionRepository: Repository<WalletTransaction>,
    private dataSource: DataSource,
    @Optional()
    private notificationSender?: NotificationSenderService,
  ) {}

  /**
   * 获取钱包概况
   */
  async getWalletOverview(userId: number) {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      select: [
        "id",
        "balance",
        "pendingBalance",
        "withdrawalFrozenBalance",
      ],
    });

    if (!user) {
      throw new NotFoundException("用户不存在");
    }

    return {
      balance: toNumber(user.balance),
      pendingBalance: toNumber(user.pendingBalance),
      withdrawalFrozenBalance: toNumber(user.withdrawalFrozenBalance),
    };
  }

  /**
   * 获取收益统计
   * 累计收益基于收入流水累计值，不受当前余额消费影响。
   */
  async getIncomeStats(userId: number) {
    const wallet = await this.getWalletOverview(userId);

    const totalResult = await this.walletTransactionRepository
      .createQueryBuilder("transaction")
      .select("COALESCE(SUM(transaction.amount), 0)", "total")
      .innerJoin(
        Order,
        "settlementOrder",
        "settlementOrder.id = transaction.relatedId",
      )
      .where("transaction.userId = :userId", { userId })
      .andWhere("transaction.type = :type", {
        type: WalletTransactionType.INCOME,
      })
      .andWhere("transaction.status IN (:...statuses)", {
        statuses: [
          WalletTransactionStatus.PENDING,
          WalletTransactionStatus.APPROVED,
        ],
      })
      .andWhere("transaction.relatedType = :relatedType", {
        relatedType: RelatedType.ORDER,
      })
      .andWhere("settlementOrder.orderType = :orderType", {
        orderType: OrderType.SECOND_HAND,
      })
      .andWhere("settlementOrder.sellerId = :sellerId", { sellerId: userId })
      .getRawOne();

    return {
      available: toNumber(wallet.balance),
      pending: toNumber(wallet.pendingBalance),
      total: toNumber(totalResult?.total),
      frozen: toNumber(wallet.withdrawalFrozenBalance),
    };
  }

  private async assertSecondHandSellerSettlement(
    manager: EntityManager,
    transaction: WalletTransaction,
  ) {
    if (
      transaction.type !== WalletTransactionType.INCOME ||
      transaction.relatedType !== RelatedType.ORDER
    ) {
      throw createBusinessException(
        ErrorCode.BUSINESS_INVALID_PARAM,
        "只能审核二手订单卖家收益结算",
      );
    }

    const order = await manager.findOne(Order, {
      where: { id: transaction.relatedId },
    });
    if (
      !order ||
      order.orderType !== OrderType.SECOND_HAND ||
      order.sellerId !== transaction.userId
    ) {
      throw createBusinessException(
        ErrorCode.BUSINESS_INVALID_PARAM,
        "交易记录不是当前卖家的二手订单结算",
      );
    }
  }

  /**
   * 获取钱包明细列表
   */
  async getWalletTransactions(
    userId: number,
    query: WalletTransactionQueryDto,
  ) {
    const { type, status, relatedType, page = 1, limit = 10 } = query;

    const queryBuilder = this.walletTransactionRepository
      .createQueryBuilder("transaction")
      .where("transaction.userId = :userId", { userId })
      .orderBy("transaction.createdAt", "DESC");

    // 类型筛选
    if (type) {
      queryBuilder.andWhere("transaction.type = :type", { type });
    }

    // 状态筛选
    if (status) {
      queryBuilder.andWhere("transaction.status = :status", { status });
    }

    if (relatedType) {
      queryBuilder.andWhere("transaction.relatedType = :relatedType", {
        relatedType,
      });
    }

    // 分页
    queryBuilder.skip((page - 1) * limit).take(limit);

    const [items, total] = await queryBuilder.getManyAndCount();
    const enrichedItems = await this.attachRelatedProducts(userId, items);

    return {
      data: enrichedItems,
      total,
      page: Number(page),
      limit: Number(limit),
    };
  }

  private async attachRelatedProducts(
    userId: number,
    items: WalletTransaction[],
  ) {
    const withdrawalIds = Array.from(
      new Set(
        items
          .filter(
            (item) =>
              item.relatedType === RelatedType.WITHDRAW &&
              Number.isFinite(Number(item.relatedId)),
          )
          .map((item) => Number(item.relatedId)),
      ),
    );
    const withdrawalMap = new Map<number, WalletWithdrawal>();
    if (withdrawalIds.length > 0) {
      const withdrawals = await this.dataSource.getRepository(WalletWithdrawal).find({
        where: { id: In(withdrawalIds), userId },
      });
      withdrawals.forEach((withdrawal) => withdrawalMap.set(withdrawal.id, withdrawal));
    }
    const withdrawalEnrichedItems = items.map((item) => {
      if (item.relatedType !== RelatedType.WITHDRAW) return item;
      const withdrawal = withdrawalMap.get(Number(item.relatedId));
      return withdrawal
        ? {
            ...item,
            withdrawalStatus: withdrawal.status,
            withdrawalNo: withdrawal.withdrawalNo,
          }
        : { ...item, historicalAdjustment: true };
    });

    const orderIds = Array.from(
      new Set(
        withdrawalEnrichedItems
          .filter(
            (item) =>
              item.relatedType === "order" && Number.isFinite(item.relatedId),
          )
          .map((item) => Number(item.relatedId)),
      ),
    );

    if (orderIds.length === 0) {
      return withdrawalEnrichedItems;
    }

    const orderRepository = this.dataSource.getRepository(Order);
    const productRepository = this.dataSource.getRepository(Product);
    const orders = await orderRepository.find({
      where: { id: In(orderIds) },
    });
    const orderMap = new Map(orders.map((order) => [order.id, order]));

    const productIds = Array.from(
      new Set(
        orders.flatMap((order) =>
          Array.isArray(order.items)
            ? order.items
                .map((item) => Number(item.productId))
                .filter((productId) => Number.isFinite(productId))
            : [],
        ),
      ),
    );

    const productMap = new Map<number, Product>();
    if (productIds.length > 0) {
      const products = await productRepository.find({
        where: { id: In(productIds) },
      });
      products.forEach((product) => {
        productMap.set(product.id, product);
      });
    }

    return withdrawalEnrichedItems.map((item) => {
      if (item.relatedType !== "order") {
        return item;
      }

      const order = orderMap.get(Number(item.relatedId));
      if (!order?.items?.length) {
        return item;
      }

      const relatedProducts = order.items.flatMap((orderItem) => {
        const product = productMap.get(Number(orderItem.productId));
        if (
          !product ||
          product.publishSource !== PublishSource.USER ||
          product.publishedBy !== userId
        ) {
          return [];
        }

        return [
          {
            productId: Number(orderItem.productId),
            productName: orderItem.productName,
            productImage: this.resolveProductImage(
              product,
              orderItem.productImage,
            ),
            quantity: Number(orderItem.quantity),
            price: Number(orderItem.price),
            skuName: orderItem.skuName,
          },
        ];
      });

      if (relatedProducts.length === 0) {
        return item;
      }

      return {
        ...item,
        relatedProducts,
      };
    });
  }

  /**
   * 创建待审核交易记录
   * 当二手商品订单确认收货时调用
   */
  async createTransaction(
    userId: number,
    amount: number,
    relatedType: string,
    relatedId: number,
    remark?: string,
  ) {
    return await this.dataSource.transaction(async (manager) => {
      // 使用行锁获取用户（防止并发更新）
      const user = await manager
        .createQueryBuilder(User, "user")
        .where("user.id = :id", { id: userId })
        .setLock("pessimistic_write")
        .getOne();

      if (!user) {
        throw new NotFoundException("用户不存在");
      }

      const oldPendingBalance = toNumber(user.pendingBalance);
      const newPendingBalance = add(oldPendingBalance, amount);

      // 更新用户待审核余额
      user.pendingBalance = newPendingBalance;
      await manager.save(user);

      // 创建待审核交易记录
      const transaction = manager.create(WalletTransaction, {
        userId,
        type: WalletTransactionType.INCOME,
        amount,
        balanceBefore: oldPendingBalance,
        balanceAfter: newPendingBalance,
        relatedType: relatedType as any,
        relatedId,
        status: WalletTransactionStatus.PENDING,
        remark: remark || "二手商品销售收入",
      });

      const savedTransaction = await manager.save(transaction);

      this.logger.log(
        `创建待审核交易成功: userId=${userId}, amount=${amount}, transactionId=${savedTransaction.id}`,
      );

      return savedTransaction;
    });
  }

  /**
   * 审核通过（支持重新审核已拒绝的记录）
   */
  async approveTransaction(
    transactionId: number,
    reviewedBy: number,
    remark?: string,
  ) {
    const transaction = await this.dataSource.transaction(async (manager) => {
      const transaction = await manager.findOne(WalletTransaction, {
        where: { id: transactionId },
      });

      if (!transaction) {
        throw new NotFoundException("交易记录不存在");
      }

      await this.assertSecondHandSellerSettlement(manager, transaction);

      // 只能审核待审核或已拒绝状态的交易
      if (
        transaction.status !== WalletTransactionStatus.PENDING &&
        transaction.status !== WalletTransactionStatus.REJECTED
      ) {
        throw createBusinessException(
          ErrorCode.BUSINESS_INVALID_PARAM,
          "只能审核待审核或已拒绝状态的交易",
        );
      }

      // 使用行锁获取用户（防止并发更新）
      const user = await manager
        .createQueryBuilder(User, "user")
        .where("user.id = :id", { id: transaction.userId })
        .setLock("pessimistic_write")
        .getOne();

      if (!user) {
        throw new NotFoundException("用户不存在");
      }

      const amount = toNumber(transaction.amount);
      const oldBalance = toNumber(user.balance);

      let newBalance = oldBalance;

      // 根据当前状态处理不同的余额逻辑
      if (transaction.status === WalletTransactionStatus.PENDING) {
        // 待审核状态：从待审核余额转到可用余额
        const oldPendingBalance = toNumber(user.pendingBalance);

        // 验证待审核余额充足
        if (oldPendingBalance < amount) {
          throw createBusinessException(
            ErrorCode.INSUFFICIENT_BALANCE,
            "待审核余额不足",
          );
        }

        const newPendingBalance = subtract(oldPendingBalance, amount);
        user.pendingBalance = newPendingBalance;
        newBalance = add(oldBalance, amount);

        this.logger.log(
          `审核通过（待审核）: transactionId=${transactionId}, userId=${user.id}, amount=${amount}, pendingBalance: ${oldPendingBalance} -> ${newPendingBalance}, balance: ${oldBalance} -> ${newBalance}`,
        );
      } else if (transaction.status === WalletTransactionStatus.REJECTED) {
        // 已拒绝状态：从冻结金额转到可用余额
        const frozenAmount = toNumber(transaction.frozenAmount || 0);

        newBalance = add(oldBalance, frozenAmount);

        // 清空冻结金额和拒绝原因
        transaction.frozenAmount = 0;
        transaction.rejectReason = null;

        this.logger.log(
          `审核通过（重新审核）: transactionId=${transactionId}, userId=${user.id}, frozenAmount=${frozenAmount}, balance: ${oldBalance} -> ${newBalance}`,
        );
      }

      // 更新用户余额
      user.balance = newBalance;
      await manager.save(user);

      // 更新交易记录状态
      transaction.status = WalletTransactionStatus.APPROVED;
      transaction.reviewedAt = new Date();
      transaction.reviewedBy = reviewedBy;
      transaction.autoProcessed = false;
      if (remark) {
        transaction.remark = remark;
      }
      await manager.save(transaction);
      if (
        transaction.type === WalletTransactionType.INCOME &&
        transaction.relatedType === RelatedType.ORDER
      ) {
        await manager.update(
          Order,
          { id: transaction.relatedId, settlementId: transaction.id },
          { settlementStatus: SettlementStatus.SETTLED },
        );
      }

      this.logger.log(
        `审核通过成功: transactionId=${transactionId}, userId=${user.id}, amount=${amount}`,
      );

      return transaction;
    });
    await this.notifySettlementResult(
      transaction,
      NotificationScene.SELLER_SETTLEMENT_APPROVED,
    );
    return transaction;
  }

  /**
   * 审核拒绝
   */
  async rejectTransaction(
    transactionId: number,
    reviewedBy: number,
    rejectReason: string,
  ) {
    const transaction = await this.dataSource.transaction(async (manager) => {
      const transaction = await manager.findOne(WalletTransaction, {
        where: { id: transactionId },
      });

      if (!transaction) {
        throw new NotFoundException("交易记录不存在");
      }

      await this.assertSecondHandSellerSettlement(manager, transaction);

      if (transaction.status !== WalletTransactionStatus.PENDING) {
        throw createBusinessException(
          ErrorCode.BUSINESS_INVALID_PARAM,
          "只能审核待审核状态的交易",
        );
      }

      // 使用行锁获取用户（防止并发更新）
      const user = await manager
        .createQueryBuilder(User, "user")
        .where("user.id = :id", { id: transaction.userId })
        .setLock("pessimistic_write")
        .getOne();

      if (!user) {
        throw new NotFoundException("用户不存在");
      }

      const amount = toNumber(transaction.amount);
      const oldPendingBalance = toNumber(user.pendingBalance);

      // 验证待审核余额充足
      if (oldPendingBalance < amount) {
        throw createBusinessException(
          ErrorCode.INSUFFICIENT_BALANCE,
          "待审核余额不足",
        );
      }

      const newPendingBalance = subtract(oldPendingBalance, amount);

      // 更新用户待审核余额
      user.pendingBalance = newPendingBalance;
      await manager.save(user);

      // 更新交易记录状态
      transaction.status = WalletTransactionStatus.REJECTED;
      transaction.frozenAmount = amount;
      transaction.rejectReason = rejectReason;
      transaction.reviewedAt = new Date();
      transaction.reviewedBy = reviewedBy;
      transaction.autoProcessed = false;
      await manager.save(transaction);

      this.logger.log(
        `审核拒绝成功: transactionId=${transactionId}, userId=${user.id}, amount=${amount}, reason=${rejectReason}`,
      );

      return transaction;
    });
    await this.notifySettlementResult(
      transaction,
      NotificationScene.SELLER_SETTLEMENT_REJECTED,
      rejectReason,
    );
    return transaction;
  }

  /**
   * 自动审核超过7天的记录
   * 由定时任务调用
   */
  async autoApproveExpiredTransactions() {
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    // 查询超过7天且状态为待审核的记录
    const expiredTransactions = await this.walletTransactionRepository.find({
      where: {
        status: WalletTransactionStatus.PENDING,
        type: WalletTransactionType.INCOME,
        relatedType: RelatedType.ORDER,
      },
      relations: ["user"],
    });

    // 过滤出超过7天的记录
    const transactionsToApprove = expiredTransactions.filter(
      (t) => new Date(t.createdAt) < sevenDaysAgo,
    );

    if (transactionsToApprove.length === 0) {
      this.logger.log("没有需要自动审核的记录");
      return {
        total: 0,
        success: 0,
        failed: 0,
      };
    }

    let successCount = 0;
    let failedCount = 0;

    // 逐一审核
    for (const transaction of transactionsToApprove) {
      try {
        const approved = await this.dataSource.transaction(async (manager) => {
          // 重新获取最新的交易记录
          const latestTransaction = await manager.findOne(WalletTransaction, {
            where: { id: transaction.id },
          });

          if (!latestTransaction) {
            throw new NotFoundException("交易记录不存在");
          }

          if (latestTransaction.status !== WalletTransactionStatus.PENDING) {
            this.logger.warn(`交易 ${transaction.id} 状态已变更，跳过自动审核`);
            return false;
          }

          await this.assertSecondHandSellerSettlement(
            manager,
            latestTransaction,
          );

          // 使用行锁获取用户
          const user = await manager
            .createQueryBuilder(User, "user")
            .where("user.id = :id", { id: transaction.userId })
            .setLock("pessimistic_write")
            .getOne();

          if (!user) {
            throw new NotFoundException("用户不存在");
          }

          const amount = toNumber(latestTransaction.amount);
          const oldPendingBalance = toNumber(user.pendingBalance);
          const oldBalance = toNumber(user.balance);

          // 验证待审核余额充足
          if (oldPendingBalance < amount) {
            throw createBusinessException(
              ErrorCode.INSUFFICIENT_BALANCE,
              "待审核余额不足",
            );
          }

          const newPendingBalance = subtract(oldPendingBalance, amount);
          const newBalance = add(oldBalance, amount);

          // 更新用户余额
          user.pendingBalance = newPendingBalance;
          user.balance = newBalance;
          await manager.save(user);

          // 更新交易记录状态
          latestTransaction.status = WalletTransactionStatus.APPROVED;
          latestTransaction.reviewedAt = new Date();
          latestTransaction.reviewedBy = 0; // 0 表示系统自动审核
          latestTransaction.autoProcessed = true;
          await manager.save(latestTransaction);
          if (
            latestTransaction.type === WalletTransactionType.INCOME &&
            latestTransaction.relatedType === RelatedType.ORDER
          ) {
            await manager.update(
              Order,
              {
                id: latestTransaction.relatedId,
                settlementId: latestTransaction.id,
              },
              { settlementStatus: SettlementStatus.SETTLED },
            );
          }
          return true;
        });

        if (!approved) {
          continue;
        }

        successCount++;
        await this.notifySettlementResult(
          transaction,
          NotificationScene.SELLER_SETTLEMENT_APPROVED,
        );
        this.logger.log(
          `自动审核成功: transactionId=${transaction.id}, userId=${transaction.userId}`,
        );
      } catch (error) {
        failedCount++;
        this.logger.error(
          `自动审核失败: transactionId=${transaction.id}, error=${error.message}`,
        );
      }
    }

    this.logger.log(
      `自动审核完成: 总数=${transactionsToApprove.length}, 成功=${successCount}, 失败=${failedCount}`,
    );

    return {
      total: transactionsToApprove.length,
      success: successCount,
      failed: failedCount,
    };
  }

  private async notifySettlementResult(
    transaction: WalletTransaction,
    scene: NotificationScene,
    reason?: string,
  ) {
    if (
      !this.notificationSender ||
      transaction.type !== WalletTransactionType.INCOME ||
      transaction.relatedType !== RelatedType.ORDER
    ) {
      return;
    }
    await this.notificationSender.send(transaction.userId, scene, {
      orderId: transaction.relatedId,
      viewRole: "seller",
      amount: toNumber(transaction.amount).toFixed(2),
      reason,
    });
  }

  /**
   * 获取钱包交易列表（带关联信息）
   * 用于后台管理
   * @param query.userId 用户ID筛选
   * @param query.status 状态筛选（pending/approved/rejected）
   * @param query.type 交易类型筛选（income/expense/freeze/unfreeze）
   * @param query.page 页码
   * @param query.limit 每页数量
   */
  async getTransactionList(query: any) {
    const { userId, status, type, relatedType, page = 1, limit = 10 } = query;

    const queryBuilder = this.walletTransactionRepository
      .createQueryBuilder("transaction")
      .leftJoinAndSelect("transaction.user", "user")
      .orderBy("transaction.createdAt", "DESC");

    // 交易类型筛选（如果不传 type，则显示所有类型）
    if (type) {
      queryBuilder.andWhere("transaction.type = :type", { type });
    }

    // 状态筛选（如果不传 status，则显示所有状态）
    if (status) {
      queryBuilder.andWhere("transaction.status = :status", { status });
    }

    if (relatedType) {
      queryBuilder.andWhere("transaction.relatedType = :relatedType", {
        relatedType,
      });
    }

    // 用户筛选
    if (userId) {
      queryBuilder.andWhere("transaction.userId = :userId", { userId });
    }

    // 分页
    queryBuilder.skip((page - 1) * limit).take(limit);

    const [items, total] = await queryBuilder.getManyAndCount();

    // 计算等待天数（仅对待审核的记录计算）
    const itemsWithWaitingDays = items.map((item) => {
      if (item.status === WalletTransactionStatus.PENDING) {
        const createdDate = new Date(item.createdAt);
        const now = new Date();
        const diffTime = Math.abs(now.getTime() - createdDate.getTime());
        const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
        return {
          ...item,
          waitingDays: diffDays,
          isOverdue: diffDays > 7,
        };
      }
      return item;
    });

    return {
      items: itemsWithWaitingDays,
      total,
      page: Number(page),
      limit: Number(limit),
    };
  }
}
