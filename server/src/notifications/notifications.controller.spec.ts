import { Test, TestingModule } from '@nestjs/testing';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { NotificationType } from './entities/notification.entity';

describe('NotificationsController', () => {
  let controller: NotificationsController;
  let service: NotificationsService;

  const mockNotificationsService = {
    findAll: jest.fn(),
    getUnreadCount: jest.fn(),
    findOne: jest.fn(),
    markAsRead: jest.fn(),
    markAllAsRead: jest.fn(),
  };

  const mockUserId = 1;
  const mockRequest = {
    user: { id: mockUserId },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [NotificationsController],
      providers: [
        {
          provide: NotificationsService,
          useValue: mockNotificationsService,
        },
      ],
    }).compile();

    controller = module.get<NotificationsController>(NotificationsController);
    service = module.get<NotificationsService>(NotificationsService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('findAll', () => {
    it('should return paginated notifications', async () => {
      const mockResult = {
        data: [
          {
            id: 1,
            userId: mockUserId,
            type: NotificationType.SYSTEM,
            title: '系统通知',
            content: '您的预约已成功',
            isRead: false,
            createdAt: Date.now(),
          },
        ],
        total: 1,
        page: 1,
        pageSize: 20,
      };

      mockNotificationsService.findAll.mockResolvedValue(mockResult);

      const result = await controller.findAll(mockRequest, {
        page: 1,
        pageSize: 20,
      });

      expect(result).toEqual(mockResult);
      expect(service.findAll).toHaveBeenCalledWith(mockUserId, {
        page: 1,
        pageSize: 20,
      });
    });

    it('should filter by type when type query param is provided', async () => {
      mockNotificationsService.findAll.mockResolvedValue({
        data: [],
        total: 0,
        page: 1,
        pageSize: 20,
      });

      await controller.findAll(mockRequest, {
        page: 1,
        pageSize: 20,
        type: NotificationType.SYSTEM,
      });

      expect(service.findAll).toHaveBeenCalledWith(mockUserId, {
        page: 1,
        pageSize: 20,
        type: NotificationType.SYSTEM,
      });
    });
  });

  describe('getUnreadCount', () => {
    it('should return unread count', async () => {
      mockNotificationsService.getUnreadCount.mockResolvedValue({ count: 5 });

      const result = await controller.getUnreadCount(mockRequest);

      expect(result).toEqual({ count: 5 });
      expect(service.getUnreadCount).toHaveBeenCalledWith(mockUserId);
    });
  });

  describe('findOne', () => {
    it('should return notification by id', async () => {
      const mockNotification = {
        id: 1,
        userId: mockUserId,
        type: NotificationType.SYSTEM,
        title: '系统通知',
        content: '您的预约已成功',
        isRead: false,
        createdAt: Date.now(),
      };

      mockNotificationsService.findOne.mockResolvedValue(mockNotification);

      const result = await controller.findOne(mockRequest, '1');

      expect(result).toEqual(mockNotification);
      expect(service.findOne).toHaveBeenCalledWith(mockUserId, 1);
    });
  });

  describe('markAsRead', () => {
    it('should mark notification as read', async () => {
      mockNotificationsService.markAsRead.mockResolvedValue({ success: true });

      const result = await controller.markAsRead(mockRequest, '1');

      expect(result).toEqual({ success: true });
      expect(service.markAsRead).toHaveBeenCalledWith(mockUserId, 1);
    });
  });

  describe('markAllAsRead', () => {
    it('should mark all notifications as read', async () => {
      mockNotificationsService.markAllAsRead.mockResolvedValue({
        success: true,
        updatedCount: 10,
      });

      const result = await controller.markAllAsRead(mockRequest);

      expect(result).toEqual({ success: true, updatedCount: 10 });
      expect(service.markAllAsRead).toHaveBeenCalledWith(mockUserId);
    });
  });
});
