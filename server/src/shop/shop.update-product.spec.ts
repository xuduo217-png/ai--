import { DataSource } from "typeorm";

jest.mock("uuid", () => ({
  v4: () => "MOCK-ORDER-UUID",
}));

import { ShopService } from "./shop.service";
import { Product, PublishSource } from "./entities/product.entity";
import { ProductSku, SkuStatus } from "./entities/product-sku.entity";

describe("ShopService.updateProduct", () => {
  const product = {
    id: 101,
    name: "单规格商品",
    hasSku: false,
    publishSource: PublishSource.ADMIN,
  } as Product;

  const existingSku = {
    id: 201,
    productId: 101,
    name: "默认规格",
    specs: {},
    price: 99,
    stock: 5,
    status: SkuStatus.ACTIVE,
    skuCode: null,
  } as ProductSku;

  const manager = {
    update: jest.fn(async () => ({ affected: 1 })),
    find: jest.fn(async (entity: any, options: any) => {
      if (entity === ProductSku && options?.where?.productId === product.id) {
        return [existingSku];
      }
      return [];
    }),
    findOne: jest.fn(async () => null),
    insert: jest.fn(async () => ({ identifiers: [{ id: 999 }] })),
    delete: jest.fn(async () => ({ affected: 1 })),
    createQueryBuilder: jest.fn(() => ({
      from: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      getCount: jest.fn(async () => 0),
    })),
  };

  const queryRunner = {
    connect: jest.fn(),
    startTransaction: jest.fn(),
    commitTransaction: jest.fn(),
    rollbackTransaction: jest.fn(),
    release: jest.fn(),
    manager,
  };

  const service = new ShopService(
    {
      findOne: jest.fn(async ({ where }: any) => {
        if (where?.id === product.id) {
          return product;
        }
        return null;
      }),
    } as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    {
      createQueryRunner: jest.fn(() => queryRunner),
    } as unknown as DataSource,
    {} as any,
    {} as any,
    {
      get: jest.fn(() => "test"),
    } as any,
    { getPlatformFeeRate: jest.fn(async () => 5) } as any,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    existingSku.price = 99;
    existingSku.stock = 5;
  });

  it("reuses the existing default sku when editing a single-spec product without an incoming sku id", async () => {
    jest.spyOn(service, "findOneProduct").mockResolvedValue({
      ...product,
      skus: [existingSku],
    } as Product);

    await service.updateProduct(
      product.id,
      {
        name: "更新后的单规格商品",
        hasSku: false,
        skus: [
          {
            name: "默认规格",
            specs: {},
            price: 128,
            stock: 9,
            status: SkuStatus.ACTIVE,
          } as any,
        ],
      },
      1,
      "SUPER_ADMIN",
    );

    expect(manager.insert).not.toHaveBeenCalled();
    expect(manager.update).toHaveBeenCalledWith(
      ProductSku,
      existingSku.id,
      expect.objectContaining({
        id: existingSku.id,
        name: "默认规格",
        price: 128,
        stock: 9,
        productId: product.id,
      }),
    );
  });
});
