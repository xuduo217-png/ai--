import { DataSource } from "typeorm";

jest.mock("uuid", () => ({
  v4: () => "MOCK-ORDER-UUID",
}));

import { ShopService } from "./shop.service";
import { Product, PublishSource } from "./entities/product.entity";
import { ProductSku, SkuStatus } from "./entities/product-sku.entity";
import { OrderStatus, SettlementStatus } from "./entities/order.entity";
import { PendingProductStatus } from "./entities/product-pending.entity";
import { PaymentChannel } from "../payment/entities/payment.entity";

describe("ShopService user published product stock sync", () => {
  const product = {
    id: 71,
    name: "用户发布商品",
    price: 88,
    stock: 1,
    hasSku: false,
    isActive: true,
    images: ["/a.jpg"],
    image: "/a.jpg",
    publishSource: PublishSource.USER,
    publishedBy: 9,
    pendingProductId: 601,
  } as Product;

  const sku = {
    id: 81,
    productId: 71,
    name: "默认规格",
    price: 88,
    stock: 1,
    status: SkuStatus.ACTIVE,
  } as ProductSku;

  const savedOrders: any[] = [];
  const updates: any[] = [];

  const createQueryBuilder = () => {
    let entity: any;
    let whereParams: Record<string, any> = {};
    return {
      update(target: any) {
        entity = target;
        return this;
      },
      set() {
        return this;
      },
      where(_sql: string, params: Record<string, any>) {
        whereParams = params;
        return this;
      },
      async execute() {
        if (entity === ProductSku) {
          if (sku.stock < whereParams.quantity) {
            return { affected: 0 };
          }
          sku.stock -= whereParams.quantity;
          return { affected: 1 };
        }
        if (entity === Product) {
          if (product.stock < whereParams.quantity) {
            return { affected: 0 };
          }
          product.stock -= whereParams.quantity;
          return { affected: 1 };
        }
        return { affected: 0 };
      },
    };
  };

  const manager = {
    findOne: jest.fn(async (entity: any, options: any) => {
      if (entity === Product && options?.where?.id === product.id) {
        return product;
      }
      if (entity === ProductSku && options?.where?.id === sku.id) {
        return sku;
      }
      if (entity?.name === "Order") {
        return savedOrders[0] ?? null;
      }
      return null;
    }),
    find: jest.fn(async (entity: any, options: any) => {
      if (entity === ProductSku && options?.where?.productId === product.id) {
        return [sku];
      }
      return [];
    }),
    create: jest.fn((_entity: any, payload: Record<string, any>) => payload),
    save: jest.fn(async (_entity: any, payload?: Record<string, any>) => {
      const entityToSave = payload ?? _entity;
      if (entityToSave.orderNo) {
        const order = {
          id: 901,
          status: OrderStatus.PENDING,
          settlementStatus: SettlementStatus.PENDING,
          ...entityToSave,
        };
        savedOrders[0] = order;
        return order;
      }
      return entityToSave;
    }),
    update: jest.fn(
      async (entity: any, idOrCriteria: any, payload: Record<string, any>) => {
        updates.push({ entity, idOrCriteria, payload });
        if (entity === Product && idOrCriteria === product.id) {
          Object.assign(product, payload);
        }
        return { affected: 1 };
      },
    ),
    createQueryBuilder,
  };

  const queryRunner = {
    connect: jest.fn(),
    startTransaction: jest.fn(),
    commitTransaction: jest.fn(),
    rollbackTransaction: jest.fn(),
    release: jest.fn(),
    manager,
  };

  const dataSource = {
    createQueryRunner: jest.fn(() => queryRunner),
    transaction: jest.fn(
      async (callback: (txManager: any) => Promise<void>) => {
        await callback({
          update: jest.fn(),
          findOne: jest.fn(async () => savedOrders[0]),
        });
      },
    ),
  } as unknown as DataSource;

  const paymentService = {
    createPayment: jest.fn(async () => ({ paymentNo: "PAY_1" })),
  };

  const service = new ShopService(
    {} as any,
    {} as any,
    { findOne: jest.fn(), update: jest.fn() } as any,
    {} as any,
    {} as any,
    {} as any,
    paymentService as any,
    dataSource,
    {
      send: jest.fn(),
      orderCreated: jest.fn(),
      orderPaid: jest.fn(),
    } as any,
    {} as any,
    { get: jest.fn(() => "test") } as any,
    { getPlatformFeeRate: jest.fn(async () => 5) } as any,
  );

  beforeEach(() => {
    product.stock = 1;
    product.isActive = true;
    sku.stock = 1;
    savedOrders.length = 0;
    updates.length = 0;
    jest.clearAllMocks();
  });

  it("decrements product.stock together with the compatibility sku for single-spec user products", async () => {
    await service.createOrder(
      {
        items: [{ productId: 71, skuId: 81, quantity: 1 }],
        shippingAddress: "测试地址",
        receiverName: "测试用户",
        receiverPhone: "13800138000",
        paymentChannel: PaymentChannel.ALIPAY,
      },
      10,
    );

    expect(sku.stock).toBe(0);
    expect(product.stock).toBe(0);
    expect(updates).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          entity: Product,
          idOrCriteria: 71,
          payload: expect.objectContaining({
            isActive: false,
          }),
        }),
        expect.objectContaining({
          entity: "products_pending",
          idOrCriteria: { id: 601 },
          payload: { status: PendingProductStatus.SOLD },
        }),
      ]),
    );
  });
});
