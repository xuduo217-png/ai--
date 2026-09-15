import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
  OnGatewayInit,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { UsersService } from '../../users/users.service';
import { FriendsService } from '../services/friends.service';
import { FriendMessagesService } from '../services/friend-messages.service';
import { RedisService } from '../../redis/redis.service';
import { FriendMessage } from '../entities/friend-message.entity';
import { AuthSessionService } from '../../auth/auth-session.service';
import { FriendChatBlocksService } from '../services/friend-chat-blocks.service';

/**
 * 认证后的 Socket 接口
 */
interface AuthenticatedSocket extends Socket {
  handshake: Socket['handshake'] & {
    user?: {
      id: number;
      username: string;
      type: 'user';
    };
  };
  user?: {
    id: number;
    username: string;
    type: 'user';
    sid?: string;
  };
  authSessionId?: string;
}

/**
 * 发送消息载荷
 */
interface SendMessagePayload {
  receiverId: number;
  messageType: 'text' | 'image' | 'voice' | 'video';
  content: string;
  tempMessageId?: string;
}

/**
 * 标记已读载荷
 */
interface MarkReadPayload {
  messageId: string;
  conversationId: string;
}

interface RevokeMessagePayload {
  messageId: string;
}

/**
 * 输入指示器载荷
 */
interface TypingPayload {
  conversationId: string;
}

/**
 * 离线消息确认载荷
 */
interface OfflineAckPayload {
  messageIds: string[];
}

/**
 * 好友 WebSocket Gateway
 *
 * 功能：
 * - 用户上线/离线管理
 * - 实时消息推送
 * - 消息 ACK 确认
 * - 已读回执
 * - 输入指示器
 * - 离线消息推送
 * - 好友申请通知
 */
