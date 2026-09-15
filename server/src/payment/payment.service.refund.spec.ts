import { DataSource } from "typeorm";
import { PaymentService } from "./payment.service";
import {
  BusinessType,
  Payment,
  PaymentChannel,
  PaymentMethod,
  PaymentStatus,
} from "./entities/payment.entity";
import { Refund, RefundStatus, RefundType } from "./entities/refund.entity";
import { Order, OrderStatus, OrderType } from "../shop/entities/order.entity";
import { User } from "../users/entities/user.entity";
import {
  AfterSaleHandlerType,
  AfterSaleStatus,
  OrderAfterSale,
} from "../shop/entities/order-after-sale.entity";
import {
  RelatedType,
  WalletTransaction,
  WalletTransactionStatus,
  WalletTransactionType,
} from "../shop/entities/wallet-transaction.entity";
import { ErrorCode } from "../common/constants/error-codes";

describe("PaymentService shop after-sale refunds", () => {
  const createFixture = (
    channel: PaymentChannel,
    orderType = OrderType.NORMAL,
  ) => {
    const order = {
      id: 10,
      orderNo: "ORD_10",
      orderType,
      status: OrderStatus.PAID,
      userId: 7,
      sellerId: orderType === OrderType.SECOND_HAND ? 8 : null,
      totalAmount: 88,
      paymentMethod: channel,
      items: [{ productName: "测试商品", quantity: 1 }],
    } as Order;
    const afterSale = {
      id: 40,
      orderId: order.id,
      orderType,
      handlerType:
        orderType === OrderType.NORMAL
          ? AfterSaleHandlerType.PLATFORM
          : AfterSaleHandlerType.SELLER,
      status: AfterSaleStatus.REFUNDING,
      approvedAmount: 88,
    } as OrderAfterSale;
    const payment = {
      id: 20,
      paymentNo: "PAY_20",
      outTradeNo: "shop_order_10",
      channel,
      method: PaymentMethod.APP,
      status: PaymentStatus.SUCCESS,
      amount: 88,
      refundAmount: 0,
      userId: 7,
      businessType: BusinessType.SHOP_ORDER,
      businessId: 10,
    } as Payment;
    const buyer = { id: 7, balance: 12 } as User;
    const walletPayment = {
      id: 19,
      userId: 7,
      type: WalletTransactionType.EXPENSE,
      amount: 88,
      relatedType: RelatedType.ORDER,
      relatedId: order.id,
      status: WalletTransactionStatus.APPROVED,
    } as WalletTransaction;
    let refundId = 30;
    let transactionRefunds: Refund[] = [];
    const manager = {
      createQueryBuilder: jest.fn((entity: any) => ({
        where: jest.fn().mockReturnThis(),
        setLock: jest.fn().mockReturnThis(),
        getOne: jest.fn(async () => (entity === Payment ? payment : buyer)),
      })),
      findOne: jest.fn(async (entity: any) => {
        if (entity === OrderAfterSale) return afterSale;
        if (entity === Order) return order;
        if (entity === Refund) return transactionRefunds[0] || null;
        return null;
      }),
      find: jest.fn(async (entity: any) =>
        entity === Refund ? transactionRefunds : [],
      ),
      create: jest.fn((_entity: any, value: any) => value),
      save: jest.fn(async (value: any) => {
        if (value?.refundNo && !value.id) {
          value.id = refundId++;
          value.createdAt = new Date();
          transactionRefunds = [value];
        }
        return value;
      }),
    };
    const dataSource = {
      getRepository: jest.fn((entity: any) => ({
        findOne: jest
          .fn()
          .mockResolvedValue(
            entity === WalletTransaction ? walletPayment : afterSale,
          ),
      })),
      transaction: jest.fn(async (callback) => callback(manager)),
    } as unknown as DataSource;
    const paymentRepository = {
      findOne: jest.fn().mockResolvedValue(payment),
      find: jest.fn().mockResolvedValue([payment]),
      create: jest.fn((value) => value),
      save: jest.fn(async (value) => {
        Object.assign(payment, value, { id: value.id || 21 });
        return payment;
      }),
    };
    const refundRepository = { find: jest.fn().mockResolvedValue([]) };
    const orderRepository = { findOne: jest.fn().mockResolvedValue(order) };
    const alipayService = {
      createRefund: jest.fn().mockResolvedValue("ALIPAY_REFUND_1"),
    };
    const wechatPayService = {
      createRefund: jest.fn().mockResolvedValue("WECHAT_REFUND_1"),
    };
    const service = new PaymentService(
      paymentRepository as any,
      {} as any,
      refundRepository as any,
      orderRepository as any,
      alipayService as any,
      wechatPayService as any,
      dataSource,
      {} as any,
      { get: jest.fn() } as any,
    );

    return {
      service,
      order,
      payment,
      buyer,
      manager,
      dataSource,
      refundRepository,
      paymentRepository,
      alipayService,
      wechatPayService,
      setTransactionRefunds: (value: Refund[]) => {
        transactionRefunds = value;
      },
    };
  };

  it.each([
    [PaymentChannel.ALIPAY, "alipayService", "ALIPAY_REFUND_1"],
    [PaymentChannel.WECHAT, "wechatPayService", "WECHAT_REFUND_1"],
  ] as const)(
    "refunds through the original %s channel with a stable key",
    async (channel, providerKey, thirdPartyRefundNo) => {
      const fixture = createFixture(channel);

      const result = await fixture.service.createShopAfterSaleRefund(
        40,
        99,
        "平台售后退款",
      );

      expect(fixture[providerKey].createRefund).toHaveBeenCalledWith(
        fixture.payment,
        88,
        "ASREF40",
        "平台售后退款",
      );
      expect(result).toEqual(
        expect.objectContaining({
          refundAmount: 88,
          status: RefundStatus.SUCCESS,
          channel,
          thirdPartyRefundNo,
        }),
      );
      expect(fixture.payment.status).toBe(PaymentStatus.REFUNDED);
    },
  );

  it("returns the successful refund found after acquiring the payment lock", async () => {
    const fixture = createFixture(PaymentChannel.ALIPAY);
    const existing = {
      id: 31,
      refundNo: "ASREF40",
      paymentId: 20,
      refundAmount: 88,
      status: RefundStatus.SUCCESS,
      channel: PaymentChannel.ALIPAY,
      metadata: { afterSaleId: 40 },
      createdAt: new Date(),
    } as unknown as Refund;
    fixture.setTransactionRefunds([existing]);

    const result = await fixture.service.createShopAfterSaleRefund(
      40,
      99,
      "并发重复退款",
    );

    expect(result.refundNo).toBe("ASREF40");
    expect(fixture.alipayService.createRefund).not.toHaveBeenCalled();
  });

  it("restores balance and writes one approved wallet transaction", async () => {
    const fixture = createFixture(PaymentChannel.BALANCE);

    await fixture.service.createShopAfterSaleRefund(40, 99, "余额售后退款");

    expect(fixture.buyer.balance).toBe(100);
    expect(fixture.manager.save).toHaveBeenCalledWith(
      expect.objectContaining<Partial<WalletTransaction>>({
        userId: 7,
        amount: 88,
        balanceBefore: 12,
        balanceAfter: 100,
        relatedType: RelatedType.REFUND,
        status: WalletTransactionStatus.APPROVED,
      }),
    );
  });

  it.each([OrderType.NORMAL, OrderType.SECOND_HAND])(
    "restores a verified %s balance payment snapshot after switching from a pending channel",
    async (orderType) => {
      const fixture = createFixture(PaymentChannel.ALIPAY, orderType);
      fixture.order.paymentMethod = PaymentChannel.BALANCE;
      fixture.order.paymentNo = "BALANCE_ORD_10_1";
      fixture.order.transactionId = fixture.order.paymentNo;
      fixture.payment.status = PaymentStatus.PENDING;

      const result = await fixture.service.createShopAfterSaleRefund(
        40,
        99,
        "历史余额订单退款",
      );

      expect(fixture.paymentRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          paymentNo: fixture.order.paymentNo,
          channel: PaymentChannel.BALANCE,
          status: PaymentStatus.SUCCESS,
          metadata: expect.objectContaining({ walletTransactionId: 19 }),
        }),
      );
      expect(result.channel).toBe(PaymentChannel.BALANCE);
      expect(fixture.buyer.balance).toBe(100);
    },
  );

  it.each([OrderType.NORMAL, OrderType.SECOND_HAND])(
    "blocks generic refunds for %s shop orders",
    async (orderType) => {
      const fixture = createFixture(PaymentChannel.ALIPAY, orderType);

      await expect(
        fixture.service.createRefund(
          {
            paymentId: 20,
            refundAmount: 88,
            type: RefundType.FULL,
            reason: "绕过售后退款",
          },
          99,
          "SUPER_ADMIN",
        ),
      ).rejects.toThrow("商城订单请通过订单售后流程退款");
      expect(fixture.alipayService.createRefund).not.toHaveBeenCalled();
    },
  );

  it("rejects payment status queries from another user", async () => {
    const fixture = createFixture(PaymentChannel.ALIPAY);

    await expect(
      fixture.service.queryPaymentStatus("PAY_20", 999, "USER"),
    ).rejects.toMatchObject({ code: ErrorCode.PERMISSION_DENIED });
  });

  it("returns a dedicated payment status DTO without internal IDs", async () => {
    const fixture = createFixture(PaymentChannel.ALIPAY);

    const result = await fixture.service.queryPaymentStatus(
      "PAY_20",
      7,
      "USER",
    );

    expect(result).toEqual(
      expect.objectContaining({
        paymentNo: "PAY_20",
        status: PaymentStatus.SUCCESS,
      }),
    );
    expect(result).not.toHaveProperty("id");
    expect(result).not.toHaveProperty("userId");
    expect(result).not.toHaveProperty("transactionId");
  });
});
