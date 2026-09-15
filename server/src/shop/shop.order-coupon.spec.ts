import { BadRequestException } from "@nestjs/common";
import { DataSource } from "typeorm";
import { ConfigService } from "@nestjs/config";
import { ShopService } from "./shop.service";
import { Order, OrderStatus, OrderType } from "./entities/order.entity";
import {
  PaymentChannel,
  PaymentStatus,
  BusinessType,
  Payment,
} from "../payment/entities/payment.entity";
import { PlatformFeeService } from "./platform-fee.service";
import { Product, PublishSource } from "./entities/product.entity";
import { ProductSku, SkuStatus } from "./entities/product-sku.entity";
import {
  PendingProductStatus,
  ProductPending,
} from "./entities/product-pending.entity";

jest.mock("uuid", () => ({
  v4: () => "test-uuid",
}));

describe("ShopService - coupon order lifecycle", () => {
  const mockProductRepository = {
    findOne: jest.fn(),
  };

  const mockProductSkuRepository = {
    findOne: jest.fn(),
  };

  const mockOrderRepository = {
    find: jest.fn(),
    findOne: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  };

  const mockCategoryRepository = {
    find: jest.fn(),
  };

  const mockCharityRepository = {
    findOne: jest.fn(),
  };

  const mockWalletTransactionRepository = {
    manager: {},
  };

  const createManager = () => ({
    create: jest.fn(),
    save: jest.fn(),
    increment: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
    find: jest.fn(),
    findOne: jest.fn(),
    createQueryBuilder: jest.fn(),
  });

  const transactionManager = createManager();
  const rollbackManager = createManager();

  const mainQueryRunner = {
    connect: jest.fn(),
    startTransaction: jest.fn(),
    commitTransaction: jest.fn(),
    rollbackTransaction: jest.fn(),
    release: jest.fn(),
    manager: transactionManager,
  };

  const rollbackQueryRunner = {
    connect: jest.fn(),
    startTransaction: jest.fn(),
    commitTransaction: jest.fn(),
    rollbackTransaction: jest.fn(),
    release: jest.fn(),
    manager: rollbackManager,
  };

  const mockDataSource = {
    createQueryRunner: jest.fn(),
    transaction: jest.fn(async (callback) => callback(transactionManager)),
  } as unknown as DataSource;

  const mockPaymentService = {
    createPayment: jest.fn(),
  };

  const mockNotificationSender = {
    send: jest.fn(),
    orderCreated: jest.fn(),
    orderPaid: jest.fn(),
  };

  const mockLogisticsService = {};

  const mockConfigService = {
    get: jest.fn((key: string) => {
      if (key === "NODE_ENV") return "test";
      return null;
    }),
  } as unknown as ConfigService;
  const mockPlatformFeeService = {
    getPlatformFeeRate: jest.fn().mockResolvedValue(5),
  } as unknown as PlatformFeeService;

  let service: ShopService;
  const couponService = {
    releaseCouponForOrder: jest.fn(),
  };

  beforeEach(() => {
    jest.clearAllMocks();
    (mockDataSource.createQueryRunner as jest.Mock)
      .mockReset()
      .mockImplementationOnce(() => mainQueryRunner)
      .mockImplementationOnce(() => rollbackQueryRunner);
    service = new ShopService(
      mockProductRepository as any,
      mockProductSkuRepository as any,
      mockOrderRepository as any,
      mockCategoryRepository as any,
      {} as any,
      mockWalletTransactionRepository as any,
      mockPaymentService as any,
      mockDataSource,
      mockNotificationSender as any,
      mockLogisticsService as any,
      mockConfigService,
      mockPlatformFeeService,
      undefined,
      undefined,
      undefined,
      mockCharityRepository as any,
    );
    service.setCouponService(couponService);
  });

  it("releases the used coupon when a pending order is cancelled by the user", async () => {
    const order = {
      id: 5001,
      userId: 99,
      status: OrderStatus.PENDING,
      items: [],
    } as Order;
    jest.spyOn(service, "findOneOrder").mockResolvedValue(order);
    transactionManager.findOne.mockResolvedValue(order);

    await service.cancelOrder(5001, 99, "用户取消");

    expect(couponService.releaseCouponForOrder).toHaveBeenCalledWith(
      5001,
      transactionManager,
    );
  });

  it("restores stock and re-lists a sold-out user single-spec product when the pending order is manually cancelled", async () => {
    const userProductId = 7001;
    const pendingProductId = 91;
    const compatibilitySku = {
      id: 801,
      productId: userProductId,
      stock: 0,
      status: SkuStatus.OUT_OF_STOCK,
    };
    const product = {
      id: userProductId,
      publishSource: PublishSource.USER,
      pendingProductId,
      name: "用户单规格商品",
      stock: 0,
      isActive: false,
      hasSku: false,
      soldAt: new Date("2026-03-01T10:00:00.000Z"),
    };

    transactionManager.increment.mockImplementation(
      async (entity: any, criteria: any, _field: string, amount: number) => {
        if (entity === ProductSku && criteria.id === compatibilitySku.id) {
          compatibilitySku.stock += amount;
        }
        if (entity === Product && criteria.id === userProductId) {
          product.stock += amount;
        }
      },
    );
    transactionManager.findOne.mockImplementation(
      async (entity: any, options: any) => {
        if (entity === Product && options?.where?.id === userProductId) {
          return product;
        }
        if (
          entity === ProductSku &&
          options?.where?.id === compatibilitySku.id
        ) {
          return compatibilitySku;
        }
        if (entity === Order && options?.where?.id === 5002) {
          return {
            id: 5002,
            userId: 99,
            status: OrderStatus.PENDING,
            items: [
              {
                productId: userProductId,
                skuId: compatibilitySku.id,
                quantity: 1,
              },
            ],
          };
        }
        if (
          entity === ProductPending &&
          options?.where?.id === pendingProductId
        ) {
          return { id: pendingProductId, status: PendingProductStatus.SOLD };
        }
        return null;
      },
    );
    transactionManager.find.mockImplementation(
      async (entity: any, options: any) => {
        if (
          entity === ProductSku &&
          options?.where?.productId === userProductId
        ) {
          return [compatibilitySku];
        }
        return [];
      },
    );
    transactionManager.save.mockImplementation(async (entity: any) => entity);
    jest
      .spyOn(service, "findOneOrder")
      .mockResolvedValueOnce({
        id: 5002,
        userId: 99,
        status: OrderStatus.PENDING,
        items: [
          { productId: userProductId, skuId: compatibilitySku.id, quantity: 1 },
        ],
      } as Order)
      .mockResolvedValueOnce({
        id: 5002,
        userId: 99,
        status: OrderStatus.CANCELLED,
        items: [
          { productId: userProductId, skuId: compatibilitySku.id, quantity: 1 },
        ],
      } as Order);

    await service.cancelOrder(5002, 99, "用户取消");

    expect(product.stock).toBe(1);
    expect(compatibilitySku.stock).toBe(1);
    expect(transactionManager.save).toHaveBeenCalledWith(
      expect.objectContaining({
        id: compatibilitySku.id,
        stock: 1,
        status: SkuStatus.ACTIVE,
      }),
    );
    expect(transactionManager.update).toHaveBeenCalledWith(
      Product,
      userProductId,
      expect.objectContaining({
        isActive: true,
        soldAt: null,
      }),
    );
    expect(transactionManager.update).toHaveBeenCalledWith(
      "products_pending",
      { id: pendingProductId },
      { status: PendingProductStatus.ON_SHELF },
    );
  });

  it("returns coupon options and selected coupon discount in order preview", async () => {
    const getOrderCouponOptions = jest.fn().mockResolvedValue([
      {
        id: 1,
        isApplicable: true,
        discountAmount: 20,
      },
    ]);

    service.setCouponService({
      ...couponService,
      getOrderCouponOptions,
    });

    mainQueryRunner.manager.findOne.mockResolvedValue({
      id: 1001,
      publishSource: "ADMIN",
      name: "测试商品",
      stock: 10,
      isActive: true,
      price: 99,
    });

    const result = await service.previewOrder(
      {
        items: [{ productId: 1001, quantity: 2 }],
        userCouponId: 1,
      },
      99,
    );

    expect(result).toEqual(
      expect.objectContaining({
        originalAmount: 198,
        couponDiscount: 20,
        totalAmount: 178,
        selectedCoupon: expect.objectContaining({ id: 1 }),
      }),
    );
  });

  it("returns the active mall charity donation rate for normal orders", async () => {
    service.setCouponService({
      ...couponService,
      getOrderCouponOptions: jest.fn().mockResolvedValue([]),
    });
    mockCharityRepository.findOne.mockResolvedValue({
      isMallAutoDonation: true,
      participantType: "donation",
      status: "ACTIVE",
      donationRate: "1.50",
    });
    mainQueryRunner.manager.findOne.mockResolvedValue({
      id: 1001,
      publishSource: "ADMIN",
      name: "测试商品",
      stock: 10,
      isActive: true,
      price: 99,
    });

    const result = await service.previewOrder(
      { items: [{ productId: 1001, quantity: 1 }] },
      99,
    );

    expect(result.charityDonationRate).toBe(1.5);
    expect(result.charityDonationAmount).toBe(1.49);
    expect(mockCharityRepository.findOne).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          isMallAutoDonation: true,
          participantType: "donation",
          status: "ACTIVE",
        }),
      }),
    );
  });

  it("rejects orders that mix platform and user-published goods", async () => {
    const getOrderCouponOptions = jest.fn().mockResolvedValue([
      {
        id: 8,
        isApplicable: false,
        discountAmount: 0,
        unavailableReason: "订单金额未达到优惠券使用门槛",
      },
    ]);

    service.setCouponService({
      ...couponService,
      getOrderCouponOptions,
    });

    mainQueryRunner.manager.findOne
      .mockResolvedValueOnce({
        id: 1001,
        publishSource: "ADMIN",
        name: "系统商品",
        stock: 10,
        isActive: true,
        price: 80,
      })
      .mockResolvedValueOnce({
        id: 1002,
        publishSource: "USER",
        publishedBy: 66,
        name: "用户商品",
        stock: 10,
        isActive: true,
        price: 50,
      });

    await expect(
      service.previewOrder(
        {
          items: [
            { productId: 1001, quantity: 1 },
            { productId: 1002, quantity: 1 },
          ],
        },
        99,
      ),
    ).rejects.toThrow("二手订单只能购买一个商品，数量固定为1");
    expect(getOrderCouponOptions).not.toHaveBeenCalled();
  });

  it("does not allow a coupon on a second-hand order", async () => {
    mainQueryRunner.manager.findOne.mockResolvedValue({
      id: 1002,
      publishSource: "USER",
      publishedBy: 66,
      name: "用户商品",
      stock: 1,
      isActive: true,
      price: 50,
    });

    await expect(
      service.previewOrder(
        {
          items: [{ productId: 1002, quantity: 1 }],
          userCouponId: 8,
        },
        99,
      ),
    ).rejects.toThrow("二手商品订单不支持使用优惠券");
  });

  it("rejects buying a self-published product", async () => {
    mainQueryRunner.manager.findOne.mockResolvedValue({
      id: 1002,
      publishSource: "USER",
      publishedBy: 99,
      name: "用户商品",
      stock: 1,
      isActive: true,
      price: 50,
    });

    await expect(
      service.previewOrder({ items: [{ productId: 1002, quantity: 1 }] }, 99),
    ).rejects.toThrow("不能购买自己发布的商品");
  });

  it("rejects quantity greater than one for a second-hand order", async () => {
    mainQueryRunner.manager.findOne.mockResolvedValue({
      id: 1002,
      publishSource: "USER",
      publishedBy: 66,
      name: "用户商品",
      stock: 2,
      isActive: true,
      price: 50,
    });

    await expect(
      service.previewOrder({ items: [{ productId: 1002, quantity: 2 }] }, 99),
    ).rejects.toThrow("二手订单只能购买一个商品，数量固定为1");
  });

  it("cancels and releases coupon usage when payment is closed before success", async () => {
    const order = {
      id: 5001,
      orderNo: "ORD-5001",
      userId: 99,
      status: OrderStatus.PENDING,
      items: [],
    };
    mockOrderRepository.findOne.mockResolvedValue(order);
    transactionManager.findOne.mockImplementation(async (entity: any) =>
      entity === Order ? order : null,
    );

    await service.handlePaymentWebhook(
      {
        businessId: 5001,
        businessType: BusinessType.SHOP_ORDER,
        status: PaymentStatus.CLOSED,
      } as Payment,
      "PAYMENT_CLOSED",
    );

    expect(couponService.releaseCouponForOrder).toHaveBeenCalledWith(
      5001,
      expect.any(Object),
    );
    expect(transactionManager.update).toHaveBeenCalledWith(
      expect.any(Function),
      5001,
      expect.objectContaining({
        status: OrderStatus.CANCELLED,
      }),
    );
  });

  it("restores stock and re-lists a sold-out user multi-sku product when payment timeout triggers auto cancellation", async () => {
    const userProductId = 7002;
    const pendingProductId = 92;
    const restoredSku = {
      id: 802,
      productId: userProductId,
      stock: 0,
      status: SkuStatus.OUT_OF_STOCK,
    };
    const userProduct = {
      id: userProductId,
      publishSource: PublishSource.USER,
      pendingProductId,
      name: "用户多规格商品",
      stock: 0,
      isActive: false,
      hasSku: true,
      soldAt: new Date("2026-03-01T10:00:00.000Z"),
    };

    mockOrderRepository.findOne.mockResolvedValue({
      id: 5003,
      orderNo: "ORD-5003",
      userId: 99,
      status: OrderStatus.PENDING,
      items: [{ productId: userProductId, skuId: restoredSku.id, quantity: 1 }],
    });
    transactionManager.increment.mockImplementation(
      async (entity: any, criteria: any, _field: string, amount: number) => {
        if (entity === ProductSku && criteria.id === restoredSku.id) {
          restoredSku.stock += amount;
        }
      },
    );
    transactionManager.findOne.mockImplementation(
      async (entity: any, options: any) => {
        if (entity === Product && options?.where?.id === userProductId) {
          return userProduct;
        }
        if (entity === ProductSku && options?.where?.id === restoredSku.id) {
          return restoredSku;
        }
        if (entity === Order && options?.where?.id === 5003) {
          return {
            id: 5003,
            status: OrderStatus.PENDING,
            items: [
              {
                productId: userProductId,
                skuId: restoredSku.id,
                quantity: 1,
              },
            ],
          };
        }
        if (
          entity === ProductPending &&
          options?.where?.id === pendingProductId
        ) {
          return { id: pendingProductId, status: PendingProductStatus.SOLD };
        }
        return null;
      },
    );
    transactionManager.find.mockImplementation(
      async (entity: any, options: any) => {
        if (
          entity === ProductSku &&
          options?.where?.productId === userProductId
        ) {
          return [restoredSku];
        }
        return [];
      },
    );
    transactionManager.save.mockImplementation(async (entity: any) => entity);

    await service.handlePaymentWebhook(
      {
        businessId: 5003,
        businessType: BusinessType.SHOP_ORDER,
        status: PaymentStatus.CLOSED,
      } as Payment,
      "PAYMENT_CLOSED",
    );

    expect(restoredSku.stock).toBe(1);
    expect(transactionManager.save).toHaveBeenCalledWith(
      expect.objectContaining({
        id: restoredSku.id,
        stock: 1,
        status: SkuStatus.ACTIVE,
      }),
    );
    expect(transactionManager.update).toHaveBeenCalledWith(
      Product,
      userProductId,
      expect.objectContaining({
        isActive: true,
        soldAt: null,
      }),
    );
    expect(transactionManager.update).toHaveBeenCalledWith(
      "products_pending",
      { id: pendingProductId },
      { status: PendingProductStatus.ON_SHELF },
    );
  });

  it("releases coupon usage during payment creation rollback after the order transaction was committed", async () => {
    const lockedCoupon = {
      coupon: { id: 10 },
      discount: 20,
      userCoupon: { id: 1 },
    };

    service.setCouponService({
      ...couponService,
      lockCouponForOrder: jest.fn().mockResolvedValue(lockedCoupon),
      markCouponUsedForOrder: jest.fn().mockResolvedValue(undefined),
      releaseCouponForOrder: couponService.releaseCouponForOrder,
    });

    transactionManager.findOne.mockResolvedValue({
      id: 1001,
      publishSource: "ADMIN",
      name: "测试商品",
      stock: 10,
      isActive: true,
    });
    transactionManager.create = jest.fn((_: any, payload: any) => payload);
    transactionManager.save = jest
      .fn()
      .mockImplementation(
        async (_entity: any, payload?: any) => payload ?? _entity,
      );
    transactionManager.createQueryBuilder = jest.fn(() => ({
      update: jest.fn().mockReturnThis(),
      set: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      execute: jest.fn().mockResolvedValue({ affected: 1 }),
    }));

    mockPaymentService.createPayment.mockRejectedValue(
      new BadRequestException("支付创建失败"),
    );

    await expect(
      service.createOrder(
        {
          items: [{ productId: 1001, quantity: 1 }],
          shippingAddress: "上海市测试路 1 号",
          receiverName: "张三",
          receiverPhone: "13800000000",
          paymentChannel: PaymentChannel.ALIPAY_WAP,
          userCouponId: 1,
        },
        99,
      ),
    ).rejects.toThrow(BadRequestException);

    expect(couponService.releaseCouponForOrder).toHaveBeenCalled();
  });

  it("auto-offlines exhausted user-published single-spec products and syncs the compatibility sku after order creation", async () => {
    const userProductId = 1002;
    const pendingProductId = 77;
    const compatibilitySku = {
      id: 301,
      productId: userProductId,
      stock: 1,
      status: SkuStatus.ACTIVE,
    };

    transactionManager.findOne = jest
      .fn()
      .mockResolvedValueOnce({
        id: userProductId,
        publishSource: PublishSource.USER,
        publishedBy: 66,
        pendingProductId,
        name: "用户商品",
        stock: 1,
        isActive: true,
        price: 50,
        hasSku: false,
      })
      .mockResolvedValueOnce({
        id: userProductId,
        publishSource: PublishSource.USER,
        publishedBy: 66,
        pendingProductId,
        name: "用户商品",
        stock: 0,
        isActive: true,
        price: 50,
        hasSku: false,
      })
      .mockResolvedValueOnce({
        id: userProductId,
        publishSource: PublishSource.USER,
        publishedBy: 66,
        pendingProductId,
        name: "用户商品",
        stock: 0,
        isActive: true,
        price: 50,
        hasSku: false,
      });
    transactionManager.find = jest.fn().mockResolvedValue([compatibilitySku]);
    transactionManager.create = jest.fn((_: any, payload: any) => payload);
    transactionManager.save = jest.fn(async (entity: any, payload?: any) => {
      const record = payload ?? entity;
      if (entity === Order) {
        return {
          id: 5002,
          orderNo: "SHOP-5002",
          totalAmount: 50,
          ...record,
        };
      }
      return record;
    });
    transactionManager.createQueryBuilder = jest.fn(() => ({
      update: jest.fn().mockReturnThis(),
      set: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      execute: jest.fn().mockResolvedValue({ affected: 1 }),
    }));
    mockPaymentService.createPayment.mockResolvedValue({
      paymentNo: "PAY-5002",
    });

    await service.createOrder(
      {
        items: [{ productId: userProductId, quantity: 1 }],
        shippingAddress: "上海市测试路 1 号",
        receiverName: "张三",
        receiverPhone: "13800000000",
        paymentChannel: PaymentChannel.ALIPAY_WAP,
      },
      99,
    );

    expect(transactionManager.save).toHaveBeenCalledWith(
      expect.objectContaining({
        id: 301,
        stock: 0,
        status: SkuStatus.OUT_OF_STOCK,
      }),
    );
    expect(transactionManager.update).toHaveBeenCalledWith(
      Product,
      userProductId,
      expect.objectContaining({
        isActive: false,
      }),
    );
    expect(transactionManager.update).toHaveBeenCalledWith(
      "products_pending",
      { id: pendingProductId },
      { status: PendingProductStatus.SOLD },
    );
  });

  it("releases coupon usage during automatic pending-order cancellation", async () => {
    const order = {
      id: 5001,
      userId: 99,
      status: OrderStatus.PENDING,
      orderType: OrderType.NORMAL,
      items: [],
    } as Order;
    mockOrderRepository.find.mockResolvedValue([order]);
    transactionManager.findOne.mockImplementation(async (entity: any) =>
      entity === Order ? order : null,
    );

    await service.autoCancelPendingOrders();

    expect(couponService.releaseCouponForOrder).toHaveBeenCalledWith(
      5001,
      transactionManager,
    );
  });

  it("restores stock when a timed-out pending order is auto cancelled by the scheduler", async () => {
    const sku = {
      id: 803,
      productId: 7003,
      stock: 0,
      status: SkuStatus.OUT_OF_STOCK,
    };
    const product = {
      id: 7003,
      publishSource: PublishSource.ADMIN,
      stock: 0,
      isActive: true,
      hasSku: true,
    };

    const order = {
      id: 5004,
      userId: 99,
      status: OrderStatus.PENDING,
      orderType: OrderType.NORMAL,
      createdAt: new Date(Date.now() - 31 * 60 * 1000),
      items: [{ productId: 7003, skuId: 803, quantity: 2 }],
    } as Order;
    mockOrderRepository.find.mockResolvedValue([order]);
    transactionManager.increment.mockImplementation(
      async (entity: any, criteria: any, _field: string, amount: number) => {
        if (entity === ProductSku && criteria.id === sku.id) {
          sku.stock += amount;
        }
      },
    );
    transactionManager.findOne.mockImplementation(
      async (entity: any, options: any) => {
        if (entity === Product && options?.where?.id === product.id) {
          return product;
        }
        if (entity === ProductSku && options?.where?.id === sku.id) {
          return sku;
        }
        if (entity === Order && options?.where?.id === order.id) {
          return order;
        }
        return null;
      },
    );
    transactionManager.find.mockImplementation(
      async (entity: any, options: any) => {
        if (entity === ProductSku && options?.where?.productId === product.id) {
          return [sku];
        }
        return [];
      },
    );
    transactionManager.save.mockImplementation(async (entity: any) => entity);

    await service.autoCancelPendingOrders();

    expect(sku.stock).toBe(2);
    expect(transactionManager.save).toHaveBeenCalledWith(
      expect.objectContaining({
        id: sku.id,
        stock: 2,
        status: SkuStatus.ACTIVE,
      }),
    );
    expect(transactionManager.update).toHaveBeenCalledWith(
      Order,
      5004,
      expect.objectContaining({
        status: OrderStatus.CANCELLED,
        cancelReason: "30分钟未支付自动取消",
      }),
    );
  });

  it("rejects direct cancellation of a paid order", async () => {
    jest.spyOn(service, "findOneOrder").mockResolvedValue({
      id: 5005,
      userId: 99,
      status: OrderStatus.PAID,
      items: [],
    } as Order);

    await expect(
      service.updateOrderStatus(5005, {
        status: OrderStatus.CANCELLED,
        cancelReason: "退款关闭订单",
      }),
    ).rejects.toThrow("已付款订单必须通过退款流程取消");
    expect(transactionManager.increment).not.toHaveBeenCalled();
  });
});
