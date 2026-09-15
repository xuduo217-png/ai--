import { Controller, Get, Put, Param, Body, Query, UseGuards, Request } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { NotificationsService } from './notifications.service';
import { QueryNotificationsDto } from './dto/notification.dto';

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  /**
   * 获取通知列表
   */
  @Get()
  async findAll(@Request() req, @Query() query: QueryNotificationsDto) {
    const userId = req.user.id;
    return await this.notificationsService.findAll(userId, query);
  }

  /**
   * 获取未读消息数量
   */
  @Get('unread-count')
  async getUnreadCount(@Request() req) {
    const userId = req.user.id;
    return await this.notificationsService.getUnreadCount(userId);
  }

  /**
   * 获取消息详情
   */
  @Get(':id')
  async findOne(@Request() req, @Param('id') id: string) {
    const userId = req.user.id;
    const notificationId = parseInt(id, 10);
    return await this.notificationsService.findOne(userId, notificationId);
  }

  /**
   * 标记单条消息已读
   */
  @Put(':id/read')
  async markAsRead(@Request() req, @Param('id') id: string) {
    const userId = req.user.id;
    const notificationId = parseInt(id, 10);
    return await this.notificationsService.markAsRead(userId, notificationId);
  }

  /**
   * 全部标记已读
   */
  @Put('read-all')
  async markAllAsRead(@Request() req) {
    const userId = req.user.id;
    return await this.notificationsService.markAllAsRead(userId);
  }
}