@WebSocketGateway({
  cors: {
    origin: '*',
  },
  namespace: '/friends', // 使用独立的命名空间
})
export class FriendsGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(FriendsGateway.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly usersService: UsersService,
    private readonly friendsService: FriendsService,
    private readonly friendMessagesService: FriendMessagesService,
    private readonly friendChatBlocksService: FriendChatBlocksService,
    private readonly redisService: RedisService,
    private readonly authSessionService: AuthSessionService,
  ) {}

  afterInit(server: Server) {
    this.logger.log('Friends WebSocket Gateway initialized');
  }

  /**
   * 从会话ID中解析对端用户ID
   * 业务规则：会话ID 采用“小ID_大ID”格式，因此可以安全反推当前聊天对端。
   */
  private resolveCounterpartId(conversationId: string, currentUserId: number): number | null {
    const ids = conversationId
      .split('_')
      .map((value) => Number(value))
      .filter((value) => Number.isFinite(value));

    if (ids.length !== 2) {
      return null;
    }

    const counterpartId = ids.find((value) => value !== currentUserId);
    return counterpartId ?? null;
  }

  /**
   * 解析 typing 事件的目标用户并校验好友关系
   * 业务规则：输入状态只能在真实好友之间流转，避免有人伪造会话 ID 对陌生用户进行骚扰。
   */
  private async resolveTypingTarget(
    conversationId: string,
    currentUserId: number,
  ): Promise<{ receiverId: number | null; errorMessage?: string }> {
    const receiverId = this.resolveCounterpartId(conversationId, currentUserId);
    if (!receiverId) {
      return {
        receiverId: null,
        errorMessage: '会话ID无效',
      };
    }

    const isFriend = await this.friendsService.isFriend(currentUserId, receiverId);
    if (!isFriend) {
      return {
        receiverId: null,
        errorMessage: '只能向好友发送输入状态',
      };
    }

    if (await this.friendChatBlocksService.hasBlockBetween(currentUserId, receiverId)) {
      return {
        receiverId: null,
        errorMessage: '当前无法发送输入状态',
      };
    }

    return { receiverId };
  }

  /**
   * 向指定用户推送新的好友申请
   */
  emitFriendRequestNew(userId: number, payload: Record<string, any>): void {
    this.server.to(`user:${userId}`).emit('friends:request:new', payload);
  }

  /**
   * 向指定用户推送好友申请已接受事件
   */
  emitFriendRequestAccepted(userId: number, payload: Record<string, any>): void {
    this.server.to(`user:${userId}`).emit('friends:request:accepted', payload);
  }

  /**
   * 向指定用户推送好友申请已拒绝事件
   */
  emitFriendRequestRejected(userId: number, payload: Record<string, any>): void {
    this.server.to(`user:${userId}`).emit('friends:request:rejected', payload);
  }

  /**
   * 向指定用户推送好友关系已解除事件
   */
  emitFriendshipDeleted(userId: number, payload: Record<string, any>): void {
    this.server.to(`user:${userId}`).emit('friends:friendship:deleted', payload);
  }

  /**
   * 派发已持久化的好友消息
   * 业务规则：HTTP 备用接口与 WebSocket 主链路都必须复用同一套“在线直推 / 离线入队”逻辑，避免行为分叉。
   */
  async dispatchPersistedMessage(message: FriendMessage): Promise<'online' | 'offline'> {
    const isOnline = await this.isUserOnline(message.receiverId);

    if (isOnline) {
      this.server.to(`user:${message.receiverId}`).emit('friends:message:new', message);
      this.logger.log(`[Friends WebSocket] 消息已推送给在线用户 ${message.receiverId}`);
      return 'online';
    }

    await this.addOfflineMessage(message.receiverId, message);
    this.logger.log(`[Friends WebSocket] 消息已存入离线队列，接收人 ${message.receiverId}`);
    return 'offline';
  }

  /** 同步撤回状态，并覆盖尚未投递的离线消息原文。 */
  async dispatchRevokedMessage(message: FriendMessage): Promise<void> {
    const hashKey = `friends:offline:${message.receiverId}`;
    if (await this.redisService.hget(hashKey, message.messageId)) {
      await this.redisService.hset(
        hashKey,
        message.messageId,
        JSON.stringify(message),
      );
    }
    this.server
      .to(`user:${message.senderId}`)
      .to(`user:${message.receiverId}`)
      .emit('friends:message:revoked', message);
  }

  /**
   * 推送已读回执给发送方
   * 业务规则：已读通知需要被 WebSocket 与 HTTP 备用接口共享，避免两条链路的对话状态不一致。
   */
  emitReadReceipt(messageId: string, conversationId: string, senderId: number, readerId: number): void {
    this.server.to(`user:${senderId}`).emit('friends:read:receipt', {
      messageId,
      conversationId,
      readerId,
    });
  }

  /**
   * 处理客户端连接
   * 验证 JWT token 并加入个人房间
   */
  async handleConnection(client: AuthenticatedSocket) {
    try {
      // 从客户端的 auth 对象中获取 token
      const token = client.handshake.auth.token;

      this.logger.log(`[Friends WebSocket] 客户端尝试连接: ${client.id}`);

      if (!token) {
        throw new UnauthorizedException('Missing token');
      }

      // 验证 token
      const payload = this.jwtService.verify(token, {
        secret: this.configService.get<string>('JWT_SECRET'),
      });
      await this.authSessionService.assertSession('user', payload.sub, payload.sid);

      this.logger.log(`[Friends WebSocket] Token 验证成功，用户ID: ${payload.sub}`);

      // 查询用户信息
      const user = await this.usersService.findOne(payload.sub);
      if (!user) {
        throw new UnauthorizedException('用户不存在');
      }

      // 将用户信息附加到 socket
      client.user = {
        id: user.id,
        username: user.username,
        type: 'user',
        sid: payload.sid,
      };
      client.handshake.user = client.user;
      client.authSessionId = payload.sid;

      // 加入个人房间（用于接收消息）
      const userRoom = `user:${user.id}`;
      client.join(userRoom);

      // 记录用户在线状态到 Redis（支持多设备）
      await this.setUserOnline(user.id, client.id);
      this.authSessionService.registerSocket(
        'user',
        user.id,
        payload.sid,
        client,
        '/friends',
      );

      this.logger.log(`[Friends WebSocket] 用户 ${user.id} 已连接，Socket ID: ${client.id}`);

      // 推送离线消息
      await this.pushOfflineMessages(client, user.id);
    } catch (error) {
      this.logger.error(`[Friends WebSocket] 连接失败: ${error.message}`);
      client.disconnect();
    }
  }

  /**
   * 处理客户端断开连接
   */
  async handleDisconnect(client: AuthenticatedSocket) {
    if (client.user) {
      const userId = client.user.id;
      this.logger.log(`[Friends WebSocket] 用户 ${userId} 断开连接，Socket ID: ${client.id}`);

      // 从 Redis 移除在线状态
      await this.setUserOffline(userId, client.id);
      this.authSessionService.unregisterSocket('user', userId, client.id);
    }
  }

  /**
   * 用户主动加入（可选，连接时已自动加入）
   */
  @SubscribeMessage('friends:join')
  async handleJoin(@ConnectedSocket() client: AuthenticatedSocket) {
    if (!client.user) {
      return { success: false, message: '未认证' };
    }

    return {
      success: true,
      userId: client.user.id,
    };
  }

  /**
   * 用户主动离开
   */
  @SubscribeMessage('friends:leave')
  async handleLeave(@ConnectedSocket() client: AuthenticatedSocket) {
    if (client.user) {
      await this.setUserOffline(client.user.id, client.id);
    }
    return { success: true };
  }

  /**
   * 发送消息
   */
  @SubscribeMessage('friends:message:send')
  async handleSendMessage(
    @MessageBody() payload: SendMessagePayload,
    @ConnectedSocket() client: AuthenticatedSocket,
  ) {
    if (!client.user) {
      return { success: false, message: '未认证' };
    }

    try {
      const senderId = client.user.id;
      const { receiverId, messageType, content, tempMessageId } = payload;

      await this.setUserOnline(senderId, client.id);

      // 保存消息到 MySQL
      const message = await this.friendMessagesService.sendMessage(senderId, {
        receiverId,
        messageType: messageType as any, // 类型转换
        content,
        tempMessageId,
      });

      await this.dispatchPersistedMessage(message);

      // 主动推送 ACK 给发送方（兼容客户端事件监听）
      client.emit('friends:message:ack', {
        success: true,
        messageId: message.messageId,
        tempMessageId,
      });

      // 返回 ACK 确认
      return {
        success: true,
        message,
        tempMessageId,
      };
    } catch (error) {
      this.logger.error(`[Friends WebSocket] 发送消息失败: ${error.message}`);
      return {
        success: false,
        message: error.message,
      };
    }
  }

  @SubscribeMessage('friends:message:revoke')
  async handleRevokeMessage(
    @MessageBody() payload: RevokeMessagePayload,
    @ConnectedSocket() client: AuthenticatedSocket,
  ) {
    if (!client.user) {
      return { success: false, message: '未认证' };
    }
    try {
      const message = await this.friendMessagesService.revokeMessage(
        payload.messageId,
        client.user.id,
      );
      await this.dispatchRevokedMessage(message);
      return { success: true, message };
    } catch (error) {
      this.logger.error(`[Friends WebSocket] 撤回消息失败: ${error.message}`);
      return { success: false, message: error.message };
    }
  }

  /**
   * 标记消息已读
   */
  @SubscribeMessage('friends:message:read')
  async handleMarkRead(
    @MessageBody() payload: MarkReadPayload,
    @ConnectedSocket() client: AuthenticatedSocket,
  ) {
    if (!client.user) {
      return { success: false, message: '未认证' };
    }

    try {
      const { messageId, conversationId } = payload;
      await this.setUserOnline(client.user.id, client.id);
      const { message, changed } = await this.friendMessagesService.markMessageAsRead(
        messageId,
        client.user.id,
      );

      if (changed) {
        this.emitReadReceipt(messageId, conversationId, message.senderId, client.user.id);
      }

      return { success: true };
    } catch (error) {
      this.logger.error(`[Friends WebSocket] 标记已读失败: ${error.message}`);
      return { success: false, message: error.message };
    }
  }

  /**
   * 开始输入
   */
  @SubscribeMessage('friends:typing:start')
  async handleTypingStart(
    @MessageBody() payload: TypingPayload,
    @ConnectedSocket() client: AuthenticatedSocket,
  ) {
    if (!client.user) {
      return { success: false, message: '未认证' };
    }

    try {
      const { conversationId } = payload;
      await this.setUserOnline(client.user.id, client.id);

      const { receiverId, errorMessage } = await this.resolveTypingTarget(
        conversationId,
        client.user.id,
      );
      if (!receiverId) {
        return { success: false, message: errorMessage || '输入状态发送失败' };
      }

      this.server.to(`user:${receiverId}`).emit('friends:typing:indicator', {
        conversationId,
        userId: client.user.id,
        isTyping: true,
      });

      return { success: true };
    } catch (error) {
      this.logger.error(`[Friends WebSocket] 开始输入事件处理失败: ${error.message}`);
      return { success: false, message: error.message };
    }
  }

  /**
   * 停止输入
   */
  @SubscribeMessage('friends:typing:stop')
  async handleTypingStop(
    @MessageBody() payload: TypingPayload,
    @ConnectedSocket() client: AuthenticatedSocket,
  ) {
    if (!client.user) {
      return { success: false, message: '未认证' };
    }

    try {
      const { conversationId } = payload;
      await this.setUserOnline(client.user.id, client.id);

      const { receiverId, errorMessage } = await this.resolveTypingTarget(
        conversationId,
        client.user.id,
      );
      if (!receiverId) {
        return { success: false, message: errorMessage || '输入状态发送失败' };
      }

      this.server.to(`user:${receiverId}`).emit('friends:typing:indicator', {
        conversationId,
        userId: client.user.id,
        isTyping: false,
      });

      return { success: true };
    } catch (error) {
      this.logger.error(`[Friends WebSocket] 停止输入事件处理失败: ${error.message}`);
      return { success: false, message: error.message };
    }
  }

  /**
   * 拉取离线消息
   */
  @SubscribeMessage('friends:offline:fetch')
  async handleFetchOfflineMessages(@ConnectedSocket() client: AuthenticatedSocket) {
    if (!client.user) {
      return { success: false, message: '未认证' };
    }

    try {
      await this.setUserOnline(client.user.id, client.id);
      await this.pushOfflineMessages(client, client.user.id);
      return { success: true };
    } catch (error) {
      this.logger.error(`[Friends WebSocket] 拉取离线消息失败: ${error.message}`);
      return { success: false, message: error.message };
    }
  }

  /**
   * 客户端确认已接收离线消息后，从 Redis 队列中移除对应记录
   */
  @SubscribeMessage('friends:offline:ack')
  async handleOfflineAck(
    @MessageBody() payload: OfflineAckPayload,
    @ConnectedSocket() client: AuthenticatedSocket,
  ) {
    if (!client.user) {
      return { success: false, message: '未认证' };
    }

    const messageIds = Array.from(
      new Set((payload?.messageIds || []).filter((messageId) => typeof messageId === 'string' && messageId.length > 0)),
    );

    if (messageIds.length === 0) {
      return { success: true, removedCount: 0 };
    }

    const hashKey = `friends:offline:${client.user.id}`;
    const timelineKey = `friends:offline:timeline:${client.user.id}`;

    await this.redisService.hdel(hashKey, ...messageIds);
    await this.redisService.zrem(timelineKey, ...messageIds);

    return {
      success: true,
      removedCount: messageIds.length,
    };
  }

  /**
   * 设置用户在线状态（Redis Hash - 支持多设备）
   */
  private async setUserOnline(userId: number, socketId: string): Promise<void> {
    const key = `friends:online:${userId}`;
    const value = JSON.stringify({
      connectedAt: Date.now(),
      socketId,
    });
    await this.redisService.hset(key, socketId, value);
    await this.redisService.expire(key, 300); // 5 分钟无活动自动过期
  }

  /**
   * 设置用户离线状态
   */
  private async setUserOffline(userId: number, socketId: string): Promise<void> {
    const key = `friends:online:${userId}`;
    await this.redisService.hdel(key, socketId);
  }

  /**
   * 检查用户是否在线
   */
  private async isUserOnline(userId: number): Promise<boolean> {
    const roomRegistry = this.getRoomRegistry();
    if (roomRegistry) {
      const userRoom = roomRegistry.get(`user:${userId}`);
      return Boolean(userRoom && userRoom.size > 0);
    }

    const key = `friends:online:${userId}`;
    const sockets = await this.redisService.hgetall(key);
    return Object.keys(sockets).length > 0;
  }

  /**
   * 获取当前网关可用的房间索引
   * 业务规则：Nest 在命名空间网关下注入的通常是 Namespace，不是根 Server，不能固定走 server.sockets.adapter。
   */
  private getRoomRegistry(): Map<string, Set<string>> | undefined {
    const gatewayServer = this.server as unknown as {
      adapter?: {
        rooms?: Map<string, Set<string>>;
      };
      sockets?: {
        adapter?: {
          rooms?: Map<string, Set<string>>;
        };
      };
    };

    return gatewayServer.adapter?.rooms ?? gatewayServer.sockets?.adapter?.rooms;
  }

  /**
   * 添加离线消息到 Redis（Hash + Sorted Set）
   */
  private async addOfflineMessage(userId: number, message: any): Promise<void> {
    const hashKey = `friends:offline:${userId}`;
    const timelineKey = `friends:offline:timeline:${userId}`;

    // 存储消息到 Hash
    await this.redisService.hset(hashKey, message.messageId, JSON.stringify(message));

    // 添加到时间索引（Sorted Set）
    await this.redisService.zadd(timelineKey, Date.now(), message.messageId);

    // 设置 TTL（30 天）
    await this.redisService.expire(hashKey, 2592000);
    await this.redisService.expire(timelineKey, 2592000);
  }

  /**
   * 推送离线消息
   */
  private async pushOfflineMessages(client: AuthenticatedSocket, userId: number): Promise<void> {
    const hashKey = `friends:offline:${userId}`;
    const timelineKey = `friends:offline:timeline:${userId}`;

    // 从 Sorted Set 获取所有消息ID（按时间排序）
    const messageIds = await this.redisService.zrange(timelineKey, 0, -1);

    if (messageIds.length === 0) {
      this.logger.log(`[Friends WebSocket] 用户 ${userId} 没有离线消息`);
      return;
    }

    // 从 Hash 批量获取消息内容
    const messages = await this.redisService.hmget(hashKey, ...messageIds);

    // 推送消息
    for (const messageStr of messages) {
      if (messageStr) {
        const message = JSON.parse(messageStr);
        client.emit('friends:message:new', {
          ...message,
          deliveryMode: 'offline',
        });
      }
    }

    this.logger.log(`[Friends WebSocket] 已推送 ${messages.length} 条离线消息给用户 ${userId}`);
  }
}
