import { DataSource, Repository } from "typeorm";
import { ShopService } from "./shop.service";
import {
  PaymentChannel,
  PaymentStatus,
} from "../payment/entities/payment.entity";
import { Order, OrderStatus, OrderType } from "./entities/order.entity";
import {
  RelatedType,
  WalletTransactionStatus,
  WalletTransactionType,
} from "./entities/wallet-transaction.entity";
import { User } from "../users/entities/user.entity";
import { ErrorCode } from "../common/constants/error-codes";

jest.mock("uuid", () => ({
  v4: jest.fn(() => "mocked-balance-payment-id"),
}));

describe("ShopService balance payment", () => {
  let service: ShopService;
  let dataSource: { transaction: jest.Mock };
  let currentUser: User;
  let orderUpdates: Array<{
    entity: any;
    id: number;
    payload: Record<string, any>;
  }>;
  let savedWalletTransactions: Array<Record<string, any>>;
  let savedPayments: Array<Record<string, any>>;
  const paymentService = {
    fulfillShopOrderDonation: jest.fn().mockResolvedValue(undefined),
    closePendingShopPaymentsForChannelSwitch: jest.fn(),
  };

  const orderRepository = {} as Partial<Repository<Order>>;
  const notificationSender = {
    send: jest.fn(),
    orderCreated: jest.fn(),
    orderPaid: jest.fn(),
  } as any;

  const baseOrder = {
    id: 18,
    orderNo: "ORD_BALANCE_18",
    userId: 7,
    sellerId: 9,
    orderType: OrderType.SECOND_HAND,
    totalAmount: 99,
    status: OrderStatus.PENDING,
    items: [{ productName: "测试商品", quantity: 1 }],
  } as Order;

  const createLockedOrderQuery = () => ({
    where: jest.fn().mockReturnThis(),
    setLock: jest.fn().mockReturnThis(),
    getOne: jest.fn(async () => baseOrder),
  });

  const createLockedUserQuery = () => ({
    where: jest.fn().mockReturnThis(),
    setLock: jest.fn().mockReturnThis(),
    getOne: jest.fn(async () => currentUser),
  });

  beforeEach(() => {
    currentUser = {
      id: 7,
      balance: 120,
      pendingBalance: 0,
    } as User;
    orderUpdates = [];
    savedWalletTransactions = [];
    savedPayments = [];
    paymentService.closePendingShopPaymentsForChannelSwitch.mockResolvedValue(
      undefined,
    );

    dataSource = {
      transaction: jest.fn(async (callback: (manager: any) => Promise<any>) => {
        const manager = {
          createQueryBuilder: jest.fn((entity: any) => {
            if (entity === Order) {
              return createLockedOrderQuery();
            }
            if (entity === User) {
              return createLockedUserQuery();
            }

            throw new Error(`Unexpected entity: ${entity?.name || entity}`);
          }),
          findOne: jest.fn(async () => null),
          create: jest.fn(
            (_entity: any, payload: Record<string, any>) => payload,
          ),
          save: jest.fn(async (_entity: any, payload?: Record<string, any>) => {
            const entityToSave = payload ?? _entity;

            if ("type" in entityToSave && "relatedType" in entityToSave) {
              savedWalletTransactions.push(entityToSave);
              return entityToSave;
            }

            if ("channel" in entityToSave && "outTradeNo" in entityToSave) {
              savedPayments.push(entityToSave);
              return entityToSave;
            }

            if ("balance" in entityToSave) {
              currentUser = {
                ...currentUser,
                ...entityToSave,
              };
              return currentUser;
            }

            return entityToSave;
          }),
          update: jest.fn(
            async (entity: any, id: number, payload: Record<string, any>) => {
              orderUpdates.push({ entity, id, payload });
              return { affected: 1 };
            },
          ),
        };

        return callback(manager);
      }),
    };

    service = new ShopService(
      {} as any,
      {} as any,
      orderRepository as any,
      {} as any,
      {} as any,
      {} as any,
      paymentService as any,
      dataSource as unknown as DataSource,
      notificationSender,
      {} as any,
      { get: jest.fn(() => "test") } as any,
      { getPlatformFeeRate: jest.fn(async () => 5) } as any,
    );
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it("marks the order as paid and creates an approved wallet expense when paying with balance", async () => {
    jest
      .spyOn(service, "findOneOrder")
      .mockResolvedValueOnce(baseOrder)
      .mockResolvedValueOnce({
        ...baseOrder,
        status: OrderStatus.PAID,
        paymentMethod: "balance",
      } as Order);

    const result = await service.payOrder(18, 7, PaymentChannel.BALANCE);

    expect(dataSource.transaction).toHaveBeenCalledTimes(1);
    expect(currentUser.balance).toBe(21);
    expect(orderUpdates).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          entity: Order,
          id: 18,
          payload: expect.objectContaining({
            status: OrderStatus.PAID,
            paymentMethod: "balance",
            platformFeeRate: 5,
            platformFee: 4.95,
            sellerIncome: 94.05,
          }),
        }),
      ]),
    );
    expect(savedWalletTransactions).toEqual([
      expect.objectContaining({
        userId: 7,
        type: WalletTransactionType.EXPENSE,
        amount: 99,
        balanceBefore: 120,
        balanceAfter: 21,
        relatedType: RelatedType.ORDER,
        relatedId: 18,
        status: WalletTransactionStatus.APPROVED,
      }),
    ]);
    expect(
      paymentService.closePendingShopPaymentsForChannelSwitch,
    ).toHaveBeenCalledWith(18, PaymentChannel.BALANCE);
    expect(savedPayments).toEqual([
      expect.objectContaining({
        channel: PaymentChannel.BALANCE,
        status: PaymentStatus.SUCCESS,
        amount: 99,
        businessId: 18,
      }),
    ]);
    expect(notificationSender.orderPaid).toHaveBeenCalledWith(7, {
      orderId: 18,
    });
    expect(notificationSender.orderPaid).toHaveBeenCalledWith(9, {
      orderId: 18,
      viewRole: "seller",
    });
    expect(result.paymentParams).toEqual(
      expect.objectContaining({
        isBalance: true,
      }),
    );
  });

  it("rejects balance payment when the user available balance is insufficient", async () => {
    currentUser.balance = 20;

    jest.spyOn(service, "findOneOrder").mockResolvedValue(baseOrder);

    await expect(
      service.payOrder(18, 7, PaymentChannel.BALANCE),
    ).rejects.toMatchObject({
      code: ErrorCode.INSUFFICIENT_BALANCE,
    });

    expect(dataSource.transaction).toHaveBeenCalledTimes(1);
    expect(orderUpdates).toHaveLength(0);
    expect(savedWalletTransactions).toHaveLength(0);
    expect(notificationSender.orderPaid).not.toHaveBeenCalled();
  });
});
