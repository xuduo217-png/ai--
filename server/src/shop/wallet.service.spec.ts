import { WalletService } from "./wallet.service";
import {
  Order,
  OrderType,
  SettlementStatus,
} from "./entities/order.entity";
import { Product, PublishSource } from "./entities/product.entity";
import { User } from "../users/entities/user.entity";
import {
  RelatedType,
  WalletTransactionStatus,
  WalletTransactionType,
  WalletTransaction,
} from "./entities/wallet-transaction.entity";
import { NotificationScene } from "../notifications/notification-sender.service";
import {
  WalletWithdrawal,
  WalletWithdrawalStatus,
} from "./entities/wallet-withdrawal.entity";

describe("WalletService.getIncomeStats", () => {
  let service: WalletService;
  let userRepository: { findOne: jest.Mock };
  let walletTransactionRepository: { createQueryBuilder: jest.Mock };
  let orderRepository: { find: jest.Mock };
  let productRepository: { find: jest.Mock };
  let withdrawalRepository: { find: jest.Mock };
  let dataSource: { getRepository: jest.Mock };

  beforeEach(() => {
    userRepository = {
      findOne: jest.fn(),
    };

    walletTransactionRepository = {
      createQueryBuilder: jest.fn(),
    };

    orderRepository = {
      find: jest.fn(),
    };

    productRepository = {
      find: jest.fn(),
    };
    withdrawalRepository = {
      find: jest.fn(),
    };

    dataSource = {
      getRepository: jest.fn((entity) => {
        if (entity === Order) {
          return orderRepository;
        }

        if (entity === Product) {
          return productRepository;
        }

        if (entity === WalletWithdrawal) {
          return withdrawalRepository;
        }

        return null;
      }),
    };

    service = new WalletService(
      userRepository as any,
      walletTransactionRepository as any,
      dataSource as any,
    );
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it("keeps cumulative income based on income records instead of current balance", async () => {
    userRepository.findOne.mockResolvedValue({
      id: 11,
      balance: 30,
      pendingBalance: 20,
      withdrawalFrozenBalance: 8,
    } as User);

    const queryBuilder = {
      select: jest.fn().mockReturnThis(),
      innerJoin: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      getRawOne: jest.fn().mockResolvedValue({
        total: "120.00",
      }),
    };

    walletTransactionRepository.createQueryBuilder.mockReturnValue(
      queryBuilder,
    );

    await expect(service.getIncomeStats(11)).resolves.toEqual({
      available: 30,
      pending: 20,
      total: 120,
      frozen: 8,
    });
    expect(queryBuilder.innerJoin).toHaveBeenCalledWith(
      Order,
      "settlementOrder",
      "settlementOrder.id = transaction.relatedId",
    );
    expect(queryBuilder.andWhere).toHaveBeenCalledWith(
      "transaction.relatedType = :relatedType",
      { relatedType: RelatedType.ORDER },
    );
    expect(queryBuilder.andWhere).toHaveBeenCalledWith(
      "settlementOrder.orderType = :orderType",
      { orderType: OrderType.SECOND_HAND },
    );
    expect(queryBuilder.andWhere).toHaveBeenCalledWith(
      "settlementOrder.sellerId = :sellerId",
      { sellerId: 11 },
    );
  });

  it("returns related products for seller settlement transactions without exposing unrelated order items", async () => {
    const queryBuilder = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getManyAndCount: jest.fn().mockResolvedValue([
        [
          {
            id: 21,
            userId: 10,
            type: WalletTransactionType.INCOME,
            amount: 95,
            balanceBefore: 0,
            balanceAfter: 95,
            relatedType: RelatedType.ORDER,
            relatedId: 100,
            status: WalletTransactionStatus.PENDING,
            remark: "用户发布商品销售结算（成交¥100.00，手续费¥5.00）",
            createdAt: "2026-03-17T10:00:00.000Z",
          },
        ],
        1,
      ]),
    };

    walletTransactionRepository.createQueryBuilder.mockReturnValue(
      queryBuilder,
    );
    orderRepository.find.mockResolvedValue([
      {
        id: 100,
        items: [
          {
            productId: 501,
            productName: "二手猫窝",
            quantity: 1,
            price: 100,
          },
          {
            productId: 777,
            productName: "别人的逗猫棒",
            quantity: 1,
            price: 40,
          },
        ],
      },
    ]);
    productRepository.find.mockResolvedValue([
      {
        id: 501,
        publishSource: PublishSource.USER,
        publishedBy: 10,
        image: "/uploads/cat-bed-cover.png",
        images: ["/uploads/cat-bed-1.png"],
      },
      {
        id: 777,
        publishSource: PublishSource.USER,
        publishedBy: 88,
        image: "/uploads/cat-stick.png",
      },
    ]);

    await expect(
      service.getWalletTransactions(10, { page: 1, limit: 10 }),
    ).resolves.toEqual({
      data: [
        expect.objectContaining({
          id: 21,
          relatedProducts: [
            {
              productId: 501,
              productName: "二手猫窝",
              productImage: "/uploads/cat-bed-1.png",
              quantity: 1,
              price: 100,
            },
          ],
        }),
      ],
      total: 1,
      page: 1,
      limit: 10,
    });
  });

  it("syncs the order and notifies the seller after settlement approval", async () => {
    const transaction = {
      id: 21,
      userId: 10,
      type: WalletTransactionType.INCOME,
      amount: 95,
      relatedType: RelatedType.ORDER,
      relatedId: 100,
      status: WalletTransactionStatus.PENDING,
    } as WalletTransaction;
    const seller = { id: 10, balance: 0, pendingBalance: 95 } as User;
    const manager = {
      findOne: jest.fn(async (entity) => {
        if (entity === WalletTransaction) return transaction;
        if (entity === Order) {
          return {
            id: 100,
            orderType: OrderType.SECOND_HAND,
            sellerId: 10,
          } as Order;
        }
        return null;
      }),
      createQueryBuilder: jest.fn(() => ({
        where: jest.fn().mockReturnThis(),
        setLock: jest.fn().mockReturnThis(),
        getOne: jest.fn().mockResolvedValue(seller),
      })),
      save: jest.fn(async (value) => value),
      update: jest.fn(),
    };
    const notificationSender = { send: jest.fn() };
    const approvalService = new WalletService(
      {} as any,
      {} as any,
      {
        transaction: jest.fn(async (callback) => callback(manager)),
      } as any,
      notificationSender as any,
    );

    await approvalService.approveTransaction(21, 1);

    expect(manager.update).toHaveBeenCalledWith(
      Order,
      { id: 100, settlementId: 21 },
      { settlementStatus: SettlementStatus.SETTLED },
    );
    expect(notificationSender.send).toHaveBeenCalledWith(
      10,
      NotificationScene.SELLER_SETTLEMENT_APPROVED,
      expect.objectContaining({
        orderId: 100,
        viewRole: "seller",
        amount: "95.00",
      }),
    );
  });

  it("attaches real withdrawal status in one batch and marks unmatched history", async () => {
    const queryBuilder = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getManyAndCount: jest.fn().mockResolvedValue([
        [
          { id: 41, userId: 10, relatedType: RelatedType.WITHDRAW, relatedId: 1 },
          { id: 42, userId: 10, relatedType: RelatedType.WITHDRAW, relatedId: 2 },
        ],
        2,
      ]),
    };
    walletTransactionRepository.createQueryBuilder.mockReturnValue(queryBuilder);
    withdrawalRepository.find.mockResolvedValue([
      {
        id: 1,
        userId: 10,
        withdrawalNo: "W20260730001",
        status: WalletWithdrawalStatus.PROCESSING,
      },
    ]);

    const result = await service.getWalletTransactions(10, {
      page: 1,
      limit: 10,
      relatedType: RelatedType.WITHDRAW,
    });

    expect(withdrawalRepository.find).toHaveBeenCalledTimes(1);
    expect(result.data).toEqual([
      expect.objectContaining({
        id: 41,
        withdrawalStatus: WalletWithdrawalStatus.PROCESSING,
        withdrawalNo: "W20260730001",
      }),
      expect.objectContaining({ id: 42, historicalAdjustment: true }),
    ]);
    expect(queryBuilder.andWhere).toHaveBeenCalledWith(
      "transaction.relatedType = :relatedType",
      { relatedType: RelatedType.WITHDRAW },
    );
  });

  it("rejects manual review for income that is not a second-hand seller settlement", async () => {
    const transaction = {
      id: 31,
      userId: 10,
      type: WalletTransactionType.INCOME,
      amount: 50,
      relatedType: RelatedType.RECHARGE,
      relatedId: 99,
      status: WalletTransactionStatus.PENDING,
    } as WalletTransaction;
    const manager = {
      findOne: jest.fn().mockResolvedValue(transaction),
    };
    const reviewService = new WalletService(
      {} as any,
      {} as any,
      {
        transaction: jest.fn(async (callback) => callback(manager)),
      } as any,
    );

    await expect(reviewService.approveTransaction(31, 1)).rejects.toMatchObject({
      response: expect.objectContaining({ code: "3000" }),
    });
    await expect(
      reviewService.rejectTransaction(31, 1, "invalid"),
    ).rejects.toMatchObject({
      response: expect.objectContaining({ code: "3000" }),
    });
  });

  it("does not count a stale auto-approval candidate as successful", async () => {
    const candidate = {
      id: 22,
      userId: 10,
      type: WalletTransactionType.INCOME,
      amount: 95,
      relatedType: RelatedType.ORDER,
      relatedId: 100,
      status: WalletTransactionStatus.PENDING,
      createdAt: new Date("2026-01-01T00:00:00.000Z"),
    } as WalletTransaction;
    const staleService = new WalletService(
      {} as any,
      { find: jest.fn().mockResolvedValue([candidate]) } as any,
      {
        transaction: jest.fn(async (callback) =>
          callback({
            findOne: jest.fn().mockResolvedValue({
              ...candidate,
              status: WalletTransactionStatus.APPROVED,
            }),
          }),
        ),
      } as any,
    );

    await expect(
      staleService.autoApproveExpiredTransactions(),
    ).resolves.toEqual({
      total: 1,
      success: 0,
      failed: 0,
    });
    expect(
      (staleService as any).walletTransactionRepository.find,
    ).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ relatedType: RelatedType.ORDER }),
      }),
    );
  });
});
