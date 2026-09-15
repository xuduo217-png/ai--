import {
  Injectable,
  Logger,
  InternalServerErrorException,
  NotFoundException,
  BadRequestException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository, DataSource, Like, In } from "typeorm";
import {
  Coupon,
  CouponStatus,
  CouponType,
  ClaimType,
  CouponScope,
} from "./entities/coupon.entity";
import { CouponProduct } from "./entities/coupon-product.entity";
import { UserCoupon, UserCouponStatus } from "./entities/user-coupon.entity";
import { CreateCouponDto } from "./dto/create-coupon.dto";
import { UpdateCouponDto } from "./dto/update-coupon.dto";
import { QueryCouponDto } from "./dto/query-coupon.dto";
import { ClaimCouponDto } from "./dto/claim-coupon.dto";
import {
  createBusinessException,
  ErrorCode,
} from "../common/constants/error-codes";
import * as crypto from "crypto";

export interface CouponRuleSnapshot {
  id: number;
  name: string;
  type: CouponType;
  scope: CouponScope;
  description?: string;
  status: CouponStatus;
  discountValue: number;
  minAmount: number;
  minOrderAmount: number;
  maxDiscount?: number | null;
  validFrom: string;
  validUntil: string;
  canStack: boolean;
  isEnabled: boolean;
}

export interface UserCouponView {
  id: number;
  userId: number;
  couponId: number;
  status: UserCouponStatus;
  validFrom: string;
  validUntil: string;
  expiresAt: string;
  usedAt?: string | null;
  orderId?: number | null;
  createdAt: string;
  coupon: CouponRuleSnapshot;
}

export interface OrderCouponOption extends UserCouponView {
  isApplicable: boolean;
  discountAmount: number;
  unavailableReason?: string;
}

export interface CouponScanDetailView {
  claimCode: string;
  claimType: ClaimType;
  claimed: boolean;
  canClaim: boolean;
  unavailableReason?: string;
  coupon: CouponRuleSnapshot;
  userCoupon: UserCouponView | null;
}

interface CouponEvaluationContext {
  orderAmount: number;
  productIds: number[];
  specificProductMap?: Map<number, Set<number>>;
  orderLines?: Array<{
    productId: number;
    amount: number;
  }>;
}

interface LockCouponForOrderParams {
  userCouponId: number;
  userId: number;
  orderAmount: number;
  productIds: number[];
  orderLines?: Array<{
    productId: number;
    amount: number;
  }>;
  manager?: any;
}

@Injectable()
export class CouponService {
  private readonly logger = new Logger(CouponService.name);

  constructor(
    @InjectRepository(Coupon)
    private couponRepository: Repository<Coupon>,
    @InjectRepository(UserCoupon)
    private userCouponRepository: Repository<UserCoupon>,
    @InjectRepository(CouponProduct)
    private couponProductRepository: Repository<CouponProduct>,
    private dataSource: DataSource,
  ) {}

