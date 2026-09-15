import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Optional,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository, DataSource } from "typeorm";
import {
  ProductPending,
  PendingProductStatus,
  ProductCondition,
} from "./entities/product-pending.entity";
import { Product, PublishSource } from "./entities/product.entity";
import { Category } from "./entities/category.entity";
import { ProductSku, SkuStatus } from "./entities/product-sku.entity";
import { CreateProductPendingDto } from "./dto/create-product-pending.dto";
import { UpdateProductStatusDto } from "./dto/update-product-status.dto";
import { ReviewProductDto } from "./dto/review-product.dto";
import { NotificationsService } from "../notifications/notifications.service";
import {
  NotificationType,
  ActionType,
} from "../notifications/entities/notification.entity";
import { ModerationService } from "../moderation/moderation.service";

@Injectable()
export class SecondHandProductService {
  constructor(
    @InjectRepository(ProductPending)
    private productPendingRepository: Repository<ProductPending>,
    @InjectRepository(Product)
    private productRepository: Repository<Product>,
    @InjectRepository(Category)
    private categoryRepository: Repository<Category>,
    @InjectRepository(ProductSku)
    private productSkuRepository: Repository<ProductSku>,
    private dataSource: DataSource,
    private notificationsService: NotificationsService,
    @Optional()
    private readonly moderationService?: ModerationService,
  ) {}

  private normalizePendingStock(stock?: number | null): number {
    if (typeof stock !== "number" || !Number.isFinite(stock)) {
      return 1;
    }

    return Math.max(1, Math.floor(stock));
  }

  /**
   * 清理关键词，防止SQL注入和DoS攻击
   */
  private sanitizeKeyword(keyword: string | undefined): string | undefined {
    if (!keyword) {
      return undefined;
    }

    // 限制长度
    const maxLength = 50;
    const truncated = keyword.substring(0, maxLength);

    // 转义 SQL LIKE 特殊字符
    return truncated.replace(/[%_\\]/g, "\\$&");
  }

  /**
   * 创建待审核商品
   */
  async createPendingProduct(userId: number, dto: CreateProductPendingDto) {
    const normalizedStock = this.normalizePendingStock(dto.stock);
    const pendingProduct = this.productPendingRepository.create({
      userId,
      ...dto,
      stock: normalizedStock,
      status: PendingProductStatus.UNDER_REVIEW,
    });

    return await this.productPendingRepository.save(pendingProduct);
  }

  /**
   * 编辑待审核商品
   */
  async updatePendingProduct(
    id: number,
    userId: number,
    dto: CreateProductPendingDto,
  ) {
    const pendingProduct = await this.productPendingRepository.findOne({
      where: { id },
    });

    if (!pendingProduct) {
      throw new NotFoundException("商品不存在");
    }

    if (pendingProduct.userId !== userId) {
      throw new ForbiddenException("无权编辑此商品");
    }

    // 仅禁止已售出的商品编辑
    if (pendingProduct.status === PendingProductStatus.SOLD) {
      throw new BadRequestException("已售出的商品不可编辑");
    }

    // 更新商品信息，状态重置为审核中
    Object.assign(pendingProduct, dto, {
      stock: this.normalizePendingStock(dto.stock ?? pendingProduct.stock),
    });
    pendingProduct.status = PendingProductStatus.UNDER_REVIEW;
    pendingProduct.rejectReason = null;

    return await this.productPendingRepository.save(pendingProduct);
  }

  /**
   * 获取待审核商品详情（编辑时使用）
   */
  async getPendingProductDetail(id: number, userId: number) {
    const pendingProduct = await this.productPendingRepository.findOne({
      where: { id },
      relations: ["category"],
    });

    if (!pendingProduct) {
      throw new NotFoundException("商品不存在");
    }

    if (pendingProduct.userId !== userId) {
      throw new ForbiddenException("无权查看此商品");
    }

    return pendingProduct;
  }

  /**
   * 获取待审核商品详情（后台管理）
   */
  async getPendingProductDetailForAdmin(id: number) {
    const pendingProduct = await this.productPendingRepository.findOne({
      where: { id },
      relations: ["user", "category"],
    });

    if (!pendingProduct) {
      throw new NotFoundException("商品不存在");
    }

    return pendingProduct;
  }

