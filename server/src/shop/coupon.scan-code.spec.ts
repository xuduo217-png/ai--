import { DataSource } from "typeorm";
import { CouponService } from "./coupon.service";
import {
  ClaimType,
  Coupon,
  CouponScope,
  CouponStatus,
  CouponType,
} from "./entities/coupon.entity";
import { UserCoupon, UserCouponStatus } from "./entities/user-coupon.entity";

describe("CouponService - scan code coupon workflow", () => {
  const mockCouponRepository = {
    findOne: jest.fn(),
  };

  const mockUserCouponRepository = {
    findOne: jest.fn(),
    find: jest.fn(),
    count: jest.fn(),
    save: jest.fn(),
    update: jest.fn(),
  };

  const mockCouponProductRepository = {
    find: jest.fn(),
  };

  const couponQuery = {
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    setLock: jest.fn().mockReturnThis(),
    getOne: jest.fn(),
  };

  const queryRunner = {
    connect: jest.fn(),
    startTransaction: jest.fn(),
    commitTransaction: jest.fn(),
    rollbackTransaction: jest.fn(),
    release: jest.fn(),
    manager: {
      createQueryBuilder: jest.fn(() => couponQuery),
      count: jest.fn(),
      create: jest.fn(
        (_entity: unknown, payload: Record<string, unknown>) => payload,
      ),
      save: jest.fn(),
    },
  };

  const mockDataSource = {
    createQueryRunner: jest.fn(() => queryRunner),
  } as unknown as DataSource;

  const service = new CouponService(
    mockCouponRepository as any,
    mockUserCouponRepository as any,
    mockCouponProductRepository as any,
    mockDataSource,
  );

  const createScanCoupon = (overrides?: Partial<Coupon>): Coupon =>
    ({
      id: 9,
      name: "扫码立减券",
      description: "扫码领取后可在商城使用",
      type: CouponType.FULL_REDUCTION,
      status: CouponStatus.ACTIVE,
      scope: CouponScope.ALL,
      discountValue: 30,
      minAmount: 199,
      minOrderAmount: 199,
      maxDiscount: null,
      canStack: 0,
      isEnabled: 0,
      isExpired: 0,
      isClaimedOut: 0,
      stock: 50,
      claimedCount: 12,
      perUserLimit: 1,
      validFrom: new Date("2026-03-01T00:00:00.000Z"),
      validAt: new Date("2026-03-31T23:59:59.000Z"),
      claimType: ClaimType.SCAN_CODE,
      claimCode: "CLAIM_D37EBD",
      createdAt: new Date("2026-03-01T00:00:00.000Z"),
      updatedAt: new Date("2026-03-01T00:00:00.000Z"),
      ...overrides,
    }) as Coupon;

  const createUserCoupon = (overrides?: Partial<UserCoupon>): UserCoupon =>
    ({
      id: 1001,
      userId: 88,
      couponId: 9,
      coupon: createScanCoupon(),
      status: UserCouponStatus.AVAILABLE,
      orderId: null,
      usedAt: null,
      expiredAt: new Date("2026-03-31T23:59:59.000Z"),
      createdAt: new Date("2026-03-13T10:00:00.000Z"),
      ...overrides,
    }) as UserCoupon;

  afterEach(() => { jest.useRealTimers(); });

  beforeEach(() => {
    jest.useFakeTimers({ now: new Date('2026-03-15T12:00:00.000Z') });
    jest.clearAllMocks();
    couponQuery.where.mockReturnThis();
    couponQuery.andWhere.mockReturnThis();
    couponQuery.setLock.mockReturnThis();
  });

  it("returns scan coupon detail and marks coupons already claimed by the current user", async () => {
    mockCouponRepository.findOne.mockResolvedValue(createScanCoupon());
    mockUserCouponRepository.findOne.mockResolvedValue(createUserCoupon());

    const result = await (service as any).getCouponDetailByClaimCode(
      "CLAIM_D37EBD",
      88,
    );

    expect(result).toEqual(
      expect.objectContaining({
        claimCode: "CLAIM_D37EBD",
        canClaim: false,
        claimed: true,
        claimType: ClaimType.SCAN_CODE,
        coupon: expect.objectContaining({
          id: 9,
          name: "扫码立减券",
          minAmount: 199,
        }),
        userCoupon: expect.objectContaining({
          couponId: 9,
          status: UserCouponStatus.AVAILABLE,
        }),
      }),
    );
  });

  it("claims a scan coupon when only claimCode is provided", async () => {
    const coupon = createScanCoupon();
    couponQuery.getOne.mockResolvedValue(coupon);
    queryRunner.manager.count.mockResolvedValue(0);
    queryRunner.manager.save
      .mockResolvedValueOnce({
        id: 1002,
        userId: 88,
        couponId: 9,
        status: UserCouponStatus.AVAILABLE,
        expiredAt: coupon.validAt,
      })
      .mockResolvedValueOnce({
        ...coupon,
        claimedCount: coupon.claimedCount + 1,
      });

    const result = await service.claimCoupon(
      { claimCode: "CLAIM_D37EBD" } as any,
      88,
    );

    expect(result).toEqual(
      expect.objectContaining({
        id: 1002,
        userId: 88,
        couponId: 9,
        status: UserCouponStatus.AVAILABLE,
      }),
    );
    expect(queryRunner.manager.create).toHaveBeenCalledWith(
      UserCoupon,
      expect.objectContaining({
        userId: 88,
        couponId: 9,
      }),
    );
    expect(queryRunner.commitTransaction).toHaveBeenCalled();
  });
});