  /**
   * 创建优惠券（管理员）
   */
  async createCoupon(createCouponDto: CreateCouponDto): Promise<Coupon> {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const now = new Date();
      const validAt = new Date(createCouponDto.validAt);

      // 判断是否已过期
      const isExpired = validAt < now ? 1 : 0;

      // 如果是扫码领取类型，生成唯一领取码
      let claimCode: string | undefined;
      if (createCouponDto.claimType === ClaimType.SCAN_CODE) {
        claimCode = await this.generateUniqueClaimCode();
      }

      // 创建优惠券
      const coupon = queryRunner.manager.create(Coupon, {
        ...createCouponDto,
        validFrom: new Date(createCouponDto.validFrom),
        validAt: validAt,
        isEnabled: createCouponDto.isEnabled ?? 0,
        isExpired: isExpired,
        isClaimedOut: 0, // 新创建的优惠券，未有人领取，不会已领完
        claimCode: claimCode,
      });

      const saved = await queryRunner.manager.save(Coupon, coupon);

      // 如果是指定商品，创建关联关系
      let products: any[] = [];
      if (
        createCouponDto.scope === "SPECIFIC" &&
        createCouponDto.productIds?.length > 0
      ) {
        const couponProducts = createCouponDto.productIds.map((productId) =>
          queryRunner.manager.create(CouponProduct, {
            couponId: saved.id,
            productId,
          }),
        );
        await queryRunner.manager.save(CouponProduct, couponProducts);

        // 在事务内加载关联的商品
        const savedCouponProducts = await queryRunner.manager
          .createQueryBuilder(CouponProduct, "cp")
          .leftJoinAndSelect("cp.product", "product")
          .where("cp.couponId = :couponId", { couponId: saved.id })
          .getMany();
        products = savedCouponProducts
          .filter((cp) => cp.product !== null)
          .map((cp) => cp.product);
      }

      await queryRunner.commitTransaction();
      this.logger.log(`Coupon created: ${saved.id}, name: ${saved.name}`);

      // 直接返回已加载的数据，避免在事务外再次查询
      return {
        ...saved,
        products: products.length > 0 ? products : undefined,
      } as Coupon;
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  /**
   * 获取可领取的优惠券列表
   */
  async getAvailableCoupons(userId: number): Promise<Coupon[]> {
    const now = new Date();
    const coupons = await this.couponRepository.find({
      where: { status: CouponStatus.ACTIVE, isEnabled: 0 },
      order: { createdAt: "DESC" },
    });

    // 过滤掉用户已领完的优惠券
    const available = [];
    for (const coupon of coupons) {
      const claimedCount = await this.userCouponRepository.count({
        where: { userId, couponId: coupon.id },
      });

      if (
        claimedCount < coupon.perUserLimit &&
        coupon.claimedCount < coupon.stock &&
        now >= coupon.validFrom &&
        now <= coupon.validAt
      ) {
        available.push(coupon);
      }
    }

    return available;
  }

  /**
   * 领取优惠券
   * 安全修复：使用悲观锁防止并发超发
   */
  async claimCoupon(dto: ClaimCouponDto, userId: number): Promise<UserCoupon> {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // 1. 使用悲观锁查询优惠券（防止并发超发）
      const coupon = await this.findClaimableCouponForUpdate(
        dto,
        queryRunner.manager,
      );

      if (!coupon) {
        throw createBusinessException(ErrorCode.COUPON_NOT_FOUND);
      }

      // 2. 验证优惠券状态
      if (coupon.status !== CouponStatus.ACTIVE) {
        throw createBusinessException(ErrorCode.COUPON_EXPIRED);
      }

      if (coupon.isEnabled !== 0) {
        throw createBusinessException(
          ErrorCode.COUPON_NOT_APPLICABLE,
          "优惠券已禁用",
        );
      }

      // 3. 验证有效期
      const now = new Date();
      if (now < coupon.validFrom || now > coupon.validAt) {
        throw createBusinessException(ErrorCode.COUPON_EXPIRED);
      }

      // 4. 验证库存
      if (coupon.claimedCount >= coupon.stock) {
        throw createBusinessException(ErrorCode.COUPON_OUT_OF_STOCK);
      }

      // 5. 验证用户领取数量
      const claimedCount = await queryRunner.manager.count(UserCoupon, {
        where: { userId, couponId: coupon.id },
      });

      if (claimedCount >= coupon.perUserLimit) {
        throw createBusinessException(ErrorCode.COUPON_LIMIT_EXCEEDED);
      }

      // 6. 创建用户优惠券
      const userCoupon = queryRunner.manager.create(UserCoupon, {
        userId,
        couponId: coupon.id,
        status: UserCouponStatus.AVAILABLE,
        expiredAt: coupon.validAt,
      });

      const saved = await queryRunner.manager.save(UserCoupon, userCoupon);

      // 7. 更新优惠券已领取数量
      coupon.claimedCount += 1;
      await queryRunner.manager.save(Coupon, coupon);

      await queryRunner.commitTransaction();
      this.logger.log(
        `Coupon claimed: userId=${userId}, couponId=${coupon.id}`,
      );

      return saved;
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  /**
   * 获取我的优惠券
   */
  async getMyCoupons(
    userId: number,
    status?: UserCouponStatus,
  ): Promise<UserCouponView[]> {
    const where: any = { userId };
    if (status) {
      where.status = status;
    }

    const userCoupons = await this.userCouponRepository.find({
      where,
      relations: ["coupon"],
      order: { createdAt: "DESC" },
    });

    const normalizedCoupons = await this.syncUserCouponStatuses(userCoupons);
    return normalizedCoupons.map((userCoupon) =>
      this.toUserCouponView(userCoupon),
    );
  }

  /**
   * 获取我的优惠券数量统计
   * 统计前会先将已过期但仍为 AVAILABLE 的券自动标记为 EXPIRED
   */
  async getMyCouponCount(userId: number): Promise<{
    available: number;
    used: number;
    expired: number;
  }> {
    const now = new Date();

    // 先做一次过期状态修正，避免统计口径不一致
    await this.userCouponRepository
      .createQueryBuilder()
      .update(UserCoupon)
      .set({ status: UserCouponStatus.EXPIRED })
      .where("userId = :userId", { userId })
      .andWhere("status = :status", { status: UserCouponStatus.AVAILABLE })
      .andWhere("expiredAt < :now", { now })
      .execute();

    const [available, used, expired] = await Promise.all([
      this.userCouponRepository.count({
        where: { userId, status: UserCouponStatus.AVAILABLE },
      }),
      this.userCouponRepository.count({
        where: { userId, status: UserCouponStatus.USED },
      }),
      this.userCouponRepository.count({
        where: { userId, status: UserCouponStatus.EXPIRED },
      }),
    ]);

    return { available, used, expired };
  }

  async getCouponDetailByClaimCode(
    claimCode: string,
    userId: number,
  ): Promise<CouponScanDetailView> {
    const coupon = await this.findCouponByClaimCode(claimCode);

    if (!coupon) {
      throw createBusinessException(ErrorCode.COUPON_NOT_FOUND);
    }

    const userCoupon = await this.userCouponRepository.findOne({
      where: { userId, couponId: coupon.id },
      relations: ["coupon"],
      order: { createdAt: "DESC" },
    });

    const normalizedUserCoupon = userCoupon
      ? (await this.syncUserCouponStatuses([userCoupon]))[0]
      : null;
    const availability = this.getCouponClaimAvailability(coupon);

    return {
      claimCode: coupon.claimCode,
      claimType: coupon.claimType,
      claimed: Boolean(normalizedUserCoupon),
      canClaim: !normalizedUserCoupon && availability.canClaim,
      unavailableReason: normalizedUserCoupon
        ? "您已领取过该优惠券"
        : availability.reason,
      coupon: this.toCouponRuleSnapshot(coupon),
      userCoupon: normalizedUserCoupon
        ? this.toUserCouponView(normalizedUserCoupon)
        : null,
    };
  }

  /**
   * 使用优惠券
   * 安全修复：使用事务和悲观锁防止并发使用同一优惠券
   */
  async useCoupon(
    userCouponId: number,
    orderId: number,
    orderAmount: number,
  ): Promise<number> {
    return await this.dataSource.transaction(async (manager) => {
      const lockedCoupon = await this.lockCouponForOrder({
        userCouponId,
        userId: -1,
        orderAmount,
        productIds: [],
        manager,
      });
      await this.markCouponUsedForOrder(
        lockedCoupon.userCoupon,
        orderId,
        manager,
      );
      return lockedCoupon.discount;
    });
  }

  /**
   * 计算优惠金额
   */
  private calculateDiscount(coupon: Coupon, orderAmount: number): number {
    if (coupon.type === CouponType.FULL_REDUCTION) {
      // 满减券
      return Number(coupon.discountValue);
    } else {
      // 折扣券
      const discount = orderAmount * (Number(coupon.discountValue) / 100);
      const maxDiscount = coupon.maxDiscount
        ? Number(coupon.maxDiscount)
        : discount;
      return Math.min(discount, maxDiscount);
    }
  }

  private getEffectiveMinAmount(coupon: Coupon): number {
    return Math.max(
      Number(coupon.minAmount || 0),
      Number(coupon.minOrderAmount || 0),
    );
  }

  private async syncUserCouponStatuses(
    userCoupons: UserCoupon[],
  ): Promise<UserCoupon[]> {
    const now = new Date();

    for (const userCoupon of userCoupons) {
      if (
        userCoupon.status === UserCouponStatus.AVAILABLE &&
        now > userCoupon.expiredAt
      ) {
        await this.userCouponRepository.update(userCoupon.id, {
          status: UserCouponStatus.EXPIRED,
        });
        userCoupon.status = UserCouponStatus.EXPIRED;
      }
    }

    return userCoupons;
  }

  private toUserCouponView(userCoupon: UserCoupon): UserCouponView {
    return {
      id: userCoupon.id,
      userId: userCoupon.userId,
      couponId: userCoupon.couponId,
      status: userCoupon.status,
      validFrom: userCoupon.coupon.validFrom.toISOString(),
      validUntil: userCoupon.expiredAt.toISOString(),
      expiresAt: userCoupon.expiredAt.toISOString(),
      usedAt: userCoupon.usedAt ? userCoupon.usedAt.toISOString() : null,
      orderId: userCoupon.orderId ?? null,
      createdAt: userCoupon.createdAt.toISOString(),
      coupon: this.toCouponRuleSnapshot(userCoupon.coupon),
    };
  }

  private toCouponRuleSnapshot(coupon: Coupon): CouponRuleSnapshot {
    const effectiveMinAmount = this.getEffectiveMinAmount(coupon);

    return {
      id: coupon.id,
      name: coupon.name,
      type: coupon.type,
      scope: coupon.scope,
      description: coupon.description,
      status: coupon.status,
      discountValue: Number(coupon.discountValue),
      minAmount: effectiveMinAmount,
      minOrderAmount: Number(coupon.minOrderAmount || 0),
      maxDiscount:
        coupon.maxDiscount !== null && coupon.maxDiscount !== undefined
          ? Number(coupon.maxDiscount)
          : null,
      validFrom: coupon.validFrom.toISOString(),
      validUntil: coupon.validAt.toISOString(),
      canStack: coupon.canStack === 1,
      isEnabled: coupon.isEnabled === 0,
    };
  }

  private async findClaimableCouponForUpdate(
    dto: ClaimCouponDto,
    manager: any,
  ): Promise<Coupon | null> {
    const query = manager
      .createQueryBuilder(Coupon, "coupon")
      .setLock("pessimistic_write");

    if (dto.couponId) {
      return query.where("coupon.id = :id", { id: dto.couponId }).getOne();
    }

    if (dto.claimCode) {
      return query
        .where("coupon.claimCode = :claimCode", { claimCode: dto.claimCode })
        .andWhere("coupon.claimType = :claimType", {
          claimType: ClaimType.SCAN_CODE,
        })
        .getOne();
    }

    throw new BadRequestException("couponId 或 claimCode 不能为空");
  }

  private async findCouponByClaimCode(
    claimCode: string,
  ): Promise<Coupon | null> {
    return this.couponRepository.findOne({
      where: {
        claimCode,
        claimType: ClaimType.SCAN_CODE,
      },
    });
  }

  private getCouponClaimAvailability(coupon: Coupon): {
    canClaim: boolean;
    reason?: string;
  } {
    if (coupon.status !== CouponStatus.ACTIVE) {
      return {
        canClaim: false,
        reason: "优惠券已失效",
      };
    }

    if (coupon.isEnabled !== 0) {
      return {
        canClaim: false,
        reason: "优惠券已禁用",
      };
    }

    const now = new Date();
    if (now < coupon.validFrom) {
      return {
        canClaim: false,
        reason: "优惠券尚未生效",
      };
    }

    if (now > coupon.validAt) {
      return {
        canClaim: false,
        reason: "优惠券已过期",
      };
    }

    if (coupon.claimedCount >= coupon.stock) {
      return {
        canClaim: false,
        reason: "优惠券已领完",
      };
    }

    return {
      canClaim: true,
    };
  }

  private async loadSpecificProductMap(
    userCoupons: UserCoupon[],
  ): Promise<Map<number, Set<number>>> {
    const couponIds = userCoupons
      .filter((userCoupon) => userCoupon.coupon?.scope === CouponScope.SPECIFIC)
      .map((userCoupon) => userCoupon.couponId);

    if (couponIds.length === 0) {
      return new Map();
    }

    const couponProducts = await this.couponProductRepository.find({
      where: { couponId: In(couponIds) },
    });

    const specificProductMap = new Map<number, Set<number>>();
    for (const couponProduct of couponProducts) {
      if (!specificProductMap.has(couponProduct.couponId)) {
        specificProductMap.set(couponProduct.couponId, new Set());
      }
      specificProductMap
        .get(couponProduct.couponId)!
        .add(couponProduct.productId);
    }

    return specificProductMap;
  }

  private evaluateCoupon(
    userCoupon: UserCoupon,
    context: CouponEvaluationContext,
    specificProductMap?: Map<number, Set<number>>,
  ): {
    isApplicable: boolean;
    discountAmount: number;
    unavailableReason?: string;
    applicableAmount: number;
  } {
    if (!userCoupon) {
      return {
        isApplicable: false,
        discountAmount: 0,
        unavailableReason: "优惠券不存在",
        applicableAmount: 0,
      };
    }

    if (userCoupon.status !== UserCouponStatus.AVAILABLE) {
      return {
        isApplicable: false,
        discountAmount: 0,
        unavailableReason: "优惠券已使用或失效",
        applicableAmount: 0,
      };
    }

    const coupon = userCoupon.coupon;
    const now = new Date();

    if (!coupon || coupon.status !== CouponStatus.ACTIVE) {
      return {
        isApplicable: false,
        discountAmount: 0,
        unavailableReason: "优惠券已失效",
        applicableAmount: 0,
      };
    }

    if (coupon.isEnabled !== 0) {
      return {
        isApplicable: false,
        discountAmount: 0,
        unavailableReason: "优惠券已禁用",
        applicableAmount: 0,
      };
    }

    if (now < coupon.validFrom) {
      return {
        isApplicable: false,
        discountAmount: 0,
        unavailableReason: "优惠券尚未生效",
        applicableAmount: 0,
      };
    }

    if (now > coupon.validAt || now > userCoupon.expiredAt) {
      return {
        isApplicable: false,
        discountAmount: 0,
        unavailableReason: "优惠券已过期",
        applicableAmount: 0,
      };
    }

    let applicableAmount = context.orderAmount;

    if (coupon.scope === CouponScope.SPECIFIC) {
      const matchedProductIds =
        specificProductMap?.get(coupon.id) ?? new Set<number>();
      const matchedOrderLines = (context.orderLines ?? []).filter(
        ({ productId }) => matchedProductIds.has(productId),
      );
      const hasMatchedProduct =
        matchedOrderLines.length > 0 ||
        context.productIds.some((productId) =>
          matchedProductIds.has(productId),
        );

      if (!hasMatchedProduct) {
        return {
          isApplicable: false,
          discountAmount: 0,
          unavailableReason: "优惠券仅适用于指定商品",
          applicableAmount: 0,
        };
      }

      if (matchedOrderLines.length > 0) {
        applicableAmount = matchedOrderLines.reduce(
          (sum, orderLine) => sum + orderLine.amount,
          0,
        );
      }
    }

    const effectiveMinAmount = this.getEffectiveMinAmount(coupon);

    if (applicableAmount < effectiveMinAmount) {
      return {
        isApplicable: false,
        discountAmount: 0,
        unavailableReason: "订单金额未达到优惠券使用门槛",
        applicableAmount,
      };
    }

    return {
      isApplicable: true,
      discountAmount: this.calculateDiscount(coupon, applicableAmount),
      applicableAmount,
    };
  }

  private async evaluateCouponForLockedUserCoupon(
    userCoupon: UserCoupon,
    orderAmount: number,
    productIds: number[],
    orderLines?: Array<{ productId: number; amount: number }>,
  ) {
    const specificProductMap = await this.loadSpecificProductMap([userCoupon]);
    return this.evaluateCoupon(
      userCoupon,
      {
        orderAmount,
        productIds,
        orderLines,
      },
      specificProductMap,
    );
  }

  /**
   * 验证优惠券是否可用
   */
  async validateCoupon(
    userCouponId: number,
    userId: number,
    orderAmount: number,
    productIds: number[] = [],
    orderLines?: Array<{ productId: number; amount: number }>,
  ): Promise<any> {
    const userCoupon = await this.userCouponRepository.findOne({
      where: { id: userCouponId, userId },
      relations: ["coupon"],
    });

    if (!userCoupon) {
      throw createBusinessException(ErrorCode.COUPON_NOT_FOUND);
    }

    const [normalizedCoupon] = await this.syncUserCouponStatuses([userCoupon]);
    const evaluation = this.evaluateCoupon(
      normalizedCoupon,
      {
        orderAmount,
        productIds,
        orderLines,
      },
      await this.loadSpecificProductMap([normalizedCoupon]),
    );

    if (!evaluation.isApplicable) {
      throw createBusinessException(
        ErrorCode.COUPON_NOT_APPLICABLE,
        evaluation.unavailableReason,
      );
    }

    return {
      valid: true,
      coupon: normalizedCoupon.coupon,
      discount: evaluation.discountAmount,
    };
  }

  async getOrderCouponOptions(
    userId: number,
    orderAmount: number,
    productIds: number[],
    orderLines?: Array<{ productId: number; amount: number }>,
  ): Promise<OrderCouponOption[]> {
    const userCoupons = await this.userCouponRepository.find({
      where: { userId },
      relations: ["coupon"],
      order: { createdAt: "DESC" },
    });

    const normalizedCoupons = await this.syncUserCouponStatuses(userCoupons);
    const specificProductMap =
      await this.loadSpecificProductMap(normalizedCoupons);
    const context: CouponEvaluationContext = {
      orderAmount,
      productIds,
      specificProductMap,
      orderLines,
    };

    return normalizedCoupons.map((userCoupon) => {
      const evaluation = this.evaluateCoupon(
        userCoupon,
        context,
        specificProductMap,
      );
      return {
        ...this.toUserCouponView(userCoupon),
        isApplicable: evaluation.isApplicable,
        discountAmount: evaluation.discountAmount,
        unavailableReason: evaluation.unavailableReason,
      };
    });
  }

  async lockCouponForOrder(params: LockCouponForOrderParams): Promise<{
    userCoupon: UserCoupon;
    coupon: Coupon;
    discount: number;
  }> {
    const managerQuery = params.manager
      ? params.manager
          .createQueryBuilder(UserCoupon, "userCoupon")
          .leftJoinAndSelect("userCoupon.coupon", "coupon")
          .where("userCoupon.id = :userCouponId", {
            userCouponId: params.userCouponId,
          })
      : null;

    if (managerQuery && params.userId > 0) {
      managerQuery.andWhere("userCoupon.userId = :userId", {
        userId: params.userId,
      });
    }

    const userCoupon = managerQuery
      ? await managerQuery.setLock("pessimistic_write").getOne()
      : await this.userCouponRepository.findOne({
          where: { id: params.userCouponId, userId: params.userId },
          relations: ["coupon"],
        });

    if (!userCoupon) {
      throw createBusinessException(ErrorCode.COUPON_NOT_FOUND);
    }

    const evaluation = await this.evaluateCouponForLockedUserCoupon(
      userCoupon,
      params.orderAmount,
      params.productIds,
      params.orderLines,
    );

    if (!evaluation.isApplicable) {
      throw createBusinessException(
        ErrorCode.COUPON_NOT_APPLICABLE,
        evaluation.unavailableReason,
      );
    }

    return {
      userCoupon,
      coupon: userCoupon.coupon,
      discount: evaluation.discountAmount,
    };
  }

  async markCouponUsedForOrder(
    userCoupon: UserCoupon,
    orderId: number,
    manager: any,
  ): Promise<void> {
    userCoupon.status = UserCouponStatus.USED;
    userCoupon.orderId = orderId;
    userCoupon.usedAt = new Date();
    await manager.save(userCoupon);
  }

  async releaseCouponForOrder(orderId: number, manager?: any): Promise<void> {
    const userCoupon = manager
      ? await manager.findOne(UserCoupon, {
          where: { orderId },
          relations: ["coupon"],
        })
      : await this.userCouponRepository.findOne({
          where: { orderId },
          relations: ["coupon"],
        });

    if (!userCoupon || userCoupon.status !== UserCouponStatus.USED) {
      return;
    }

    const now = new Date();
    const coupon = userCoupon.coupon;
    const canRestore =
      now <= userCoupon.expiredAt &&
      coupon?.status === CouponStatus.ACTIVE &&
      coupon?.isEnabled === 0 &&
      now >= coupon.validFrom &&
      now <= coupon.validAt;

    userCoupon.status = canRestore
      ? UserCouponStatus.AVAILABLE
      : UserCouponStatus.EXPIRED;
    userCoupon.orderId = null as any;
    userCoupon.usedAt = null as any;

    if (manager) {
      await manager.save(UserCoupon, userCoupon);
      return;
    }

    await this.userCouponRepository.save(userCoupon);
  }

  /**
   * 获取所有优惠券（管理员）
   */
  async getAllCoupons(): Promise<Coupon[]> {
    return this.couponRepository.find({
      order: { createdAt: "DESC" },
    });
  }

  /**
   * 作废优惠券（管理员）
   */
  async revokeCoupon(couponId: number): Promise<void> {
    await this.couponRepository.update(couponId, {
      status: CouponStatus.REVOKED,
    });
    await this.userCouponRepository.update(
      {
        couponId,
        status: UserCouponStatus.AVAILABLE,
      },
      {
        status: UserCouponStatus.EXPIRED,
      },
    );
    this.logger.log(`Coupon revoked: ${couponId}`);
  }

  // ========== 后台管理功能 ==========

  /**
   * 更新优惠券状态（已过期、已领完）
   */
  async updateCouponStatus(couponId?: number): Promise<void> {
    const now = new Date();
    const baseWhere: any = {};
    if (couponId) {
      baseWhere.id = couponId;
    }

    // 批量更新已过期的优惠券：当前时间 > validAt 且 isExpired = 0
    await this.couponRepository
      .createQueryBuilder()
      .update(Coupon)
      .set({
        isExpired: 1,
        status: CouponStatus.EXPIRED,
      })
      .where("isExpired = :isExpired", { isExpired: 0 })
      .andWhere("validAt < :now", { now })
      .andWhere(couponId ? "id = :id" : "1=1", { id: couponId })
      .execute();

    // 批量更新已领完的优惠券：claimedCount >= stock 且 isClaimedOut = 0
    await this.couponRepository
      .createQueryBuilder()
      .update(Coupon)
      .set({
        isClaimedOut: 1,
      })
      .where("isClaimedOut = :isClaimedOut", { isClaimedOut: 0 })
      .andWhere("claimedCount >= stock")
      .andWhere(couponId ? "id = :id" : "1=1", { id: couponId })
      .execute();
  }

  /**
   * 获取优惠券列表（分页）
   */
  async getCouponList(query: QueryCouponDto) {
    // 先更新状态
    await this.updateCouponStatus();

    const { page = 1, limit = 10, name, type, scope, isEnabled } = query;
    const where: any = {};

    if (name) {
      where.name = Like(`%${name}%`);
    }
    if (type) {
      where.type = type;
    }
    if (scope) {
      where.scope = scope;
    }
    if (typeof isEnabled !== "undefined") {
      where.isEnabled = isEnabled;
    }

    const [list, total] = await this.couponRepository.findAndCount({
      where,
      order: { createdAt: "DESC" },
      skip: (page - 1) * limit,
      take: limit,
    });

    // 为指定商品类型的优惠券加载关联商品
    const couponIds = list
      .filter((c) => c.scope === "SPECIFIC")
      .map((c) => c.id);
    if (couponIds.length > 0) {
      try {
        const couponProducts = await this.couponProductRepository
          .createQueryBuilder("cp")
          .leftJoinAndSelect("cp.product", "product")
          .where("cp.couponId IN (:...couponIds)", { couponIds })
          .getMany();

        // 按优惠券ID分组商品
        const productsMap = new Map<number, any[]>();
        couponProducts.forEach((cp) => {
          if (!productsMap.has(cp.couponId)) {
            productsMap.set(cp.couponId, []);
          }
          if (cp.product) {
            productsMap.get(cp.couponId)!.push(cp.product);
          }
        });

        // 将商品列表附加到对应的优惠券
        list.forEach((coupon) => {
          if (coupon.scope === "SPECIFIC") {
            (coupon as any).products = productsMap.get(coupon.id) || [];
          }
        });
      } catch (error) {
        this.logger.error(`加载优惠券商品关联失败: ${error.message}`);
        // 如果加载商品失败，至少返回优惠券列表
        list.forEach((coupon) => {
          if (coupon.scope === "SPECIFIC") {
            (coupon as any).products = [];
          }
        });
      }
    }

    return {
      data: list,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * 获取优惠券详情（包含商品关联）
   */
  async findOne(id: number): Promise<Coupon> {
    const coupon = await this.couponRepository.findOne({
      where: { id },
    });

    if (!coupon) {
      throw createBusinessException(ErrorCode.COUPON_NOT_FOUND);
    }

    // 如果是指定商品，加载商品列表
    if (coupon.scope === "SPECIFIC") {
      try {
        const couponProducts = await this.couponProductRepository
          .createQueryBuilder("cp")
          .leftJoinAndSelect("cp.product", "product")
          .where("cp.couponId = :couponId", { couponId: id })
          .getMany();

        (coupon as any).products = couponProducts
          .filter((cp) => cp.product !== null)
          .map((cp) => cp.product);
      } catch (error) {
        this.logger.error(`加载优惠券商品关联失败: ${error.message}`);
        (coupon as any).products = [];
      }
    }

    return coupon;
  }

  /**
   * 更新优惠券
   */
  async updateCoupon(
    id: number,
    updateCouponDto: UpdateCouponDto,
  ): Promise<Coupon> {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // 获取原优惠券数据（用于判断状态）
      const existingCoupon = await queryRunner.manager.findOne(Coupon, {
        where: { id },
      });

      if (!existingCoupon) {
        throw createBusinessException(ErrorCode.COUPON_NOT_FOUND);
      }

      // 提取 Coupon 实体中存在的字段（排除 productIds）
      const { productIds, ...couponData } = updateCouponDto;

      // 计算更新后的过期状态
      const newValidAt = updateCouponDto.validAt
        ? new Date(updateCouponDto.validAt)
        : existingCoupon.validAt;

      const isExpired = newValidAt < new Date() ? 1 : 0;

      // 如果领取方式改为扫码领取且当前没有领取码，生成一个
      let claimCodeToSet = existingCoupon.claimCode;
      if (
        updateCouponDto.claimType === ClaimType.SCAN_CODE &&
        !existingCoupon.claimCode
      ) {
        claimCodeToSet = await this.generateUniqueClaimCode();
        this.logger.log(`为优惠券 ${id} 生成领取码: ${claimCodeToSet}`);
      }

      // 更新基本信息
      await queryRunner.manager.update(Coupon, id, {
        ...couponData,
        claimCode: claimCodeToSet,
        validFrom: updateCouponDto.validFrom
          ? new Date(updateCouponDto.validFrom)
          : undefined,
        validAt: updateCouponDto.validAt ? newValidAt : undefined,
        isExpired: isExpired,
      });

      // 如果是指定商品，更新关联关系
      if (updateCouponDto.scope === "SPECIFIC" && productIds) {
        // 删除旧的关联
        await queryRunner.manager.delete(CouponProduct, { couponId: id });

        // 创建新的关联
        if (productIds.length > 0) {
          const couponProducts = productIds.map((productId) =>
            queryRunner.manager.create(CouponProduct, {
              couponId: id,
              productId,
            }),
          );
          await queryRunner.manager.save(CouponProduct, couponProducts);
        }
      } else if (updateCouponDto.scope === "ALL") {
        // 删除旧的关联
        await queryRunner.manager.delete(CouponProduct, { couponId: id });
      }

      await queryRunner.commitTransaction();
      this.logger.log(`Coupon updated: ${id}`);

      return this.findOne(id);
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  /**
   * 切换优惠券状态（启用/禁用）
   */
  async toggleCouponStatus(id: number): Promise<void> {
    const coupon = await this.couponRepository.findOne({ where: { id } });
    if (!coupon) {
      throw createBusinessException(ErrorCode.COUPON_NOT_FOUND);
    }

    const newStatus = coupon.isEnabled === 0 ? 1 : 0;
    await this.couponRepository.update(id, { isEnabled: newStatus });

    if (newStatus === 1) {
      await this.userCouponRepository.update(
        {
          couponId: id,
          status: UserCouponStatus.AVAILABLE,
        },
        {
          status: UserCouponStatus.EXPIRED,
        },
      );
    }

    this.logger.log(`Coupon status toggled: ${id}, new status: ${newStatus}`);
  }

  /**
   * 生成唯一的领取码
   * @returns 领取码，格式：CLAIM_XXXXXX
   */
  private async generateUniqueClaimCode(): Promise<string> {
    const generateCode = () => {
      const chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
      let code = "CLAIM_";
      for (let i = 0; i < 6; i++) {
        code += chars[crypto.randomInt(0, chars.length)];
      }
      return code;
    };

    const MAX_ATTEMPTS = 100;
    let attempts = 0;

    let code = generateCode();
    // 确保唯一性
    while (
      await this.couponRepository.findOne({ where: { claimCode: code } })
    ) {
      if (attempts >= MAX_ATTEMPTS) {
        throw new InternalServerErrorException("领取码生成失败，请重试");
      }
      code = generateCode();
      attempts++;
    }
    return code;
  }

  /**
   * 生成优惠券二维码
   * @param id 优惠券ID
   * @returns 二维码图片 base64 或错误信息
   */
  async generateQRCode(
    id: number,
  ): Promise<{ qrcode?: string; success: boolean; message?: string }> {
    const coupon = await this.couponRepository.findOne({
      where: { id },
    });

    if (!coupon) {
      return {
        success: false,
        message: "优惠券不存在",
      };
    }

    // 如果 claimType 不是扫码领取，返回错误
    if (coupon.claimType !== ClaimType.SCAN_CODE) {
      return {
        success: false,
        message: "该优惠券不是扫码领取类型，无法生成二维码",
      };
    }

    // 如果没有领取码，自动生成一个
    let claimCode = coupon.claimCode;
    if (!claimCode) {
      claimCode = await this.generateUniqueClaimCode();
      await this.couponRepository.update(coupon.id, { claimCode });
      this.logger.log(`为优惠券 ${coupon.id} 自动生成领取码: ${claimCode}`);
    }

    // 生成二维码内容
    const qrContent = JSON.stringify({
      type: "coupons",
      value: claimCode,
    });

    // 使用 qrcode 库生成
    const QRCode = require("qrcode");
    const qrcode = await QRCode.toDataURL(qrContent, {
      width: 300,
      margin: 2,
      color: {
        dark: "#000000",
        light: "#FFFFFF",
      },
    });

    return {
      success: true,
      qrcode,
    };
  }

  /**
   * 检查用户是否可以领取优惠券
   */
  async canUserClaimCoupon(userId: number, couponId: number): Promise<boolean> {
    const coupon = await this.couponRepository.findOne({
      where: { id: couponId },
    });

    // 1. 优惠券是否存在
    if (!coupon) return false;

    // 2. 优惠券是否启用
    if (coupon.isEnabled !== 0) return false;

    // 3. 优惠券是否在有效期内
    const now = new Date();
    if (coupon.validFrom > now || coupon.validAt < now) return false;

    // 4. 优惠券是否已过期或已作废
    if (coupon.status !== CouponStatus.ACTIVE) return false;

    // 5. 优惠券是否已领完
    if (coupon.stock <= coupon.claimedCount) return false;

    // 6. 用户是否已领取达到上限
    const userClaimedCount = await this.userCouponRepository.count({
      where: { userId, couponId },
    });
    if (userClaimedCount >= coupon.perUserLimit) return false;

    return true;
  }

  /**
   * 为新用户自动领取可领取的优惠券
   * @param userId 用户ID
   * @returns 领取到的优惠券列表
   */
  async claimCouponsForNewUser(userId: number): Promise<UserCoupon[]> {
    // 查找所有新用户领取类型的有效优惠券
    const availableCoupons = await this.couponRepository.find({
      where: {
        claimType: ClaimType.NEW_USER,
        isEnabled: 0,
        status: CouponStatus.ACTIVE,
      },
    });

    const claimedCoupons: UserCoupon[] = [];

    for (const coupon of availableCoupons) {
      try {
        // 检查是否可以领取（库存、限领等）
        const canClaim = await this.canUserClaimCoupon(userId, coupon.id);
        if (!canClaim) continue;

        // 领取优惠券
        const userCoupon = await this.claimCoupon(
          { couponId: coupon.id },
          userId,
        );
        claimedCoupons.push(userCoupon);
      } catch (error) {
        // 单个优惠券领取失败不影响其他
        this.logger.error(`优惠券 ${coupon.id} 领取失败:`, error);
      }
    }

    return claimedCoupons;
  }
}