  /**
   * 获取我的商品列表
   */
  async getMyProducts(userId: number, query: any) {
    // 强制限制每页数量，防止 DoS 攻击
    const MAX_LIMIT = 100;
    const { status = "all", page = 1, limit = 10, isActive } = query;
    const validLimit = Math.min(limit, MAX_LIMIT);
    const validPage = Math.max(page, 1);

    // 先查询临时表数据，并 JOIN 正式表获取状态
    const queryBuilder = this.productPendingRepository
      .createQueryBuilder("pp")
      .leftJoinAndSelect("pp.category", "category")
      .leftJoin("products", "p", "p.id = pp.productId")
      .addSelect("p.isActive", "product_isActive")
      .where("pp.userId = :userId", { userId });

    // 临时表状态筛选
    if (status !== "all") {
      // 支持多状态查询，逗号分隔
      const statusList = String(status)
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean);

      // 兼容 approved 映射为 on_shelf
      const normalized = statusList.flatMap((s) =>
        s === PendingProductStatus.ON_SHELF ||
        s === PendingProductStatus.APPROVED
          ? [PendingProductStatus.ON_SHELF, PendingProductStatus.APPROVED]
          : [s],
      );

      queryBuilder.andWhere("pp.status IN (:...statusList)", {
        statusList: Array.from(new Set(normalized)),
      });
    }

    // 正式表状态筛选（上下架状态）
    if (isActive !== undefined) {
      queryBuilder.andWhere("p.isActive = :isActive", { isActive });
    }

    // 分页（使用强制限制的值）
    queryBuilder
      .orderBy("pp.createdAt", "DESC")
      .skip((validPage - 1) * validLimit)
      .take(validLimit);

    const [rawAndEntities, total] = await Promise.all([
      queryBuilder.getRawAndEntities(),
      queryBuilder.getCount(),
    ]);

    const items = rawAndEntities.entities.map((entity, index) => {
      const raw = rawAndEntities.raw[index];
      const joinedIsActive = raw?.product_isActive;
      return Object.assign(entity, {
        isActive:
          joinedIsActive === null || joinedIsActive === undefined
            ? undefined
            : Boolean(joinedIsActive),
      });
    });

