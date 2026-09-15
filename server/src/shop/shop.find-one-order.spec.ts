import { BadRequestException } from "@nestjs/common";
import { DataSource, Repository } from "typeorm";
import { ShopService } from "./shop.service";
import { Order, OrderStatus, OrderType } from "./entities/order.entity";
import {
  CharityDonationSource,
  CharityRecord,
} from "../charity/entities/charity-record.entity";

jest.mock("uuid", () => ({
  v4: jest.fn(() => "mocked-id"),
}));

describe("ShopService.findOneOrder", () => {
  let service: ShopService;
  let orderRepository: jest.Mocked<Partial<Repository<Order>>>;
  let charityRecordRepository: jest.Mocked<Partial<Repository<CharityRecord>>>;

  beforeEach(() => {
    orderRepository = {
      findOne: jest.fn(),
    };
    charityRecordRepository = {
      find: jest.fn().mockResolvedValue([]),
    };

    service = new ShopService(
      {} as any,
      {} as any,
      orderRepository as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as DataSource,
      {} as any,
      {} as any,
      {
        get: jest.fn(() => "test"),
      } as any,
      { getPlatformFeeRate: jest.fn(async () => 5) } as any,
      undefined,
      undefined,
      charityRecordRepository as any,
    );

    jest
      .spyOn(service as any, "fillOrderItemsWithImages")
      .mockResolvedValue(undefined);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it("allows the seller to read their related second-hand order", async () => {
    const order = {
      id: 101,
      orderNo: "ORD_SELLER_101",
      userId: 8,
      sellerId: 12,
      status: OrderStatus.COMPLETED,
      items: [
        {
          productId: 501,
          productName: "二手猫爬架",
          quantity: 1,
          price: 100,
        },
      ],
    } as Order;

    orderRepository.findOne!.mockResolvedValue(order);

    await expect(service.findOneOrder(101, 12, "USER")).resolves.toMatchObject({
      id: 101,
      sellerId: 12,
    });
  });

  it("still rejects unrelated users", async () => {
    const order = {
      id: 102,
      orderNo: "ORD_SELLER_102",
      userId: 8,
      sellerId: 12,
      status: OrderStatus.COMPLETED,
      items: [],
    } as Order;

    orderRepository.findOne!.mockResolvedValue(order);

    await expect(service.findOneOrder(102, 99, "USER")).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it("returns the order's net charity donation after refund reversals", async () => {
    const order = {
      id: 103,
      orderNo: "ORD_CHARITY_103",
      orderType: OrderType.NORMAL,
      userId: 8,
      status: OrderStatus.PAID,
      items: [],
    } as Order;
    orderRepository.findOne!.mockResolvedValue(order);
    charityRecordRepository.find!.mockResolvedValue([
      { donationAmount: 1.5 },
      { donationAmount: -0.75 },
    ] as CharityRecord[]);

    await expect(service.findOneOrder(103, 8, "USER")).resolves.toMatchObject({
      charityDonationAmount: 0.75,
    });
    expect(charityRecordRepository.find).toHaveBeenCalledWith({
      where: {
        orderId: 103,
        donationSource: CharityDonationSource.MALL_ORDER,
      },
      select: { donationAmount: true },
    });
  });
});
