import {
  Controller,
  Get,
  Post,
  Delete,
  Query,
  Param,
  UseGuards,
  ParseIntPipe,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiParam,
  ApiResponse,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../auth/guards/roles.guard';
import { Roles } from '../../auth/decorators/roles.decorator';
import { FriendsService } from '../services/friends.service';
import { FriendRequestsService } from '../services/friend-requests.service';
import { FriendMessagesService } from '../services/friend-messages.service';
import { FriendsGateway } from '../gateways/friends.gateway';
import {
  AdminQueryFriendshipsDto,
  AdminQueryFriendRequestsDto,
} from '../dto/admin.dto';
import { AdminQueryMessagesDto } from '../dto/message.dto';

/**
 * 好友管理后台控制器
 *
 * 功能：
 * - 查看所有好友关系
 * - 查看所有好友申请
 * - 查看所有消息记录
 * - 查看会话消息
 * - 获取统计数据
 */
@ApiTags('friends-admin')
@ApiBearerAuth()
@Controller('friends/admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF')
export class FriendsAdminController {
  constructor(
    private readonly friendsService: FriendsService,
    private readonly friendRequestsService: FriendRequestsService,
    private readonly friendMessagesService: FriendMessagesService,
    private readonly friendsGateway: FriendsGateway,
  ) {}

  /**
   * 获取所有好友关系（分页）
   */
  @Get('friendships')
  @ApiOperation({ summary: '获取所有好友关系（分页）' })
  @ApiResponse({ status: 200, description: '查询成功' })
  async getFriendships(@Query() query: AdminQueryFriendshipsDto) {
    return this.friendsService.adminGetFriendships(query);
  }

  /**
   * 获取所有好友申请（分页）
   */
  @Get('requests')
  @ApiOperation({ summary: '获取所有好友申请（分页）' })
  @ApiResponse({ status: 200, description: '查询成功' })
  async getFriendRequests(@Query() query: AdminQueryFriendRequestsDto) {
    return this.friendRequestsService.adminGetFriendRequests(query);
  }

  /**
   * 获取所有消息记录（分页）
   */
  @Get('messages')
  @ApiOperation({ summary: '获取所有消息记录（分页）' })
  @ApiResponse({ status: 200, description: '查询成功' })
  async getMessages(@Query() query: AdminQueryMessagesDto) {
    return this.friendMessagesService.adminGetMessages(query);
  }

  /**
   * 获取会话所有消息
   */
  @Get('conversations/:conversationId/messages')
  @ApiOperation({ summary: '获取会话所有消息' })
  @ApiParam({ name: 'conversationId', description: '会话ID' })
  @ApiResponse({ status: 200, description: '查询成功' })
  async getConversationMessages(@Param('conversationId') conversationId: string) {
    const messages = await this.friendMessagesService.getConversationMessages(conversationId);
    return {
      success: true,
      data: messages,
    };
  }

  /**
   * 获取统计数据
   */
  @Get('statistics')
  @ApiOperation({ summary: '获取统计数据' })
  @ApiResponse({ status: 200, description: '查询成功' })
  async getStatistics() {
    // 并行查询所有统计数据
    const [
      messageStats,
      totalFriendships,
      todayNewFriendships,
      activeUsers,
      todayMessages,
      pendingRequests,
      avgFriendsPerUser,
      activeUserGrowth,
      offlineQueueStatus,
    ] = await Promise.all([
      this.friendMessagesService.getMessageStatistics(),
      this.friendsService.getTotalFriendshipPairs(),
      this.friendsService.getTodayNewFriendships(),
      this.friendMessagesService.getActiveUsersCount(),
      this.friendMessagesService.getTodayMessagesCount(),
      this.friendRequestsService.getPendingRequestsCount(),
      this.friendsService.getAvgFriendsPerUser(),
      this.friendMessagesService.getActiveUserGrowth(),
      this.friendMessagesService.getOfflineQueueStatus(),
    ]);

    return {
      success: true,
      data: {
        totalFriendships,
        todayNewFriendships,
        activeUsers,
        totalMessages: messageStats.total,
        todayMessages,
        pendingRequests,
        offlineQueueSize: offlineQueueStatus.totalMessages,
        avgFriendsPerUser: Math.round(avgFriendsPerUser * 100) / 100, // 保留两位小数
        messageStatsByType: {
          text: messageStats.text,
          image: messageStats.image,
          voice: messageStats.voice,
        },
        activeUserGrowth,
      },
    };
  }

  /**
   * 处理过期申请（手动触发）
   */
  @Post('requests/handle-expired')
  @ApiOperation({ summary: '处理过期申请' })
  @ApiResponse({ status: 200, description: '处理成功' })
  async handleExpiredRequests() {
    const count = await this.friendRequestsService.handleExpiredRequests();
    return {
      success: true,
      data: { affectedCount: count },
    };
  }

  /**
   * 获取离线消息队列状态
   */
  @Get('offline-queue')
  @ApiOperation({ summary: '获取离线消息队列状态' })
  @ApiResponse({ status: 200, description: '查询成功' })
  async getOfflineQueueStatus() {
    const status = await this.friendMessagesService.getOfflineQueueStatus();
    return {
      success: true,
      data: status,
    };
  }

  /**
   * 清空指定用户的离线消息队列
   */
  @Delete('offline-queue/:userId')
  @ApiOperation({ summary: '清空指定用户的离线消息队列' })
  @ApiParam({ name: 'userId', description: '用户ID' })
  @ApiResponse({ status: 200, description: '清空成功' })
  async clearUserOfflineQueue(@Param('userId', ParseIntPipe) userId: number) {
    const count = await this.friendMessagesService.clearUserOfflineQueue(userId);
    return {
      success: true,
      data: { clearedCount: count },
    };
  }

  /**
   * 强制解除好友关系（管理员操作）
   */
  @Delete('friendships')
  @ApiOperation({ summary: '强制解除好友关系' })
  @ApiResponse({ status: 200, description: '解除成功' })
  async forceDeleteFriendship(
    @Query('userId', ParseIntPipe) userId: number,
    @Query('friendId', ParseIntPipe) friendId: number,
  ) {
    await this.friendsService.deleteFriendship(userId, friendId);

    this.friendsGateway.emitFriendshipDeleted(userId, {
      friendId,
      deletedByUserId: userId,
    });
    this.friendsGateway.emitFriendshipDeleted(friendId, {
      friendId: userId,
      deletedByUserId: userId,
    });

    return {
      success: true,
      message: '好友关系已解除',
    };
  }
}