    return {
      data: items,
      total,
      page: validPage,
      limit: validLimit,
    };
  }

  /**
   * 获取商品详情
   */
  async getProductDetail(id: number, currentUserId?: number) {
    const product = await this.productRepository.findOne({
      where: { id },
      relations: ["publisher", "categoryRelation"],
    });

    if (!product) {
      throw new NotFoundException("商品不存在");
    }

    const blockedUserIds =
      await this.moderationService?.getBlockedUserIds(currentUserId);
    if (product.publishedBy && blockedUserIds?.includes(product.publishedBy)) {
      throw new NotFoundException("商品不存在");
    }

    // 增加浏览次数
    product.viewCount += 1;
    await this.productRepository.save(product);

    return product;
  }

  /**
   * 上架/下架商品（同时更新正式表和临时表）
   */
  async updateProductStatus(
    id: number,
    userId: number,
    dto: UpdateProductStatusDto,
  ) {
    const product = await this.productRepository.findOne({
      where: { id },
    });

    if (!product) {
      throw new NotFoundException("商品不存在");
    }

    if (product.publishedBy !== userId) {
      throw new ForbiddenException("无权操作此商品");
    }

    // 更新正式表状态（使用 isActive）
    const newStatus = dto.status as boolean;
    product.isActive = newStatus;
    await this.productRepository.save(product);

    // 同步临时表状态，保证前端状态/按钮一致
    if (product.pendingProductId) {
      await this.productPendingRepository.update(
        { id: product.pendingProductId },
        {
          status: newStatus
            ? PendingProductStatus.ON_SHELF
            : PendingProductStatus.OFF_SHELF,
        },
      );
    }

    return product;
  }

  /**
   * 获取商品分类列表（二级分类树）
   * 返回所有一级分类及其启用的二级分类
   */
  async getSecondHandCategories() {
    // 查询所有一级分类（parentId IS NULL）
    const rootCategories = await this.categoryRepository.find({
      where: {
        parentId: null as any,
        status: "ACTIVE" as any,
      },
      order: {
        sortOrder: "ASC",
      },
      relations: ["children"],
    });

    // 过滤出状态为启用的二级分类
    return rootCategories.map((category) => ({
      ...category,
      children:
        category.children?.filter((child) => child.status === "ACTIVE") || [],
    }));
  }

  // ========== 后台管理相关方法 ==========

  /**
   * 获取待审核商品列表
   */
  async getPendingProducts(query: any) {
    // 强制限制每页数量，防止 DoS 攻击
    const MAX_LIMIT = 100;
    const { status, categoryId, keyword, page = 1, limit = 10 } = query;
    const validLimit = Math.min(limit, MAX_LIMIT);
    const validPage = Math.max(page, 1);

    const queryBuilder = this.productPendingRepository
      .createQueryBuilder("pp")
      .leftJoinAndSelect("pp.user", "user")
      .leftJoinAndSelect("pp.category", "category")
      .orderBy("pp.createdAt", "DESC");

    // 状态筛选
    if (status) {
      queryBuilder.andWhere("pp.status = :status", { status });
    }

    // 分类筛选
    if (categoryId) {
      queryBuilder.andWhere("pp.categoryId = :categoryId", { categoryId });
    }

    // 关键词搜索（添加长度限制和转义）
    const sanitizedKeyword = this.sanitizeKeyword(keyword);
    if (sanitizedKeyword) {
      queryBuilder.andWhere(
        "(pp.title LIKE :keyword OR user.phone LIKE :keyword OR user.nickname LIKE :keyword)",
        { keyword: `%${sanitizedKeyword}%` },
      );
    }

    // 分页（使用强制限制的值）
    queryBuilder.skip((validPage - 1) * validLimit).take(validLimit);

    const [items, total] = await queryBuilder.getManyAndCount();

    return {
      data: items,
      total,
      page: validPage,
      limit: validLimit,
    };
  }

  /**
   * 审核商品
   */
  async reviewProduct(id: number, dto: ReviewProductDto, adminId: number) {
    const pendingProduct = await this.productPendingRepository.findOne({
      where: { id },
      relations: ["user", "category"],
    });

    if (!pendingProduct) {
      throw new NotFoundException("商品不存在");
    }

    if (
      pendingProduct.status !== PendingProductStatus.UNDER_REVIEW &&
      pendingProduct.status !== PendingProductStatus.APPROVED &&
      pendingProduct.status !== PendingProductStatus.ON_SHELF &&
      pendingProduct.status !== PendingProductStatus.OFF_SHELF
    ) {
      throw new BadRequestException("该商品已审核或不可审核");
    }

    // 拒绝时必须填写原因
    if (!dto.approved && !dto.rejectReason) {
      throw new BadRequestException("拒绝时必须填写原因");
    }

    // 使用事务处理
    await this.dataSource.transaction(async (manager) => {
      if (dto.approved) {
        // 审核通过
        let formalProduct: Product | null = null;
        const normalizedStock = this.normalizePendingStock(
          pendingProduct.stock,
        );

        if (pendingProduct.productId) {
          // 编辑已有商品
          formalProduct = await manager.findOne(Product, {
            where: { id: pendingProduct.productId },
          });

          if (!formalProduct) {
            throw new NotFoundException("关联的正式商品不存在");
          }

          Object.assign(formalProduct, {
            name: pendingProduct.title,
            description: pendingProduct.description,
            price: pendingProduct.price,
            stock: normalizedStock,
            images: pendingProduct.images,
            categoryId: pendingProduct.categoryId,
            negotiable: pendingProduct.negotiable,
            condition: pendingProduct.condition,
            shippingFee: pendingProduct.shippingFee,
          });
        } else {
          // 新发布商品，创建正式表记录
          formalProduct = new Product();
          Object.assign(formalProduct, {
            name: pendingProduct.title,
            description: pendingProduct.description,
            price: pendingProduct.price,
            stock: normalizedStock,
            images: pendingProduct.images,
            categoryId: pendingProduct.categoryId,
            negotiable: pendingProduct.negotiable,
            condition: pendingProduct.condition,
            shippingFee: pendingProduct.shippingFee,
            publishSource: PublishSource.USER,
            publishedBy: pendingProduct.userId,
            sells: 0,
            isHot: false,
            isTop: false,
            hasSku: false,
            isVirtual: false,
            viewCount: 0,
          });
        }

        // 审核元数据和上架状态
        formalProduct.publishSource = PublishSource.USER;
        formalProduct.publishedBy = pendingProduct.userId;
        formalProduct.auditedBy = adminId;
        formalProduct.auditedAt = new Date();
        formalProduct.isActive = true;
        formalProduct.soldAt = null;
        formalProduct.pendingProductId = pendingProduct.id;

        // 保存或创建正式商品
        formalProduct = await manager.save(formalProduct);
        pendingProduct.productId = formalProduct.id;

        // 审核通过后，保证存在至少一个可用的 SKU
        let skus = await manager.find(ProductSku, {
          where: { productId: formalProduct.id },
        });

        if (skus.length === 0) {
          const defaultSku = manager.create(ProductSku, {
            productId: formalProduct.id,
            name: "默认规格",
            specs: {},
            price: pendingProduct.price,
            originalPrice: pendingProduct.price,
            stock: normalizedStock,
            status: SkuStatus.ACTIVE,
            image: pendingProduct.images?.[0] || null,
            skuCode: `SKU_${formalProduct.id}_${Date.now()}`,
          });
          await manager.save(defaultSku);
          skus = [defaultSku];
        }

        // 用户发布商品采用单规格模型：仅保留一个可用 SKU，并与待审核库存保持一致
        const primarySku =
          skus.find((sku) => sku.status === SkuStatus.ACTIVE) ?? skus[0];
        for (const sku of skus) {
          const isPrimarySku = sku.id === primarySku.id;
          sku.status = isPrimarySku ? SkuStatus.ACTIVE : SkuStatus.INACTIVE;
          sku.stock = isPrimarySku ? normalizedStock : 0;
          sku.price = pendingProduct.price;
          if (!sku.originalPrice) {
            sku.originalPrice = pendingProduct.price;
          }
          if (!sku.image) {
            sku.image = pendingProduct.images?.[0] || null;
          }
          await manager.save(sku);
        }

        // 同步正式商品库存/状态：单规格模型，hasSku 置为 false 但保留默认 SKU 兼容
        formalProduct.hasSku = false;
        formalProduct.stock = normalizedStock;
        formalProduct.price = pendingProduct.price;
        await manager.save(formalProduct);

        pendingProduct.status = PendingProductStatus.ON_SHELF;
        pendingProduct.rejectReason = null;
        await manager.update(ProductPending, pendingProduct.id, {
          stock: normalizedStock,
          status: PendingProductStatus.ON_SHELF,
          rejectReason: null,
        });

        // 发送审核通过消息
        await this.notificationsService.create({
          userId: pendingProduct.userId,
          type: NotificationType.SYSTEM,
          title: "商品审核通过",
          content: `您发布的《${pendingProduct.title}》已通过审核，快来查看吧！`,
          actionType: ActionType.PAGE,
          actionData: {
            path: "ProductDetail",
            params: { id: formalProduct.id },
          },
        });
      } else {
        // 审核拒绝
        pendingProduct.status = PendingProductStatus.REJECTED;
        pendingProduct.rejectReason = dto.rejectReason || "审核未通过";
        await manager.update(ProductPending, pendingProduct.id, {
          status: PendingProductStatus.REJECTED,
          rejectReason: pendingProduct.rejectReason,
        });

        // 发送审核拒绝消息
        await this.notificationsService.create({
          userId: pendingProduct.userId,
          type: NotificationType.SYSTEM,
          title: "商品审核未通过",
          content: `您发布的《${pendingProduct.title}》未通过审核，原因：${dto.rejectReason}`,
          actionType: ActionType.PAGE,
          actionData: { path: "MyPublishedProducts" },
        });
      }

      await manager.save(pendingProduct);
    });

    return {
      success: true,
      message: dto.approved ? "审核通过" : "审核拒绝",
    };
  }

  /**
   * 获取正式商品列表（后台管理）
   */
  async getFormalProducts(query: any) {
    // 强制限制每页数量，防止 DoS 攻击
    const MAX_LIMIT = 100;
    const { categoryId, keyword, page = 1, limit = 10 } = query;
    const validLimit = Math.min(limit, MAX_LIMIT);
    const validPage = Math.max(page, 1);

    const queryBuilder = this.productRepository
      .createQueryBuilder("p")
      .leftJoinAndSelect("p.publisher", "user")
      .leftJoinAndSelect("p.categoryRelation", "category")
      .where("p.publishSource = :source", { source: "USER" })
      .orderBy("p.createdAt", "DESC");

    // 分类筛选
    if (categoryId) {
      queryBuilder.andWhere("p.categoryId = :categoryId", { categoryId });
    }

    // 关键词搜索（添加长度限制和转义）
    const sanitizedKeyword = this.sanitizeKeyword(keyword);
    if (sanitizedKeyword) {
      queryBuilder.andWhere(
        "(p.name LIKE :keyword OR user.phone LIKE :keyword)",
        { keyword: `%${sanitizedKeyword}%` },
      );
    }

    // 分页（使用强制限制的值）
    queryBuilder.skip((validPage - 1) * validLimit).take(validLimit);

    const [items, total] = await queryBuilder.getManyAndCount();

    return {
      data: items,
      total,
      page: validPage,
      limit: validLimit,
    };
  }

  /**
   * 强制下架商品（后台管理）
   */
  async forceDelistProduct(id: number) {
    const product = await this.productRepository.findOne({
      where: { id },
    });

    if (!product) {
      throw new NotFoundException("商品不存在");
    }

    product.isActive = false;
    await this.productRepository.save(product);

    return {
      success: true,
      message: "商品已下架",
    };
  }
}
