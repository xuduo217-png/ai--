import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  ParseIntPipe,
  HttpCode,
  HttpStatus,
} from "@nestjs/common";
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiParam,
  ApiResponse,
} from "@nestjs/swagger";
import { JwtAuthGuard } from "../../auth/guards/jwt-auth.guard";
import { CurrentUser } from "../../common/decorators/current-user.decorator";
import { FriendsService } from "../services/friends.service";
import { FriendRequestsService } from "../services/friend-requests.service";
import { FriendMessagesService } from "../services/friend-messages.service";
import { FriendsGateway } from "../gateways/friends.gateway";
import { UsersService } from "../../users/users.service";
import { FriendChatBlocksService } from "../services/friend-chat-blocks.service";
import {
  BlockFriendChatDto,
  QueryFriendChatBlocksDto,
} from "../dto/friend-chat-block.dto";
import {
  SearchUserByPhoneDto,
  SendFriendRequestDto,
  AcceptFriendRequestDto,
  RejectFriendRequestDto,
  UpdateFriendRemarkDto,
  QueryFriendsDto,
  QueryFriendRequestsDto,
} from "../dto/friend-request.dto";
import {
  SendMessageDto,
  MarkMessageReadDto,
  QueryMessagesDto,
} from "../dto/message.dto";

/**
 * 好友关系控制器
 *
 * 功能：
 * - 通过手机号搜索用户
 * - 发送好友申请
 * - 接受/拒绝好友申请
 * - 获取好友列表
 * - 修改好友备注
 * - 删除好友
 * - 发送消息（HTTP 备用接口）
 * - 查询历史消息
 */
@ApiTags("friends")
@ApiBearerAuth()
@Controller("friends")
@UseGuards(JwtAuthGuard)
export class FriendsController {
  constructor(
    private readonly friendsService: FriendsService,
    private readonly friendRequestsService: FriendRequestsService,
    private readonly friendMessagesService: FriendMessagesService,
    private readonly friendChatBlocksService: FriendChatBlocksService,
    private readonly friendsGateway: FriendsGateway,
    private readonly usersService: UsersService,
  ) {}

  /**
   * 通过手机号搜索用户
   */
  @Post("search-by-phone")
  @ApiOperation({ summary: "通过手机号搜索用户" })
  @ApiResponse({ status: 200, description: "搜索成功" })
  async searchUserByPhone(@Body() dto: SearchUserByPhoneDto) {
    const user = await this.usersService.findByPhone(dto.phone);

    if (!user) {
      return {
        found: false,
        user: null,
        message: "用户不存在",
      };
    }

    return {
      found: true,
      user: {
        id: user.id,
        username: user.username,
        avatar: user.avatar,
        phone: user.phone,
      },
      message: "搜索成功",
    };
  }

