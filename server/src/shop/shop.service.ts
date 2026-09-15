import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
  Inject,
  Optional,
} from "@nestjs/common";
import { randomUUID } from "crypto";
import { InjectRepository } from "@nestjs/typeorm";
import {
  Repository,
  DataSource,
  QueryRunner,
  LessThan,
  LessThanOrEqual,
  In,
  Like,
} from "typeorm";
import { ConfigService } from "@nestjs/config";
import { Product, PublishSource } from "./entities/product.entity";
import { ProductSku, SkuStatus } from "./entities/product-sku.entity";
import { Category, CategoryStatus } from "./entities/category.entity";
import {
  Order,
  OrderStatus,
  OrderItem,
  OrderType,
  SettlementStatus,
} from "./entities/order.entity";
import { Coupon } from "./entities/coupon.entity";
import { UserCoupon } from "./entities/user-coupon.entity";
import { CreateProductDto } from "./dto/create-product.dto";
import { UpdateProductDto } from "./dto/update-product.dto";
import { CreateOrderDto, OrderItemDto } from "./dto/create-order.dto";
import { UpdateOrderStatusDto } from "./dto/update-order-status.dto";
import { UpdateShippingDto } from "./dto/update-shipping.dto";
import { QueryProductDto } from "./dto/query-product.dto";
import { QueryOrderDto } from "./dto/query-order.dto";
import { BatchGetProductsDto } from "./dto/batch-get-products.dto";
import { PreviewOrderDto } from "./dto/preview-order.dto";
import {
  CreateProductSkuDto,
  CreateProductSkuBatchDto,
} from "./dto/create-product-sku.dto";
import { UpdateProductSkuDto } from "./dto/update-product-sku.dto";
import { PaginatedResult } from "../common/dto/pagination.dto";
import { PaymentService } from "../payment/payment.service";
import {
  PaymentChannel,
  BusinessType,
  PaymentMethod,
} from "../payment/entities/payment.entity";
import { Payment, PaymentStatus } from "../payment/entities/payment.entity";
import {
  createBusinessException,
  ErrorCode,
} from "../common/constants/error-codes";
import { NotificationSenderService } from "../notifications/notification-sender.service";
import { LogisticsService } from "../logistics/logistics.service";
import { User } from "../users/entities/user.entity";
import { SystemConfig } from "../system-configs/entities/system-config.entity";
import {
  WalletTransaction,
  WalletTransactionType,
  WalletTransactionStatus,
  RelatedType,
} from "./entities/wallet-transaction.entity";
import {
  ProductPending,
  PendingProductStatus,
} from "./entities/product-pending.entity";
import {
  add,
  equals,
  subtract,
  toCents,
  toNumber,
  toYuan,
} from "../common/utils/currency.util";
import { serializeShopResponse } from "./shop.serialization";
import { PlatformFeeService } from "./platform-fee.service";
import { ModerationService } from "../moderation/moderation.service";
import {
  ACTIVE_AFTER_SALE_STATUSES,
  AfterSaleHandlerType,
  AfterSaleStatus,
  OrderAfterSale,
} from "./entities/order-after-sale.entity";
import { OrderAfterSaleItem } from "./entities/order-after-sale-item.entity";
import {
  CharityDonationSource,
  CharityRecord,
} from "../charity/entities/charity-record.entity";
import {
  Charity,
  CharityStatus,
  ParticipantType,
} from "../charity/entities/charity.entity";

export interface MallHomepageBanner {
  id: string;
  imageUrl: string;
  actionType: MallHomepageBannerActionType;
  productId?: number;
  sortOrder: number;
}

export enum MallHomepageBannerActionType {
  NONE = "none",
  PRODUCT = "product",
}

const MALL_HOME_HOT_PRODUCTS_CONFIG_KEY = "mall_home_hot_products";
const MALL_HOME_BANNERS_CONFIG_KEY = "mall_home_banners";
const MALL_HOME_HOT_PRODUCTS_CONFIG_DESCRIPTION = "商城首页热门商品配置";
const MALL_HOME_BANNERS_CONFIG_DESCRIPTION = "商城首页 Banner 配置";

@Injectable()
export class ShopService {
  private readonly logger = new Logger(ShopService.name);
  private readonly isDevelopment: boolean;

  constructor(
    @InjectRepository(Product)
    private productRepository: Repository<Product>,
    @InjectRepository(ProductSku)
    private productSkuRepository: Repository<ProductSku>,
    @InjectRepository(Order)
    private orderRepository: Repository<Order>,
    @InjectRepository(Category)
    private categoryRepository: Repository<Category>,
    @InjectRepository(SystemConfig)
    private systemConfigRepository: Repository<SystemConfig>,
    @InjectRepository(WalletTransaction)
    private walletTransactionRepository: Repository<WalletTransaction>,
    private paymentService: PaymentService,
    private dataSource: DataSource,
    private readonly notificationSender: NotificationSenderService,
    private readonly logisticsService: LogisticsService,
    private readonly configService: ConfigService,
    private readonly platformFeeService: PlatformFeeService,
    @Optional()
    private readonly moderationService?: ModerationService,
    @Optional()
    @InjectRepository(OrderAfterSale)
    private afterSaleRepository?: Repository<OrderAfterSale>,
    @Optional()
    @InjectRepository(CharityRecord)
    private charityRecordRepository?: Repository<CharityRecord>,
    @Optional()
    @InjectRepository(Charity)
    private charityRepository?: Repository<Charity>,
  ) {
    // 虚拟支付仅允许在开发环境使用
    this.isDevelopment =
      this.configService.get<string>("NODE_ENV") !== "production";
  }

  // 注入CouponService（循环依赖，使用ModuleRef注入）
  private couponService: any;

  setCouponService(couponService: any) {
    this.couponService = couponService;
  }

  private async applyBlockedPublishersFilter(
    queryBuilder: any,
    currentUserId?: number,
  ) {
    const blockedUserIds =
      await this.moderationService?.getBlockedUserIds(currentUserId);

    if (blockedUserIds?.length) {
      queryBuilder.andWhere(
        "(product.publishedBy IS NULL OR product.publishedBy NOT IN (:...blockedUserIds))",
        { blockedUserIds },
      );
    }
  }

  private normalizeMallHotProductIds(
    configValue?: Record<string, any> | null,
  ): number[] {
    const rawProductIds = Array.isArray(configValue?.productIds)
      ? configValue.productIds
      : [];

    return Array.from(
      new Set(
        rawProductIds
          .map((id) => Number(id))
          .filter((id) => Number.isInteger(id) && id > 0),
      ),
    );
  }

  private normalizeMallHomepageBanners(
    configValue?: Record<string, any> | null,
  ): MallHomepageBanner[] {
    const rawBanners = Array.isArray(configValue?.banners)
      ? configValue.banners
      : [];

    const normalizedBanners: Array<MallHomepageBanner | null> = rawBanners.map(
      (banner, index) => {
        const imageUrl =
          typeof banner?.imageUrl === "string" ? banner.imageUrl.trim() : "";

        if (!imageUrl) {
          return null;
        }

        const legacyLink =
          typeof banner?.link === "string" && banner.link.trim()
            ? banner.link.trim()
            : undefined;
        const rawActionType =
          typeof banner?.actionType === "string"
            ? banner.actionType.trim().toLowerCase()
            : "";
        const productIdValue = Number(banner?.productId);
        const explicitProductId =
          Number.isInteger(productIdValue) && productIdValue > 0
            ? productIdValue
            : undefined;
        const inferredProductId =
          explicitProductId ??
          this.extractMallHomepageBannerProductIdFromLegacyLink(legacyLink);
        const actionType =
          (rawActionType === MallHomepageBannerActionType.PRODUCT &&
            inferredProductId) ||
          (!rawActionType && inferredProductId)
            ? MallHomepageBannerActionType.PRODUCT
            : MallHomepageBannerActionType.NONE;
        const sortOrderValue = Number(banner?.sortOrder);
        const sortOrder = Number.isFinite(sortOrderValue)
          ? sortOrderValue
          : index;
        const id =
          typeof banner?.id === "string" && banner.id.trim()
            ? banner.id.trim()
            : `mall-banner-${index + 1}`;

        return {
          id,
          imageUrl,
          actionType,
          productId:
            actionType === MallHomepageBannerActionType.PRODUCT
              ? inferredProductId
              : undefined,
          sortOrder,
        };
      },
    );

    return normalizedBanners
      .filter((banner): banner is MallHomepageBanner => Boolean(banner))
      .sort((left, right) => {
        if (left.sortOrder !== right.sortOrder) {
          return left.sortOrder - right.sortOrder;
        }

        return left.id.localeCompare(right.id);
      });
  }

  private extractMallHomepageBannerProductIdFromLegacyLink(
    link?: string,
  ): number | undefined {
    if (!link) {
      return undefined;
    }

    const productIdMatch = link.match(/(?:product:|\/product\/)(\d+)/i);
    if (!productIdMatch?.[1]) {
      return undefined;
    }

    const productId = Number(productIdMatch[1]);
    return Number.isInteger(productId) && productId > 0 ? productId : undefined;
  }

  private async collectDescendantCategoryIds(
    initialCategoryIds: number[],
  ): Promise<number[]> {
    const normalizedInitialIds = Array.from(
      new Set(
        initialCategoryIds.filter(
          (categoryId) =>
            Number.isInteger(categoryId) && Number(categoryId) > 0,
        ),
      ),
    );

    if (normalizedInitialIds.length === 0) {
      return [];
    }

    const collectedCategoryIds = new Set<number>(normalizedInitialIds);
    let parentIds = normalizedInitialIds;

    while (parentIds.length > 0) {
      const childCategories = await this.categoryRepository.find({
        where: parentIds.map((parentId) => ({ parentId })),
      });

      const nextParentIds: number[] = [];

      childCategories.forEach((category) => {
        if (!collectedCategoryIds.has(category.id)) {
          collectedCategoryIds.add(category.id);
          nextParentIds.push(category.id);
        }
      });

      parentIds = nextParentIds;
    }

    return Array.from(collectedCategoryIds);
  }

  private async resolveCategoryIdsByKeyword(
    keyword: string,
  ): Promise<number[]> {
    const trimmedKeyword = keyword.trim();

    if (!trimmedKeyword) {
      return [];
    }

    const matchedCategories = await this.categoryRepository.find({
      where: {
        name: Like(`%${trimmedKeyword}%`),
      },
    });

    return this.collectDescendantCategoryIds(
      matchedCategories.map((category) => category.id),
    );
  }

  private async resolveCategoryFilterIds(
    categoryId: number,
  ): Promise<number[]> {
    const matchedCategory = await this.categoryRepository.findOne({
      where: { id: categoryId },
    });

    if (!matchedCategory) {
      return [];
    }

    return this.collectDescendantCategoryIds([categoryId]);
  }

  private async getConfiguredMallHotProductIds(): Promise<number[]> {
    const config = await this.systemConfigRepository.findOne({
      where: { configKey: MALL_HOME_HOT_PRODUCTS_CONFIG_KEY },
    });

    return this.normalizeMallHotProductIds(config?.configValue);
  }

  private async getConfiguredMallHotProducts(): Promise<Product[]> {
    const configuredProductIds = await this.getConfiguredMallHotProductIds();

    if (configuredProductIds.length === 0) {
      return [];
    }

    const products = await this.productRepository.find({
      where: {
        id: In(configuredProductIds),
        isActive: true,
      },
      relations: ["skus", "publisher", "categoryRelation"],
    });

    const orderByProductId = new Map(
      configuredProductIds.map((productId, index) => [productId, index]),
    );

    return products.sort((left, right) => {
      return (
        (orderByProductId.get(left.id) ?? Number.MAX_SAFE_INTEGER) -
        (orderByProductId.get(right.id) ?? Number.MAX_SAFE_INTEGER)
      );
    });
  }

  async getMallHomepageHotProductsConfig(): Promise<{ productIds: number[] }> {
    return {
      productIds: await this.getConfiguredMallHotProductIds(),
    };
  }

  async updateMallHomepageHotProductsConfig(
    productIds: number[],
  ): Promise<{ productIds: number[] }> {
    const normalizedProductIds = this.normalizeMallHotProductIds({
      productIds,
    });

    const existingProducts = normalizedProductIds.length
      ? await this.productRepository.find({
          where: {
            id: In(normalizedProductIds),
          },
          select: ["id"],
        })
      : [];

    const existingProductIdSet = new Set(
      existingProducts.map((product) => product.id),
    );
    const persistedProductIds = normalizedProductIds.filter((productId) =>
      existingProductIdSet.has(productId),
    );

    const existingConfig = await this.systemConfigRepository.findOne({
      where: { configKey: MALL_HOME_HOT_PRODUCTS_CONFIG_KEY },
    });

    if (existingConfig) {
      existingConfig.configValue = {
        productIds: persistedProductIds,
      };
      existingConfig.description = MALL_HOME_HOT_PRODUCTS_CONFIG_DESCRIPTION;
      await this.systemConfigRepository.save(existingConfig);
    } else {
      await this.systemConfigRepository.save(
        this.systemConfigRepository.create({
          configKey: MALL_HOME_HOT_PRODUCTS_CONFIG_KEY,
          configValue: {
            productIds: persistedProductIds,
          },
          description: MALL_HOME_HOT_PRODUCTS_CONFIG_DESCRIPTION,
        }),
      );
    }

    return {
      productIds: persistedProductIds,
    };
  }

  async getMallHomepageBanners(): Promise<{ banners: MallHomepageBanner[] }> {
    const config = await this.systemConfigRepository.findOne({
      where: { configKey: MALL_HOME_BANNERS_CONFIG_KEY },
    });

    return {
      banners: this.normalizeMallHomepageBanners(config?.configValue),
    };
  }

  async updateMallHomepageBanners(
    banners: Array<Partial<MallHomepageBanner>>,
  ): Promise<{ banners: MallHomepageBanner[] }> {
    const normalizedBanners = this.normalizeMallHomepageBanners({
      banners,
    });

    const existingConfig = await this.systemConfigRepository.findOne({
      where: { configKey: MALL_HOME_BANNERS_CONFIG_KEY },
    });

    if (existingConfig) {
      existingConfig.configValue = {
        banners: normalizedBanners,
      };
      existingConfig.description = MALL_HOME_BANNERS_CONFIG_DESCRIPTION;
      await this.systemConfigRepository.save(existingConfig);
    } else {
      await this.systemConfigRepository.save(
        this.systemConfigRepository.create({
          configKey: MALL_HOME_BANNERS_CONFIG_KEY,
          configValue: {
            banners: normalizedBanners,
          },
          description: MALL_HOME_BANNERS_CONFIG_DESCRIPTION,
        }),
      );
    }

    return {
      banners: normalizedBanners,
    };
  }

