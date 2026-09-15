import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from "@nestjs/websockets";
import { Logger, UnauthorizedException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { JwtService } from "@nestjs/jwt";
import { Server, Socket } from "socket.io";

import { AuthSessionService } from "../auth/auth-session.service";
import { MessageType } from "../friends/entities/friend-message.entity";
import { RedisService } from "../redis/redis.service";
import { UsersService } from "../users/users.service";
import { MarketplaceMessage } from "./entities/marketplace-message.entity";
import { MarketplaceChatService } from "./marketplace-chat.service";

interface MarketplaceSocket extends Socket {
  user?: { id: number; username: string; sid?: string };
}

interface MarketplaceJwtPayload {
  sub?: unknown;
  type?: unknown;
  sid?: unknown;
}

interface SendPayload {
  conversationId: string;
  messageType: MessageType;
  content: string;
  tempMessageId?: string;
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : "操作失败";
}

@WebSocketGateway({ cors: { origin: "*" }, namespace: "/marketplace-chat" })
export class MarketplaceChatGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(MarketplaceChatGateway.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly usersService: UsersService,
    private readonly chatService: MarketplaceChatService,
    private readonly redisService: RedisService,
    private readonly authSessionService: AuthSessionService,
  ) {}

  afterInit() {
    this.logger.log("Marketplace chat WebSocket Gateway initialized");
  }

  async handleConnection(client: MarketplaceSocket) {
    try {
      const auth = client.handshake.auth as unknown as { token?: unknown };
      const token = auth.token;
      if (typeof token !== "string" || !token.trim()) {
        throw new UnauthorizedException("Missing token");
      }
      const payload = this.jwtService.verify<MarketplaceJwtPayload>(token, {
        secret: this.configService.get<string>("JWT_SECRET"),
      });
      if (payload.type !== "user") {
        throw new UnauthorizedException("商城聊天仅支持普通用户账号");
      }
      const userId = Number(payload.sub);
      const sid = typeof payload.sid === "string" ? payload.sid : undefined;
      if (!Number.isInteger(userId) || !sid) {
        throw new UnauthorizedException("Token 信息无效");
      }
      await this.authSessionService.assertSession("user", userId, sid);
      const user = await this.usersService.findOne(userId);
      if (!user) {
        throw new UnauthorizedException("用户不存在");
      }
      client.user = { id: user.id, username: user.username, sid };
      await client.join(`user:${user.id}`);
      await this.setUserOnline(user.id, client.id);
      this.authSessionService.registerSocket(
        "user",
        user.id,
        sid,
        client,
        "/marketplace-chat",
      );
      await this.pushOfflineMessages(client, user.id);
    } catch (error) {
      this.logger.error(`商城聊天连接失败: ${errorMessage(error)}`);
      client.disconnect();
    }
  }

  async handleDisconnect(client: MarketplaceSocket) {
    if (!client.user) {
      return;
    }
    await this.setUserOffline(client.user.id, client.id);
    this.authSessionService.unregisterSocket("user", client.user.id, client.id);
  }

  @SubscribeMessage("marketplace:join")
  handleJoin(@ConnectedSocket() client: MarketplaceSocket) {
    return client.user
      ? { success: true, userId: client.user.id }
      : { success: false, message: "未认证" };
  }

  @SubscribeMessage("marketplace:message:send")
  async handleSend(
    @MessageBody() payload: SendPayload,
    @ConnectedSocket() client: MarketplaceSocket,
  ) {
    if (!client.user) {
      return { success: false, message: "未认证" };
    }
    try {
      await this.setUserOnline(client.user.id, client.id);
      const message = await this.chatService.sendMessage(
        client.user.id,
        payload,
      );
      await this.dispatchPersistedMessage(message);
      client.emit("marketplace:message:ack", {
        success: true,
        messageId: message.messageId,
        tempMessageId: payload.tempMessageId,
      });
      return { success: true, message, tempMessageId: payload.tempMessageId };
    } catch (error) {
      return { success: false, message: errorMessage(error) };
    }
  }

  @SubscribeMessage("marketplace:message:revoke")
  async handleRevoke(
    @MessageBody() payload: { messageId: string },
    @ConnectedSocket() client: MarketplaceSocket,
  ) {
    if (!client.user) {
      return { success: false, message: "未认证" };
    }
    try {
      const message = await this.chatService.revokeMessage(
        payload.messageId,
        client.user.id,
      );
      await this.dispatchRevokedMessage(message);
      return { success: true, message };
    } catch (error) {
      return { success: false, message: errorMessage(error) };
    }
  }

  @SubscribeMessage("marketplace:message:read")
  async handleRead(
    @MessageBody() payload: { messageId: string; conversationId: string },
    @ConnectedSocket() client: MarketplaceSocket,
  ) {
    if (!client.user) {
      return { success: false, message: "未认证" };
    }
    try {
      const { message, changed } = await this.chatService.markMessageAsRead(
        payload.messageId,
        payload.conversationId,
        client.user.id,
      );
      if (changed) {
        this.emitReadReceipt(message, client.user.id);
      }
      return { success: true };
    } catch (error) {
      return { success: false, message: errorMessage(error) };
    }
  }

  @SubscribeMessage("marketplace:typing:start")
  async handleTypingStart(
    @MessageBody() payload: { conversationId: string },
    @ConnectedSocket() client: MarketplaceSocket,
  ) {
    return this.dispatchTyping(client, payload.conversationId, true);
  }

  @SubscribeMessage("marketplace:typing:stop")
  async handleTypingStop(
    @MessageBody() payload: { conversationId: string },
    @ConnectedSocket() client: MarketplaceSocket,
  ) {
    return this.dispatchTyping(client, payload.conversationId, false);
  }

  @SubscribeMessage("marketplace:offline:ack")
  async handleOfflineAck(
    @MessageBody() payload: { messageIds: string[] },
    @ConnectedSocket() client: MarketplaceSocket,
  ) {
    if (!client.user) {
      return { success: false, message: "未认证" };
    }
    const messageIds = Array.from(
      new Set(
        (payload?.messageIds || []).filter(
          (id) => typeof id === "string" && id.length > 0,
        ),
      ),
    );
    if (messageIds.length === 0) {
      return { success: true, removedCount: 0 };
    }
    await this.redisService.hdel(
      this.offlineHash(client.user.id),
      ...messageIds,
    );
    await this.redisService.zrem(
      this.offlineTimeline(client.user.id),
      ...messageIds,
    );
    return { success: true, removedCount: messageIds.length };
  }

  @SubscribeMessage("marketplace:offline:fetch")
  async handleOfflineFetch(@ConnectedSocket() client: MarketplaceSocket) {
    if (!client.user) {
      return { success: false, message: "未认证" };
    }
    await this.pushOfflineMessages(client, client.user.id);
    return { success: true };
  }

  async dispatchPersistedMessage(message: MarketplaceMessage) {
    if (await this.isUserOnline(message.receiverId)) {
      this.server
        .to(`user:${message.receiverId}`)
        .emit("marketplace:message:new", message);
      return "online" as const;
    }
    await this.addOfflineMessage(message.receiverId, message);
    return "offline" as const;
  }

  async dispatchRevokedMessage(message: MarketplaceMessage) {
    const hashKey = this.offlineHash(message.receiverId);
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
      .emit("marketplace:message:revoked", message);
  }

  emitReadReceipt(message: MarketplaceMessage, readerId: number) {
    this.server
      .to(`user:${message.senderId}`)
      .emit("marketplace:read:receipt", {
        messageId: message.messageId,
        conversationId: message.conversationId,
        readerId,
      });
  }

  private async dispatchTyping(
    client: MarketplaceSocket,
    conversationId: string,
    isTyping: boolean,
  ) {
    if (!client.user) {
      return { success: false, message: "未认证" };
    }
    try {
      const receiverId = await this.chatService.resolveCounterpart(
        client.user.id,
        conversationId,
      );
      this.server
        .to(`user:${receiverId}`)
        .emit("marketplace:typing:indicator", {
          conversationId,
          userId: client.user.id,
          isTyping,
        });
      return { success: true };
    } catch (error) {
      return { success: false, message: errorMessage(error) };
    }
  }

  private async setUserOnline(userId: number, socketId: string) {
    const key = `marketplace:online:${userId}`;
    await this.redisService.hset(
      key,
      socketId,
      JSON.stringify({
        connectedAt: Date.now(),
        socketId,
      }),
    );
    await this.redisService.expire(key, 300);
  }

  private async setUserOffline(userId: number, socketId: string) {
    await this.redisService.hdel(`marketplace:online:${userId}`, socketId);
  }

  private async isUserOnline(userId: number) {
    const registry = this.getRoomRegistry();
    const room = registry?.get(`user:${userId}`);
    if (room) {
      return room.size > 0;
    }
    const sockets = await this.redisService.hgetall(
      `marketplace:online:${userId}`,
    );
    return Object.keys(sockets).length > 0;
  }

  private getRoomRegistry(): Map<string, Set<string>> | undefined {
    const server = this.server as unknown as {
      adapter?: { rooms?: Map<string, Set<string>> };
      sockets?: { adapter?: { rooms?: Map<string, Set<string>> } };
    };
    return server.adapter?.rooms ?? server.sockets?.adapter?.rooms;
  }

  private async addOfflineMessage(userId: number, message: MarketplaceMessage) {
    await this.redisService.hset(
      this.offlineHash(userId),
      message.messageId,
      JSON.stringify(message),
    );
    await this.redisService.zadd(
      this.offlineTimeline(userId),
      Date.now(),
      message.messageId,
    );
    await this.redisService.expire(this.offlineHash(userId), 2592000);
    await this.redisService.expire(this.offlineTimeline(userId), 2592000);
  }

  private async pushOfflineMessages(client: MarketplaceSocket, userId: number) {
    const ids = await this.redisService.zrange(
      this.offlineTimeline(userId),
      0,
      -1,
    );
    if (ids.length === 0) {
      return;
    }
    const messages = await this.redisService.hmget(
      this.offlineHash(userId),
      ...ids,
    );
    for (const raw of messages) {
      if (raw) {
        client.emit("marketplace:message:new", {
          ...JSON.parse(raw),
          deliveryMode: "offline",
        });
      }
    }
  }

  private offlineHash(userId: number) {
    return `marketplace:offline:${userId}`;
  }

  private offlineTimeline(userId: number) {
    return `marketplace:offline:timeline:${userId}`;
  }
}
