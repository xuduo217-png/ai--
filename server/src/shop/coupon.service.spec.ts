import { DataSource } from 'typeorm'
import { CouponService } from './coupon.service'
import { Coupon, CouponScope, CouponStatus, CouponType } from './entities/coupon.entity'
import { UserCoupon, UserCouponStatus } from './entities/user-coupon.entity'

describe('CouponService - order coupon workflow', () => {
  const mockCouponRepository = {
    findOne: jest.fn(),
  }

  const mockUserCouponRepository = {
    findOne: jest.fn(),
    find: jest.fn(),
    save: jest.fn(),
    update: jest.fn(),
  }

  const mockCouponProductRepository = {
    find: jest.fn(),
  }

  const lockedUserCouponQuery = {
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    setLock: jest.fn().mockReturnThis(),
    getOne: jest.fn(),
  }

  const mockManager = {
    createQueryBuilder: jest.fn(() => lockedUserCouponQuery),
    save: jest.fn(),
  }

  const mockDataSource = {
    transaction: jest.fn(async (callback) => callback(mockManager)),
  } as unknown as DataSource

  const service = new CouponService(
    mockCouponRepository as any,
    mockUserCouponRepository as any,
    mockCouponProductRepository as any,
    mockDataSource,
  )

  const createLockedUserCoupon = (overrides?: Partial<UserCoupon>): UserCoupon => {
    const coupon = {
      id: 10,
      name: '指定商品券',
      type: CouponType.FULL_REDUCTION,
      status: CouponStatus.ACTIVE,
      scope: CouponScope.SPECIFIC,
      isEnabled: 0,
      validFrom: new Date('2026-03-01T00:00:00.000Z'),
      validAt: new Date('2026-03-31T23:59:59.000Z'),
      minAmount: 100,
      discountValue: 20,
      maxDiscount: null,
    } as Coupon

    return {
      id: 1,
      userId: 99,
      couponId: coupon.id,
      coupon,
      status: UserCouponStatus.AVAILABLE,
      orderId: null as any,
      usedAt: null as any,
      expiredAt: new Date('2026-03-31T23:59:59.000Z'),
      createdAt: new Date('2026-03-05T00:00:00.000Z'),
      ...overrides,
    } as UserCoupon
  }

  afterEach(() => { jest.useRealTimers(); });

  beforeEach(() => {
    jest.useFakeTimers({ now: new Date('2026-03-15T12:00:00.000Z') });
    jest.clearAllMocks()
    lockedUserCouponQuery.leftJoinAndSelect.mockReturnThis()
    lockedUserCouponQuery.where.mockReturnThis()
    lockedUserCouponQuery.andWhere.mockReturnThis()
    lockedUserCouponQuery.setLock.mockReturnThis()
  })

  it('rejects specific-product coupons when no ordered product matches the bound products', async () => {
    lockedUserCouponQuery.getOne.mockResolvedValue(
      createLockedUserCoupon(),
    )
    mockCouponProductRepository.find.mockResolvedValue([
      { couponId: 10, productId: 2001 },
    ])

    await expect(
      service.lockCouponForOrder({
        userCouponId: 1,
        userId: 99,
        orderAmount: 199,
        productIds: [3001],
        manager: mockManager as any,
      }),
    ).rejects.toThrow('优惠券仅适用于指定商品')
  })

  it('rejects disabled coupons during order locking even if the user coupon is still AVAILABLE', async () => {
    lockedUserCouponQuery.getOne.mockResolvedValue(
      createLockedUserCoupon({
        coupon: {
          ...createLockedUserCoupon().coupon,
          scope: CouponScope.ALL,
          isEnabled: 1,
        } as Coupon,
      }),
    )
    mockCouponProductRepository.find.mockResolvedValue([])

    await expect(
      service.lockCouponForOrder({
        userCouponId: 1,
        userId: 99,
        orderAmount: 199,
        productIds: [3001],
        manager: mockManager as any,
      }),
    ).rejects.toThrow('优惠券已禁用')
  })

  it('calculates specific-product coupon discount from matched line amounts only', async () => {
    lockedUserCouponQuery.getOne.mockResolvedValue(
      createLockedUserCoupon(),
    )
    mockCouponProductRepository.find.mockResolvedValue([
      { couponId: 10, productId: 2001 },
    ])

    const result = await service.lockCouponForOrder({
      userCouponId: 1,
      userId: 99,
      orderAmount: 260,
      productIds: [2001, 3001],
      orderLines: [
        { productId: 2001, amount: 120 },
        { productId: 3001, amount: 140 },
      ],
      manager: mockManager as any,
    })

    expect(result.discount).toBe(20)
  })

  it('marks discount coupons as unavailable when minOrderAmount is not met', async () => {
    lockedUserCouponQuery.getOne.mockResolvedValue(
      createLockedUserCoupon({
        coupon: {
          ...createLockedUserCoupon().coupon,
          scope: CouponScope.ALL,
          type: CouponType.DISCOUNT,
          discountValue: 8.5,
          minAmount: 0,
          minOrderAmount: 300,
          maxDiscount: 50,
        } as Coupon,
      }),
    )
    mockCouponProductRepository.find.mockResolvedValue([])

    await expect(
      service.lockCouponForOrder({
        userCouponId: 1,
        userId: 99,
        orderAmount: 260,
        productIds: [3001],
        manager: mockManager as any,
      }),
    ).rejects.toThrow('订单金额未达到优惠券使用门槛')
  })

  it('maps effective order threshold to coupon.minAmount for app compatibility', async () => {
    mockUserCouponRepository.find.mockResolvedValue([
      createLockedUserCoupon({
        coupon: {
          ...createLockedUserCoupon().coupon,
          scope: CouponScope.ALL,
          type: CouponType.DIRECT_DISCOUNT,
          minAmount: 0,
          minOrderAmount: 199,
        } as Coupon,
      }),
    ])
    mockCouponProductRepository.find.mockResolvedValue([])

    const result = await service.getMyCoupons(99)

    expect(result).toEqual([
      expect.objectContaining({
        coupon: expect.objectContaining({
          minAmount: 199,
        }),
      }),
    ])
  })

  it('restores a used coupon back to AVAILABLE when the pending order is cancelled before payment', async () => {
    mockUserCouponRepository.findOne.mockResolvedValue({
      id: 1,
      userId: 99,
      couponId: 10,
      status: UserCouponStatus.USED,
      orderId: 5001,
      usedAt: new Date('2026-03-12T10:00:00.000Z'),
      expiredAt: new Date('2026-03-31T23:59:59.000Z'),
      coupon: {
        id: 10,
        status: CouponStatus.ACTIVE,
        isEnabled: 0,
        validFrom: new Date('2026-03-01T00:00:00.000Z'),
        validAt: new Date('2026-03-31T23:59:59.000Z'),
      },
    })

    await service.releaseCouponForOrder(5001)

    expect(mockUserCouponRepository.save).toHaveBeenCalledWith(
      expect.objectContaining({
        status: UserCouponStatus.AVAILABLE,
        orderId: null,
        usedAt: null,
      }),
    )
  })
})