  private async buildOrderPricingContext(
    manager: any,
    orderItems: OrderItemDto[],
    userId: number,
    checkStock: boolean,
  ): Promise<{
    items: OrderItem[];
    totalAmount: number;
    stockErrors: Array<{
      productName: string;
      skuName?: string;
      requested: number;
      available: number;
    }>;
    productIds: number[];
    couponEligibleAmount: number;
    couponEligibleProductIds: number[];
    couponEligibleOrderLines: Array<{ productId: number; amount: number }>;
    containsUserPublishedProducts: boolean;
    orderType: OrderType;
    sellerId: number | null;
  }> {
    const items: OrderItem[] = [];
    let totalAmount = 0;
    const stockErrors: Array<{
      productName: string;
      skuName?: string;
      requested: number;
      available: number;
    }> = [];
    const productIds = new Set<number>();
    const couponEligibleProductIds = new Set<number>();
    const couponEligibleOrderLines: Array<{
      productId: number;
      amount: number;
    }> = [];
    let couponEligibleAmount = 0;
    let containsUserPublishedProducts = false;
    let containsAdminPublishedProducts = false;
    let sellerId: number | null = null;

    if (!orderItems.length) {
      throw new BadRequestException("订单至少包含一个商品");
    }

    for (const item of orderItems) {
      const product = await manager.findOne(Product, {
        where: { id: item.productId },
      });

      if (!product) {
        throw createBusinessException(ErrorCode.PRODUCT_NOT_FOUND);
      }

      if (!product.isActive) {
        throw createBusinessException(
          ErrorCode.PRODUCT_NOT_ACTIVE,
          `商品 ${product.name} 已下架`,
        );
      }

      if (product.publishedBy === userId) {
        throw createBusinessException(
          ErrorCode.BUSINESS_PERMISSION_DENIED,
          `不能购买自己发布的商品 ${product.name}`,
        );
      }

      productIds.add(product.id);
      const isCouponEligibleProduct =
        product.publishSource !== PublishSource.USER;

      if (!isCouponEligibleProduct) {
        containsUserPublishedProducts = true;
        if (orderItems.length !== 1 || item.quantity !== 1) {
          throw new BadRequestException(
            "二手订单只能购买一个商品，数量固定为1",
          );
        }
        if (!product.publishedBy) {
          throw new BadRequestException("二手商品缺少卖家信息，暂时无法购买");
        }
        if (sellerId && sellerId !== product.publishedBy) {
          throw new BadRequestException("一个二手订单只能包含一个卖家的商品");
        }
        sellerId = product.publishedBy;
      } else {
        containsAdminPublishedProducts = true;
      }

      if (item.skuId) {
        const sku = await manager.findOne(ProductSku, {
          where: { id: item.skuId, productId: product.id },
        });

        if (!sku) {
          throw createBusinessException(
            ErrorCode.PRODUCT_NOT_FOUND,
            `商品 ${product.name} 的规格不存在`,
          );
        }

        if (sku.status !== SkuStatus.ACTIVE) {
          throw createBusinessException(
            ErrorCode.PRODUCT_NOT_ACTIVE,
            `商品 ${product.name} 的规格已下架`,
          );
        }

        if (checkStock && sku.stock < item.quantity) {
          stockErrors.push({
            productName: product.name,
            skuName: sku.name,
            requested: item.quantity,
            available: sku.stock,
          });
          continue;
        }

        const productImage =
          product.images && product.images.length > 0
            ? product.images[0]
            : product.image;

        items.push({
          productId: product.id,
          productName: product.name,
          productImage,
          quantity: item.quantity,
          price: sku.price,
          skuId: sku.id,
          skuName: sku.name,
        });

        const lineAmount = toNumber(sku.price) * item.quantity;
        totalAmount += lineAmount;

        if (isCouponEligibleProduct) {
          couponEligibleProductIds.add(product.id);
          couponEligibleAmount += lineAmount;
          couponEligibleOrderLines.push({
            productId: product.id,
            amount: lineAmount,
          });
        }
      } else {
        if (checkStock && product.stock < item.quantity) {
          stockErrors.push({
            productName: product.name,
            requested: item.quantity,
            available: product.stock,
          });
          continue;
        }

        const productImage =
          product.images && product.images.length > 0
            ? product.images[0]
            : product.image;

        items.push({
          productId: product.id,
          productName: product.name,
          productImage,
          quantity: item.quantity,
          price: product.price,
        });

        const lineAmount = toNumber(product.price) * item.quantity;
        totalAmount += lineAmount;

        if (isCouponEligibleProduct) {
          couponEligibleProductIds.add(product.id);
          couponEligibleAmount += lineAmount;
          couponEligibleOrderLines.push({
            productId: product.id,
            amount: lineAmount,
          });
        }
      }
    }

    if (containsUserPublishedProducts && containsAdminPublishedProducts) {
      throw new BadRequestException("二手商品不能与平台商品混合下单");
    }

    return {
      items,
      totalAmount,
      stockErrors,
      productIds: Array.from(productIds),
      couponEligibleAmount,
      couponEligibleProductIds: Array.from(couponEligibleProductIds),
      couponEligibleOrderLines,
      containsUserPublishedProducts,
      orderType: containsUserPublishedProducts
        ? OrderType.SECOND_HAND
        : OrderType.NORMAL,
      sellerId,
    };
  }

