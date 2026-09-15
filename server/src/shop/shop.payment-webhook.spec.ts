import { DataSource, Repository } from "typeorm";
import { ShopService } from "./shop.service";
import {
  BusinessType,
  Payment,
  PaymentChannel,
} from "../payment/entities/payment.entity";
import { Order, OrderStatus } from "./entities/order.entity";
import { PlatformFeeService } from "./platform-fee.service";
import { Product, PublishSource } from "./entities/product.entity";
import { ProductSku, SkuStatus } from "./entities/product-sku.entity";
import {
  PendingProductStatus,
  ProductPending,
} from "./entities/product-pending.entity";

jest.mock("uuid", () => ({
  v4: jest.fn(() => "mocked-id"),
}));

describe("ShopService.handlePaymentWebhook", () => {
  let service: ShopService;
  let orderRepository: jest.Mocked<Partial<Repository<Order>>>;
  let transactionManager: any;

  const productRepository = {} as any;
  const productSkuRepository = {} as any;
  const categoryRepository = {} as any;
  const systemConfigRepository = {} as any;
  const walletTransactionRepository = {} as any;
  const paymentService = {} as any;
  const dataSource = {
    transaction: jest.fn(async (callback: (manager: any) => Promise<any>) =>
      callback(transactionManager),
    ),
  } as unknown as DataSource;
  const logisticsService = {} as any;
  const notificationSender = {
    send: jest.fn(),
    orderCompleted: jest.fn(),
  } as any;
  const configService = {
    get: jest.fn(() => "test"),
  } as any;
  const platformFeeService = {
    getPlatformFeeRate: jest.fn().mockResolvedValue(5),
  } as unknown as PlatformFeeService;

  /**
   * 构造最小支付对象
   * 仅保留支付回调落单校验所需字段，避免测试关注点分散
   */
  const createPayment = (overrides: Partial<Payment> = {}): Payment =>
    ({
      paymentNo: "PAY_1",
      channel: PaymentChannel.ALIPAY,
      businessType: BusinessType.SHOP_ORDER,
      businessId: 1,
      userId: 7,
      amount: 99.99,
      transactionId: "trade_1",
      ...overrides,
    }) as Payment;

  const createOrder = (overrides: Partial<Order> = {}): Order =>
    ({
      id: 1,
      orderNo: "ORD_1",
      userId: 7,
      totalAmount: "99.99" as any,
      status: OrderStatus.PENDING,
      ...overrides,
    }) as Order;

  beforeEach(() => {
    transactionManager = {
      increment: jest.fn(),
      update: jest.fn(),
      findOne: jest.fn(),
      find: jest.fn(),
      count: jest.fn().mockResolvedValue(0),
      save: jest.fn(async (entity: any) => entity),
      createQueryBuilder: jest.fn(),
    };
    orderRepository = {
      findOne: jest.fn(),
      update: jest.fn(),
    };

    service = new ShopService(
      productRepository,
      productSkuRepository,
      orderRepository as any,
      categoryRepository,
      systemConfigRepository,
      walletTransactionRepository,
      paymentService,
      dataSource,
      notificationSender,
      logisticsService,
      configService,
      platformFeeService,
    );

    jest
      .spyOn(service as any, "processSellerSettlement")
      .mockResolvedValue(undefined);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it("should reject webhook when payment user does not match order owner", async () => {
    orderRepository.findOne!.mockResolvedValue(createOrder());

    await service.handlePaymentWebhook(
      createPayment({ userId: 8 }),
      "PAYMENT_SUCCESS",
    );

    expect(orderRepository.update).not.toHaveBeenCalled();
  });

  it("should reject webhook when payment amount does not match order amount", async () => {
    orderRepository.findOne!.mockResolvedValue(createOrder());

    await service.handlePaymentWebhook(
      createPayment({ amount: 88.88 }),
      "PAYMENT_SUCCESS",
    );

    expect(orderRepository.update).not.toHaveBeenCalled();
  });

  it("should reject webhook when business id does not match loaded order", async () => {
    orderRepository.findOne!.mockResolvedValue(createOrder({ id: 9 }));

    await service.handlePaymentWebhook(
      createPayment({ businessId: 1 }),
      "PAYMENT_SUCCESS",
    );

    expect(orderRepository.update).not.toHaveBeenCalled();
  });

  it("should update order to paid when payment snapshot matches order", async () => {
    orderRepository
      .findOne!.mockResolvedValueOnce(createOrder())
      .mockResolvedValueOnce(createOrder());

    await service.handlePaymentWebhook(createPayment(), "PAYMENT_SUCCESS");

    expect(orderRepository.update).toHaveBeenCalledWith(
      1,
      expect.objectContaining({
        status: OrderStatus.PAID,
        transactionId: "trade_1",
      }),
    );
    expect((service as any).processSellerSettlement).not.toHaveBeenCalled();
  });

  it("should settle seller income only after the buyer confirms receipt", async () => {
    const shippedOrder = createOrder({
      status: OrderStatus.SHIPPED,
      shippedAt: new Date("2026-03-01T10:00:00.000Z") as any,
    });

    transactionManager.findOne.mockResolvedValue(shippedOrder);
    jest.spyOn(service, "findOneOrder").mockResolvedValue(shippedOrder);

    await service.confirmOrder(1, 7);

    expect(shippedOrder.status).toBe(OrderStatus.COMPLETED);
    expect(transactionManager.save).toHaveBeenCalledWith(shippedOrder);
    expect((service as any).processSellerSettlement).toHaveBeenCalledWith(
      shippedOrder,
      transactionManager,
    );
  });

  it("should block receipt confirmation while an after-sale is active", async () => {
    const shippedOrder = createOrder({
      status: OrderStatus.SHIPPED,
      shippedAt: new Date("2026-03-01T10:00:00.000Z") as any,
    });
    transactionManager.findOne.mockResolvedValue(shippedOrder);
    transactionManager.count.mockResolvedValue(1);

    await expect(service.confirmOrder(1, 7)).rejects.toThrow(
      "订单存在进行中的售后，不能确认收货",
    );
    expect(transactionManager.save).not.toHaveBeenCalled();
    expect((service as any).processSellerSettlement).not.toHaveBeenCalled();
  });

  it("should auto confirm shipped orders after 10 days and trigger settlement", async () => {
    const shippedOrder = createOrder({
      status: OrderStatus.SHIPPED,
      shippedAt: new Date("2026-03-01T10:00:00.000Z") as any,
      autoConfirmAt: new Date(Date.now() - 1000) as any,
    });

    orderRepository.find = jest.fn().mockResolvedValue([shippedOrder]);
    transactionManager.findOne.mockResolvedValue(shippedOrder);

    const result = await service.autoConfirmShippedOrders();

    expect(shippedOrder.status).toBe(OrderStatus.COMPLETED);
    expect((service as any).processSellerSettlement).toHaveBeenCalledWith(
      shippedOrder,
      transactionManager,
    );
    expect(result).toEqual({
      processed: 1,
      total: 1,
    });
  });

  it("should restore stock and relist a sold-out user product when refund succeeds", async () => {
    const productId = 9001;
    const pendingProductId = 333;
    const sku = {
      id: 901,
      productId,
      stock: 0,
      status: SkuStatus.OUT_OF_STOCK,
    } as ProductSku;
    const product = {
      id: productId,
      publishSource: PublishSource.USER,
      pendingProductId,
      stock: 0,
      isActive: false,
      hasSku: true,
      soldAt: new Date("2026-03-01T10:00:00.000Z"),
    } as Product;

    orderRepository.findOne!.mockResolvedValue(
      createOrder({
        id: 66,
        status: OrderStatus.PAID,
        items: [
          {
            productId,
            productName: "退款商品",
            quantity: 2,
            price: 49.99,
            skuId: sku.id,
          },
        ],
      }),
    );
    transactionManager.increment.mockImplementation(
      async (entity: any, criteria: any, _field: string, amount: number) => {
        if (entity === ProductSku && criteria.id === sku.id) {
          sku.stock += amount;
        }
      },
    );
    transactionManager.findOne.mockImplementation(
      async (entity: any, options: any) => {
        if (entity === Product && options?.where?.id === productId) {
          return product;
        }
        if (entity === ProductSku && options?.where?.id === sku.id) {
          return sku;
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
        if (entity === ProductSku && options?.where?.productId === productId) {
          return [sku];
        }
        return [];
      },
    );
    transactionManager.createQueryBuilder.mockReturnValue({
      where: jest.fn().mockReturnThis(),
      setLock: jest.fn().mockReturnThis(),
      getOne: jest.fn().mockResolvedValue(
        createOrder({
          id: 66,
          status: OrderStatus.PAID,
          items: [
            {
              productId,
              productName: "退款商品",
              quantity: 2,
              price: 49.99,
              skuId: sku.id,
            },
          ],
        }),
      ),
    });

    await service.handlePaymentWebhook(
      createPayment({
        businessId: 66,
        refundAmount: 99.99,
      }),
      "REFUND_SUCCESS",
    );

    expect(dataSource.transaction).toHaveBeenCalledTimes(1);
    expect(sku.stock).toBe(2);
    expect(transactionManager.save).toHaveBeenCalledWith(
      expect.objectContaining({
        id: sku.id,
        stock: 2,
        status: SkuStatus.ACTIVE,
      }),
    );
    expect(transactionManager.update).toHaveBeenCalledWith(
      Product,
      productId,
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
    expect(transactionManager.update).toHaveBeenCalledWith(
      Order,
      66,
      expect.objectContaining({
        status: OrderStatus.CANCELLED,
        cancelReason: "退款成功自动回补库存",
      }),
    );
  });
});
