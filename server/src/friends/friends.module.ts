import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { Friendship } from './entities/friendship.entity';
import { FriendRequest } from './entities/friend-request.entity';
import { FriendMessage } from './entities/friend-message.entity';
import { FriendChatBlock } from './entities/friend-chat-block.entity';
import { User } from '../users/entities/user.entity';
import { FriendsService } from './services/friends.service';
import { FriendRequestsService } from './services/friend-requests.service';
import { FriendMessagesService } from './services/friend-messages.service';
import { FriendChatBlocksService } from './services/friend-chat-blocks.service';
import { FriendsController } from './controllers/friends.controller';
import { FriendsAdminController } from './controllers/friends-admin.controller';
import { FriendsGateway } from './gateways/friends.gateway';
import { UsersModule } from '../users/users.module';
import { UploadModule } from '../upload/upload.module';
import { RedisModule } from '../redis/redis.module';
import { AuthModule } from '../auth/auth.module';

/**
 * 好友模块
 *
 * 功能：
 * - 好友关系管理（添加、删除、查询、备注）
 * - 好友申请管理（创建、接受、拒绝、过期）
 * - 消息管理（发送、离线队列、已读状态）
 * - WebSocket 实时通讯
 * - Admin 管理后台
 */
@Module({
  imports: [
    // 导入 TypeORM 实体
    TypeOrmModule.forFeature([
      Friendship,
      FriendRequest,
      FriendMessage,
      FriendChatBlock,
      User, // 添加 User 实体
    ]),
    // 导入其他模块
    UsersModule,
    AuthModule,
    UploadModule,
    RedisModule, // 添加 Redis 模块
    JwtModule.register({}),
  ],
  controllers: [
    FriendsController,
    FriendsAdminController,
  ],
  providers: [
    FriendsService,
    FriendRequestsService,
    FriendMessagesService,
    FriendChatBlocksService,
    FriendsGateway,
  ],
  exports: [
    FriendsService,
    FriendRequestsService,
    FriendMessagesService,
    FriendChatBlocksService,
    FriendsGateway,
  ],
})
export class FriendsModule {}
