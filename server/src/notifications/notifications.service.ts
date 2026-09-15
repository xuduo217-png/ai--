import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Notification, NotificationType, ActionType } from './entities/notification.entity';
import {
  QueryNotificationsDto,
  UnreadCountResponseDto,
  MarkAsReadResponseDto,
  MarkAllAsReadResponseDto,
  CreateNotificationDto,
} from './dto/notification.dto';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectRepository(Notification)
    private readonly notificationRepository: Repository<Notification>,
  ) {}

  /**
   * 获取通知列表（分页）
   */
  async findAll(
    userId: number,
    queryNotificationsDto: QueryNotificationsDto,
  ): Promise<{ data: Notification[]; total: number; page: number; pageSize: number }> {
    const { page, pageSize, type } = queryNotificationsDto;
    const skip = (page - 1) * pageSize;

    const where: any = { userId };
    if (type) {
      where.type = type;
    }

    const [data, total] = await this.notificationRepository.findAndCount({
      where,
      order: { createdAt: 'DESC' },
      skip,
      take: pageSize,
    });

    return {
      data,
      total,
      page,
      pageSize,
    };
  }

  /**
   * 获取未读消息数量
   */
  async getUnreadCount(userId: number): Promise<UnreadCountResponseDto> {
    const count = await this.notificationRepository.count({
      where: { userId, isRead: false },
    });

    return { count };
  }

  /**
   * 获取消息详情
   */
  async findOne(userId: number, id: number): Promise<Notification> {
    const notification = await this.notificationRepository.findOne({
      where: { id, userId },
    });

    if (!notification) {
      throw new NotFoundException('Notification not found');
    }

    return notification;
  }

  /**
   * 标记单条消息已读
   */
  async markAsRead(userId: number, id: number): Promise<MarkAsReadResponseDto> {
    const notification = await this.findOne(userId, id);

    await this.notificationRepository.update(notification.id, {
      isRead: true,
      readAt: Date.now(),
    });

    return { success: true };
  }

  /**
   * 全部标记已读
   */
  async markAllAsRead(userId: number): Promise<MarkAllAsReadResponseDto> {
    const unreadNotifications = await this.notificationRepository.find({
      where: { userId, isRead: false },
    });

    const now = Date.now();
    const updatePromises = unreadNotifications.map((notification) =>
      this.notificationRepository.save({
        ...notification,
        isRead: true,
        readAt: now,
      }),
    );

    await Promise.all(updatePromises);

    return {
      success: true,
      updatedCount: unreadNotifications.length,
    };
  }

  /**
   * 创建通知（内部使用）
   */
  async create(createNotificationDto: CreateNotificationDto): Promise<Notification> {
    const now = Date.now();
    const notification = this.notificationRepository.create({
      ...createNotificationDto,
      isRead: false,
      createdAt: now,
      updatedAt: now,
      readAt: null,
    });

    return await this.notificationRepository.save(notification);
  }
}
