import { Test, TestingModule } from "@nestjs/testing";
import { getRepositoryToken } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { NotFoundException } from "@nestjs/common";
import { NotificationsService } from "./notifications.service";
import {
  Notification,
  NotificationType,
  ActionType,
} from "./entities/notification.entity";
import { CreateNotificationDto } from "./dto/notification.dto";
import {
  NotificationScene,
  NotificationSenderService,
} from "./notification-sender.service";

describe("NotificationsService", () => {
  let service: NotificationsService;
  let repository: Repository<Notification>;

  const mockRepository = {
    find: jest.fn(),
    findAndCount: jest.fn(),
    findOne: jest.fn(),
    create: jest.fn(),
    save: jest.fn(),
    update: jest.fn(),
    count: jest.fn(),
    countBy: jest.fn(),
  };

  const mockUserId = 1;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationsService,
        {
          provide: getRepositoryToken(Notification),
          useValue: mockRepository,
        },
      ],
    }).compile();

    service = module.get<NotificationsService>(NotificationsService);
    repository = module.get<Repository<Notification>>(
      getRepositoryToken(Notification),
    );
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe("findAll", () => {
    it("should return paginated notification list", async () => {
      const mockNotifications = [
        {
          id: 1,
          userId: mockUserId,
          type: NotificationType.SYSTEM,
          title: "系统通知",
          content: "您的预约已成功",
          isRead: false,
          actionType: ActionType.APPOINTMENT,
          actionData: { appointmentId: 123 },
          priority: 0,
          createdAt: Date.now(),
          updatedAt: Date.now(),
          readAt: null,
        },
      ];

      mockRepository.findAndCount.mockResolvedValue([mockNotifications, 1]);

      const result = await service.findAll(mockUserId, {
        page: 1,
        pageSize: 20,
      });

      expect(result).toEqual({
        data: mockNotifications,
        total: 1,
        page: 1,
        pageSize: 20,
      });
      expect(mockRepository.findAndCount).toHaveBeenCalledWith({
        where: { userId: mockUserId },
        order: { createdAt: "DESC" },
        skip: 0,
        take: 20,
      });
    });

    it("should filter by notification type when type is provided", async () => {
      mockRepository.findAndCount.mockResolvedValue([[], 0]);

      await service.findAll(mockUserId, {
        page: 1,
        pageSize: 20,
        type: NotificationType.SYSTEM,
      });

      expect(mockRepository.findAndCount).toHaveBeenCalledWith({
        where: { userId: mockUserId, type: NotificationType.SYSTEM },
        order: { createdAt: "DESC" },
        skip: 0,
        take: 20,
      });
    });

    it("should calculate skip correctly for pagination", async () => {
      mockRepository.findAndCount.mockResolvedValue([[], 0]);

      await service.findAll(mockUserId, {
        page: 2,
        pageSize: 20,
      });

      expect(mockRepository.findAndCount).toHaveBeenCalledWith({
        where: { userId: mockUserId },
        order: { createdAt: "DESC" },
        skip: 20,
        take: 20,
      });
    });
  });

  describe("getUnreadCount", () => {
    it("should return unread count", async () => {
      mockRepository.count.mockResolvedValue(5);

      const result = await service.getUnreadCount(mockUserId);

      expect(result).toEqual({ count: 5 });
      expect(mockRepository.count).toHaveBeenCalledWith({
        where: { userId: mockUserId, isRead: false },
      });
    });

    it("should return 0 when no unread messages", async () => {
      mockRepository.count.mockResolvedValue(0);

      const result = await service.getUnreadCount(mockUserId);

      expect(result).toEqual({ count: 0 });
    });
  });

  describe("findOne", () => {
    it("should return notification by id", async () => {
      const mockNotification = {
        id: 1,
        userId: mockUserId,
        type: NotificationType.SYSTEM,
        title: "系统通知",
        content: "您的预约已成功",
        isRead: false,
        actionType: ActionType.APPOINTMENT,
        actionData: { appointmentId: 123 },
        priority: 0,
        createdAt: Date.now(),
        updatedAt: Date.now(),
        readAt: null,
      };

      mockRepository.findOne.mockResolvedValue(mockNotification);

      const result = await service.findOne(mockUserId, 1);

      expect(result).toEqual(mockNotification);
      expect(mockRepository.findOne).toHaveBeenCalledWith({
        where: { id: 1, userId: mockUserId },
      });
    });

    it("should throw NotFoundException when notification not found", async () => {
      mockRepository.findOne.mockResolvedValue(null);

      await expect(service.findOne(mockUserId, 999)).rejects.toThrow(
        NotFoundException,
      );
      await expect(service.findOne(mockUserId, 999)).rejects.toThrow(
        "Notification not found",
      );
    });

    it("should throw NotFoundException when notification belongs to different user", async () => {
      const otherUserId = 2;
      mockRepository.findOne.mockResolvedValue(null);

      await expect(service.findOne(otherUserId, 1)).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe("markAsRead", () => {
    it("should mark notification as read", async () => {
      const mockNotification = {
        id: 1,
        userId: mockUserId,
        type: NotificationType.SYSTEM,
        title: "系统通知",
        content: "您的预约已成功",
        isRead: false,
        actionType: ActionType.APPOINTMENT,
        actionData: { appointmentId: 123 },
        priority: 0,
        createdAt: Date.now(),
        updatedAt: Date.now(),
        readAt: null,
      };

      mockRepository.findOne.mockResolvedValue(mockNotification);
      const now = Date.now();
      jest.spyOn(Date, "now").mockReturnValue(now);
      mockRepository.update.mockResolvedValue({ affected: 1 });

      const result = await service.markAsRead(mockUserId, 1);

      expect(result).toEqual({ success: true });
      expect(mockRepository.findOne).toHaveBeenCalledWith({
        where: { id: 1, userId: mockUserId },
      });
      expect(mockRepository.update).toHaveBeenCalledWith(
        1,
        expect.objectContaining({
          isRead: true,
          readAt: now,
        }),
      );
    });

    it("should throw NotFoundException when notification not found", async () => {
      mockRepository.findOne.mockResolvedValue(null);

      await expect(service.markAsRead(mockUserId, 999)).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe("markAllAsRead", () => {
    it("should mark all unread notifications as read", async () => {
      const mockUnreadNotifications = [
        { id: 1, userId: mockUserId, isRead: false },
        { id: 2, userId: mockUserId, isRead: false },
      ];

      mockRepository.find.mockResolvedValue(mockUnreadNotifications);
      mockRepository.save.mockResolvedValue({});
      const now = Date.now();
      jest.spyOn(Date, "now").mockReturnValue(now);

      const result = await service.markAllAsRead(mockUserId);

      expect(result).toEqual({ success: true, updatedCount: 2 });
      expect(mockRepository.find).toHaveBeenCalledWith({
        where: { userId: mockUserId, isRead: false },
      });
      expect(mockRepository.save).toHaveBeenCalledTimes(2);
    });

    it("should return 0 updatedCount when no unread notifications", async () => {
      mockRepository.find.mockResolvedValue([]);

      const result = await service.markAllAsRead(mockUserId);

      expect(result).toEqual({ success: true, updatedCount: 0 });
      expect(mockRepository.save).not.toHaveBeenCalled();
    });
  });

  describe("create", () => {
    it("should create a new notification", async () => {
      const createDto: CreateNotificationDto = {
        userId: mockUserId,
        type: NotificationType.SYSTEM,
        title: "系统通知",
        content: "您的预约已成功",
        actionType: ActionType.APPOINTMENT,
        actionData: { appointmentId: 123 },
        priority: 0,
      };

      const now = Date.now();
      jest.spyOn(Date, "now").mockReturnValue(now);

      const mockNotification = {
        id: 1,
        ...createDto,
        isRead: false,
        createdAt: now,
        updatedAt: now,
        readAt: null,
      };

      mockRepository.create.mockResolvedValue(mockNotification);
      mockRepository.save.mockResolvedValue(mockNotification);

      const result = await service.create(createDto);

      expect(result).toEqual(mockNotification);
      expect(mockRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          ...createDto,
          isRead: false,
          createdAt: now,
          updatedAt: now,
          readAt: null,
        }),
      );
      expect(mockRepository.save).toHaveBeenCalled();
    });
  });
});

describe("NotificationSenderService navigation payloads", () => {
  const notificationsService = {
    create: jest.fn().mockResolvedValue(undefined),
  };
  let sender: NotificationSenderService;

  beforeEach(() => {
    jest.clearAllMocks();
    sender = new NotificationSenderService(
      notificationsService as unknown as NotificationsService,
    );
  });

  it.each([
    NotificationScene.APPOINTMENT_CREATED,
    NotificationScene.APPOINTMENT_CONFIRMED,
    NotificationScene.APPOINTMENT_REJECTED,
    NotificationScene.APPOINTMENT_COMPLETED,
    NotificationScene.APPOINTMENT_CANCELLED,
    NotificationScene.APPOINTMENT_RESCHEDULED,
  ])("adds the standard appointment discriminator for %s", async (scene) => {
    await sender.send(7, scene, { appointmentId: 31 });

    expect(notificationsService.create).toHaveBeenCalledWith(
      expect.objectContaining({
        actionType: ActionType.APPOINTMENT,
        actionData: { appointmentId: 31, appointmentKind: "standard" },
      }),
    );
  });

  it.each([
    NotificationScene.HEALTH_APPOINTMENT_CREATED,
    NotificationScene.HEALTH_APPOINTMENT_COMPLETED,
  ])("adds the health appointment discriminator for %s", async (scene) => {
    await sender.send(7, scene, { appointmentId: 32 });

    expect(notificationsService.create).toHaveBeenCalledWith(
      expect.objectContaining({
        actionType: ActionType.APPOINTMENT,
        actionData: { appointmentId: 32, appointmentKind: "health" },
      }),
    );
  });

  it("keeps cancelled orders actionable", async () => {
    await sender.send(7, NotificationScene.ORDER_CANCELLED, { orderId: 41 });

    expect(notificationsService.create).toHaveBeenCalledWith(
      expect.objectContaining({
        actionType: ActionType.ORDER,
        actionData: { orderId: 41, viewRole: "buyer" },
      }),
    );
  });

  it("includes order, after-sale and role identifiers for after-sale navigation", async () => {
    await sender.send(8, NotificationScene.AFTER_SALE_CREATED, {
      orderId: 41,
      afterSaleId: 51,
      viewRole: "seller",
    });

    expect(notificationsService.create).toHaveBeenCalledWith(
      expect.objectContaining({
        actionType: ActionType.ORDER,
        actionData: {
          orderId: 41,
          afterSaleId: 51,
          viewRole: "seller",
        },
      }),
    );
  });

  it("routes settlement results to the seller order view", async () => {
    await sender.send(8, NotificationScene.SELLER_SETTLEMENT_APPROVED, {
      orderId: 41,
      amount: "95.00",
    });

    expect(notificationsService.create).toHaveBeenCalledWith(
      expect.objectContaining({
        actionType: ActionType.ORDER,
        actionData: { orderId: 41, viewRole: "seller" },
      }),
    );
  });

  it("routes rejected products to the published-products list", async () => {
    await sender.send(7, NotificationScene.PRODUCT_AUDIT_REJECTED, {
      productId: 51,
      productName: "二手猫窝",
      reason: "信息不完整",
    });

    expect(notificationsService.create).toHaveBeenCalledWith(
      expect.objectContaining({
        actionType: ActionType.PAGE,
        actionData: { path: "MyPublishedProducts" },
      }),
    );
  });

  it("routes announcements without an explicit target to home", async () => {
    await sender.send(7, NotificationScene.SYSTEM_ANNOUNCEMENT, {
      title: "维护通知",
      content: "维护完成",
    });

    expect(notificationsService.create).toHaveBeenCalledWith(
      expect.objectContaining({
        actionType: ActionType.PAGE,
        actionData: { path: "Home" },
      }),
    );
  });
});
