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
import { ChatService } from './chat.service';
import { ChatSessionService } from './chat-session.service';
import { MessageType } from './entities/message.entity';
import {
  Logger,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import { UseGuards } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { UsersService } from '../users/users.service';
import { DoctorsService } from '../doctors/doctors.service';
import { RedisService } from '../redis/redis.service';
import { UploadService } from '../upload/upload.service';
import { AuthSessionService } from '../auth/auth-session.service';
import { ChatSessionExtensionResult } from './chat-session-extension.service';

/**
 * 用户信息类型
 */
interface UserInfo {
  id: number;
  username: string;
  role?: string; // 角色字段（医生没有 role，设为可选）
  type: 'user' | 'doctor'; // 用户类型：普通用户或医生
  sid?: string;
}

/**
 * 认证后的 Socket 接口
 * 使用交叉类型扩展标准 Socket 的 handshake 属性，添加用户信息
 */
interface AuthenticatedSocket extends Socket {
  /**
   * 扩展 handshake，添加用户信息属性
   * 使用交叉类型保留原始 Handshake 的所有属性
   */
  handshake: Socket['handshake'] & {
    user?: UserInfo;
  };
  /**
   * Socket 上的用户信息
   * 在 handleConnection 中从 handshake.user 复制过来
   */
  user?: UserInfo;
  authSessionId?: string;
}

interface SendMessagePayload {
  conversationId?: string;
  receiverId?: number;
  content: string;
  type?: MessageType;
}

interface SendAiConsultationPayload {
  conversationId: string;
  aiConsultationId: number;
}

interface RevokeMessagePayload {
  conversationId: string;
  messageId: number;
}

interface JoinRoomPayload {
  conversationId?: string;
  userId?: number;
  doctorId?: number;
}

interface TypingPayload {
  conversationId: string;
  userId: number;
  isTyping: boolean;
}

interface GetSessionPayload {
  userId: number;
  doctorId: number;
}

@WebSocketGateway({
  cors: {
    origin: '*',
  },
})
export class ChatGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(ChatGateway.name);

  private personalRoom(
    principalType: 'user' | 'doctor',
    principalId: number,
  ): string {
    return `chat:${principalType}:${principalId}`;
  }

  private emitIncomingMessage(
    message: any,
    receiverType: 'user' | 'doctor',
    receiverId: number,
  ): void {
    this.server
      .to(this.personalRoom(receiverType, receiverId))
      .emit('chat:message:new', message);
  }

  emitRevokedMessage(message: any): void {
    this.server.to(message.conversationId).emit('messageRevoked', message);
    if (message.senderId && message.senderType) {
      this.server
        .to(this.personalRoom(message.senderType, message.senderId))
        .emit('chat:message:revoked', message);
    }
    if (message.receiverId && message.receiverType) {
      this.server
        .to(this.personalRoom(message.receiverType, message.receiverId))
        .emit('chat:message:revoked', message);
    }
  }

  /**
   * 统一解析咨询会话。
   * 业务规则：
   * 1. 新链路优先信任服务端持久化 `conversationId`
   * 2. 旧链路若仍传 `userId + doctorId`，则回退解析/创建当前活跃会话
   */
  private async resolveSessionFromPayload(options: {
    conversationId?: string;
    userId?: number;
    doctorId?: number;
    currentUserId?: number;
    createIfMissing?: boolean;
  }) {
    let session: any = null;

    if (options.conversationId) {
      session = await this.chatSessionService.getSessionByConversationId(
        options.conversationId,
      );
    } else if (options.userId && options.doctorId) {
      session = options.createIfMissing
        ? await this.chatSessionService.getOrCreateSession(
            options.userId,
            options.doctorId,
          )
        : await this.chatSessionService.getSession(
            options.userId,
            options.doctorId,
          );
    }

    if (!session) {
      throw new BadRequestException('无效的 conversationId 或参与者参数');
    }

    if (
      options.currentUserId &&
      session.userId !== options.currentUserId &&
      session.doctorId !== options.currentUserId
    ) {
      throw new UnauthorizedException('您无权访问该会话');
    }

    return session;
  }

  /**
   * 从当前会话中解析发送/接收双方。
   * 这样做是为了彻底摆脱 `conversationId.split("_")` 的旧假设。
   */
  private resolveConversationContext(
    session: { userId: number; doctorId: number; conversationId: string },
    currentUser: UserInfo,
  ) {
    const isDoctorSender = currentUser.type === 'doctor';
    const receiverId = isDoctorSender ? session.userId : session.doctorId;
    const receiverType: 'user' | 'doctor' = isDoctorSender ? 'user' : 'doctor';

    return {
      conversationId: session.conversationId,
      userId: session.userId,
      doctorId: session.doctorId,
      receiverId,
      receiverType,
    };
  }

  constructor(
    private readonly chatService: ChatService,
    private readonly chatSessionService: ChatSessionService,
    private readonly redisService: RedisService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly usersService: UsersService,
    private readonly doctorsService: DoctorsService,
    private readonly uploadService: UploadService,
    private readonly authSessionService: AuthSessionService,
  ) {}

  afterInit(server: Server) {
    this.logger.log('WebSocket Gateway initialized');
  }

  async handleConnection(client: AuthenticatedSocket) {
    // 🔐 手动验证 JWT token（NestJS Guard 不适用于 WebSocket 连接）
    try {
      // 从客户端的 auth 对象中获取 token
      const token = client.handshake.auth.token;

      this.logger.log(``);
      this.logger.log(`========================================`);
      this.logger.log(`[WebSocket] 客户端尝试连接`);
      this.logger.log(`----------------------------------------`);
      this.logger.log(`客户端 ID: ${client.id}`);
      this.logger.log(`Token 存在: ${!!token}`);
      this.logger.log(`========================================`);

      if (!token) {
        throw new UnauthorizedException('Missing token');
      }

      // 验证 token
      const payload = this.jwtService.verify(token, {
        secret: this.configService.get<string>('JWT_SECRET'),
      });
      await this.authSessionService.assertSession(
        payload.type,
        payload.sub,
        payload.sid,
      );

      this.logger.log(
        `[WebSocket] Token 验证成功，payload:`,
        JSON.stringify(payload),
      );

      // 根据 type 字段查询用户
      const type = payload.type; // 'user' 或 'doctor'
      const sub = payload.sub; // 用户 ID

      let user: any = null;

      if (type === 'doctor') {
        this.logger.log(`[WebSocket] 从医生表查询用户，sub=${sub}`);
        const doctor = await this.doctorsService.findOne(sub);
        if (!doctor) {
          throw new UnauthorizedException('医生不存在');
        }
        const { password, ...result } = doctor;
        user = { ...result, type: 'doctor', sid: payload.sid };
      } else {
        this.logger.log(`[WebSocket] 从用户表查询用户，sub=${sub}`);
        let userRecord = await this.usersService.findOne(sub);

        if (!userRecord && payload.username) {
          this.logger.log(
            `[WebSocket] 尝试用 username 查找: ${payload.username}`,
          );
          userRecord = await this.usersService.findByUsername(payload.username);
        }
        if (!userRecord && payload.phone) {
          this.logger.log(`[WebSocket] 尝试用 phone 查找: ${payload.phone}`);
          userRecord = await this.usersService.findByPhone(payload.phone);
        }

        if (!userRecord) {
          throw new UnauthorizedException('用户不存在');
        }
        const { password, ...result } = userRecord;
        user = { ...result, type: 'user', sid: payload.sid };
      }

      // 将用户信息注入到 client.handshake 和 client.user
      client.handshake.user = user;
      client.user = user;
      client.authSessionId = payload.sid;

      /**
       * 认证成功后立即加入个人房间。
       * 这样做是为了让首页、通知等非聊天页场景也能及时收到支付成功等个人级推送，
       * 避免客户端必须先进入具体会话后才能订阅个人消息。
       */
      const personalRoom = this.personalRoom(user.type, user.id);
      client.join(personalRoom);

      this.authSessionService.registerSocket(
        payload.type,
        sub,
        payload.sid,
        client,
        '/',
      );

      this.logger.log(``);
      this.logger.log(`========================================`);
      this.logger.log(`[WebSocket] ✅ 客户端已连接并认证`);
      this.logger.log(`----------------------------------------`);
      this.logger.log(`客户端 ID: ${client.id}`);
      this.logger.log(
        `用户信息: username=${user.username}, id=${user.id}, type=${user.type}`,
      );
      this.logger.log(`个人房间: ${personalRoom}`);
      this.logger.log(`========================================`);
    } catch (error) {
      this.logger.error(`[WebSocket] ❌ 认证失败: ${error.message}`);
      // 认证失败，断开连接
      client.disconnect();
      return;
    }
  }

  handleDisconnect(client: AuthenticatedSocket) {
    const username = client.user?.username || 'Unknown';
    const userId = client.user?.id;
    const userType = client.user?.type;
    this.logger.log(``);
    this.logger.log(
      `[WebSocket] 客户端已断开: ${client.id}, User: ${username} (${userId})`,
    );
    if (userId && userType) {
      this.authSessionService.unregisterSocket(userType, userId, client.id);
    }
  }

  @SubscribeMessage('join')
  async handleJoin(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: JoinRoomPayload,
  ) {
    const user = client.user || client.handshake.user;
    if (!user) {
      throw new UnauthorizedException('Unauthorized');
    }
    if (!client.user) {
      client.user = user;
    }

    const session = await this.resolveSessionFromPayload({
      conversationId: data.conversationId,
      userId: data.userId,
      doctorId: data.doctorId,
      currentUserId: user.id,
      createIfMissing: true,
    });
    const conversationId = session.conversationId;

    // 订阅个人房间（用于接收个人通知，如 paymentRequired）
    const personalRoom = this.personalRoom(user.type, user.id);
    client.join(personalRoom);

    // 订阅会话房间（用于接收聊天消息）
    client.join(conversationId);

    // 🔍 详细日志：记录客户端信息
    this.logger.log(``);
    this.logger.log(`========================================`);
    this.logger.log(`[handleJoin] 客户端加入房间`);
    this.logger.log(`----------------------------------------`);
    this.logger.log(`客户端 ID: ${client.id}`);
    this.logger.log(
      `用户信息: id=${client.user?.id}, type=${client.user?.type}, username=${client.user?.username}`,
    );
    this.logger.log(
      `请求参数: conversationId=${data.conversationId}, userId=${data.userId}, doctorId=${data.doctorId}`,
    );
    this.logger.log(`个人房间: ${personalRoom}`);
    this.logger.log(`会话房间: ${conversationId}`);
    this.logger.log(`========================================`);

    // 🔍 调试日志：查看会话房间中的所有客户端
    const conversationRoomSockets = await this.server
      .in(conversationId)
      .fetchSockets();
    this.logger.log(
      `[handleJoin] 会话房间 ${conversationId} 中的客户端数量: ${conversationRoomSockets.length}`,
    );
    conversationRoomSockets.forEach((socket, index) => {
      // 使用 unknown 作为中间类型，然后访问 handshake.user
      const authSocket = socket as unknown as AuthenticatedSocket;
      this.logger.log(
        `  [${index + 1}] Socket ID: ${socket.id}, User: ${authSocket.handshake?.user?.username || authSocket.user?.username} (${authSocket.handshake?.user?.id || authSocket.user?.id}), Type: ${authSocket.handshake?.user?.type || authSocket.user?.type}`,
      );
    });

    try {
      // 检查是否需要发送欢迎消息（自动回复第1条）
      if (
        session &&
        session.status === 'FREE' &&
        session.autoReplyCount === 0
      ) {
        this.logger.log(
          `[handleJoin] 首次进入房间，发送欢迎消息 [${session.userId}-${session.doctorId}]`,
        );

        // 发送欢迎消息（自动回复第1条）
        await this.chatService.sendInitialAutoReply(
          conversationId,
          session.userId,
          session.doctorId,
        );

        // 获取刚发送的消息并推送给会话房间（包括触发者）
        const tempKey = `chat:temp:${conversationId}`;
        const messages = await this.redisService.lrange(tempKey, 0, 0);
        if (messages.length > 0) {
          const welcomeMessage = JSON.parse(messages[0]);
          this.server.to(conversationId).emit('newMessage', welcomeMessage);
          this.emitIncomingMessage(welcomeMessage, 'user', session.userId);
          this.logger.log(
            `[handleJoin] 欢迎消息已推送到会话房间 ${conversationId}（包括触发者）`,
          );
        }
      }
    } catch (error) {
      this.logger.error(`[handleJoin] 发送欢迎消息失败: ${error.message}`);
    }

    return { success: true, conversationId, personalRoom };
  }

  @SubscribeMessage('leave')
  handleLeave(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: JoinRoomPayload,
  ) {
    const user = client.user || client.handshake.user;
    if (!user) {
      throw new UnauthorizedException('Unauthorized');
    }

    const sessionPromise = this.resolveSessionFromPayload({
      conversationId: data.conversationId,
      userId: data.userId,
      doctorId: data.doctorId,
      currentUserId: user.id,
      createIfMissing: false,
    });

    return sessionPromise
      .then((session) => {
        const conversationId = session.conversationId;
        const personalRoom = this.personalRoom(user.type, user.id);

        // 个人房间属于登录生命周期，离开具体咨询页时只退出会话房间。
        client.leave(conversationId);

        this.logger.log(
          `Client ${client.id} left conversation=${conversationId}, retained personal=${personalRoom}`,
        );
        return { success: true, conversationId, personalRoom };
      })
      .catch((error) => {
        this.logger.warn(`[leave] 离开房间失败: ${error.message}`);
        return { error: error.message };
      });
  }

  @SubscribeMessage('sendMessage')
  async handleMessage(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() payload: SendMessagePayload,
  ) {
    // 优先从 client.user 获取，如果没有则从 handshake.user 获取（兼容 handleConnection 未执行的情况）
    const user = client.user || client.handshake.user;
    if (!user) {
      this.logger.error('[sendMessage] 用户未认证');
      return { error: 'Unauthorized' };
    }

    // 确保 client.user 已设置（供其他方法使用）
    if (!client.user) {
      client.user = user;
    }

    this.logger.log(
      `[sendMessage] 用户信息: id=${user.id}, type=${user.type}, username=${user.username}`,
    );
    this.logger.log(
      `[sendMessage] 收到消息: conversationId=${payload.conversationId}, content=${payload.content}`,
    );

    try {
      const participantPair =
        !payload.conversationId && payload.receiverId
          ? user.type === 'doctor'
            ? { userId: payload.receiverId, doctorId: user.id }
            : { userId: user.id, doctorId: payload.receiverId }
          : undefined;

      const session = await this.resolveSessionFromPayload({
        conversationId: payload.conversationId,
        userId: participantPair?.userId,
        doctorId: participantPair?.doctorId,
        currentUserId: user.id,
        createIfMissing: true,
      });
      const { conversationId, receiverId, receiverType } =
        this.resolveConversationContext(session, user);

      this.logger.log(
        `[sendMessage] 解析结果: conversationId=${conversationId}, receiverId=${receiverId}, receiverType=${receiverType}`,
      );

      // 检查是否可以发送消息（检查免费额度）
      const check = await this.chatService.canSendMessage(
        user.id,
        receiverId,
        user.type,
        receiverType,
        conversationId,
      );

      if (!check.canSend) {
        this.logger.warn(`[sendMessage] 用户无法发送消息: ${check.reason}`);

        // 业务规则：付费提示只应在普通用户免费额度用尽时触发。
        // 医生发消息时如果误走到这里，会把 userId 当成 doctorId 去查套餐，产生异常提示消息。
        if (check.reason === 'FREE_LIMIT_EXCEEDED' && user.type === 'user') {
          const packages =
            await this.chatService.getAvailablePackages(receiverId);

          // 创建并发送付费提示消息（保存到数据库）
          const paymentPromptMessage =
            await this.chatService.sendPaymentPromptMessage(
              user.id,
              receiverId,
              packages,
            );

          // 通过 WebSocket 广播付费提示消息到会话房间
          this.server
            .to(conversationId)
            .emit('newMessage', paymentPromptMessage);
          this.emitIncomingMessage(paymentPromptMessage, 'user', user.id);
          this.logger.log(
            `[sendMessage] 已发送付费提示消息到会话房间 ${conversationId}, packages count: ${packages.length}`,
          );
        }

        return { error: check.reason };
      }

      // 媒体消息验证
      const messageType = payload.type || MessageType.TEXT;
      if (
        messageType === MessageType.IMAGE ||
        messageType === MessageType.VIDEO
      ) {
        const mediaLabel = messageType === MessageType.VIDEO ? '视频' : '图片';
        const mediaEmoji = messageType === MessageType.VIDEO ? '🎬' : '📷';
        this.logger.log(
          `[sendMessage] ${mediaEmoji} 检测到${mediaLabel}消息，开始验证`,
        );
        this.logger.log(
          `[sendMessage] ${mediaLabel}消息内容: ${payload.content}`,
        );

        try {
          // 支持两种格式：
          // 1. 字符串格式：content 直接是媒体 URL
          // 2. JSON 格式：content 是 JSON 对象，包含 url、thumbnail 等字段
          let mediaUrl: string;

          // 判断 content 是否为 JSON 格式
          if (payload.content.startsWith('{')) {
            // JSON 格式
            const mediaContent = JSON.parse(payload.content);

            if (!mediaContent.url) {
              this.logger.error(`[sendMessage] ${mediaLabel}消息缺少 url 字段`);
              throw new BadRequestException(
                `无效的${mediaLabel}消息：缺少${mediaLabel} URL`,
              );
            }

            mediaUrl = mediaContent.url;
            this.logger.log(
              `[sendMessage] ${mediaLabel}消息为 JSON 格式: ${mediaUrl}`,
            );
          } else {
            mediaUrl = payload.content;
            this.logger.log(
              `[sendMessage] ${mediaLabel}消息为字符串格式: ${mediaUrl}`,
            );
          }

          // 验证文件是否存在（临时禁用，先让媒体消息能发送）
          // TODO: 修复 fileExists 方法后重新启用
          /*
          this.logger.log(`[sendMessage] 🔍 开始验证文件是否存在: ${mediaUrl}`);
          const fileExists = await this.uploadService.fileExists(mediaUrl);
          this.logger.log(`[sendMessage] 文件存在性检查结果: ${fileExists}`);

          if (!fileExists) {
            this.logger.error(`[sendMessage] ❌ ${mediaLabel}文件不存在: ${mediaUrl}`);
            throw new BadRequestException(`${mediaLabel}文件不存在`);
          }
          */

          this.logger.log(
            `[sendMessage] ✅ ${mediaLabel}消息验证通过（跳过文件检查）: url=${mediaUrl}`,
          );
        } catch (error) {
          if (error instanceof BadRequestException) {
            this.logger.error(
              `[sendMessage] ❌ BadRequestException: ${error.message}`,
            );
            throw error;
          }

          // JSON 解析错误或其他错误
          this.logger.error(
            `[sendMessage] ❌ ${mediaLabel}消息验证失败: ${error.message}`,
          );
          this.logger.error(`[sendMessage] 错误堆栈: ${error.stack}`);
          throw new BadRequestException(`无效的${mediaLabel}消息格式`);
        }
      }

      // 调用 sendMessage 方法（会根据会话状态自动选择存储方式：FREE→Redis, PAID→MySQL）
      const message = await this.chatService.sendMessage(
        conversationId,
        user.id,
        user.type,
        receiverId,
        receiverType,
        payload.content,
        payload.type || MessageType.TEXT,
      );

      // 🔍 详细日志：记录消息广播信息
      this.logger.log(``);
      this.logger.log(`========================================`);
      this.logger.log(`[sendMessage] 准备广播消息`);
      this.logger.log(`----------------------------------------`);
      this.logger.log(
        `发送者: ${user.username} (id=${user.id}, type=${user.type})`,
      );
      this.logger.log(`接收者: id=${receiverId}, type=${receiverType}`);
      this.logger.log(`会话 ID: ${conversationId}`);
      this.logger.log(`消息内容: ${payload.content?.substring(0, 50)}`);
      this.logger.log(`========================================`);

      // 🔍 调试日志：广播前查看房间中的客户端
      const conversationRoomSockets = await this.server
        .in(conversationId)
        .fetchSockets();
      this.logger.log(
        `[sendMessage] 会话房间 ${conversationId} 中的客户端数量: ${conversationRoomSockets.length}`,
      );
      conversationRoomSockets.forEach((socket, index) => {
        // 使用 unknown 作为中间类型，然后访问 handshake.user
        const authSocket = socket as unknown as AuthenticatedSocket;
        this.logger.log(
          `  [${index + 1}] Socket ID: ${socket.id}, User: ${authSocket.handshake?.user?.username || authSocket.user?.username} (${authSocket.handshake?.user?.id || authSocket.user?.id}), Type: ${authSocket.handshake?.user?.type || authSocket.user?.type}`,
        );
      });

      // 向会话房间广播消息（除了发送者自己）
      // 前端已使用乐观更新，不需要再收到自己发送的消息
      client.to(conversationId).emit('newMessage', message);
      this.emitIncomingMessage(message, receiverType, receiverId);

      this.logger.log(
        `[sendMessage] ✅ 消息已广播到会话房间 ${conversationId}（排除发送者）`,
      );
      this.logger.log(`========================================`);

      // 检查是否需要触发自动回复（仅限普通用户在免费会话中发消息）
      // 业务规则：自动回复是“用户咨询 -> 系统回复”的链路，医生主动发送图片/文字时绝不能追加自动回复。
      const currentSession =
        await this.chatSessionService.getSessionByConversationId(
          conversationId,
        );
      if (
        currentSession &&
        currentSession.status === 'FREE' &&
        user.type === 'user'
      ) {
        const autoReplyMessage = await this.chatService.triggerAutoReply(
          conversationId,
          currentSession.userId,
          currentSession.doctorId,
        );

        // 如果有自动回复，发送到会话房间（包括触发者）
        // 注意：使用 server.to() 而不是 client.to()，确保触发者也能收到自动回复
        if (autoReplyMessage) {
          this.server.to(conversationId).emit('newMessage', autoReplyMessage);
          this.emitIncomingMessage(
            autoReplyMessage,
            'user',
            currentSession.userId,
          );
          this.logger.log(
            `[sendMessage] 自动回复已广播到会话房间 ${conversationId}（包括触发者）`,
          );
        } else {
          const shouldSendPaymentPrompt =
            await this.chatService.shouldSendPaymentPromptAfterMessage(
              conversationId,
            );

          if (shouldSendPaymentPrompt) {
            this.logger.log(
              `[sendMessage] 自动回复已全部发送，用户已追加一条消息，准备发送付费提示`,
            );
            const packages =
              await this.chatService.getAvailablePackages(receiverId);
            const paymentPromptMessage =
              await this.chatService.sendPaymentPromptMessage(
                user.id,
                receiverId,
                packages,
              );

            this.server
              .to(conversationId)
              .emit('newMessage', paymentPromptMessage);
            this.emitIncomingMessage(
              paymentPromptMessage,
              'user',
              currentSession.userId,
            );
            this.logger.log(
              `[sendMessage] 已发送付费提示消息到会话房间 ${conversationId}, packages count: ${packages.length}`,
            );
          } else {
            this.logger.log(
              `[sendMessage] triggerAutoReply 返回 null，当前无需发送付费提示`,
            );
          }
        }
      }

      return { success: true, message };
    } catch (error) {
      this.logger.error(`Error sending message: ${error.message}`, error.stack);

      // 业务规则：异常兜底时也只给普通用户发送付费提示，避免医生端出现不该有的系统消息。
      if (
        error.message === 'FREE_LIMIT_EXCEEDED' &&
        user.type === 'user' &&
        payload.conversationId
      ) {
        const session =
          await this.chatSessionService.getSessionByConversationId(
            payload.conversationId,
          );
        if (!session) {
          return { error: error.message };
        }
        const packages = await this.chatService.getAvailablePackages(
          session.doctorId,
        );

        // 创建并发送付费提示消息（保存到数据库）
        const paymentPromptMessage =
          await this.chatService.sendPaymentPromptMessage(
            session.userId,
            session.doctorId,
            packages,
          );

        // 通过 WebSocket 广播付费提示消息到会话房间
        this.server
          .to(payload.conversationId)
          .emit('newMessage', paymentPromptMessage);
        this.emitIncomingMessage(paymentPromptMessage, 'user', session.userId);
        this.logger.log(
          `[sendMessage] 异常捕获，已发送付费提示消息到会话房间 ${payload.conversationId}, packages count: ${packages.length}`,
        );
      }

      return { error: error.message };
    }
  }

  @SubscribeMessage('sendAiConsultation')
  async handleSendAiConsultation(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() payload: SendAiConsultationPayload,
  ) {
    const user = client.user || client.handshake.user;
    if (!user) {
      return { error: 'Unauthorized' };
    }
    if (!client.user) client.user = user;

    try {
      const session = await this.resolveSessionFromPayload({
        conversationId: payload.conversationId,
        currentUserId: user.id,
      });
      const { receiverId } = this.resolveConversationContext(session, user);

      const message = await this.chatService.sendAiConsultation(
        payload.conversationId,
        user.id,
        receiverId,
        payload.aiConsultationId,
      );

      // 向会话房间广播 AI 问诊消息（包括发送者）
      // 注意：AI 问诊虽然是用户触发的，但用户应该收到确认
      this.server.to(payload.conversationId).emit('newMessage', message);
      this.emitIncomingMessage(message, 'doctor', receiverId);
      this.logger.log(
        `[sendAiConsultation] AI 问诊消息已广播到会话房间 ${payload.conversationId}（包括发送者）`,
      );

      return { success: true, message };
    } catch (error) {
      this.logger.error(`Error sending AI consultation: ${error.message}`);
      return { error: error.message };
    }
  }

  @SubscribeMessage('revokeMessage')
  async handleRevokeMessage(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() payload: RevokeMessagePayload,
  ) {
    const user = client.user || client.handshake.user;
    if (!user) {
      return { success: false, error: 'Unauthorized' };
    }
    try {
      const message = await this.chatService.revokeMessage(
        payload.conversationId,
        Number(payload.messageId),
        user.id,
        user.type,
      );
      this.emitRevokedMessage(message);
      return { success: true, message };
    } catch (error) {
      this.logger.warn(`[revokeMessage] 撤回失败: ${error.message}`);
      return { success: false, error: error.message };
    }
  }

  @SubscribeMessage('markAsRead')
  async handleMarkAsRead(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { messageId: number },
  ) {
    const user = client.user || client.handshake.user;
    if (!user) {
      return { error: 'Unauthorized' };
    }
    try {
      await this.chatService.markAsRead(data.messageId, user.id, user.type);
      this.server
        .to(this.personalRoom(user.type, user.id))
        .emit('messagesRead', { messageId: data.messageId });
      return { success: true };
    } catch (error) {
      this.logger.error(`Error marking as read: ${error.message}`);
      return { error: error.message };
    }
  }

  @SubscribeMessage('markConversationAsRead')
  async handleMarkConversationAsRead(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { conversationId: string },
  ) {
    const user = client.user || client.handshake.user;
    if (!user) {
      return { error: 'Unauthorized' };
    }
    try {
      await this.chatService.markConversationAsRead(
        data.conversationId,
        user.id,
        user.type,
      );
      this.server
        .to(this.personalRoom(user.type, user.id))
        .emit('conversationRead', { conversationId: data.conversationId });
      return { success: true };
    } catch (error) {
      this.logger.error(`Error marking conversation as read: ${error.message}`);
      return { error: error.message };
    }
  }

  @SubscribeMessage('getHistory')
  async handleGetHistory(
    @MessageBody()
    data: {
      conversationId: string;
      page?: number;
      limit?: number;
    },
  ) {
    try {
      const messages = await this.chatService.getMessagesByConversation(
        data.conversationId,
        data.page || 1,
        data.limit || 50,
      );
      return { success: true, messages };
    } catch (error) {
      this.logger.error(`Error getting history: ${error.message}`);
      return { error: error.message };
    }
  }

  @SubscribeMessage('typing')
  async handleTyping(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: TypingPayload,
  ) {
    const user = client.user || client.handshake.user;
    if (!user) {
      throw new UnauthorizedException('Unauthorized');
    }

    const session = await this.resolveSessionFromPayload({
      conversationId: data.conversationId,
      currentUserId: user.id,
    });
    const recipientType: 'user' | 'doctor' =
      user.type === 'user' ? 'doctor' : 'user';
    const recipientId =
      recipientType === 'doctor' ? session.doctorId : session.userId;
    const recipientRoom = this.personalRoom(recipientType, recipientId);

    this.server.to(recipientRoom).emit('userTyping', {
      conversationId: data.conversationId,
      userId: user.id,
      isTyping: data.isTyping,
    });

    return { success: true };
  }

  @SubscribeMessage('getSession')
  async handleGetSession(@MessageBody() data: GetSessionPayload) {
    try {
      const session = await this.chatService.getOrCreateSession(
        data.userId,
        data.doctorId,
      );
      return { success: true, session };
    } catch (error) {
      this.logger.error(`Error getting session: ${error.message}`);
      return { error: error.message };
    }
  }

  @SubscribeMessage('checkCanSend')
  async handleCheckCanSend(
    @MessageBody() data: { userId: number; doctorId: number },
  ) {
    try {
      const check = await this.chatService.canSendMessage(
        data.userId,
        data.doctorId,
      );
      return { success: true, canSend: check };
    } catch (error) {
      this.logger.error(`Error checking can send: ${error.message}`);
      return { error: error.message };
    }
  }

  @SubscribeMessage('getUnreadCount')
  async handleGetUnreadCount(@ConnectedSocket() client: AuthenticatedSocket) {
    const user = client.user || client.handshake.user;
    if (!user) {
      return { error: 'Unauthorized' };
    }
    if (!client.user) client.user = user;

    try {
      const count = await this.chatService.getUnreadCount(user.id, user.type);
      return { success: true, count };
    } catch (error) {
      this.logger.error(`Error getting unread count: ${error.message}`);
      return { error: error.message };
    }
  }

  /**
   * 推送支付成功消息（公共方法，供其他 Service 调用）
   * @param userId 用户 ID
   * @param doctorId 医生 ID
   * @param paymentMessage 支付成功消息对象
   */
  notifyPaymentSuccess(userId: number, doctorId: number, paymentMessage: any) {
    const userRoom = this.personalRoom('user', userId);
    const doctorRoom = this.personalRoom('doctor', doctorId);

    this.logger.log(
      `[notifyPaymentSuccess] 推送支付成功消息到房间 ${userRoom} 和 ${doctorRoom}, ` +
        `订单: ${paymentMessage.orderId}, 内容: ${paymentMessage.content?.substring(0, 30)}`,
    );

    // 向用户和医生发送支付成功消息
    this.server.to(userRoom).emit('newMessage', paymentMessage);
    this.server.to(doctorRoom).emit('newMessage', paymentMessage);
    this.emitIncomingMessage(paymentMessage, 'user', userId);
  }

  emitSessionExtended(extension: ChatSessionExtensionResult): void {
    const event = {
      extensionId: extension.extensionId,
      conversationId: extension.conversationId,
      userId: extension.userId,
      doctorId: extension.doctorId,
      orderId: extension.orderId,
      extensionMinutes: extension.extensionMinutes,
      previousServiceEndAt: extension.previousServiceEndAt,
      serviceEndAt: extension.serviceEndAt,
      status: extension.status,
      extendedAt: extension.extendedAt,
    };
    this.server
      .to(extension.conversationId)
      .emit('chat:session:extended', event);
    this.server
      .to(this.personalRoom('user', extension.userId))
      .emit('chat:session:extended', event);
    this.server
      .to(this.personalRoom('doctor', extension.doctorId))
      .emit('chat:session:extended', event);
  }

  /**
   * 广播医生在线状态变化（公共方法，供 DoctorsService 调用）
   * @param doctorId 医生 ID
   * @param onlineStatus 在线状态（ONLINE/OFFLINE）
   */
  notifyDoctorOnlineStatus(
    doctorId: number,
    onlineStatus: 'ONLINE' | 'OFFLINE',
  ) {
    this.logger.log(
      `[notifyDoctorOnlineStatus] 广播医生在线状态变化: doctorId=${doctorId}, status=${onlineStatus}`,
    );

    // 向所有连接的客户端广播医生在线状态变化
    this.server.emit('doctorOnlineStatusChanged', {
      doctorId,
      onlineStatus,
    });
  }

  /**
   * 🔍 辅助方法：查看所有房间中的客户端（仅用于调试）
   * 可以通过 HTTP API 调用此方法来诊断房间订阅问题
   */
  async debugRoomState(conversationId: string) {
    this.logger.log(``);
    this.logger.log(`========================================`);
    this.logger.log(`[DEBUG] 房间状态查询`);
    this.logger.log(`----------------------------------------`);

    try {
      const session =
        await this.chatSessionService.getSessionByConversationId(
          conversationId,
        );

      // 查看会话房间中的客户端
      const conversationRoomSockets = await this.server
        .in(conversationId)
        .fetchSockets();
      this.logger.log(
        `会话房间 [${conversationId}] 中的客户端数量: ${conversationRoomSockets.length}`,
      );
      conversationRoomSockets.forEach((socket, index) => {
        // 使用 unknown 作为中间类型，然后访问 handshake.user
        const authSocket = socket as unknown as AuthenticatedSocket;
        const user = authSocket.handshake?.user || authSocket.user;
        this.logger.log(
          `  [${index + 1}] Socket ID: ${socket.id}, User: ${user?.username} (${user?.id}), Type: ${user?.type}`,
        );
      });

      // 查看会话涉及的用户的个人房间
      const userRoom1 = session
        ? this.personalRoom('user', session.userId)
        : null;
      const userRoom2 = session
        ? this.personalRoom('doctor', session.doctorId)
        : null;

      const userRoom1Sockets = userRoom1
        ? await this.server.in(userRoom1).fetchSockets()
        : [];
      this.logger.log(
        `个人房间 [${userRoom1 ?? 'N/A'}] 中的客户端数量: ${userRoom1Sockets.length}`,
      );
      userRoom1Sockets.forEach((socket, index) => {
        // 使用 unknown 作为中间类型，然后访问 handshake.user
        const authSocket = socket as unknown as AuthenticatedSocket;
        const user = authSocket.handshake?.user || authSocket.user;
        this.logger.log(
          `  [${index + 1}] Socket ID: ${socket.id}, User: ${user?.username} (${user?.id})`,
        );
      });

      const userRoom2Sockets = userRoom2
        ? await this.server.in(userRoom2).fetchSockets()
        : [];
      this.logger.log(
        `个人房间 [${userRoom2 ?? 'N/A'}] 中的客户端数量: ${userRoom2Sockets.length}`,
      );
      userRoom2Sockets.forEach((socket, index) => {
        // 使用 unknown 作为中间类型，然后访问 handshake.user
        const authSocket = socket as unknown as AuthenticatedSocket;
        const user = authSocket.handshake?.user || authSocket.user;
        this.logger.log(
          `  [${index + 1}] Socket ID: ${socket.id}, User: ${user?.username} (${user?.id})`,
        );
      });

      this.logger.log(`========================================`);

      return {
        conversationRoom: {
          roomId: conversationId,
          clients: conversationRoomSockets.length,
          details: conversationRoomSockets.map((s: any) => ({
            socketId: s.id,
            userId: s.user?.id,
            username: s.user?.username,
            type: s.user?.type,
          })),
        },
        personalRooms: {
          [userRoom1 ?? 'unknown-user-1']: {
            clients: userRoom1Sockets.length,
            details: userRoom1Sockets.map((s: any) => ({
              socketId: s.id,
              userId: s.user?.id,
              username: s.user?.username,
            })),
          },
          [userRoom2 ?? 'unknown']: {
            clients: userRoom2Sockets.length,
            details: userRoom2Sockets.map((s: any) => ({
              socketId: s.id,
              userId: s.user?.id,
              username: s.user?.username,
            })),
          },
        },
      };
    } catch (error) {
      this.logger.error(`[DEBUG] 查询房间状态失败: ${error.message}`);
      return { error: error.message };
    }
  }
}