  // Product CRUD
  /**
   * 创建商品（支持用户发布和后台发布）
   */
  async createProduct(
    createProductDto: CreateProductDto,
    currentUser: any,
  ): Promise<Product> {
    const publishSource =
      currentUser.role === "SUPER_ADMIN" || currentUser.role === "STAFF"
        ? PublishSource.ADMIN
        : PublishSource.USER;

    // 使用事务处理商品和SKU的创建
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // 创建商品
      const { skus, ...productData } = createProductDto;
      const product = queryRunner.manager.create(Product, {
        ...productData,
        publishSource,
        publishedBy: currentUser.id,
        isActive: true, // 所有商品创建后默认启用
      });

      const saved = await queryRunner.manager.save(product);

      // 处理 SKU 创建
      if (skus && skus.length > 0) {
        // 多规格商品：批量创建 SKU（明确排除自动生成的字段）
        const skuEntities = skus.map((sku) => {
          // 清理 SKU 数据，只保留允许的字段
          const cleanSku: any = {
            name: sku.name,
            specs: sku.specs,
            price: sku.price,
            originalPrice: sku.originalPrice,
            stock: sku.stock,
            status: sku.status,
            image: sku.image,
            // 清理 skuCode，空字符串转为 null
            skuCode:
              sku.skuCode && sku.skuCode.trim() !== ""
                ? sku.skuCode.trim()
                : null,
            productId: saved.id,
          };
          return cleanSku;
        });

        // 检查提交的 SKU 中是否有重复的 skuCode
        const skuCodes = skuEntities
          .map((s) => s.skuCode)
          .filter((code) => code !== null);

        const uniqueSkuCodes = new Set(skuCodes);
        if (skuCodes.length !== uniqueSkuCodes.size) {
          throw createBusinessException(
            ErrorCode.BUSINESS_INVALID_PARAM,
            "同一商品下的 SKU 编码不能重复",
          );
        }

        try {
          await queryRunner.manager.insert(ProductSku, skuEntities);
        } catch (insertError: any) {
          this.logger.error(
            `Failed to insert SKUs for new product ${saved.id}:`,
            {
              error: insertError.message,
              driverError: insertError.driverError,
              skus: skuEntities.map((s) => ({
                name: s.name,
                skuCode: s.skuCode,
              })),
            },
          );

          if (
            insertError.driverError?.errno === 1062 ||
            insertError.driverError?.code === "ER_DUP_ENTRY"
          ) {
            throw createBusinessException(
              ErrorCode.BUSINESS_INVALID_PARAM,
              "SKU 编码与其他商品冲突，请使用不同的编码",
            );
          }
          throw insertError;
        }
      } else {
        // 单规格商品：自动创建默认 SKU
        const defaultSku = queryRunner.manager.create(ProductSku, {
          name: "默认规格",
          specs: {},
          price: saved.price,
          originalPrice: null,
          stock: saved.stock,
          status: SkuStatus.ACTIVE,
          image: saved.image || null,
          skuCode: null,
          productId: saved.id,
        });

        try {
          await queryRunner.manager.save(defaultSku);
          this.logger.log(
            `Default SKU created for single-SKU product ${saved.id}`,
          );
        } catch (insertError: any) {
          this.logger.error(
            `Failed to insert default SKU for product ${saved.id}:`,
            insertError,
          );
          throw insertError;
        }
      }

      await queryRunner.commitTransaction();
      this.logger.log(
        `Product created: ${saved.id}, source: ${publishSource}, isActive: true`,
      );

      // 重新查询包含 SKU 的商品
      return this.findOneProduct(saved.id);
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  /**
   * 查询商品列表（支持分页和高级筛选）
   */
  async findAllProducts(
    query: QueryProductDto,
    currentUserId?: number,
  ): Promise<PaginatedResult<Product>> {
    const {
      page = 1,
      pageSize = 20,
      keyword,
      category,
      categoryId,
      publishSource,
      minPrice,
      maxPrice,
      publishedBy,
      isActive,
      sortBy = "createdAt",
      sortOrder = "DESC",
    } = query;

    const queryBuilder = this.productRepository.createQueryBuilder("product");

    // 关联发布者信息
    queryBuilder.leftJoinAndSelect("product.publisher", "publisher");

    await this.applyBlockedPublishersFilter(queryBuilder, currentUserId);

    // 关键词搜索
    if (keyword) {
      const categoryIds = await this.resolveCategoryIdsByKeyword(keyword);

      if (categoryIds.length > 0) {
        queryBuilder.andWhere(
          "(product.name LIKE :keyword OR product.categoryId IN (:...categoryIds))",
          {
            keyword: `%${keyword}%`,
            categoryIds,
          },
        );
      } else {
        queryBuilder.andWhere("product.name LIKE :keyword", {
          keyword: `%${keyword}%`,
        });
      }
    }

    // 分类筛选（旧版枚举分类）
    if (category) {
      queryBuilder.andWhere("product.category = :category", { category });
    }

    // 商品分类ID筛选（新版分类表）
    if (categoryId) {
      const filterCategoryIds = await this.resolveCategoryFilterIds(categoryId);

      if (filterCategoryIds.length > 0) {
        queryBuilder.andWhere("product.categoryId IN (:...filterCategoryIds)", {
          filterCategoryIds,
        });
      } else {
        queryBuilder.andWhere("product.categoryId = :missingCategoryId", {
          missingCategoryId: -1,
        });
      }
    }

    // 发布来源筛选
    if (publishSource) {
      queryBuilder.andWhere("product.publishSource = :publishSource", {
        publishSource,
      });
    }

    // 价格区间筛选
    if (minPrice !== undefined) {
      queryBuilder.andWhere("product.price >= :minPrice", { minPrice });
    }
    if (maxPrice !== undefined) {
      queryBuilder.andWhere("product.price <= :maxPrice", { maxPrice });
    }

    // 发布者筛选
    if (publishedBy !== undefined) {
      queryBuilder.andWhere("product.publishedBy = :publishedBy", {
        publishedBy,
      });
    }

    // 上架状态筛选
    if (isActive !== undefined) {
      queryBuilder.andWhere("product.isActive = :isActive", {
        isActive: isActive === "true",
      });
    }

    // 排序
    queryBuilder.orderBy(`product.${sortBy}`, sortOrder);

    // 分页
    queryBuilder.skip((page - 1) * pageSize).take(pageSize);

    const [data, total] = await queryBuilder.getManyAndCount();

    return {
      data: serializeShopResponse(data),
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 获取待审核商品列表（管理员专用）
   */
  async getMyProducts(
    userId: number,
    query: QueryProductDto,
  ): Promise<PaginatedResult<Product>> {
    return this.findAllProducts({
      ...query,
      publishedBy: userId,
    });
  }

  async findOneProduct(id: number, currentUserId?: number): Promise<Product> {
    const product = await this.productRepository.findOne({
      where: { id },
      relations: ["skus", "publisher", "categoryRelation"], // 自动加载 SKU、发布者和分类
    });
    if (!product) {
      throw new NotFoundException("商品不存在");
    }

    const blockedUserIds =
      await this.moderationService?.getBlockedUserIds(currentUserId);
    if (product.publishedBy && blockedUserIds?.includes(product.publishedBy)) {
      throw new NotFoundException("商品不存在");
    }

    return serializeShopResponse(product);
  }

  async updateProduct(
    id: number,
    updateProductDto: UpdateProductDto,
    userId: number,
    userRole: string,
  ): Promise<Product> {
    const product = await this.productRepository.findOne({ where: { id } });

    if (!product) {
      throw createBusinessException(ErrorCode.PRODUCT_NOT_FOUND);
    }

    // 权限检查
    if (
      product.publishSource === PublishSource.USER &&
      product.publishedBy !== userId &&
      userRole !== "SUPER_ADMIN"
    ) {
      throw createBusinessException(ErrorCode.BUSINESS_PERMISSION_DENIED);
    }

    // 使用事务处理商品更新和SKU的同步
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // 分离 SKU 数据
      const { skus, ...productData } = updateProductDto;

      // 直接更新商品数据，不改变状态
      // 用户发布的商品编辑后不再改变 isActive 或审核状态
      await queryRunner.manager.update(Product, id, productData as any);

      // 如果提供了 SKU，使用智能更新策略：增删改
      if (skus) {
        // 获取现有 SKU
        const existingSkus = await queryRunner.manager.find(ProductSku, {
          where: { productId: id },
        });

        const existingSkuMap = new Map(existingSkus.map((s) => [s.id, s]));
        const incomingSkuIds = new Set<number>();
        const nextHasSku = productData.hasSku ?? product.hasSku;
        const reusableSingleSkuId =
          !nextHasSku && skus.length === 1 && existingSkus.length > 0
            ? existingSkus[0].id
            : null;

        // 预处理提交的 SKU 数据
        const skuEntities = skus.map((sku) => {
          // 清理 SKU 数据
          const cleanSku: any = {
            name: sku.name,
            specs: sku.specs,
            price: sku.price,
            originalPrice: sku.originalPrice,
            stock: sku.stock,
            status: sku.status,
            image: sku.image,
            // 清理 skuCode，空字符串转为 null
            skuCode:
              sku.skuCode && sku.skuCode.trim() !== ""
                ? sku.skuCode.trim()
                : null,
            productId: id,
          };

          // 如果提供了 id，说明是更新现有 SKU
          if (sku.id) {
            incomingSkuIds.add(sku.id);
            cleanSku.id = sku.id;
          } else if (reusableSingleSkuId) {
            incomingSkuIds.add(reusableSingleSkuId);
            cleanSku.id = reusableSingleSkuId;
          }

          return cleanSku;
        });

        // 检查提交的 SKU 中是否有重复的 skuCode
        const skuCodes = skuEntities
          .map((s) => s.skuCode)
          .filter((code) => code !== null);

        const uniqueSkuCodes = new Set(skuCodes);
        if (skuCodes.length !== uniqueSkuCodes.size) {
          throw createBusinessException(
            ErrorCode.BUSINESS_INVALID_PARAM,
            "同一商品下的 SKU 编码不能重复",
          );
        }

        // 处理 SKU：更新、创建、删除
        for (const skuEntity of skuEntities) {
          if (skuEntity.id) {
            // 更新现有 SKU
            const existingSku = existingSkuMap.get(skuEntity.id);
            if (existingSku) {
              // 检查 skuCode 是否与其他商品冲突（排除当前 SKU）
              if (
                skuEntity.skuCode &&
                skuEntity.skuCode !== existingSku.skuCode
              ) {
                const conflictSku = await queryRunner.manager.findOne(
                  ProductSku,
                  {
                    where: {
                      skuCode: skuEntity.skuCode,
                      productId: id,
                    },
                  },
                );
                if (
                  conflictSku &&
                  conflictSku.id !== skuEntity.id &&
                  conflictSku.productId === id
                ) {
                  throw createBusinessException(
                    ErrorCode.BUSINESS_INVALID_PARAM,
                    "SKU 编码与其他商品冲突，请使用不同的编码",
                  );
                }
              }

              await queryRunner.manager.update(
                ProductSku,
                skuEntity.id,
                skuEntity,
              );
            }
          } else {
            // 创建新 SKU
            try {
              await queryRunner.manager.insert(ProductSku, {
                ...skuEntity,
                productId: id,
              });
            } catch (insertError: any) {
              if (
                insertError.driverError?.errno === 1062 ||
                insertError.driverError?.code === "ER_DUP_ENTRY"
              ) {
                throw createBusinessException(
                  ErrorCode.BUSINESS_INVALID_PARAM,
                  "SKU 编码与其他商品冲突，请使用不同的编码",
                );
              }
              throw insertError;
            }
          }
        }

        // 删除不再存在的 SKU（只删除没有被购物车引用的 SKU）
        for (const existingSku of existingSkus) {
          if (!incomingSkuIds.has(existingSku.id)) {
            // 检查是否有购物车引用此 SKU
            const cartCount = await queryRunner.manager
              .createQueryBuilder()
              .from("shopping_carts", "cart")
              .where("cart.skuId = :skuId", { skuId: existingSku.id })
              .getCount();

            if (cartCount > 0) {
              // 有购物车引用，强制保留此 SKU（记录日志）
              this.logger.warn(
                `SKU "${existingSku.name}" (ID: ${existingSku.id}) 被购物车引用，已跳过删除。引用数: ${cartCount}`,
              );
              continue; // 跳过删除，保留此 SKU
            }

            // 没有购物车引用，可以删除
            await queryRunner.manager.delete(ProductSku, existingSku.id);
            this.logger.log(
              `SKU 已删除: ${existingSku.name} (ID: ${existingSku.id})`,
            );
          }
        }
      } else {
        // 没有提供 skus 参数，检查是否需要为单规格商品创建默认 SKU
        const existingSkus = await queryRunner.manager.find(ProductSku, {
          where: { productId: id },
        });

        if (existingSkus.length === 0) {
          // 没有 SKU，创建默认 SKU
          const product = await queryRunner.manager.findOne(Product, {
            where: { id },
          });

          const defaultSku = queryRunner.manager.create(ProductSku, {
            name: "默认规格",
            specs: {},
            price: product.price,
            originalPrice: null,
            stock: product.stock,
            status: SkuStatus.ACTIVE,
            image: product.image || null,
            skuCode: null,
            productId: id,
          });

          try {
            await queryRunner.manager.save(defaultSku);
            this.logger.log(`Default SKU created for single-SKU product ${id}`);
          } catch (insertError: any) {
            this.logger.error(
              `Failed to insert default SKU for product ${id}:`,
              insertError,
            );
            throw insertError;
          }
        }
      }

      await queryRunner.commitTransaction();

      // 重新查询包含 SKU 的商品
      return this.findOneProduct(id);
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  async removeProduct(
    id: number,
    userId: number,
    userRole: string,
  ): Promise<void> {
    const product = await this.productRepository.findOne({ where: { id } });

    if (!product) {
      throw createBusinessException(ErrorCode.PRODUCT_NOT_FOUND);
    }

    // 权限检查
    if (
      product.publishSource === PublishSource.USER &&
      product.publishedBy !== userId &&
      userRole !== "SUPER_ADMIN"
    ) {
      throw createBusinessException(ErrorCode.BUSINESS_PERMISSION_DENIED);
    }

    await this.productRepository.delete(id);
    this.logger.log(`Product deleted: ${id}`);
  }

  async updateStock(id: number, quantity: number): Promise<void> {
    await this.productRepository.decrement({ id }, "stock", quantity);
  }

  // Order CRUD
  /**
   * 创建订单（使用事务和乐观锁）
   *
   * 事务流程：
   * 1. 开始事务
   * 2. 验证商品并锁定（乐观锁）
   * 3. 扣减库存（带版本检查）
   * 4. 创建订单
   * 5. 创建支付
   * 6. 提交事务
   * 7. 如果任何步骤失败，回滚事务
   */
  async createOrder(
    createOrderDto: CreateOrderDto,
    userId: number,
  ): Promise<
    | { order: Order; paymentParams: any }
    | { success: false; errorType: string; message: string; details?: any[] }
  > {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    // 标志变量：跟踪事务是否已提交
    let transactionCommitted = false;

    try {
      this.logger.log(
        `Starting transaction for order creation, userId: ${userId}`,
      );

      const {
        items,
        totalAmount: calculatedAmount,
        stockErrors,
        productIds,
        couponEligibleAmount,
        couponEligibleProductIds,
        couponEligibleOrderLines,
        containsUserPublishedProducts,
        orderType,
        sellerId,
      } = await this.buildOrderPricingContext(
        queryRunner.manager,
        createOrderDto.items,
        userId,
        true,
      );
      let totalAmount = calculatedAmount;

      if (containsUserPublishedProducts && createOrderDto.userCouponId) {
        throw new BadRequestException("二手商品订单不支持使用优惠券");
      }

      // 检查是否有库存不足的商品
      if (stockErrors.length > 0) {
        // 回滚事务
        await queryRunner.rollbackTransaction();
        await queryRunner.release();

        // 构建友好的错误消息
        const errorMessages = stockErrors.map(
          (error) =>
            `${error.productName}${error.skuName ? ` (${error.skuName})` : ""} 库存不足，当前库存：${error.available}`,
        );

        this.logger.warn(
          `[订单创建失败] 库存不足: ${errorMessages.join(", ")}`,
        );
        this.logger.log(
          `[库存验证汇总] 共检查 ${createOrderDto.items.length} 个商品，${stockErrors.length} 个库存不足`,
        );

        // 返回错误响应，不抛出异常
        return {
          success: false,
          errorType: "STOCK_OUT",
          message: errorMessages.join("；"),
          details: stockErrors,
        };
      } else {
        this.logger.log(
          `[库存验证通过] 共检查 ${createOrderDto.items.length} 个商品，库存充足`,
        );
      }

      // 2. 验证并使用优惠券
      const originalAmount = totalAmount;
      let couponDiscount = 0;
      let couponId = null;
      let lockedUserCoupon: {
        userCoupon: UserCoupon;
        coupon: Coupon;
        discount: number;
      } | null = null;

      if (createOrderDto.userCouponId && this.couponService) {
        try {
          lockedUserCoupon = await this.couponService.lockCouponForOrder({
            userCouponId: createOrderDto.userCouponId,
            userId,
            orderAmount: couponEligibleAmount,
            productIds: couponEligibleProductIds,
            orderLines: couponEligibleOrderLines,
            manager: queryRunner.manager,
          });

          couponDiscount = lockedUserCoupon.discount;
          couponId = lockedUserCoupon.coupon.id;
          totalAmount -= couponDiscount;

          this.logger.log(
            `Coupon applied: userCouponId=${createOrderDto.userCouponId}, discount=${couponDiscount}`,
          );
        } catch (error) {
          this.logger.error(`Coupon validation failed: ${error.message}`);
          throw error;
        }
      }

      // 3. 生成订单号（使用 UUID 保证唯一性）
      const orderNo = this.generateOrderNo();
      const platformFeeRate = containsUserPublishedProducts
        ? await this.platformFeeService.getPlatformFeeRate()
        : null;
      const platformFee = containsUserPublishedProducts
        ? Number(((totalAmount * platformFeeRate) / 100).toFixed(2))
        : null;

      // 4. 创建订单
      const order = queryRunner.manager.create(Order, {
        orderNo,
        orderType,
        userId,
        sellerId,
        items: this.buildOrderItemSnapshots(items, couponDiscount),
        originalAmount,
        couponId,
        couponDiscount,
        totalAmount,
        shippingAddress: createOrderDto.shippingAddress,
        receiverName: createOrderDto.receiverName,
        receiverPhone: createOrderDto.receiverPhone,
        remark: createOrderDto.remark,
        autoConfirmDays: 10,
        platformFeeRate,
        platformFee,
        sellerIncome: containsUserPublishedProducts
          ? Number((totalAmount - platformFee).toFixed(2))
          : null,
        settlementStatus: containsUserPublishedProducts
          ? SettlementStatus.PENDING
          : null,
      });

      const savedOrder = await queryRunner.manager.save(Order, order);
      this.logger.log(`Order created: ${orderNo}, id: ${savedOrder.id}`);

      if (lockedUserCoupon) {
        await this.couponService.markCouponUsedForOrder(
          lockedUserCoupon.userCoupon,
          savedOrder.id,
          queryRunner.manager,
        );
      }

      // 4. 扣减库存（安全修复：使用带条件的 UPDATE 确保库存不会变负）
      for (const item of createOrderDto.items) {
        if (item.skuId) {
          const product = await queryRunner.manager.findOne(Product, {
            where: { id: item.productId },
          });

          if (!product) {
            throw createBusinessException(ErrorCode.PRODUCT_NOT_FOUND);
          }

          // 使用条件 UPDATE：只有库存足够时才扣减
          const result = await queryRunner.manager
            .createQueryBuilder()
            .update(ProductSku)
            .set({ stock: () => "stock - :quantity" })
            .where("id = :id AND stock >= :quantity", {
              id: item.skuId,
              quantity: item.quantity,
            })
            .execute();

          if (result.affected === 0) {
            // 库存不足，回滚事务
            this.logger.error(
              `SKU stock insufficient during decrement: skuId=${item.skuId}, requested=${item.quantity}`,
            );
            throw new BadRequestException(`商品库存不足，可能已被其他用户购买`);
          }
          this.logger.log(
            `SKU stock decremented: skuId=${item.skuId}, quantity=${item.quantity}`,
          );

          // 单规格商品即使走默认 SKU 下单，也需要同步商品表库存，避免前台展示和审核状态失真
          if (!product.hasSku) {
            const productUpdateResult = await queryRunner.manager
              .createQueryBuilder()
              .update(Product)
              .set({ stock: () => "stock - :quantity" })
              .where("id = :id AND stock >= :quantity", {
                id: item.productId,
                quantity: item.quantity,
              })
              .execute();

            if (productUpdateResult.affected === 0) {
              this.logger.error(
                `Product stock insufficient during single-sku sync decrement: productId=${item.productId}, requested=${item.quantity}`,
              );
              throw new BadRequestException(
                `商品库存不足，可能已被其他用户购买`,
              );
            }
            this.logger.log(
              `Product stock synced for single-sku item: productId=${item.productId}, quantity=${item.quantity}`,
            );
          }
        } else {
          // 使用条件 UPDATE：只有库存足够时才扣减
          const result = await queryRunner.manager
            .createQueryBuilder()
            .update(Product)
            .set({ stock: () => "stock - :quantity" })
            .where("id = :id AND stock >= :quantity", {
              id: item.productId,
              quantity: item.quantity,
            })
            .execute();

          if (result.affected === 0) {
            // 库存不足，回滚事务
            this.logger.error(
              `Product stock insufficient during decrement: productId=${item.productId}, requested=${item.quantity}`,
            );
            throw new BadRequestException(`商品库存不足，可能已被其他用户购买`);
          }
          this.logger.log(
            `Product stock decremented: productId=${item.productId}, quantity=${item.quantity}`,
          );
        }
      }

      // 4.5. 检查用户发布商品的库存，如果库存为0则自动下架
      for (const productId of productIds) {
        // 查询商品信息
        const product = await queryRunner.manager.findOne(Product, {
          where: { id: productId },
        });

        if (!product) {
          this.logger.warn(
            `Product not found for auto-offline check: ${productId}`,
          );
          continue;
        }

        // 只处理用户发布的商品
        if (product.publishSource !== PublishSource.USER) {
          this.logger.log(
            `Product ${productId} is not published by user, skip auto-offline check`,
          );
          continue;
        }

        // 单规格用户商品以 product.stock 为准，同时同步兼容默认 SKU 库存
        let remainingStock = product.stock;
        if (!product.hasSku) {
          await this.syncSingleSpecCompatibilitySkuStock(
            queryRunner.manager,
            productId,
          );
        } else {
          const skus = await queryRunner.manager.find(ProductSku, {
            where: { productId },
          });
          if (skus.length > 0) {
            const activeSkuStock = skus
              .filter((sku) => sku.status === SkuStatus.ACTIVE)
              .reduce((sum, sku) => sum + sku.stock, 0);
            remainingStock = activeSkuStock;
          }
        }

        if (remainingStock <= 0) {
          await queryRunner.manager.update(Product, productId, {
            isActive: false,
            soldAt: new Date(),
          });
          if (product.pendingProductId) {
            await queryRunner.manager.update(
              "products_pending",
              { id: product.pendingProductId },
              { status: PendingProductStatus.SOLD },
            );
          }
          this.logger.log(
            `User published product ${productId} (${product.name}) auto-offlined: stock is 0`,
          );
        }
      }

      // 5. 提交事务（在创建支付前提交，避免支付接口超时导致事务锁死）
      await queryRunner.commitTransaction();
      transactionCommitted = true; // 标记事务已提交
      this.logger.log(`Transaction committed for order: ${orderNo}`);

      // 6. 创建支付或虚拟支付（事务外执行，如果失败需要手动回滚库存和订单）
      try {
        // 检查是否为虚拟支付（跳过真实支付流程）
        // 安全修复：虚拟支付仅允许在开发环境使用
        if (createOrderDto.isVirtualPayment) {
          if (!this.isDevelopment) {
            this.logger.warn(
              `Virtual payment rejected in production environment: userId=${userId}, orderNo=${orderNo}`,
            );
            throw new BadRequestException("虚拟支付仅在开发环境可用");
          }

          // 在独立事务中完成支付状态。结算只能在确认收货后触发。
          await this.dataSource.transaction(async (manager) => {
            await manager.update(Order, savedOrder.id, {
              status: OrderStatus.PAID,
              paidAt: new Date(),
              paymentMethod: "virtual",
            });

            this.logger.log(
              `Order ${savedOrder.orderNo} paid with virtual payment`,
            );
          });

          // 发送订单创建和支付成功通知
          await this.notificationSender.orderCreated(userId, {
            orderId: savedOrder.id,
          });
          await this.notificationSender.orderPaid(userId, {
            orderId: savedOrder.id,
          });
          if (sellerId) {
            await this.notificationSender.orderPaid(sellerId, {
              orderId: savedOrder.id,
              viewRole: "seller",
            } as any);
          }

          // 重新查询订单返回最新状态
          const paidOrder = await this.findOneOrder(
            savedOrder.id,
            userId,
            "USER",
          );

          return {
            order: paidOrder,
            paymentParams: {
              paymentNo: `VIRTUAL_${orderNo}`,
              isVirtual: true,
            },
          };
        } else if (createOrderDto.paymentChannel === PaymentChannel.BALANCE) {
          const balancePaymentResult = await this.payOrderWithBalance(
            savedOrder.id,
            userId,
          );

          await this.notificationSender.orderCreated(userId, {
            orderId: savedOrder.id,
          });

          return balancePaymentResult;
        } else {
          // 真实支付：创建支付记录
          const paymentParams = await this.paymentService.createPayment({
            channel: createOrderDto.paymentChannel,
            method: this.mapPaymentMethodFromChannel(
              createOrderDto.paymentChannel,
            ),
            amount: savedOrder.totalAmount,
            userId,
            businessType: BusinessType.SHOP_ORDER,
            businessId: savedOrder.id,
            subject: `商城订单支付 - ${items[0].productName}${items.length > 1 ? ` 等${items.length}件商品` : ""}`,
            body: items
              .map((item) => `${item.productName} x${item.quantity}`)
              .join(", "),
            expireIn: 900,
          });

          await this.orderRepository.update(savedOrder.id, {
            paymentNo: paymentParams.paymentNo,
            paymentMethod: this.getPaymentMethodString(
              createOrderDto.paymentChannel,
            ),
          });
          savedOrder.paymentNo = paymentParams.paymentNo;
          savedOrder.paymentMethod = this.getPaymentMethodString(
            createOrderDto.paymentChannel,
          );

          this.logger.log(
            `Order created with payment: ${savedOrder.orderNo}, paymentNo: ${paymentParams.paymentNo}`,
          );

          // 发送订单创建成功通知
          await this.notificationSender.orderCreated(userId, {
            orderId: savedOrder.id,
          });

          return {
            order: savedOrder,
            paymentParams,
          };
        }
      } catch (paymentError) {
        // 支付创建失败，需要回滚库存和删除订单
        this.logger.error(
          `Create payment failed, rolling back order and stock: ${paymentError.message}`,
        );

        // 启动新事务进行回滚
        const rollbackRunner = this.dataSource.createQueryRunner();
        await rollbackRunner.connect();
        await rollbackRunner.startTransaction();

        try {
          // 恢复库存
          for (const item of createOrderDto.items) {
            await this.restoreOrderItemStock(rollbackRunner.manager, item);
          }

          for (const productId of new Set(
            createOrderDto.items.map((item) => item.productId),
          )) {
            await this.restoreProductAvailabilityAfterRestock(
              rollbackRunner.manager,
              productId,
            );
          }

          if (this.couponService) {
            await this.couponService.releaseCouponForOrder(
              savedOrder.id,
              rollbackRunner.manager,
            );
          }
          // 删除订单
          await rollbackRunner.manager.delete(Order, savedOrder.id);

          await rollbackRunner.commitTransaction();
          this.logger.log(`Rollback completed for order: ${orderNo}`);
        } catch (rollbackError) {
          await rollbackRunner.rollbackTransaction();
          this.logger.error(`Rollback failed: ${rollbackError.message}`);
          throw new BadRequestException("订单创建失败，请稍后重试");
        } finally {
          await rollbackRunner.release();
        }

        throw paymentError;
      }
    } catch (error) {
      // 主流程失败，回滚事务（仅在事务未提交时）
      if (!transactionCommitted) {
        await queryRunner.rollbackTransaction();
        this.logger.error(`Transaction rolled back: ${error.message}`);
      } else {
        this.logger.error(
          `Error after transaction committed: ${error.message}`,
        );
      }
      throw error;
    } finally {
      // 释放 QueryRunner
      await queryRunner.release();
    }
  }

  /**
   * 使用乐观锁扣减库存
   * @param queryRunner 查询运行器
   * @param productId 商品ID
   * @param quantity 扣减数量
   */
  private async updateStockWithLock(
    queryRunner: QueryRunner,
    productId: number,
    quantity: number,
  ): Promise<void> {
    const product = await queryRunner.manager.findOne(Product, {
      where: { id: productId },
      lock: { mode: "optimistic", version: "version" as any },
    });

    if (!product) {
      throw createBusinessException(ErrorCode.PRODUCT_NOT_FOUND);
    }

    if (product.stock < quantity) {
      throw createBusinessException(
        ErrorCode.PRODUCT_OUT_OF_STOCK,
        `商品 ${product.name} 库存不足`,
      );
    }

    // 扣减库存（TypeORM 会自动检查 version 字段）
    product.stock -= quantity;
    try {
      await queryRunner.manager.save(Product, product);
      this.logger.log(
        `Stock updated: productId=${productId}, newStock=${product.stock}`,
      );
    } catch (error) {
      // 乐观锁冲突
      if (error.message?.includes("optimistic")) {
        throw createBusinessException(
          ErrorCode.PRODUCT_OUT_OF_STOCK,
          "商品库存变更，请重新下单",
        );
      }
      throw error;
    }
  }

  async previewOrder(
    previewOrderDto: PreviewOrderDto,
    userId: number,
  ): Promise<{
    originalAmount: number;
    couponDiscount: number;
    totalAmount: number;
    selectedCoupon: any | null;
    coupons: any[];
    containsUserPublishedProducts: boolean;
    couponEligibleAmount: number;
    couponExcludedAmount: number;
    charityDonationRate: number | null;
    charityDonationAmount: number | null;
  }> {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();

    try {
      const {
        totalAmount,
        couponEligibleAmount,
        couponEligibleProductIds,
        couponEligibleOrderLines,
        containsUserPublishedProducts,
      } = await this.buildOrderPricingContext(
        queryRunner.manager,
        previewOrderDto.items as OrderItemDto[],
        userId,
        false,
      );

      if (containsUserPublishedProducts && previewOrderDto.userCouponId) {
        throw new BadRequestException("二手商品订单不支持使用优惠券");
      }

      const coupons =
        !containsUserPublishedProducts && this.couponService
          ? await this.couponService.getOrderCouponOptions(
              userId,
              couponEligibleAmount,
              couponEligibleProductIds,
              couponEligibleOrderLines,
            )
          : [];

      const selectedCoupon = previewOrderDto.userCouponId
        ? coupons.find(
            (coupon) => coupon.id === previewOrderDto.userCouponId,
          ) || null
        : null;

      if (previewOrderDto.userCouponId && !selectedCoupon) {
        throw createBusinessException(ErrorCode.COUPON_NOT_FOUND);
      }

      if (selectedCoupon && !selectedCoupon.isApplicable) {
        throw createBusinessException(
          ErrorCode.COUPON_NOT_APPLICABLE,
          selectedCoupon.unavailableReason,
        );
      }

      const couponDiscount = selectedCoupon?.discountAmount ?? 0;
      const payableAmount = Math.max(0, add(totalAmount, -couponDiscount));
      const charityDonationRate = containsUserPublishedProducts
        ? null
        : await this.getActiveMallDonationRate();
      const charityDonationAmount =
        charityDonationRate == null
          ? null
          : toYuan(
              Math.round((toCents(payableAmount) * charityDonationRate) / 100),
            );

      return {
        originalAmount: totalAmount,
        couponDiscount,
        totalAmount: payableAmount,
        selectedCoupon,
        coupons,
        containsUserPublishedProducts,
        couponEligibleAmount,
        couponExcludedAmount: Math.max(
          0,
          add(totalAmount, -couponEligibleAmount),
        ),
        charityDonationRate,
        charityDonationAmount,
      };
    } finally {
      await queryRunner.release();
    }
  }

  private async getActiveMallDonationRate(): Promise<number | null> {
    if (!this.charityRepository) return null;
    const charity = await this.charityRepository.findOne({
      where: {
        isMallAutoDonation: true,
        participantType: ParticipantType.DONATION,
        status: CharityStatus.ACTIVE,
      },
      order: { isPinned: "DESC", createdAt: "DESC" },
    });
    if (!charity) return null;
    const rate = Number(charity.donationRate);
    return Number.isFinite(rate) && rate > 0 ? rate : null;
  }

  /**
   * 扣减 SKU 库存（使用乐观锁）
   */
  private async updateSkuStockWithLock(
    queryRunner: QueryRunner,
    skuId: number,
    quantity: number,
  ): Promise<void> {
    const sku = await queryRunner.manager.findOne(ProductSku, {
      where: { id: skuId },
      lock: { mode: "optimistic", version: "version" as any },
    });

    if (!sku) {
      throw createBusinessException(ErrorCode.PRODUCT_NOT_FOUND, "SKU不存在");
    }

    if (sku.stock < quantity) {
      throw createBusinessException(
        ErrorCode.PRODUCT_OUT_OF_STOCK,
        `商品 (${sku.name}) 库存不足，当前库存：${sku.stock}`,
      );
    }

    // 扣减库存（TypeORM 会自动检查 version 字段）
    sku.stock -= quantity;
    try {
      await queryRunner.manager.save(ProductSku, sku);
      this.logger.log(
        `SKU stock updated: skuId=${skuId}, newStock=${sku.stock}`,
      );
    } catch (error) {
      // 乐观锁冲突
      if (error.message?.includes("optimistic")) {
        throw createBusinessException(
          ErrorCode.PRODUCT_OUT_OF_STOCK,
          "商品库存变更，请重新下单",
        );
      }
      throw error;
    }
  }

  async findAllOrders(userId?: number, userRole?: string): Promise<Order[]> {
    const where: any = {};

    if (userRole === "USER") {
      where.userId = userId;
    }

    const orders = await this.orderRepository.find({
      where,
      relations: ["user"],
      order: { createdAt: "DESC" },
    });

    return serializeShopResponse(orders);
  }

  async findOneOrder(
    id: number,
    userId?: number,
    userRole?: string,
  ): Promise<Order> {
    const order = await this.orderRepository.findOne({
      where: { id },
      relations: ["user", "seller", "logistics"],
    });

    if (!order) {
      throw new NotFoundException("订单不存在");
    }

    if (
      userRole === "USER" &&
      order.userId !== userId &&
      order.sellerId !== userId
    ) {
      throw new BadRequestException("无权查看此订单");
    }

    // 补充订单项的图片信息（强制更新，确保使用商品的第一张图片而不是 SKU 图片）
    await this.fillOrderItemsWithImages([order], true);
    await this.decorateOrderViews([order], userId, userRole);
    await this.decorateOrderCharityDonation(order);

    return serializeShopResponse(order);
  }

  private async decorateOrderCharityDonation(order: Order): Promise<void> {
    if (!this.charityRecordRepository || order.orderType !== OrderType.NORMAL) {
      Object.assign(order, { charityDonationAmount: null });
      return;
    }

    const records = await this.charityRecordRepository.find({
      where: {
        orderId: order.id,
        donationSource: CharityDonationSource.MALL_ORDER,
      },
      select: { donationAmount: true },
    });
    Object.assign(order, {
      charityDonationAmount: records.length
        ? records.reduce(
            (total, record) => add(total, record.donationAmount || 0),
            0,
          )
        : null,
    });
  }

  private async decorateOrderViews(
    orders: Order[],
    currentUserId?: number,
    userRole?: string,
  ): Promise<void> {
    if (!orders.length) return;
    if (!this.afterSaleRepository) {
      for (const order of orders) {
        Object.assign(order, {
          viewRole: order.sellerId === currentUserId ? "seller" : "buyer",
          availableActions: [],
          afterSaleSummary: null,
        });
      }
      return;
    }
    const afterSales = await this.afterSaleRepository.find({
      where: { orderId: In(orders.map((order) => order.id)) },
      relations: ["items"],
      order: { createdAt: "DESC" },
    });
    const latestByOrder = new Map<number, OrderAfterSale>();
    for (const afterSale of afterSales) {
      if (!latestByOrder.has(afterSale.orderId)) {
        latestByOrder.set(afterSale.orderId, afterSale);
      }
    }
    const activeStatuses = new Set<string>(ACTIVE_AFTER_SALE_STATUSES);

    for (const order of orders) {
      const afterSale = latestByOrder.get(order.id);
      const isSecondHand = order.orderType === OrderType.SECOND_HAND;
      const now = new Date();
      const arbitrationOpen = Boolean(
        !afterSale?.arbitrationDeadlineAt ||
        afterSale.arbitrationDeadlineAt >= now,
      );
      const handlerOpen = Boolean(
        !afterSale?.handlerDeadlineAt || afterSale.handlerDeadlineAt >= now,
      );
      const handlerReceiptOpen = Boolean(
        !afterSale?.handlerReceiptDeadlineAt ||
        afterSale.handlerReceiptDeadlineAt >= now,
      );
      const activeAfterSale = Boolean(
        afterSale && activeStatuses.has(afterSale.status),
      );
      const viewRole =
        userRole === "SUPER_ADMIN" || userRole === "STAFF"
          ? "admin"
          : order.sellerId === currentUserId
            ? "seller"
            : "buyer";
      const availableActions: string[] = [];

      if (viewRole === "buyer") {
        if (order.status === OrderStatus.PENDING) {
          availableActions.push("pay", "cancel");
        }
        const completedAfterSaleOpen =
          order.status === OrderStatus.COMPLETED &&
          Boolean(
            order.afterSaleDeadlineAt && order.afterSaleDeadlineAt >= now,
          );
        if (
          ((isSecondHand &&
            [OrderStatus.PAID, OrderStatus.SHIPPED].includes(order.status)) ||
            (!isSecondHand &&
              ([OrderStatus.PAID, OrderStatus.SHIPPED].includes(order.status) ||
                completedAfterSaleOpen))) &&
          !activeAfterSale &&
          this.hasRefundableQuantity(order, afterSales)
        ) {
          availableActions.push("apply_after_sale");
        }
        if (order.status === OrderStatus.SHIPPED && !activeAfterSale) {
          availableActions.push("confirm_receipt");
        }
        if (afterSale) availableActions.push("view_after_sale");
        if (
          afterSale?.status === AfterSaleStatus.WAITING_BUYER_RETURN &&
          (!afterSale.buyerReturnDeadlineAt ||
            afterSale.buyerReturnDeadlineAt >= now)
        )
          availableActions.push("submit_return");
        if (
          afterSale?.handlerType === AfterSaleHandlerType.SELLER &&
          afterSale &&
          [
            AfterSaleStatus.HANDLER_REJECTED,
            AfterSaleStatus.HANDLER_TIMEOUT,
          ].includes(afterSale.status) &&
          arbitrationOpen
        ) {
          availableActions.push("request_arbitration");
        }
      }

      if (viewRole === "seller" && isSecondHand) {
        if (order.status === OrderStatus.PAID && !activeAfterSale) {
          availableActions.push("ship");
        }
        if (order.status === OrderStatus.SHIPPED) {
          availableActions.push("update_tracking");
        }
        if (afterSale) availableActions.push("view_after_sale");
        if (
          afterSale?.status === AfterSaleStatus.PENDING_HANDLER &&
          handlerOpen
        ) {
          availableActions.push("handle_after_sale");
        }
        if (
          afterSale?.status === AfterSaleStatus.WAITING_HANDLER_RECEIPT &&
          handlerReceiptOpen
        ) {
          availableActions.push("confirm_return");
        }
      }

      Object.assign(order, {
        viewRole,
        availableActions,
        afterSaleSummary: afterSale
          ? {
              id: afterSale.id,
              afterSaleNo: afterSale.afterSaleNo,
              status: afterSale.status,
              orderType: afterSale.orderType,
              handlerType: afterSale.handlerType,
              afterSaleType: afterSale.afterSaleType,
              requestedAmount: afterSale.requestedAmount,
              approvedAmount: afterSale.approvedAmount,
              refundAmount:
                afterSale.approvedAmount || afterSale.requestedAmount,
              updatedAt: afterSale.updatedAt,
            }
          : null,
      });
    }
  }

  private async releaseOrderResources(
    order: Order,
    manager: any,
    reason: string,
  ): Promise<void> {
    if (order.inventoryRestoredAt) {
      return;
    }

    const touchedProductIds = new Set<number>();

    for (const item of order.items || []) {
      touchedProductIds.add(item.productId);
      await this.restoreOrderItemStock(manager, item);
    }

    for (const productId of touchedProductIds) {
      await this.restoreProductAvailabilityAfterRestock(manager, productId);
    }

    if (this.couponService) {
      await this.couponService.releaseCouponForOrder(order.id, manager);
    }

    const now = new Date();
    await manager.update(Order, order.id, {
      status: OrderStatus.CANCELLED,
      cancelReason: reason,
      cancelledAt: now,
      inventoryRestoredAt: now,
    });
    order.status = OrderStatus.CANCELLED;
    order.cancelReason = reason;
    order.cancelledAt = now;
    order.inventoryRestoredAt = now;
  }

  private hasRefundableQuantity(order: Order, afterSales: OrderAfterSale[]) {
    const refundedByLine = new Map<string, number>();
    for (const afterSale of afterSales) {
      if (
        afterSale.orderId !== order.id ||
        afterSale.status !== AfterSaleStatus.REFUNDED
      )
        continue;
      for (const item of afterSale.items || []) {
        refundedByLine.set(
          item.lineKey,
          (refundedByLine.get(item.lineKey) || 0) +
            Number(item.refundedQuantity || 0),
        );
      }
    }
    return (order.items || []).some(
      (item) =>
        Number(item.quantity) > Number(refundedByLine.get(item.lineKey) || 0),
    );
  }

  private async assertNoActiveAfterSale(orderId: number, message: string) {
    if (!this.afterSaleRepository) return;
    const active = await this.afterSaleRepository.count({
      where: { orderId, status: In([...ACTIVE_AFTER_SALE_STATUSES]) },
    });
    if (active > 0) throw new BadRequestException(message);
  }

  private async getNormalAfterSaleDays(manager?: any) {
    const config = manager
      ? await manager.findOne(SystemConfig, {
          where: { configKey: "shop_after_sale_policy" },
        })
      : await this.systemConfigRepository.findOne({
          where: { configKey: "shop_after_sale_policy" },
        });
    const value = config?.configValue || {};
    return Number(value.normalCompletedDays) || 7;
  }

  async finalizeRefundedOrder(
    orderId: number,
    manager: any,
    reason: string,
  ): Promise<void> {
    const order = await manager
      .createQueryBuilder(Order, "order")
      .where("order.id = :orderId", { orderId })
      .setLock("pessimistic_write")
      .getOne();
    if (!order) throw new NotFoundException("订单不存在");
    if (order.inventoryRestoredAt) return;
    await this.releaseOrderResources(order, manager, reason);
  }

  async finalizeAfterSaleRefund(
    orderId: number,
    items: OrderAfterSaleItem[],
    manager: any,
    fullRefundReason: string,
    pauseStartedAt?: Date,
  ): Promise<void> {
    const order = await manager
      .createQueryBuilder(Order, "order")
      .where("order.id = :orderId", { orderId })
      .setLock("pessimistic_write")
      .getOne();
    if (!order) throw new NotFoundException("订单不存在");

    const refundIncrementCents = items.reduce(
      (sum, item) =>
        sum + toCents(item.approvedAmount) - toCents(item.refundedAmount || 0),
      0,
    );
    if (refundIncrementCents <= 0) return;

    const touchedProductIds = new Set<number>();
    for (const item of items) {
      const restoreQuantity =
        Number(item.restockQuantity || 0) -
        Number(item.inventoryRestoredQuantity || 0);
      if (restoreQuantity > 0) {
        await this.restoreOrderItemStock(manager, {
          productId: item.productId,
          skuId: item.skuId || undefined,
          quantity: restoreQuantity,
        });
        touchedProductIds.add(item.productId);
        item.inventoryRestoredQuantity = Number(item.restockQuantity);
      }
      item.refundedQuantity = Number(item.approvedQuantity);
      item.refundedAmount = toNumber(item.approvedAmount);
    }
    for (const productId of touchedProductIds) {
      await this.restoreProductAvailabilityAfterRestock(manager, productId);
    }
    await manager.save(OrderAfterSaleItem, items);

    const refundedAmount = toYuan(
      toCents(order.refundedAmount || 0) + refundIncrementCents,
    );
    if (toCents(refundedAmount) > toCents(order.totalAmount)) {
      throw new BadRequestException("订单累计退款金额超过实付金额");
    }
    order.refundedAmount = refundedAmount;
    if (toCents(refundedAmount) === toCents(order.totalAmount)) {
      if (this.couponService) {
        await this.couponService.releaseCouponForOrder(order.id, manager);
      }
      const now = new Date();
      order.status = OrderStatus.CANCELLED;
      order.cancelReason = fullRefundReason;
      order.cancelledAt = now;
      order.inventoryRestoredAt = now;
    } else if (
      pauseStartedAt &&
      order.autoConfirmAt &&
      [OrderStatus.PAID, OrderStatus.SHIPPED].includes(order.status)
    ) {
      const pausedMs = Math.max(Date.now() - pauseStartedAt.getTime(), 0);
      order.autoConfirmAt = new Date(order.autoConfirmAt.getTime() + pausedMs);
    }
    await manager.save(order);
  }

  private async restoreOrderItemStock(
    manager: any,
    item: Pick<OrderItem, "productId" | "skuId" | "quantity">,
  ): Promise<void> {
    if (item.skuId) {
      await manager.increment(
        ProductSku,
        { id: item.skuId },
        "stock",
        item.quantity,
      );

      const product = await manager.findOne(Product, {
        where: { id: item.productId },
      });

      if (!product) {
        return;
      }

      if (product.hasSku) {
        const restoredSku = await manager.findOne(ProductSku, {
          where: { id: item.skuId },
        });

        if (
          restoredSku &&
          restoredSku.stock > 0 &&
          restoredSku.status !== SkuStatus.ACTIVE
        ) {
          restoredSku.status = SkuStatus.ACTIVE;
          await manager.save(restoredSku);
        }
        return;
      }

      await manager.increment(
        Product,
        { id: item.productId },
        "stock",
        item.quantity,
      );
      return;
    }

    await manager.increment(
      Product,
      { id: item.productId },
      "stock",
      item.quantity,
    );
  }

  private async restoreProductAvailabilityAfterRestock(
    manager: any,
    productId: number,
  ): Promise<void> {
    const product = await manager.findOne(Product, {
      where: { id: productId },
    });

    if (!product) {
      return;
    }

    let restoredStock = Math.max(Number(product.stock || 0), 0);

    if (!product.hasSku) {
      await this.syncSingleSpecCompatibilitySkuStock(manager, productId);
      restoredStock = Math.max(Number(product.stock || 0), 0);
    } else {
      const skus = await manager.find(ProductSku, {
        where: { productId },
      });

      restoredStock = 0;
      for (const sku of skus) {
        const skuStock = Math.max(Number(sku.stock || 0), 0);
        restoredStock += skuStock;

        if (skuStock > 0 && sku.status !== SkuStatus.INACTIVE) {
          sku.status = SkuStatus.ACTIVE;
          await manager.save(sku);
        }
      }
    }

    if (product.publishSource !== PublishSource.USER || restoredStock <= 0) {
      return;
    }

    if (!product.soldAt) {
      return;
    }

    if (product.pendingProductId) {
      const pendingProduct = await manager.findOne(ProductPending, {
        where: { id: product.pendingProductId },
      });
      if (pendingProduct?.status !== PendingProductStatus.SOLD) {
        return;
      }
    }

    await manager.update(Product, productId, {
      isActive: true,
      soldAt: null,
    });

    if (product.pendingProductId) {
      await manager.update(
        "products_pending",
        { id: product.pendingProductId },
        { status: PendingProductStatus.ON_SHELF },
      );
    }
  }

  private async restoreUserPublishedProductAvailability(
    manager: any,
    productId: number,
  ): Promise<void> {
    await this.restoreProductAvailabilityAfterRestock(manager, productId);
  }

  private async cancelPendingOrderInternal(
    order: Order,
    reason: string,
  ): Promise<void> {
    await this.dataSource.transaction(async (manager) => {
      const lockedOrder = await manager.findOne(Order, {
        where: { id: order.id },
        lock: { mode: "pessimistic_write" },
      });
      if (!lockedOrder || lockedOrder.status !== OrderStatus.PENDING) {
        return;
      }
      await this.releaseOrderResources(lockedOrder, manager, reason);
    });
  }

  private async syncSingleSpecCompatibilitySkuStock(
    manager: any,
    productId: number,
  ): Promise<void> {
    const product = await manager.findOne(Product, {
      where: { id: productId },
    });

    if (!product || product.hasSku) {
      return;
    }

    const skus = await manager.find(ProductSku, {
      where: { productId },
    });

    if (skus.length === 0) {
      return;
    }

    const [primarySku, ...extraSkus] = skus;
    primarySku.stock = Math.max(product.stock, 0);
    primarySku.status =
      primarySku.stock > 0 ? SkuStatus.ACTIVE : SkuStatus.OUT_OF_STOCK;
    await manager.save(primarySku);

    for (const sku of extraSkus) {
      sku.stock = 0;
      sku.status = SkuStatus.INACTIVE;
      await manager.save(sku);
    }
  }

  async updateOrderStatus(
    id: number,
    updateOrderStatusDto: UpdateOrderStatusDto,
  ): Promise<Order> {
    const order = await this.findOneOrder(id);
    const now = new Date();

    if (order.orderType === OrderType.SECOND_HAND) {
      throw new BadRequestException("二手订单必须由买卖双方流程或售后仲裁推进");
    }

    // 状态流转验证
    const validTransitions: Record<OrderStatus, OrderStatus[]> = {
      // 普通商品订单状态
      [OrderStatus.PENDING]: [OrderStatus.PAID, OrderStatus.CANCELLED],
      [OrderStatus.PAID]: [OrderStatus.SHIPPED, OrderStatus.CANCELLED],
      [OrderStatus.SHIPPED]: [OrderStatus.COMPLETED],
      [OrderStatus.COMPLETED]: [],
      [OrderStatus.CANCELLED]: [],
    };

    const allowedStatuses = validTransitions[order.status];
    if (!allowedStatuses.includes(updateOrderStatusDto.status)) {
      throw new BadRequestException(
        `订单状态从 ${order.status} 无法变更为 ${updateOrderStatusDto.status}`,
      );
    }

    if (
      updateOrderStatusDto.status === OrderStatus.CANCELLED &&
      order.status === OrderStatus.PAID
    ) {
      throw new BadRequestException("已付款订单必须通过退款流程取消");
    }

    if (
      updateOrderStatusDto.status === OrderStatus.CANCELLED &&
      order.status === OrderStatus.PENDING
    ) {
      await this.cancelPendingOrderInternal(
        order,
        updateOrderStatusDto.cancelReason || "后台取消订单",
      );

      await this.notificationSender.send(
        order.userId,
        "ORDER_CANCELLED" as any,
        { orderId: id, reason: updateOrderStatusDto.cancelReason },
      );

      return this.findOneOrder(id);
    }

    await this.dataSource.transaction(async (manager) => {
      const lockedOrder = await manager.findOne(Order, {
        where: { id },
        lock: { mode: "pessimistic_write" },
      });
      if (!lockedOrder) throw new NotFoundException("订单不存在");
      if (lockedOrder.orderType === OrderType.SECOND_HAND) {
        throw new BadRequestException(
          "二手订单必须由买卖双方流程或售后仲裁推进",
        );
      }
      if (
        !validTransitions[lockedOrder.status].includes(
          updateOrderStatusDto.status,
        )
      ) {
        throw new BadRequestException(
          `订单状态从 ${lockedOrder.status} 无法变更为 ${updateOrderStatusDto.status}`,
        );
      }
      if (
        [OrderStatus.SHIPPED, OrderStatus.COMPLETED].includes(
          updateOrderStatusDto.status,
        )
      ) {
        const activeAfterSale = await manager.count(OrderAfterSale, {
          where: { orderId: id, status: In([...ACTIVE_AFTER_SALE_STATUSES]) },
        });
        if (activeAfterSale > 0) {
          throw new BadRequestException("订单存在进行中的售后，不能推进状态");
        }
      }

      lockedOrder.status = updateOrderStatusDto.status;
      if (updateOrderStatusDto.status === OrderStatus.PAID) {
        lockedOrder.paidAt = now;
      } else if (updateOrderStatusDto.status === OrderStatus.SHIPPED) {
        lockedOrder.shippedAt = now;
        lockedOrder.autoConfirmAt = new Date(
          now.getTime() + 10 * 24 * 60 * 60 * 1000,
        );
      } else if (updateOrderStatusDto.status === OrderStatus.COMPLETED) {
        const normalAfterSaleDays = await this.getNormalAfterSaleDays(manager);
        lockedOrder.completedAt = now;
        lockedOrder.confirmAt = now;
        lockedOrder.afterSaleDeadlineAt = new Date(
          now.getTime() + normalAfterSaleDays * 24 * 60 * 60 * 1000,
        );
      }
      await manager.save(lockedOrder);
    });

    const updated = await this.findOneOrder(id);

    // 根据订单状态发送相应通知
    switch (updateOrderStatusDto.status) {
      case OrderStatus.PAID:
        await this.notificationSender.orderPaid(order.userId, { orderId: id });
        break;
      case OrderStatus.SHIPPED:
        await this.notificationSender.orderShipped(order.userId, {
          orderId: id,
        });
        break;
      case OrderStatus.COMPLETED:
        await this.notificationSender.orderCompleted(order.userId, {
          orderId: id,
        });
        break;
      case OrderStatus.CANCELLED:
        await this.notificationSender.send(
          order.userId,
          "ORDER_CANCELLED" as any,
          { orderId: id, reason: updateOrderStatusDto.cancelReason },
        );
        break;
    }

    return updated;
  }

  /**
   * 设置物流信息（自动标记为已发货）
   * @param id 订单ID
   * @param updateShippingDto 物流信息
   * @returns 更新后的订单
   */
  async setShipping(
    id: number,
    updateShippingDto: UpdateShippingDto,
  ): Promise<Order> {
    const order = await this.findOneOrder(id);

    if (order.orderType === OrderType.SECOND_HAND) {
      throw new BadRequestException("二手订单只能由卖家在 APP 中确认发货");
    }

    // 验证订单状态（只有已支付状态可以设置物流）
    if (order.status !== OrderStatus.PAID) {
      throw new BadRequestException("只有已支付的订单可以设置物流信息");
    }
    await this.assertNoActiveAfterSale(id, "订单存在进行中的售后，不能发货");

    // 验证物流公司是否存在
    const logistics = await this.logisticsService.findOne(
      updateShippingDto.logisticsId,
    );
    if (!logistics.isEnabled) {
      throw new BadRequestException("该物流公司已停用，请选择其他物流");
    }

    // 锁订单后再次核对状态和售后，避免审批与发货并发穿透。
    const now = new Date();
    await this.dataSource.transaction(async (manager) => {
      const lockedOrder = await manager.findOne(Order, {
        where: { id },
        lock: { mode: "pessimistic_write" },
      });
      if (!lockedOrder) throw new NotFoundException("订单不存在");
      if (lockedOrder.orderType === OrderType.SECOND_HAND) {
        throw new BadRequestException("二手订单只能由卖家在 APP 中确认发货");
      }
      if (lockedOrder.status !== OrderStatus.PAID) {
        throw new BadRequestException("只有已支付的订单可以设置物流信息");
      }
      const activeAfterSale = await manager.count(OrderAfterSale, {
        where: { orderId: id, status: In([...ACTIVE_AFTER_SALE_STATUSES]) },
      });
      if (activeAfterSale > 0) {
        throw new BadRequestException("订单存在进行中的售后，不能发货");
      }
      lockedOrder.logisticsId = updateShippingDto.logisticsId;
      lockedOrder.trackingNumber = updateShippingDto.trackingNumber;
      lockedOrder.status = OrderStatus.SHIPPED;
      lockedOrder.shippedAt = now;
      lockedOrder.autoConfirmAt = new Date(
        now.getTime() + 10 * 24 * 60 * 60 * 1000,
      );
      await manager.save(lockedOrder);
    });

    const updated = await this.findOneOrder(id);

    // 发送发货通知
    await this.notificationSender.orderShipped(order.userId, {
      orderId: id,
    });

    return updated;
  }

  /**
   * 获取订单列表（管理员 - 支持搜索和筛选）
   * @param search 搜索关键词（订单号、用户名、手机号）
   * @param status 订单状态
   * @param page 页码
   * @param limit 每页数量
   * @returns 分页订单列表
   */
  async findAllOrdersAdmin(
    search?: string,
    status?: OrderStatus,
    orderType?: OrderType,
    afterSaleStatus?: string,
    settlementStatus?: SettlementStatus,
    page = 1,
    limit = 10,
  ): Promise<{
    data: Order[];
    meta: { total: number; page: number; limit: number };
  }> {
    const queryBuilder = this.orderRepository
      .createQueryBuilder("order")
      .leftJoinAndSelect("order.user", "user")
      .leftJoinAndSelect("order.seller", "seller")
      .leftJoinAndSelect("order.logistics", "logistics");

    // 搜索条件：订单号、用户名、手机号
    if (search) {
      queryBuilder.andWhere(
        "(order.orderNo LIKE :search OR user.username LIKE :search OR user.phone LIKE :search OR seller.username LIKE :search OR seller.phone LIKE :search)",
        { search: `%${search}%` },
      );
    }

    // 状态筛选
    if (status) {
      queryBuilder.andWhere("order.status = :status", { status });
    }
    if (orderType) {
      queryBuilder.andWhere("order.orderType = :orderType", { orderType });
    }
    if (settlementStatus) {
      queryBuilder.andWhere("order.settlementStatus = :settlementStatus", {
        settlementStatus,
      });
    }
    if (afterSaleStatus) {
      queryBuilder.innerJoin(
        OrderAfterSale,
        "adminAfterSale",
        "adminAfterSale.orderId = order.id AND adminAfterSale.status = :afterSaleStatus",
        { afterSaleStatus },
      );
      queryBuilder.distinct(true);
    }

    queryBuilder.orderBy("order.createdAt", "DESC");

    const [data, total] = await queryBuilder
      .skip((page - 1) * limit)
      .take(limit)
      .getManyAndCount();

    // 补充订单项的图片信息
    await this.fillOrderItemsWithImages(data);
    await this.decorateOrderViews(data, undefined, "STAFF");

    return {
      data: serializeShopResponse(data),
      meta: { total, page, limit },
    };
  }

  async cancelOrder(
    id: number,
    userId: number,
    reason?: string,
  ): Promise<Order> {
    const order = await this.findOneOrder(id, userId, "USER");

    if (order.status !== OrderStatus.PENDING) {
      throw new BadRequestException("只能取消待支付订单");
    }
    await this.cancelPendingOrderInternal(order, reason || "用户取消");

    await this.notificationSender.send(userId, "ORDER_CANCELLED" as any, {
      orderId: id,
      reason,
    });

    return this.findOneOrder(id, userId, "USER");
  }

  /**
   * 使用余额支付订单
   * 业务规则：余额扣减、钱包流水、订单支付状态必须原子完成，避免订单和钱包状态不一致。
   */
  private async payOrderWithBalance(
    orderId: number,
    userId: number,
  ): Promise<{ order: Order; paymentParams: any }> {
    const paymentResult = await this.dataSource.transaction(async (manager) => {
      const order = await manager
        .createQueryBuilder(Order, "order")
        .where("order.id = :id", { id: orderId })
        .setLock("pessimistic_write")
        .getOne();

      if (!order) {
        throw createBusinessException(ErrorCode.ORDER_NOT_FOUND, "订单不存在");
      }

      if (order.userId !== userId) {
        throw createBusinessException(
          ErrorCode.BUSINESS_PERMISSION_DENIED,
          "无权支付该订单",
        );
      }

      if (order.status !== OrderStatus.PENDING) {
        throw createBusinessException(
          ErrorCode.BUSINESS_INVALID_PARAM,
          "订单状态不允许支付",
        );
      }

      const feeSnapshot = await this.getPaymentFeeSnapshot(order);

      const user = await manager
        .createQueryBuilder(User, "user")
        .where("user.id = :id", { id: userId })
        .setLock("pessimistic_write")
        .getOne();

      if (!user) {
        throw new NotFoundException("用户不存在");
      }

      const amount = toNumber(order.totalAmount);
      const oldBalance = toNumber(user.balance);

      if (oldBalance < amount) {
        throw createBusinessException(
          ErrorCode.INSUFFICIENT_BALANCE,
          "余额不足",
        );
      }

      await this.paymentService.closePendingShopPaymentsForChannelSwitch(
        order.id,
        PaymentChannel.BALANCE,
      );

      const newBalance = subtract(oldBalance, amount);
      const balancePaymentNo = `BALANCE_${order.orderNo}_${Date.now()}`;
      const paidAt = new Date();

      user.balance = newBalance;
      await manager.save(user);

      const walletTransaction = manager.create(WalletTransaction, {
        userId,
        type: WalletTransactionType.EXPENSE,
        amount,
        balanceBefore: oldBalance,
        balanceAfter: newBalance,
        relatedType: RelatedType.ORDER,
        relatedId: order.id,
        status: WalletTransactionStatus.APPROVED,
        remark: `余额支付订单 ${order.orderNo}`,
        reviewedAt: paidAt,
        reviewedBy: userId,
        autoProcessed: false,
      });
      await manager.save(WalletTransaction, walletTransaction);

      const outTradeNo = `${BusinessType.SHOP_ORDER}_${order.id}_B_${Date.now()}`;
      const balancePayment = manager.create(Payment, {
        paymentNo: balancePaymentNo,
        outTradeNo,
        channel: PaymentChannel.BALANCE,
        method: PaymentMethod.APP,
        status: PaymentStatus.SUCCESS,
        amount,
        refundAmount: 0,
        transactionId: balancePaymentNo,
        thirdPartyTradeNo: balancePaymentNo,
        userId,
        businessType: BusinessType.SHOP_ORDER,
        businessId: order.id,
        subject: `商城订单支付 - ${order.items[0]?.productName || order.orderNo}`,
        body: (order.items || [])
          .map((item) => `${item.productName} x${item.quantity}`)
          .join(", "),
        metadata: { balancePayment: true },
        paidAt,
        updatedAt: paidAt,
      });
      await manager.save(Payment, balancePayment);
      await this.paymentService.fulfillShopOrderDonation(
        manager,
        order,
        balancePayment,
      );

      await manager.update(Order, order.id, {
        status: OrderStatus.PAID,
        paidAt,
        paymentMethod: "balance",
        paymentNo: balancePaymentNo,
        transactionId: balancePaymentNo,
        ...feeSnapshot,
      });

      this.logger.log(
        `Order paid with balance: orderId=${order.id}, userId=${userId}, amount=${amount}, paymentNo=${balancePaymentNo}`,
      );

      return {
        paymentNo: balancePaymentNo,
        sellerId: order.sellerId,
      };
    });

    await this.notificationSender.orderPaid(userId, {
      orderId,
    });
    if (paymentResult.sellerId) {
      await this.notificationSender.orderPaid(paymentResult.sellerId, {
        orderId,
        viewRole: "seller",
      } as any);
    }

    return {
      order: await this.findOneOrder(orderId, userId, "USER"),
      paymentParams: {
        paymentNo: paymentResult.paymentNo,
        isBalance: true,
      },
    };
  }

  /**
   * 发起订单支付
   * @param orderId 订单ID
   * @param userId 用户ID
   * @param paymentChannel 支付渠道
   * @returns 支付参数
   */
  async payOrder(
    orderId: number,
    userId: number,
    paymentChannel: PaymentChannel,
  ): Promise<{ order: Order; paymentParams: any }> {
    // 1. 验证订单归属和状态
    const order = await this.findOneOrder(orderId, userId, "USER");

    if (order.status !== OrderStatus.PENDING) {
      throw createBusinessException(
        ErrorCode.BUSINESS_INVALID_PARAM,
        "订单状态不允许支付",
      );
    }

    if (paymentChannel === PaymentChannel.BALANCE) {
      return this.payOrderWithBalance(orderId, userId);
    }

    // 2. 记录支付方式，支付单创建成功后再写入订单
    const paymentMethod = this.getPaymentMethodString(paymentChannel);
    const feeSnapshot = await this.getPaymentFeeSnapshot(order);

    // 3. 创建支付
    try {
      const paymentParams = await this.paymentService.createPayment({
        channel: paymentChannel,
        method: this.mapPaymentMethodFromChannel(paymentChannel),
        amount: order.totalAmount,
        userId,
        businessType: BusinessType.SHOP_ORDER,
        businessId: order.id,
        subject: `商城订单支付 - ${order.items[0].productName}${order.items.length > 1 ? ` 等${order.items.length}件商品` : ""}`,
        body: order.items
          .map((item) => `${item.productName} x${item.quantity}`)
          .join(", "),
        expireIn: 900, // 15分钟过期
      });

      // 更新支付单号
      await this.orderRepository.update(orderId, {
        paymentNo: paymentParams.paymentNo,
        paymentMethod,
        ...feeSnapshot,
      });

      this.logger.log(
        `Order payment created: orderId=${orderId}, paymentNo=${paymentParams.paymentNo}`,
      );

      return {
        order: await this.findOneOrder(orderId, userId, "USER"),
        paymentParams,
      };
    } catch (error) {
      // 保留支付方式和支付单关联，便于重试时复用原支付单并追踪失败原因。
      throw error;
    }
  }

  private async getPaymentFeeSnapshot(order: Order): Promise<{
    platformFeeRate?: number;
    platformFee?: number;
    sellerIncome?: number;
  }> {
    if (order.orderType !== OrderType.SECOND_HAND) return {};
    if (!order.sellerId) {
      throw new BadRequestException("二手订单缺少卖家信息，无法支付");
    }

    const platformFeeRate = Number(
      await this.platformFeeService.getPlatformFeeRate(),
    );
    const totalAmount = toNumber(order.totalAmount);
    const platformFee = Number(
      ((totalAmount * platformFeeRate) / 100).toFixed(2),
    );
    return {
      platformFeeRate,
      platformFee,
      sellerIncome: Number((totalAmount - platformFee).toFixed(2)),
    };
  }

  /**
   * 确认收货
   * @param orderId 订单ID
   * @param userId 用户ID
   * @returns 更新后的订单
   */
  async confirmOrder(orderId: number, userId: number): Promise<Order> {
    const updatedOrder = await this.completeOrderInternal(orderId, userId);
    await this.notificationSender.orderCompleted(updatedOrder.userId, {
      orderId,
      viewRole: "buyer",
    } as any);
    if (updatedOrder.sellerId) {
      await this.notificationSender.orderCompleted(updatedOrder.sellerId, {
        orderId,
        viewRole: "seller",
      } as any);
    }
    return this.findOneOrder(orderId, userId, "USER");
  }

  private async completeOrderInternal(
    orderId: number,
    expectedBuyerId?: number,
  ): Promise<Order> {
    return this.dataSource.transaction(async (manager) => {
      const order = await manager.findOne(Order, {
        where: { id: orderId },
        lock: { mode: "pessimistic_write" },
      });
      if (!order) throw new NotFoundException("订单不存在");
      if (expectedBuyerId && order.userId !== expectedBuyerId) {
        throw new BadRequestException("只有订单买家可以确认收货");
      }
      if (order.status !== OrderStatus.SHIPPED) {
        throw new BadRequestException("只能确认已发货的订单");
      }
      const activeAfterSale = await manager.count(OrderAfterSale, {
        where: {
          orderId,
          status: In([...ACTIVE_AFTER_SALE_STATUSES]),
        },
      });
      if (activeAfterSale > 0) {
        throw new BadRequestException("订单存在进行中的售后，不能确认收货");
      }

      const now = new Date();
      order.status = OrderStatus.COMPLETED;
      order.completedAt = now;
      order.confirmAt = now;
      if (order.orderType === OrderType.NORMAL) {
        const normalAfterSaleDays = await this.getNormalAfterSaleDays(manager);
        order.afterSaleDeadlineAt = new Date(
          now.getTime() + normalAfterSaleDays * 24 * 60 * 60 * 1000,
        );
      }
      await manager.save(order);
      await this.processSellerSettlement(order, manager);
      return order;
    });
  }

  /**
   * 将支付渠道转换为字符串存储
   */
  private getPaymentMethodString(channel: PaymentChannel): string {
    if (channel === PaymentChannel.BALANCE) {
      return "balance";
    } else if (channel.startsWith("alipay")) {
      return "alipay";
    } else if (channel.startsWith("wechat")) {
      return "wechat";
    }
    return "other";
  }

  /**
   * 根据支付渠道推导支付方式
   * 业务规则：支付方式必须与第三方接口能力一致，避免所有渠道都被错误写死为 APP
   */
  private mapPaymentMethodFromChannel(channel: PaymentChannel): PaymentMethod {
    switch (channel) {
      case PaymentChannel.ALIPAY:
      case PaymentChannel.WECHAT:
        return PaymentMethod.APP;
      case PaymentChannel.ALIPAY_WAP:
      case PaymentChannel.ALIPAY_WEB:
        return PaymentMethod.WEB;
      case PaymentChannel.WECHAT_H5:
        return PaymentMethod.H5;
      case PaymentChannel.WECHAT_NATIVE:
        return PaymentMethod.NATIVE;
      case PaymentChannel.WECHAT_JSAPI:
        return PaymentMethod.JSAPI;
      default:
        return PaymentMethod.APP;
    }
  }

  async findMyOrders(userId: number): Promise<Order[]> {
    return this.orderRepository.find({
      where: { userId },
      order: { createdAt: "DESC" },
    });
  }

  /**
   * 分页查询我的订单（支持状态筛选）
   * @param userId 用户ID
   * @param query 查询参数（分页、状态筛选）
   * @returns 分页订单列表
   */
  async findMyOrdersPaginated(
    userId: number,
    query: QueryOrderDto,
    viewRole: "buyer" | "seller" = "buyer",
  ): Promise<PaginatedResult<Order>> {
    const {
      page = 1,
      pageSize = 20,
      status,
      orderType,
      afterSaleStatus,
    } = query;

    const queryBuilder = this.orderRepository
      .createQueryBuilder("order")
      .leftJoinAndSelect("order.user", "user")
      .leftJoinAndSelect("order.seller", "seller")
      .where(
        viewRole === "seller"
          ? "order.sellerId = :userId AND order.orderType = :secondHand"
          : "order.userId = :userId",
        { userId, secondHand: OrderType.SECOND_HAND },
      );

    // 状态筛选
    if (status) {
      queryBuilder.andWhere("order.status = :status", { status });
    }
    if (orderType) {
      queryBuilder.andWhere("order.orderType = :orderType", { orderType });
    }
    if (afterSaleStatus) {
      queryBuilder.innerJoin(
        OrderAfterSale,
        "filterAfterSale",
        "filterAfterSale.orderId = order.id",
      );
      if (afterSaleStatus === "active") {
        queryBuilder.andWhere(
          "filterAfterSale.status IN (:...activeStatuses)",
          {
            activeStatuses: ACTIVE_AFTER_SALE_STATUSES,
          },
        );
      } else if (afterSaleStatus !== "any") {
        queryBuilder.andWhere("filterAfterSale.status = :afterSaleStatus", {
          afterSaleStatus,
        });
      }
      queryBuilder.distinct(true);
    }

    // 按创建时间降序排序
    queryBuilder.orderBy("order.createdAt", "DESC");

    // 分页
    queryBuilder.skip((page - 1) * pageSize).take(pageSize);

    const [data, total] = await queryBuilder.getManyAndCount();

    // 补充订单项的图片信息（如果订单项没有图片，则从商品表查询）
    await this.fillOrderItemsWithImages(data);
    await this.decorateOrderViews(data, userId, "USER");

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  async getOrderActionSummary(userId: number) {
    if (!this.afterSaleRepository) {
      return {
        purchases: { pendingReceipt: 0, afterSaleResult: 0 },
        sales: { pendingShipment: 0, pendingAfterSale: 0 },
      };
    }
    const [buyerOrders, sellerOrders, buyerAfterSales, sellerAfterSales] =
      await Promise.all([
        this.orderRepository.find({ where: { userId } }),
        this.orderRepository.find({
          where: { sellerId: userId, orderType: OrderType.SECOND_HAND },
        }),
        this.afterSaleRepository.find({ where: { buyerId: userId } }),
        this.afterSaleRepository.find({ where: { sellerId: userId } }),
      ]);
    const active = new Set<string>(ACTIVE_AFTER_SALE_STATUSES);
    const buyerActiveOrderIds = new Set(
      buyerAfterSales
        .filter((item) => active.has(item.status))
        .map((item) => item.orderId),
    );
    const sellerActiveOrderIds = new Set(
      sellerAfterSales
        .filter((item) => active.has(item.status))
        .map((item) => item.orderId),
    );
    return {
      purchases: {
        pendingReceipt: buyerOrders.filter(
          (order) =>
            order.status === OrderStatus.SHIPPED &&
            !buyerActiveOrderIds.has(order.id),
        ).length,
        afterSaleResult: buyerAfterSales.filter((item) =>
          [AfterSaleStatus.REFUNDED, AfterSaleStatus.CLOSED].includes(
            item.status,
          ),
        ).length,
      },
      sales: {
        pendingShipment: sellerOrders.filter(
          (order) =>
            order.status === OrderStatus.PAID &&
            !sellerActiveOrderIds.has(order.id),
        ).length,
        pendingAfterSale: sellerAfterSales.filter((item) =>
          [
            AfterSaleStatus.PENDING_HANDLER,
            AfterSaleStatus.WAITING_HANDLER_RECEIPT,
          ].includes(item.status),
        ).length,
      },
    };
  }

  /**
   * 为订单项补充图片信息
   * 如果订单项的 productImage 为空，则从商品表查询图片（优先使用图片数组第一张）
   * @param orders 订单列表
   * @param forceUpdate 是否强制更新所有订单项的图片（包括已有图片的），默认 false
   */
  private async fillOrderItemsWithImages(
    orders: Order[],
    forceUpdate: boolean = false,
  ): Promise<void> {
    // 收集所有需要查询图片的商品ID
    const productIds = new Set<number>();
    const itemsNeedImage: OrderItem[] = [];

    for (const order of orders) {
      if (!order.items) continue;

      for (const item of order.items) {
        // 如果不是强制更新，且订单项已有图片，跳过
        if (!forceUpdate && item.productImage) continue;

        itemsNeedImage.push(item);

        // 收集需要查询的商品ID
        if (item.productId) {
          productIds.add(item.productId);
        }
      }
    }

    // 如果没有需要查询的数据，直接返回
    if (itemsNeedImage.length === 0) {
      return;
    }

    // 批量查询商品图片（包含 image 和 images 字段）
    const productImageMap = new Map<number, string>();
    if (productIds.size > 0) {
      const products = await this.productRepository
        .createQueryBuilder("product")
        .select(["product.id", "product.image", "product.images"])
        .where("product.id IN (:...productIds)", {
          productIds: Array.from(productIds),
        })
        .getMany();

      for (const product of products) {
        // 优先使用图片数组的第一张，否则使用主图
        const image =
          product.images && product.images.length > 0
            ? product.images[0]
            : product.image;

        if (image) {
          productImageMap.set(product.id, image);
        }
      }
    }

    // 填充图片到订单项
    for (const item of itemsNeedImage) {
      // 使用商品图片（强制更新或原有图片为空时）
      if (item.productId && productImageMap.has(item.productId)) {
        item.productImage = productImageMap.get(item.productId);
      }
    }
  }

  /**
   * 处理支付回调
   * 由 PaymentModule 调用
   */
  async handlePaymentWebhook(
    payment: Payment,
    event: string,
    data?: any,
  ): Promise<void> {
    const { businessId, businessType } = payment;

    // 确认是商城订单
    if (businessType !== BusinessType.SHOP_ORDER) {
      this.logger.warn(
        `Invalid business type for shop webhook: ${businessType}`,
      );
      return;
    }

    const order = await this.orderRepository.findOne({
      where: { id: businessId },
    });

    if (!order) {
      this.logger.error(`Order not found for payment webhook: ${businessId}`);
      return;
    }

    if (event === "ORDER_PAID_NOTIFICATION") {
      await this.notificationSender.orderPaid(order.userId, {
        orderId: order.id,
        viewRole: "buyer",
      } as any);
      if (order.sellerId) {
        await this.notificationSender.orderPaid(order.sellerId, {
          orderId: order.id,
          viewRole: "seller",
        } as any);
      }
    }
    // 处理支付成功事件
    else if (event === "PAYMENT_SUCCESS") {
      if (order.status !== OrderStatus.PENDING) {
        this.logger.warn(
          `Order ${order.orderNo} already processed, status: ${order.status}`,
        );
        return;
      }

      // 支付回调必须与订单快照严格匹配，避免异常支付单推进他人订单
      if (payment.userId !== order.userId) {
        this.logger.error(
          `Payment webhook user mismatch: payment=${payment.paymentNo}, paymentUserId=${payment.userId}, orderId=${order.id}, orderUserId=${order.userId}`,
        );
        return;
      }

      if (!equals(payment.amount, order.totalAmount)) {
        this.logger.error(
          `Payment webhook amount mismatch: payment=${payment.paymentNo}, paymentAmount=${payment.amount}, orderId=${order.id}, orderAmount=${order.totalAmount}`,
        );
        return;
      }

      if (
        payment.businessType !== BusinessType.SHOP_ORDER ||
        payment.businessId !== order.id
      ) {
        this.logger.error(
          `Payment webhook business mismatch: payment=${payment.paymentNo}, businessType=${payment.businessType}, businessId=${payment.businessId}, orderId=${order.id}`,
        );
        return;
      }

      await this.orderRepository.update(order.id, {
        status: OrderStatus.PAID,
        paidAt: new Date(),
        transactionId: payment.transactionId,
      });

      this.logger.log(`Order ${order.orderNo} paid successfully`);
    } else if (event === "PAYMENT_CLOSED" || event === "PAYMENT_FAILED") {
      if (order.status !== OrderStatus.PENDING) {
        return;
      }

      await this.cancelPendingOrderInternal(
        order,
        event === "PAYMENT_CLOSED" ? "支付超时自动取消" : "支付失败自动取消",
      );

      await this.notificationSender.send(
        order.userId,
        "ORDER_CANCELLED" as any,
        {
          orderId: order.id,
          reason:
            event === "PAYMENT_CLOSED"
              ? "支付超时自动取消"
              : "支付失败自动取消",
        },
      );
    }
    // 处理退款成功事件
    else if (event === "REFUND_SUCCESS") {
      this.logger.log(
        `Order ${order.orderNo} refunded: ${JSON.stringify(data)}`,
      );

      if (
        toNumber(payment.refundAmount) >= toNumber(payment.amount) &&
        order.status !== OrderStatus.CANCELLED
      ) {
        await this.dataSource.transaction((manager) =>
          this.finalizeRefundedOrder(order.id, manager, "退款成功自动回补库存"),
        );

        await this.notificationSender.send(
          order.userId,
          "ORDER_CANCELLED" as any,
          {
            orderId: order.id,
            reason: "退款成功自动回补库存",
          },
        );
      }
    }
  }

  /**
   * 生成唯一订单号（使用 UUID）
   * 格式：ORD + UUID的前28位（大写）
   * UUID 保证全局唯一性，避免高并发下的重复问题
   */
  private generateOrderNo(): string {
    const uuid = randomUUID().replace(/-/g, "").toUpperCase().substring(0, 28);
    return `ORD${uuid}`;
  }

  private buildOrderItemSnapshots(
    items: OrderItem[],
    couponDiscount: number,
  ): OrderItem[] {
    const lineCents = items.map(
      (item) => toCents(item.price) * Number(item.quantity),
    );
    const originalCents = lineCents.reduce((sum, value) => sum + value, 0);
    const discountCents = Math.min(toCents(couponDiscount), originalCents);
    let allocatedDiscount = 0;

    return items.map((item, index) => {
      const lineDiscount =
        index === items.length - 1
          ? discountCents - allocatedDiscount
          : originalCents > 0
            ? Math.floor((discountCents * lineCents[index]) / originalCents)
            : 0;
      allocatedDiscount += lineDiscount;
      return {
        ...item,
        lineKey: randomUUID(),
        discountAmount: toYuan(lineDiscount),
        paidAmount: toYuan(lineCents[index] - lineDiscount),
      };
    });
  }

  // ========== 用户发布商品结算相关方法 ==========

  /**
   * 处理用户发布商品的结算（确认收货后调用）
   * @param order 订单对象
   * @param manager QueryRunner 的 manager（用于事务）
   */
  async processSellerSettlement(order: Order, manager?: any) {
    if (!manager) {
      return this.dataSource.transaction(async (transactionManager) =>
        this.processSellerSettlement(order, transactionManager),
      );
    }

    const lockedOrder = await manager
      .createQueryBuilder(Order, "order")
      .where("order.id = :id", { id: order.id })
      .setLock("pessimistic_write")
      .getOne();

    if (!lockedOrder) {
      throw new NotFoundException("订单不存在");
    }

    if (
      lockedOrder.orderType !== OrderType.SECOND_HAND ||
      !lockedOrder.sellerId
    ) {
      return;
    }

    if (lockedOrder.status !== OrderStatus.COMPLETED) {
      this.logger.log(
        `Skip seller settlement for order ${lockedOrder.orderNo}: status=${lockedOrder.status}`,
      );
      return;
    }

    if (
      lockedOrder.settlementStatus === SettlementStatus.SETTLING ||
      lockedOrder.settlementStatus === SettlementStatus.SETTLED
    ) {
      this.logger.log(
        `Skip seller settlement for order ${lockedOrder.orderNo}: settlementStatus=${lockedOrder.settlementStatus}`,
      );
      return;
    }
    const activeAfterSale = await manager.count(OrderAfterSale, {
      where: {
        orderId: lockedOrder.id,
        status: In([...ACTIVE_AFTER_SALE_STATUSES]),
      },
    });
    if (activeAfterSale > 0) {
      this.logger.log(
        `Skip seller settlement for order ${lockedOrder.orderNo}: active after-sale`,
      );
      return;
    }

    const existingTransaction = await manager.findOne(WalletTransaction, {
      where: {
        relatedType: RelatedType.ORDER,
        relatedId: lockedOrder.id,
        type: WalletTransactionType.INCOME,
      },
    });
    if (existingTransaction) {
      await manager.update(Order, lockedOrder.id, {
        settlementStatus:
          existingTransaction.status === WalletTransactionStatus.APPROVED
            ? SettlementStatus.SETTLED
            : SettlementStatus.SETTLING,
        settlementId: existingTransaction.id,
      });
      return;
    }

    const feeRate = Number(
      lockedOrder.platformFeeRate ??
        (await this.platformFeeService.getPlatformFeeRate()),
    );
    const grossAmount = toNumber(lockedOrder.totalAmount);
    const platformFee = Number(((grossAmount * feeRate) / 100).toFixed(2));
    const sellerIncome = Number((grossAmount - platformFee).toFixed(2));
    const transaction = await this.updateSellerBalanceAndCreateTransaction(
      lockedOrder.sellerId,
      { grossAmount, platformFee, sellerIncome },
      lockedOrder.id,
      manager,
    );

    await manager.update(Order, lockedOrder.id, {
      platformFeeRate: feeRate,
      platformFee,
      sellerIncome,
      settlementStatus: SettlementStatus.SETTLING,
      settlementId: transaction.id,
    });

    this.logger.log(
      `Seller settlement processed for order ${lockedOrder.orderNo}`,
    );
  }

  /**
   * 更新卖家待审核余额并创建钱包流水记录
   * @param sellerId 卖家ID
   * @param amount 金额
   * @param orderId 订单ID
   * @param manager QueryRunner 的 manager（用于事务）
   */
  private async updateSellerBalanceAndCreateTransaction(
    sellerId: number,
    settlement: {
      grossAmount: number;
      platformFee: number;
      sellerIncome: number;
    },
    orderId: number,
    manager: any,
  ): Promise<WalletTransaction> {
    // 使用悲观锁获取卖家，防止并发更新
    const seller = await manager
      .createQueryBuilder(User, "user")
      .where("user.id = :id", { id: sellerId })
      .setLock("pessimistic_write")
      .getOne();

    if (!seller) {
      throw new NotFoundException(`卖家不存在: ${sellerId}`);
    }

    const oldPendingBalance = toNumber(seller.pendingBalance);
    const newPendingBalance = add(oldPendingBalance, settlement.sellerIncome);

    // 更新卖家待审核余额
    seller.pendingBalance = newPendingBalance;
    await manager.save(seller);

    // 创建钱包明细记录
    const walletTransaction = manager.create(WalletTransaction, {
      userId: sellerId,
      type: WalletTransactionType.INCOME,
      amount: settlement.sellerIncome,
      balanceBefore: oldPendingBalance,
      balanceAfter: newPendingBalance,
      relatedType: RelatedType.ORDER,
      relatedId: orderId,
      status: WalletTransactionStatus.PENDING,
      remark: `用户发布商品销售结算（成交¥${settlement.grossAmount.toFixed(2)}，手续费¥${settlement.platformFee.toFixed(2)}）`,
    });

    const savedTransaction = await manager.save(walletTransaction);

    this.logger.log(
      `Seller balance updated: sellerId=${sellerId}, gross=${settlement.grossAmount}, income=${settlement.sellerIncome}, newPendingBalance=${newPendingBalance}`,
    );
    return savedTransaction;
  }

  // ========== SKU 相关方法 ==========

  /**
   * 获取商品的所有 SKU
   * @param productId 商品ID
   * @returns SKU 列表
   */
  async getProductSkus(productId: number): Promise<ProductSku[]> {
    // 验证商品是否存在
    const product = await this.productRepository.findOne({
      where: { id: productId },
    });
    if (!product) {
      throw createBusinessException(ErrorCode.PRODUCT_NOT_FOUND);
    }

    return this.productSkuRepository.find({
      where: { productId },
      order: { createdAt: "ASC" },
    });
  }

  /**
   * 创建单个 SKU
   * @param productId 商品ID
   * @param createSkuDto SKU 创建 DTO
   * @returns 创建的 SKU
   */
  async createSku(
    productId: number,
    createSkuDto: CreateProductSkuDto,
  ): Promise<ProductSku> {
    // 验证商品是否存在
    const product = await this.productRepository.findOne({
      where: { id: productId },
    });
    if (!product) {
      throw createBusinessException(ErrorCode.PRODUCT_NOT_FOUND);
    }

    // 检查 SKU 编码是否重复
    if (createSkuDto.skuCode) {
      const existing = await this.productSkuRepository.findOne({
        where: { skuCode: createSkuDto.skuCode },
      });
      if (existing) {
        throw createBusinessException(
          ErrorCode.BUSINESS_INVALID_PARAM,
          "SKU 编码已存在",
        );
      }
    }

    // 创建 SKU
    const sku = this.productSkuRepository.create({
      ...createSkuDto,
      productId,
    });

    // 更新商品为多规格商品
    await this.productRepository.update(productId, { hasSku: true });

    return this.productSkuRepository.save(sku);
  }

  /**
   * 批量创建 SKU
   * @param productId 商品ID
   * @param createSkuBatchDto 批量创建 DTO
   * @returns 创建的 SKU 列表
   */
  async createSkuBatch(
    productId: number,
    createSkuBatchDto: CreateProductSkuBatchDto,
  ): Promise<ProductSku[]> {
    // 验证商品是否存在
    const product = await this.productRepository.findOne({
      where: { id: productId },
    });
    if (!product) {
      throw createBusinessException(ErrorCode.PRODUCT_NOT_FOUND);
    }

    // 检查 SKU 编码是否重复
    const skuCodes = createSkuBatchDto.skus
      .filter((s) => s.skuCode)
      .map((s) => s.skuCode);
    if (skuCodes.length > 0) {
      const existing = await this.productSkuRepository.find({
        where: skuCodes.map((code) => ({ skuCode: code })),
      });
      if (existing.length > 0) {
        throw createBusinessException(
          ErrorCode.BUSINESS_INVALID_PARAM,
          "部分 SKU 编码已存在",
        );
      }
    }

    // 批量创建 SKU
    const skus = createSkuBatchDto.skus.map((dto) =>
      this.productSkuRepository.create({
        ...dto,
        productId,
      }),
    );

    // 更新商品为多规格商品
    await this.productRepository.update(productId, { hasSku: true });

    return this.productSkuRepository.save(skus);
  }

  /**
   * 更新 SKU
   * @param productId 商品ID
   * @param skuId SKU ID
   * @param updateSkuDto 更新 DTO
   * @returns 更新后的 SKU
   */
  async updateSku(
    productId: number,
    skuId: number,
    updateSkuDto: UpdateProductSkuDto,
  ): Promise<ProductSku> {
    // 验证 SKU 是否存在
    const sku = await this.productSkuRepository.findOne({
      where: { id: skuId, productId },
    });
    if (!sku) {
      throw createBusinessException(ErrorCode.PRODUCT_NOT_FOUND, "SKU 不存在");
    }

    // 检查 SKU 编码是否重复
    if (updateSkuDto.skuCode && updateSkuDto.skuCode !== sku.skuCode) {
      const existing = await this.productSkuRepository.findOne({
        where: { skuCode: updateSkuDto.skuCode },
      });
      if (existing) {
        throw createBusinessException(
          ErrorCode.BUSINESS_INVALID_PARAM,
          "SKU 编码已存在",
        );
      }
    }

    // 更新 SKU
    Object.assign(sku, updateSkuDto);
    return this.productSkuRepository.save(sku);
  }

  /**
   * 删除 SKU
   * @param productId 商品ID
   * @param skuId SKU ID
   */
  async removeSku(productId: number, skuId: number): Promise<void> {
    // 验证 SKU 是否存在
    const sku = await this.productSkuRepository.findOne({
      where: { id: skuId, productId },
    });
    if (!sku) {
      throw createBusinessException(ErrorCode.PRODUCT_NOT_FOUND, "SKU 不存在");
    }

    await this.productSkuRepository.remove(sku);

    // 检查商品是否还有其他 SKU，如果没有则取消多规格标记
    const remainingCount = await this.productSkuRepository.count({
      where: { productId },
    });
    if (remainingCount === 0) {
      await this.productRepository.update(productId, { hasSku: false });
    }
  }

  /**
   * 获取热门商品列表
   * 优先显示 isTop=true 的商品，然后按 isHot 和销量排序
   * @param query 查询参数
   * @returns 商品列表
   */
  async getPopularProducts(
    query: QueryProductDto,
    currentUserId?: number,
  ): Promise<PaginatedResult<Product>> {
    const { page = 1, pageSize = 10, category, categoryId } = query;
    const blockedUserIds =
      await this.moderationService?.getBlockedUserIds(currentUserId);

    if (!category && !categoryId) {
      const configuredHotProducts = (
        await this.getConfiguredMallHotProducts()
      ).filter(
        (product) =>
          !product.publishedBy ||
          !blockedUserIds?.includes(product.publishedBy),
      );

      if (configuredHotProducts.length > 0) {
        const startIndex = (page - 1) * pageSize;
        const endIndex = startIndex + pageSize;
        const pagedProducts = configuredHotProducts.slice(startIndex, endIndex);

        return {
          data: serializeShopResponse(pagedProducts),
          total: configuredHotProducts.length,
          page,
          pageSize,
          totalPages: Math.ceil(configuredHotProducts.length / pageSize),
        };
      }
    }

    const queryBuilder = this.productRepository
      .createQueryBuilder("product")
      .leftJoinAndSelect("product.skus", "sku")
      .leftJoinAndSelect("product.publisher", "publisher")
      .where("product.isActive = :isActive", { isActive: true });

    await this.applyBlockedPublishersFilter(queryBuilder, currentUserId);

    // 分类筛选（旧版枚举分类）
    if (category) {
      queryBuilder.andWhere("product.category = :category", { category });
    }

    if (categoryId) {
      const filterCategoryIds = await this.resolveCategoryFilterIds(categoryId);

      if (filterCategoryIds.length > 0) {
        queryBuilder.andWhere("product.categoryId IN (:...filterCategoryIds)", {
          filterCategoryIds,
        });
      } else {
        queryBuilder.andWhere("product.categoryId = :missingCategoryId", {
          missingCategoryId: -1,
        });
      }
    }

    // 排序：isTop 优先，然后 isHot，最后按创建时间降序（最新添加的）
    queryBuilder
      .orderBy("product.isTop", "DESC")
      .addOrderBy("product.isHot", "DESC")
      .addOrderBy("product.createdAt", "DESC");

    queryBuilder.skip((page - 1) * pageSize).take(pageSize);

    const [items, total] = await queryBuilder.getManyAndCount();

    return {
      data: serializeShopResponse(items),
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 获取所有商品（用于选择器）
   *
   * @returns 所有已审核通过且启用的商品列表（仅包含 id 和 name）
   */
  async getAllProducts(): Promise<Array<{ id: number; name: string }>> {
    const products = await this.productRepository.find({
      where: {
        isActive: true,
      },
      select: ["id", "name"],
      order: {
        name: "ASC",
      },
    });

    return products;
  }

  /**
   * 批量获取商品（完整分类树版本）
   * 返回所有一级分类、二级分类及商品，前端自行处理展示逻辑
   *
   * @param dto 批量查询参数
   * @returns 完整的分类树结构：一级分类 → 二级分类 → 商品
   */
  async batchGetProducts(dto: BatchGetProductsDto) {
    const { includeEmpty, limit, sortBy, sortOrder } = dto;

    this.logger.log(
      `batchGetProducts: 查询完整分类树，includeEmpty=${includeEmpty}, limit=${limit}, sortBy=${sortBy}, sortOrder=${sortOrder}`,
    );

    // 1. 查询所有启用的一级分类（parentId 为 null）
    const firstLevelCategories = await this.categoryRepository.find({
      where: {
        parentId: null as any,
        status: CategoryStatus.ACTIVE,
      },
      order: {
        sortOrder: "ASC",
        createdAt: "DESC",
      },
    });

    this.logger.log(`找到 ${firstLevelCategories.length} 个一级分类`);

    // 2. 为每个一级分类查询其二级分类和商品
    const result = await Promise.all(
      firstLevelCategories.map(async (firstLevel) => {
        // 查询该一级分类下的所有二级分类
        const secondLevelCategories = await this.categoryRepository.find({
          where: {
            parentId: firstLevel.id,
            status: CategoryStatus.ACTIVE,
          },
          order: {
            sortOrder: "ASC",
            createdAt: "DESC",
          },
        });

        this.logger.log(
          `一级分类 "${firstLevel.name}" 下有 ${secondLevelCategories.length} 个二级分类`,
        );

        // 为每个二级分类查询商品
        const childrenWithProducts = await Promise.all(
          secondLevelCategories.map(async (secondLevel) => {
            // 查询该二级分类下的商品
            const products = await this.productRepository.find({
              where: {
                categoryId: secondLevel.id,
                isActive: true,
              },
              order: {
                [sortBy]: sortOrder,
              },
              take: limit || undefined, // 0 或 undefined 表示不限制
              relations: ["skus", "publisher"],
            });

            // 如果不包含空分类且该分类下没有商品，则跳过
            if (!includeEmpty && products.length === 0) {
              return null;
            }

            return {
              id: secondLevel.id,
              name: secondLevel.name,
              icon: secondLevel.icon,
              image: secondLevel.image,
              sortOrder: secondLevel.sortOrder,
              products,
            };
          }),
        );

        // 过滤掉 null 值（空分类）
        const validChildren = childrenWithProducts.filter(
          (child) => child !== null,
        );

        // 如果不包含空分类且该一级分类下没有有效二级分类，则跳过
        if (!includeEmpty && validChildren.length === 0) {
          return null;
        }

        return {
          id: firstLevel.id,
          name: firstLevel.name,
          icon: firstLevel.icon,
          image: firstLevel.image,
          sortOrder: firstLevel.sortOrder,
          children: validChildren,
        };
      }),
    );

    // 过滤掉 null 值（空一级分类）
    const validResult = result.filter((item) => item !== null);

    this.logger.log(
      `batchGetProducts: 返回 ${validResult.length} 个有效一级分类`,
    );

    return {
      data: validResult,
    };
  }

  /**
   * 自动取消未支付的普通订单（30 分钟）
   * 恢复库存并重新上架用户商品
   */
  async autoCancelPendingOrders() {
    const threshold = new Date(Date.now() - 30 * 60 * 1000);

    const orders = await this.orderRepository.find({
      where: {
        status: OrderStatus.PENDING,
        createdAt: LessThan(threshold),
      },
    });

    let processed = 0;

    for (const order of orders) {
      await this.cancelPendingOrderInternal(order, "30分钟未支付自动取消");

      processed += 1;
    }

    return { processed, total: orders.length };
  }

  /**
   * 自动确认已发货订单（10 天）
   */
  async autoConfirmShippedOrders() {
    const now = new Date();

    const orders = await this.orderRepository.find({
      where: {
        status: OrderStatus.SHIPPED,
        autoConfirmAt: LessThanOrEqual(now),
      },
    });

    let processed = 0;

    for (const order of orders) {
      try {
        const activeAfterSale = this.afterSaleRepository
          ? await this.afterSaleRepository.count({
              where: {
                orderId: order.id,
                status: In([...ACTIVE_AFTER_SALE_STATUSES]),
              },
            })
          : 0;
        if (activeAfterSale > 0) continue;
        const completedOrder = await this.completeOrderInternal(order.id);
        await this.notificationSender.orderCompleted(completedOrder.userId, {
          orderId: completedOrder.id,
          viewRole: "buyer",
        } as any);
        if (completedOrder.sellerId) {
          await this.notificationSender.orderCompleted(
            completedOrder.sellerId,
            {
              orderId: completedOrder.id,
              viewRole: "seller",
            } as any,
          );
        }
        processed += 1;
      } catch (error) {
        this.logger.error(
          `Auto confirm shipped order failed: orderId=${order.id}, message=${error.message}`,
        );
      }
    }

    return { processed, total: orders.length };
  }
}
