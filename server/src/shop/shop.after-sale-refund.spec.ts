import { ShopService } from "./shop.service";
import { OrderAfterSaleItem } from "./entities/order-after-sale-item.entity";
import { Order, OrderStatus, OrderType } from "./entities/order.entity";
import { Product } from "./entities/product.entity";

describe("ShopService.finalizeAfterSaleRefund", () => {
  const createFixture = () => {
    const service = Object.create(ShopService.prototype) as ShopService;
    const couponService = { releaseCouponForOrder: jest.fn() };
    (service as any).couponService = couponService;
    const order = {
      id: 1,
      orderType: OrderType.NORMAL,
      status: OrderStatus.PAID,
      totalAmount: 20,
      refundedAmount: 0,
    } as Order;
    const product = null;
    const manager = {
      createQueryBuilder: jest.fn(() => ({
        where: jest.fn().mockReturnThis(),
        setLock: jest.fn().mockReturnThis(),
        getOne: jest.fn().mockResolvedValue(order),
      })),
      increment: jest.fn(),
      findOne: jest.fn(async (entity: any) =>
        entity === Product ? product : null,
      ),
      find: jest.fn().mockResolvedValue([]),
      save: jest.fn(async (value: any) => value),
      update: jest.fn(),
    };
    return { service, couponService, order, manager };
  };

  it("keeps a partially refunded order active and restores only approved stock", async () => {
    const fixture = createFixture();
    const initialAutoConfirmAt = Date.now() + 60_000;
    fixture.order.autoConfirmAt = new Date(initialAutoConfirmAt);
    const item = {
      productId: 10,
      approvedQuantity: 1,
      approvedAmount: 8,
      refundedQuantity: 0,
      refundedAmount: 0,
      restockQuantity: 1,
      inventoryRestoredQuantity: 0,
    } as OrderAfterSaleItem;

    await fixture.service.finalizeAfterSaleRefund(
      1,
      [item],
      fixture.manager,
      "全额退款",
      new Date(Date.now() - 5_000),
    );

    expect(fixture.order.refundedAmount).toBe(8);
    expect(fixture.order.status).toBe(OrderStatus.PAID);
    expect(fixture.manager.increment).toHaveBeenCalledWith(
      Product,
      { id: 10 },
      "stock",
      1,
    );
    expect(item.inventoryRestoredQuantity).toBe(1);
    expect(fixture.order.autoConfirmAt.getTime()).toBeGreaterThanOrEqual(
      initialAutoConfirmAt + 5_000,
    );
    expect(fixture.couponService.releaseCouponForOrder).not.toHaveBeenCalled();
  });

  it("is idempotent and cancels only when cumulative refunds reach the order total", async () => {
    const fixture = createFixture();
    fixture.order.refundedAmount = 12;
    const item = {
      productId: 10,
      approvedQuantity: 1,
      approvedAmount: 8,
      refundedQuantity: 0,
      refundedAmount: 0,
      restockQuantity: 0,
      inventoryRestoredQuantity: 0,
    } as OrderAfterSaleItem;

    await fixture.service.finalizeAfterSaleRefund(
      1,
      [item],
      fixture.manager,
      "累计全额退款",
    );
    await fixture.service.finalizeAfterSaleRefund(
      1,
      [item],
      fixture.manager,
      "重复执行",
    );

    expect(fixture.order.refundedAmount).toBe(20);
    expect(fixture.order.status).toBe(OrderStatus.CANCELLED);
    expect(fixture.couponService.releaseCouponForOrder).toHaveBeenCalledTimes(
      1,
    );
    expect(fixture.manager.increment).not.toHaveBeenCalled();
  });
});
