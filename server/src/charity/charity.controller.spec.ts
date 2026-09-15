import { Test, TestingModule } from '@nestjs/testing';
import { CharityController } from './charity.controller';
import { CharityService } from './charity.service';

describe('CharityController', () => {
  let controller: CharityController;

  const mockCharityService = {
    findAll: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    remove: jest.fn(),
    getStats: jest.fn(),
    getParticipants: jest.fn(),
    publishArticle: jest.fn(),
    updateArticle: jest.fn(),
    getPublishedArticle: jest.fn(),
    getAdminArticles: jest.fn(),
    findUserActivities: jest.fn(),
    findOne: jest.fn(),
    checkIn: jest.fn(),
    getUserRecords: jest.fn(),
    getArticles: jest.fn(),
    donate: jest.fn(),
    createDonationPayment: jest.fn(),
    getDonationRecords: jest.fn(),
    getLatestDonationRecords: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [CharityController],
      providers: [
        {
          provide: CharityService,
          useValue: mockCharityService,
        },
      ],
    }).compile();

    controller = module.get<CharityController>(CharityController);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should forward optional JWT user id for charity list', async () => {
    const mockResult = {
      data: [
        {
          id: 1,
          title: '公益活动',
          userCheckInCount: 3,
          hasCheckedToday: true,
        },
      ],
      total: 1,
      page: 1,
      pageSize: 10,
      totalPages: 1,
    };

    mockCharityService.findUserActivities.mockResolvedValue(mockResult);

    const result = await controller.findUserActivities(
      { page: 1, pageSize: 10 },
      { user: { id: 7 } },
    );

    expect(result).toEqual(mockResult);
    expect(mockCharityService.findUserActivities).toHaveBeenCalledWith(
      { page: 1, pageSize: 10 },
      7,
    );
  });

  it('should allow anonymous charity detail access without regressing to required JWT', async () => {
    const mockResult = {
      id: 1,
      title: '公益活动',
    };

    mockCharityService.findOne.mockResolvedValue(mockResult);

    const result = await controller.findOne('1', {});

    expect(result).toEqual(mockResult);
    expect(mockCharityService.findOne).toHaveBeenCalledWith(1, undefined);
  });

  it('should forward optional JWT user id for charity articles filtering', async () => {
    const mockResult = [
      {
        id: 11,
        charityId: 1,
        title: '公益总结',
      },
    ];

    mockCharityService.getArticles.mockResolvedValue(mockResult);

    const result = await controller.getArticles('1', { user: { id: 9 } });

    expect(result).toEqual(mockResult);
    expect(mockCharityService.getArticles).toHaveBeenCalledWith(1, 9);
  });

  it('should expose admin charity articles without user-target filtering', async () => {
    const mockResult = [
      {
        id: 12,
        charityId: 1,
        title: '管理员文章列表',
      },
    ];

    mockCharityService.getAdminArticles.mockResolvedValue(mockResult);

    const result = await (controller as any).getAdminArticles('1');

    expect(result).toEqual(mockResult);
    expect(mockCharityService.getAdminArticles).toHaveBeenCalledWith(1);
  });

  it('should forward donation payload to charity service', async () => {
    const mockResult = {
      success: true,
      message: '捐款成功',
      donationAmount: 20,
    };

    mockCharityService.donate.mockResolvedValue(mockResult);

    const result = await (controller as any).donate(
      '9',
      { amount: 20, paymentMethod: 'balance' },
      { user: { id: 6 } },
    );

    expect(result).toEqual(mockResult);
    expect(mockCharityService.donate).toHaveBeenCalledWith(
      6,
      9,
      { amount: 20, paymentMethod: 'balance' },
    );
  });

  it('should validate idempotency key and create an Alipay donation payment', async () => {
    const mockResult = {
      paymentNo: 'PAY_CHARITY_1',
      amount: 20,
      paymentParams: { alipayOrderString: 'alipay-order-string' },
    };
    const idempotencyKey = '123e4567-e89b-42d3-a456-426614174000';
    mockCharityService.createDonationPayment.mockResolvedValue(mockResult);

    const result = await controller.createDonationPayment(
      '9',
      idempotencyKey,
      { amount: 20 },
      { user: { id: 6 } },
    );

    expect(result).toEqual(mockResult);
    expect(mockCharityService.createDonationPayment).toHaveBeenCalledWith(
      6,
      9,
      idempotencyKey,
      { amount: 20 },
    );
  });

  it('should expose donation records without requiring a logged in user', async () => {
    const mockResult = {
      data: [
        {
          id: 21,
          charityId: 9,
          userId: 6,
          userName: '爱心人士',
          donationAmount: 20,
        },
      ],
      total: 1,
      page: 1,
      pageSize: 10,
      totalPages: 1,
    };

    mockCharityService.getDonationRecords.mockResolvedValue(mockResult);

    const result = await (controller as any).getDonationRecords('9', '1', '10');

    expect(result).toEqual(mockResult);
    expect(mockCharityService.getDonationRecords).toHaveBeenCalledWith(9, 1, 10);
  });

  it('should expose the latest donation records without requiring a logged in user', async () => {
    const mockResult = {
      data: [{ userName: '爱心人士', donationAmount: 20 }],
      total: 1,
      page: 1,
      pageSize: 20,
      totalPages: 1,
    };

    mockCharityService.getLatestDonationRecords.mockResolvedValue(mockResult);

    const result = await controller.getLatestDonationRecords();

    expect(result).toEqual(mockResult);
    expect(mockCharityService.getLatestDonationRecords).toHaveBeenCalledWith();
  });
});
