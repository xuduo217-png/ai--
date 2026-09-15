import { Repository } from "typeorm";

import { SecondHandProductService } from "./second-hand-product.service";
import {
  ProductPending,
  PendingProductStatus,
  ProductCondition,
} from "./entities/product-pending.entity";
import { Product, PublishSource } from "./entities/product.entity";
import { Category } from "./entities/category.entity";
import { ProductSku, SkuStatus } from "./entities/product-sku.entity";
import { NotificationsService } from "../notifications/notifications.service";
import { ActionType } from "../notifications/entities/notification.entity";

describe("SecondHandProductService", () => {
  let service: SecondHandProductService;

  const productPendingRepository = {
    create: jest.fn(),
    save: jest.fn(),
    findOne: jest.fn(),
    update: jest.fn(),
    createQueryBuilder: jest.fn(),
  } as unknown as jest.Mocked<Partial<Repository<ProductPending>>>;

  const productRepository = {
    findOne: jest.fn(),
    save: jest.fn(),
    createQueryBuilder: jest.fn(),
  } as unknown as jest.Mocked<Partial<Repository<Product>>>;

  const categoryRepository = {
    find: jest.fn(),
  } as unknown as jest.Mocked<Partial<Repository<Category>>>;

  const productSkuRepository = {
    find: jest.fn(),
  } as unknown as jest.Mocked<Partial<Repository<ProductSku>>>;

  const notificationsService = {
    create: jest.fn(),
  } as unknown as jest.Mocked<Partial<NotificationsService>>;

  const createTransactionManager = () => ({
    create: jest.fn((EntityClass, payload) =>
      Object.assign(new EntityClass(), payload),
    ),
    findOne: jest.fn(),
    find: jest.fn(),
    save: jest.fn(async (entity) => {
      if (entity instanceof Product && !entity.id) {
        entity.id = 101;
      }
      if (entity instanceof ProductSku && !entity.id) {
        entity.id = 201;
      }
      return entity;
    }),
    update: jest.fn(),
  });

  let transactionManager = createTransactionManager();
  const dataSource = {
    transaction: jest.fn(async (callback) => callback(transactionManager)),
  };

  beforeEach(() => {
    jest.clearAllMocks();
    transactionManager = createTransactionManager();
    (dataSource.transaction as jest.Mock).mockImplementation(async (callback) =>
      callback(transactionManager),
    );

    service = new SecondHandProductService(
      productPendingRepository as Repository<ProductPending>,
      productRepository as Repository<Product>,
      categoryRepository as Repository<Category>,
      productSkuRepository as Repository<ProductSku>,
      dataSource as any,
      notificationsService as unknown as NotificationsService,
    );
  });

  it("defaults pending product stock to 1 when client omits stock", async () => {
    (productPendingRepository.create as jest.Mock).mockImplementation(
      (payload) => payload,
    );
    (productPendingRepository.save as jest.Mock).mockImplementation(
      async (payload) => payload,
    );

    const result = await service.createPendingProduct(7, {
      title: "二手猫窝",
      description: "九成新，几乎没用过",
      price: 88,
      images: ["/uploads/cat-bed.png"],
      categoryId: 12,
      condition: ProductCondition.NEW,
      negotiable: false,
      shippingFee: 0,
    } as any);

    expect(productPendingRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 7,
        stock: 1,
        status: PendingProductStatus.UNDER_REVIEW,
      }),
    );
    expect(result).toEqual(
      expect.objectContaining({
        stock: 1,
      }),
    );
  });

  it("writes pending stock into new formal product and default sku when review passes", async () => {
    const pendingProduct = {
      id: 11,
      userId: 7,
      title: "二手猫窝",
      description: "九成新，几乎没用过",
      price: 88,
      stock: 6,
      images: ["/uploads/cat-bed.png"],
      categoryId: 12,
      condition: ProductCondition.NEW,
      negotiable: false,
      shippingFee: 0,
      status: PendingProductStatus.UNDER_REVIEW,
      rejectReason: null,
    } as unknown as ProductPending;

    (productPendingRepository.findOne as jest.Mock).mockResolvedValue(
      pendingProduct,
    );
    transactionManager.find.mockResolvedValue([]);

    await service.reviewProduct(11, { approved: true }, 99);

    expect(transactionManager.save).toHaveBeenCalledWith(
      expect.objectContaining({
        stock: 6,
        publishSource: PublishSource.USER,
      }),
    );
    expect(transactionManager.save).toHaveBeenCalledWith(
      expect.objectContaining({
        name: "默认规格",
        stock: 6,
        status: SkuStatus.ACTIVE,
      }),
    );
    expect(notificationsService.create).toHaveBeenCalledWith(
      expect.objectContaining({
        actionType: ActionType.PAGE,
        actionData: {
          path: "ProductDetail",
          params: { id: 101 },
        },
      }),
    );
  });

  it("routes rejected review notifications to the published-products list", async () => {
    const pendingProduct = {
      id: 12,
      userId: 7,
      title: "二手猫包",
      status: PendingProductStatus.UNDER_REVIEW,
      rejectReason: null,
    } as unknown as ProductPending;
    (productPendingRepository.findOne as jest.Mock).mockResolvedValue(
      pendingProduct,
    );

    await service.reviewProduct(
      12,
      { approved: false, rejectReason: "图片不清晰" },
      99,
    );

    expect(notificationsService.create).toHaveBeenCalledWith(
      expect.objectContaining({
        actionType: ActionType.PAGE,
        actionData: { path: "MyPublishedProducts" },
      }),
    );
  });

  it("overrides stale sku stock with pending stock when reviewing edited products", async () => {
    const pendingProduct = {
      id: 15,
      productId: 101,
      userId: 7,
      title: "二手猫爬架",
      description: "重新编辑库存",
      price: 188,
      stock: 9,
      images: ["/uploads/cat-tree.png"],
      categoryId: 12,
      condition: ProductCondition.NINETY_PERCENT,
      negotiable: false,
      shippingFee: 0,
      status: PendingProductStatus.UNDER_REVIEW,
      rejectReason: null,
    } as unknown as ProductPending;
    const formalProduct = Object.assign(new Product(), {
      id: 101,
      name: "旧标题",
      stock: 2,
      hasSku: false,
      publishSource: PublishSource.USER,
    });
    const existingSku = Object.assign(new ProductSku(), {
      id: 201,
      productId: 101,
      name: "默认规格",
      stock: 2,
      status: SkuStatus.ACTIVE,
      image: "/uploads/old.png",
      price: 188,
    });

    (productPendingRepository.findOne as jest.Mock).mockResolvedValue(
      pendingProduct,
    );
    transactionManager.findOne.mockResolvedValue(formalProduct);
    transactionManager.find.mockResolvedValue([existingSku]);

    await service.reviewProduct(15, { approved: true }, 99);

    expect(transactionManager.save).toHaveBeenCalledWith(
      expect.objectContaining({
        id: 201,
        stock: 9,
        status: SkuStatus.ACTIVE,
      }),
    );
    expect(transactionManager.save).toHaveBeenCalledWith(
      expect.objectContaining({
        id: 101,
        stock: 9,
      }),
    );
  });
});