  /**
   * 发送好友申请
   */
  @Post("request")
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "发送好友申请" })
  @ApiResponse({ status: 200, description: "请求已处理" })
  async sendFriendRequest(
    @CurrentUser() user: any,
    @Body() dto: SendFriendRequestDto,
  ) {
    return this.friendRequestsService.sendFriendRequest(
      user.id,
      dto,
    );
  }

  /**
   * 获取好友申请列表
   */
  @Get("requests")
  @ApiOperation({ summary: "获取好友申请列表" })
  @ApiResponse({ status: 200, description: "查询成功" })
  async getFriendRequests(
    @CurrentUser() user: any,
    @Query() query: QueryFriendRequestsDto,
  ) {
    return this.friendRequestsService.getFriendRequests(user.id, query);
  }

  /**
   * 接受好友申请
   */
  @Post("requests/:id/accept")
  @ApiOperation({ summary: "接受好友申请" })
  @ApiParam({ name: "id", description: "申请ID" })
  @ApiResponse({ status: 200, description: "已接受" })
  async acceptFriendRequest(
    @CurrentUser() user: any,
    @Param("id", ParseIntPipe) id: number,
    @Body() dto: AcceptFriendRequestDto,
  ) {
    const result = await this.friendRequestsService.acceptFriendRequest(
      id,
      user.id,
    );
    return {
      success: true,
      data: result,
    };
  }

  /**
   * 拒绝好友申请
   */
  @Post("requests/:id/reject")
  @ApiOperation({ summary: "拒绝好友申请" })
  @ApiParam({ name: "id", description: "申请ID" })
  @ApiResponse({ status: 200, description: "已拒绝" })
  async rejectFriendRequest(
    @CurrentUser() user: any,
    @Param("id", ParseIntPipe) id: number,
    @Body() dto?: RejectFriendRequestDto,
  ) {
    await this.friendRequestsService.rejectFriendRequest(id, user.id, dto);
    return {
      success: true,
    };
  }

  /**
   * 获取好友列表
   */
  @Get()
  @ApiOperation({ summary: "获取好友列表" })
  @ApiResponse({ status: 200, description: "查询成功" })
  async getFriendsList(
    @CurrentUser() user: any,
    @Query() query: QueryFriendsDto,
  ) {
    return this.friendsService.getFriendsList(user.id, query);
  }

  /**
   * 获取好友关系摘要
   * 社区等轻量场景只需要关系结论，不应额外拉整页数据。
   */
  @Get("relationship/:targetUserId")
  @ApiOperation({ summary: "获取好友关系摘要" })
  @ApiParam({ name: "targetUserId", description: "目标用户ID" })
  @ApiResponse({ status: 200, description: "查询成功" })
  async getRelationshipSummary(
    @CurrentUser() user: any,
    @Param("targetUserId", ParseIntPipe) targetUserId: number,
  ) {
    return this.friendRequestsService.getRelationshipSummary(
      user.id,
      targetUserId,
    );
  }

  /** 拉黑好友聊天。拉黑记录与好友关系独立保存。 */
  @Post("chat-blocks")
  @ApiOperation({ summary: "拉黑好友聊天" })
  @ApiResponse({ status: 201, description: "拉黑成功" })
  async blockFriendChat(
    @CurrentUser() user: any,
    @Body() dto: BlockFriendChatDto,
  ) {
    const block = await this.friendChatBlocksService.blockUser(
      user.id,
      dto.blockedUserId,
    );
    return {
      success: true,
      data: {
        id: block.id,
        blockedUserId: block.blockedUserId,
        blockedAt: block.createdAt,
      },
    };
  }

  /** 获取当前用户的好友聊天黑名单。 */
  @Get("chat-blocks")
  @ApiOperation({ summary: "获取好友聊天黑名单" })
  @ApiResponse({ status: 200, description: "查询成功" })
  async getFriendChatBlocks(
    @CurrentUser() user: any,
    @Query() query: QueryFriendChatBlocksDto,
  ) {
    return this.friendChatBlocksService.getBlockedUsers(user.id, query);
  }

  /** 解除好友聊天拉黑；即使双方已不是好友也允许解除。 */
  @Delete("chat-blocks/:blockedUserId")
  @ApiOperation({ summary: "解除好友聊天拉黑" })
  @ApiParam({ name: "blockedUserId", description: "被拉黑用户ID" })
  @ApiResponse({ status: 200, description: "解除成功" })
  async unblockFriendChat(
    @CurrentUser() user: any,
    @Param("blockedUserId", ParseIntPipe) blockedUserId: number,
  ) {
    await this.friendChatBlocksService.unblockUser(user.id, blockedUserId);
    return { success: true };
  }

  /**
   * 修改好友备注
   */
  @Put(":friendId/remark")
  @ApiOperation({ summary: "修改好友备注" })
  @ApiParam({ name: "friendId", description: "好友ID" })
  @ApiResponse({ status: 200, description: "修改成功" })
  async updateFriendRemark(
    @CurrentUser() user: any,
    @Param("friendId", ParseIntPipe) friendId: number,
    @Body() dto: UpdateFriendRemarkDto,
  ) {
    await this.friendsService.updateFriendRemark(user.id, friendId, dto);
    return {
      success: true,
    };
  }

  /**
   * 删除好友
   */
  @Delete(":friendId")
  @ApiOperation({ summary: "删除好友" })
  @ApiParam({ name: "friendId", description: "好友ID" })
  @ApiResponse({ status: 200, description: "删除成功" })
  async deleteFriend(
    @CurrentUser() user: any,
    @Param("friendId", ParseIntPipe) friendId: number,
  ) {
    await this.friendsService.deleteFriendship(user.id, friendId);

    this.friendsGateway.emitFriendshipDeleted(user.id, {
      friendId,
      deletedByUserId: user.id,
    });
    this.friendsGateway.emitFriendshipDeleted(friendId, {
      friendId: user.id,
      deletedByUserId: user.id,
    });

    return {
      success: true,
    };
  }

  /**
   * 发送消息（HTTP 备用接口，主要用 WebSocket）
   */
  @Post("messages/send")
  @ApiOperation({ summary: "发送消息（HTTP 备用接口）" })
  @ApiResponse({ status: 201, description: "发送成功" })
  async sendMessage(@CurrentUser() user: any, @Body() dto: SendMessageDto) {
    const message = await this.friendMessagesService.sendMessage(user.id, dto);
    await this.friendsGateway.dispatchPersistedMessage(message);

    return {
      success: true,
      data: { message },
    };
  }

  @Post("messages/:messageId/revoke")
  @ApiOperation({ summary: "撤回两分钟内发送的好友消息" })
  @ApiParam({ name: "messageId", description: "消息UUID" })
  @ApiResponse({ status: 200, description: "撤回成功" })
  async revokeMessage(
    @CurrentUser() user: any,
    @Param("messageId") messageId: string,
  ) {
    const message = await this.friendMessagesService.revokeMessage(
      messageId,
      user.id,
    );
    await this.friendsGateway.dispatchRevokedMessage(message);
    return { success: true, data: { message } };
  }

  /**
   * 标记消息已读
   */
  @Post("messages/read")
  @ApiOperation({ summary: "标记消息已读" })
  @ApiResponse({ status: 200, description: "标记成功" })
  async markMessageAsRead(
    @CurrentUser() user: any,
    @Body() dto: MarkMessageReadDto,
  ) {
    const { message, changed } =
      await this.friendMessagesService.markMessageAsRead(
        dto.messageId,
        user.id,
      );

    if (changed) {
      this.friendsGateway.emitReadReceipt(
        dto.messageId,
        dto.conversationId,
        message.senderId,
        user.id,
      );
    }

    return {
      success: true,
    };
  }

  /**
   * 获取历史消息
   */
  @Get("messages/:friendId/history")
  @ApiOperation({ summary: "获取历史消息" })
  @ApiParam({ name: "friendId", description: "好友ID" })
  @ApiResponse({ status: 200, description: "查询成功" })
  async getHistoryMessages(
    @CurrentUser() user: any,
    @Param("friendId", ParseIntPipe) friendId: number,
    @Query() query: QueryMessagesDto,
  ) {
    return this.friendMessagesService.getHistoryMessages(
      user.id,
      friendId,
      query,
    );
  }

  /**
   * 获取未读消息数
   */
  @Get("messages/unread-count")
  @ApiOperation({ summary: "获取未读消息数" })
  @ApiResponse({ status: 200, description: "查询成功" })
  async getUnreadCount(@CurrentUser() user: any) {
    const count = await this.friendMessagesService.getUnreadCount(user.id);
    return {
      success: true,
      data: { count },
    };
  }
}
