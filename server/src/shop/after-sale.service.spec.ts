import "reflect-metadata";
import { plainToInstance } from "class-transformer";
import { validate } from "class-validator";
import { DataSource } from "typeorm";
import { AfterSaleService } from "./after-sale.service";
import {
  AdminAfterSaleDecision,
  AdminArbitrateAfterSaleDto,
  AdminReviewAfterSaleDto,
} from "./dto/after-sale.dto";
import {
  AfterSaleHandlerType,
  AfterSaleStatus,
  AfterSaleType,
  ArbitrationDecision,
  HandlerDecision,
  OrderAfterSale,
} from "./entities/order-after-sale.entity";
import { OrderAfterSaleItem } from "./entities/order-after-sale-item.entity";
import { OrderAfterSaleLog } from "./entities/order-after-sale-log.entity";
import { Order, OrderStatus, OrderType } from "./entities/order.entity";

describe("AfterSaleService", () => {
  let order: Order;
  let afterSale: OrderAfterSale | null;
  let items: OrderAfterSaleItem[];
  let manager: any;
  let service: AfterSaleService;
  let afterSaleRepository: any;
  const paymentService = { createShopAfterSaleRefund: jest.fn() };
  const shopService = { finalizeAfterSaleRefund: jest.fn() };
  const notificationSender = { send: jest.fn() };

  beforeEach(() => {
    jest.clearAllMocks();
    order = {
      id: 41,
      orderNo: "ORD41",
      userId: 51,
      sellerId: null,
      orderType: OrderType.NORMAL,
      status: OrderStatus.PAID,
      totalAmount: 32,
      refundedAmount: 0,
      autoConfirmAt: null,
      items: [
        {
          lineKey: "line-1",
          productId: 101,
          productName: "多数量商品",
          quantity: 3,
          price: 10,
          discountAmount: 3,
          paidAmount: 27,
        },
        {
          lineKey: "line-2",
          productId: 102,
          productName: "单数量商品",
          quantity: 1,
          price: 5,
          discountAmount: 0,
          paidAmount: 5,
        },
      ],
    } as Order;
    afterSale = null;
    items = [];

    manager = {
      createQueryBuilder: jest.fn((entity: any) => ({
        where: jest.fn().mockReturnThis(),
        setLock: jest.fn().mockReturnThis(),
        getOne: jest.fn(async () =>
          entity === OrderAfterSale ? afterSale : order,
        ),
      })),
      findOne: jest.fn().mockResolvedValue(null),
      find: jest.fn(async (entity: any) => {
        if (entity === OrderAfterSaleItem) return items;
        if (entity === OrderAfterSale) return [];
        return [];
      }),
      create: jest.fn((entity: any, value: any) => {
        if (entity === OrderAfterSale) {
          afterSale = {
            id: 71,
            createdAt: new Date(),
            ...value,
          } as OrderAfterSale;
          return afterSale;
        }
        if (entity === OrderAfterSaleItem) {
          const item = {
            id: items.length + 1,
            createdAt: new Date(),
            updatedAt: new Date(),
            ...value,
          } as OrderAfterSaleItem;
          items.push(item);
          return item;
        }
        return value;
      }),
      save: jest.fn(async (entity: any, value?: any) => value ?? entity),
    };
    afterSaleRepository = {
      findOne: jest.fn(async () =>
        afterSale ? { ...afterSale, order, items } : null,
      ),
      findOneBy: jest.fn(async () => afterSale),
      findOneByOrFail: jest.fn(async () => afterSale),
      update: jest.fn(),
      find: jest.fn().mockResolvedValue([]),
      createQueryBuilder: jest.fn(),
    };
    const itemRepository = {};
    const logRepository = { find: jest.fn().mockResolvedValue([]) };
    const configRepository = { findOne: jest.fn().mockResolvedValue(null) };
    const dataSource = {
      getRepository: jest.fn(() => ({ find: jest.fn().mockResolvedValue([]) })),
      transaction: jest.fn(async (callback) => callback(manager)),
    } as unknown as DataSource;
    paymentService.createShopAfterSaleRefund.mockResolvedValue({
      refundId: 81,
      refundNo: "ASREF71",
    });

    service = new AfterSaleService(
      afterSaleRepository,
      itemRepository as any,
      logRepository as any,
      configRepository as any,
      dataSource,
      paymentService as any,
      shopService as any,
      notificationSender as any,
    );
  });

  it("allows platform processing DTOs without a reason", async () => {
    const reviewDto = plainToInstance(AdminReviewAfterSaleDto, {
      decision: AdminAfterSaleDecision.REJECT,
    });
    const arbitrationDto = plainToInstance(AdminArbitrateAfterSaleDto, {
      decision: ArbitrationDecision.SUPPORT_SELLER,
    });

    await expect(validate(reviewDto)).resolves.toHaveLength(0);
    await expect(validate(arbitrationDto)).resolves.toHaveLength(0);
  });

  it("calculates a normal-order request from selected lines and quantities", async () => {
    const result = await service.create(41, 51, {
      afterSaleType: AfterSaleType.REFUND_ONLY,
      items: [{ lineKey: "line-1", quantity: 2 }],
      reasonCode: "damaged",
      description: " 包装破损 ",
      evidenceUrls: ["/uploads/evidence.jpg"],
    });

    expect(result.status).toBe(AfterSaleStatus.PENDING_HANDLER);
    expect(result.handlerType).toBe(AfterSaleHandlerType.PLATFORM);
    expect(result.requestedAmount).toBe(18);
    expect(result.items).toEqual([
      expect.objectContaining({
        lineKey: "line-1",
        requestedQuantity: 2,
        paidAmount: 18,
        discountAmount: 2,
      }),
    ]);
    expect(manager.save).toHaveBeenCalledWith(
      OrderAfterSaleLog,
      expect.objectContaining({ afterSaleId: 71, action: "create" }),
    );
  });

  it("rejects duplicate lines and quantities above the remaining quantity", async () => {
    await expect(
      service.create(41, 51, {
        afterSaleType: AfterSaleType.REFUND_ONLY,
        items: [
          { lineKey: "line-1", quantity: 1 },
          { lineKey: "line-1", quantity: 1 },
        ],
        reasonCode: "damaged",
      }),
    ).rejects.toThrow("售后商品行不能重复");

    await expect(
      service.create(41, 51, {
        afterSaleType: AfterSaleType.REFUND_ONLY,
        items: [{ lineKey: "line-1", quantity: 4 }],
        reasonCode: "damaged",
      }),
    ).rejects.toThrow("可售后数量不足");
  });

  it("supports partial admin approval and refunds only the approved amount", async () => {
    await service.create(41, 51, {
      afterSaleType: AfterSaleType.REFUND_ONLY,
      items: [{ lineKey: "line-1", quantity: 2 }],
      reasonCode: "damaged",
    });

    const result = await service.adminReview(71, 91, {
      decision: AdminAfterSaleDecision.APPROVE,
      afterSaleType: AfterSaleType.REFUND_ONLY,
      approvedItems: [{ lineKey: "line-1", quantity: 1 }],
      reason: "同意退一件",
    });

    expect(paymentService.createShopAfterSaleRefund).toHaveBeenCalledWith(
      71,
      91,
      "平台同意商城售后退款",
    );
    expect(shopService.finalizeAfterSaleRefund).toHaveBeenCalledWith(
      41,
      expect.arrayContaining([
        expect.objectContaining({ approvedQuantity: 1, approvedAmount: 9 }),
      ]),
      manager,
      expect.any(String),
      expect.any(Date),
    );
    expect(result.status).toBe(AfterSaleStatus.REFUNDED);
    expect(result.approvedAmount).toBe(9);
  });

  it("closes a rejected platform request when the processing reason is omitted", async () => {
    await service.create(41, 51, {
      afterSaleType: AfterSaleType.REFUND_ONLY,
      items: [{ lineKey: "line-2", quantity: 1 }],
      reasonCode: "other",
    });

    const result = await service.adminReview(71, 91, {
      decision: AdminAfterSaleDecision.REJECT,
    });

    expect(result.status).toBe(AfterSaleStatus.CLOSED);
    expect(result.handlerReason).toBeNull();
    expect(result.availableActions).not.toContain("request_arbitration");
    expect(paymentService.createShopAfterSaleRefund).not.toHaveBeenCalled();
  });

  it("enforces the configured completed-order application deadline", async () => {
    order.status = OrderStatus.COMPLETED;
    order.completedAt = new Date(Date.now() - 8 * 24 * 60 * 60 * 1000);
    order.afterSaleDeadlineAt = new Date(Date.now() - 24 * 60 * 60 * 1000);

    await expect(
      service.create(41, 51, {
        afterSaleType: AfterSaleType.REFUND_ONLY,
        items: [{ lineKey: "line-2", quantity: 1 }],
        reasonCode: "other",
      }),
    ).rejects.toThrow("订单已超过售后申请期限");
  });

  it("keeps the second-hand arbitration path when the processing reason is omitted", async () => {
    order.orderType = OrderType.SECOND_HAND;
    order.sellerId = 61;
    afterSale = {
      id: 71,
      orderId: 41,
      orderType: OrderType.SECOND_HAND,
      handlerType: AfterSaleHandlerType.SELLER,
      buyerId: 51,
      sellerId: 61,
      status: AfterSaleStatus.HANDLER_REJECTED,
      arbitrationDeadlineAt: new Date(Date.now() + 60 * 60 * 1000),
      createdAt: new Date(),
      items: [],
    } as OrderAfterSale;

    await service.applyArbitration(71, 51, {
      reason: "请求平台核实",
      evidenceUrls: [],
    });
    const result = await service.arbitrate(71, 91, {
      decision: ArbitrationDecision.SUPPORT_SELLER,
    });

    expect(result.status).toBe(AfterSaleStatus.CLOSED);
    expect(result.arbitrationRemark).toBeNull();
    expect(paymentService.createShopAfterSaleRefund).not.toHaveBeenCalled();
  });

  it("approves the requested amount when arbitration supports the buyer", async () => {
    order.orderType = OrderType.SECOND_HAND;
    order.sellerId = 61;
    items = [
      {
        id: 1,
        afterSaleId: 71,
        lineKey: "line-1",
        productId: 101,
        productName: "多数量商品",
        requestedQuantity: 2,
        approvedQuantity: 0,
        refundedQuantity: 0,
        paidAmount: 18,
        approvedAmount: 0,
        refundedAmount: 0,
        restockQuantity: 0,
        inventoryRestoredQuantity: 0,
      } as OrderAfterSaleItem,
    ];
    afterSale = {
      id: 71,
      orderId: 41,
      orderType: OrderType.SECOND_HAND,
      handlerType: AfterSaleHandlerType.SELLER,
      afterSaleType: AfterSaleType.REFUND_ONLY,
      buyerId: 51,
      sellerId: 61,
      status: AfterSaleStatus.HANDLER_REJECTED,
      requestedAmount: 18,
      approvedAmount: null,
      arbitrationDeadlineAt: new Date(Date.now() + 60 * 60 * 1000),
      createdAt: new Date(),
      items,
    } as OrderAfterSale;

    await service.applyArbitration(71, 51, { reason: "请求平台核实" });
    const result = await service.arbitrate(71, 91, {
      decision: ArbitrationDecision.SUPPORT_BUYER,
      remark: "支持退款",
    });

    expect(result.status).toBe(AfterSaleStatus.REFUNDED);
    expect(result.approvedAmount).toBe(18);
    expect(items[0]).toEqual(
      expect.objectContaining({ approvedQuantity: 2, approvedAmount: 18 }),
    );
    expect(paymentService.createShopAfterSaleRefund).toHaveBeenCalledWith(
      71,
      91,
      "平台仲裁支持买家",
    );
  });

  it("keeps platform return confirmation available after an empty-tracking timeout", async () => {
    afterSale = {
      id: 71,
      orderId: 41,
      orderType: OrderType.NORMAL,
      handlerType: AfterSaleHandlerType.PLATFORM,
      afterSaleType: AfterSaleType.RETURN_REFUND,
      buyerId: 51,
      sellerId: null,
      status: AfterSaleStatus.HANDLER_TIMEOUT,
      handlerDecision: HandlerDecision.APPROVED,
      returnRequired: true,
      returnTrackingNumber: null,
      returnEvidenceUrls: [],
      createdAt: new Date(),
      items: [],
    } as OrderAfterSale;

    const result = await service.findOne(71, 91, "SUPER_ADMIN");

    expect(result.availableActions).toContain("confirm_return");
    expect(result.availableActions).not.toContain("review_after_sale");
    await expect(service.cancel(71, 51)).rejects.toThrow(
      "买家已提交退货，不能取消售后",
    );
  });

  it("marks a platform handling timeout without auto-refunding or closing", async () => {
    afterSale = {
      id: 71,
      orderId: 41,
      orderType: OrderType.NORMAL,
      handlerType: AfterSaleHandlerType.PLATFORM,
      buyerId: 51,
      sellerId: null,
      status: AfterSaleStatus.PENDING_HANDLER,
      handlerDeadlineAt: new Date(Date.now() - 1000),
      createdAt: new Date(),
      items: [],
    } as OrderAfterSale;
    afterSaleRepository.find.mockResolvedValue([{ id: 71 }]);

    await expect(service.processTimeouts()).resolves.toEqual({
      total: 1,
      processed: 1,
    });
    expect(afterSale.status).toBe(AfterSaleStatus.HANDLER_TIMEOUT);
    expect(paymentService.createShopAfterSaleRefund).not.toHaveBeenCalled();
  });
});
