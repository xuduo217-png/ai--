import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";

import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";
import { CurrentUser } from "../common/decorators/current-user.decorator";
import {
  MarkMarketplaceMessageReadDto,
  OpenMarketplaceConversationDto,
  QueryMarketplaceConversationsDto,
  QueryMarketplaceMessagesDto,
  SendMarketplaceMessageDto,
} from "./dto/marketplace-chat.dto";
import { MarketplaceChatGateway } from "./marketplace-chat.gateway";
import { MarketplaceChatService } from "./marketplace-chat.service";

@ApiTags("marketplace-chat")
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller("marketplace-chat")
export class MarketplaceChatController {
  constructor(
    private readonly chatService: MarketplaceChatService,
    private readonly chatGateway: MarketplaceChatGateway,
  ) {}

  @Post("conversations")
  @ApiOperation({ summary: "创建或获取商品买卖会话" })
  async openConversation(
    @CurrentUser() user: any,
    @Body() dto: OpenMarketplaceConversationDto,
  ) {
    const userId = this.requireUserId(user);
    return {
      success: true,
      data: await this.chatService.openConversation(userId, dto),
    };
  }

  @Get("conversations")
  @ApiOperation({ summary: "获取当前用户的商城会话列表" })
  async listConversations(
    @CurrentUser() user: any,
    @Query() query: QueryMarketplaceConversationsDto,
  ) {
    return this.chatService.listConversations(this.requireUserId(user), query);
  }

  @Get("conversations/:conversationId")
  @ApiOperation({ summary: "获取商城会话详情" })
  async getConversation(
    @CurrentUser() user: any,
    @Param("conversationId") conversationId: string,
  ) {
    const userId = this.requireUserId(user);
    return {
      success: true,
      data: await this.chatService.getConversation(userId, conversationId),
    };
  }

  @Get("conversations/:conversationId/messages")
  @ApiOperation({ summary: "分页获取商城会话消息" })
  async getHistory(
    @CurrentUser() user: any,
    @Param("conversationId") conversationId: string,
    @Query() query: QueryMarketplaceMessagesDto,
  ) {
    return this.chatService.getHistory(
      this.requireUserId(user),
      conversationId,
      query,
    );
  }

  @Post("messages/send")
  @ApiOperation({ summary: "发送商城消息（HTTP备用接口）" })
  async sendMessage(
    @CurrentUser() user: any,
    @Body() dto: SendMarketplaceMessageDto,
  ) {
    const message = await this.chatService.sendMessage(
      this.requireUserId(user),
      dto,
    );
    await this.chatGateway.dispatchPersistedMessage(message);
    return { success: true, data: { message } };
  }

  @Post("messages/:messageId/revoke")
  @ApiOperation({ summary: "撤回两分钟内发送的商城消息" })
  async revokeMessage(
    @CurrentUser() user: any,
    @Param("messageId") messageId: string,
  ) {
    const message = await this.chatService.revokeMessage(
      messageId,
      this.requireUserId(user),
    );
    await this.chatGateway.dispatchRevokedMessage(message);
    return { success: true, data: { message } };
  }

  @Post("messages/read")
  @ApiOperation({ summary: "标记商城消息已读" })
  async markMessageRead(
    @CurrentUser() user: any,
    @Body() dto: MarkMarketplaceMessageReadDto,
  ) {
    const userId = this.requireUserId(user);
    const { message, changed } = await this.chatService.markMessageAsRead(
      dto.messageId,
      dto.conversationId,
      userId,
    );
    if (changed) {
      this.chatGateway.emitReadReceipt(message, userId);
    }
    return { success: true };
  }

  @Post("conversations/:conversationId/read")
  @ApiOperation({ summary: "批量标记商城会话已读" })
  async markConversationRead(
    @CurrentUser() user: any,
    @Param("conversationId") conversationId: string,
  ) {
    const changedCount = await this.chatService.markConversationAsRead(
      this.requireUserId(user),
      conversationId,
    );
    return { success: true, data: { changedCount } };
  }

  @Get("unread-count")
  @ApiOperation({ summary: "获取商城消息未读总数" })
  async getUnreadCount(@CurrentUser() user: any) {
    return {
      success: true,
      data: {
        count: await this.chatService.getUnreadCount(this.requireUserId(user)),
      },
    };
  }

  private requireUserId(user: unknown): number {
    const principal =
      user && typeof user === "object"
        ? (user as { id?: unknown; type?: unknown })
        : null;
    const userId = Number(principal?.id);
    if (principal?.type !== "user" || !Number.isInteger(userId)) {
      throw new ForbiddenException("商城聊天仅支持普通用户账号");
    }
    return userId;
  }
}
