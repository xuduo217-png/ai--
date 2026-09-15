import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { FriendsGateway } from './friends.gateway';
import { FriendMessagesService } from '../services/friend-messages.service';
import { FriendsService } from '../services/friends.service';
import { RedisService } from '../../redis/redis.service';
import { UsersService } from '../../users/users.service';
import { AuthSessionService } from '../../auth/auth-session.service';
import { FriendChatBlocksService } from '../services/friend-chat-blocks.service';

/**
 * 局部 mock uuid，避免 Jest 在当前仓库配置下解析 ESM 版本时报语法错误。
 */
jest.mock('uuid', () => ({
  v4: jest.fn(() => 'mocked-uuid'),
}));

/**
 * 创建好友网关测试实例
 * 业务规则：这里只验证网关内部判断逻辑，不引入 Nest 容器，避免测试被无关依赖放大。
 */
function createGateway(
  redisService: Partial<
    Pick<RedisService, 'hgetall' | 'hset' | 'expire' | 'zadd'>
  >,
  friendsService?: Partial<Pick<FriendsService, 'isFriend'>>,
  friendChatBlocksService?: Partial<
    Pick<FriendChatBlocksService, 'hasBlockBetween'>
  >,
): FriendsGateway {
  return new FriendsGateway(
    {} as JwtService,
    {} as ConfigService,
    {} as UsersService,
    {
      isFriend: jest.fn().mockResolvedValue(true),
      ...friendsService,
    } as FriendsService,
    {} as FriendMessagesService,
    {
      hasBlockBetween: jest.fn().mockResolvedValue(false),
      ...friendChatBlocksService,
    } as FriendChatBlocksService,
    redisService as RedisService,
    {
      assertSession: jest.fn().mockResolvedValue(undefined),
      registerSocket: jest.fn(),
      unregisterSocket: jest.fn(),
    } as unknown as AuthSessionService,
  );
}

describe('FriendsGateway', () => {
  it('should detect online user from namespace adapter rooms', async () => {
    const redisService = {
      hgetall: jest.fn().mockResolvedValue({}),
    };
    const gateway = createGateway(redisService);

    (gateway as any).server = {
      adapter: {
        rooms: new Map([['user:12', new Set(['socket-1'])]]),
      },
    };

    await expect((gateway as any).isUserOnline(12)).resolves.toBe(true);
    expect(redisService.hgetall).not.toHaveBeenCalled();
  });

  it('should fall back to redis when room registry is unavailable', async () => {
    const redisService = {
      hgetall: jest.fn().mockResolvedValue({
        'socket-1': JSON.stringify({ connectedAt: Date.now() }),
      }),
    };
    const gateway = createGateway(redisService);

    (gateway as any).server = {
      sockets: new Map(),
    };

    await expect((gateway as any).isUserOnline(15)).resolves.toBe(true);
    expect(redisService.hgetall).toHaveBeenCalledWith('friends:online:15');
  });

  it('should trust namespace rooms over stale redis records in single-instance mode', async () => {
    const redisService = {
      hgetall: jest.fn().mockResolvedValue({
        'socket-stale': JSON.stringify({ connectedAt: Date.now() }),
      }),
    };
    const gateway = createGateway(redisService);

    (gateway as any).server = {
      adapter: {
        rooms: new Map(),
      },
    };

    await expect((gateway as any).isUserOnline(15)).resolves.toBe(false);
    expect(redisService.hgetall).not.toHaveBeenCalled();
  });

  it('should queue message when receiver room is not present', async () => {
    const redisService = {
      hset: jest.fn().mockResolvedValue(undefined),
      zadd: jest.fn().mockResolvedValue(undefined),
      expire: jest.fn().mockResolvedValue(undefined),
    };
    const gateway = createGateway(redisService);

    const emit = jest.fn();
    const to = jest.fn(() => ({ emit }));
    (gateway as any).server = {
      adapter: {
        rooms: new Map(),
      },
      to,
    };

    const deliveryMode = await gateway.dispatchPersistedMessage({
      messageId: 'msg-1',
      receiverId: 9,
    } as any);

    expect(deliveryMode).toBe('offline');
    expect(to).not.toHaveBeenCalled();
    expect(redisService.hset).toHaveBeenCalledWith(
      'friends:offline:9',
      'msg-1',
      expect.any(String),
    );
  });

  it('should reject typing indicator for non-friends', async () => {
    const redisService = {
      hset: jest.fn().mockResolvedValue(undefined),
      expire: jest.fn().mockResolvedValue(undefined),
    };
    const gateway = createGateway(redisService, {
      isFriend: jest.fn().mockResolvedValue(false),
    });

    const emit = jest.fn();
    const to = jest.fn(() => ({ emit }));
    (gateway as any).server = { to };

    const result = await gateway.handleTypingStart(
      { conversationId: '1_2' } as any,
      {
        id: 'socket-1',
        user: { id: 1, username: 'tester', type: 'user' },
      } as any,
    );

    expect(result).toEqual({
      success: false,
      message: '只能向好友发送输入状态',
    });
    expect(to).not.toHaveBeenCalled();
  });

  it('should reject typing indicator when either friend has blocked the chat', async () => {
    const redisService = {
      hset: jest.fn().mockResolvedValue(undefined),
      expire: jest.fn().mockResolvedValue(undefined),
    };
    const gateway = createGateway(redisService, undefined, {
      hasBlockBetween: jest.fn().mockResolvedValue(true),
    });
    const to = jest.fn();
    (gateway as any).server = { to };

    const result = await gateway.handleTypingStart(
      { conversationId: '1_2' } as any,
      {
        id: 'socket-1',
        user: { id: 1, username: 'tester', type: 'user' },
      } as any,
    );

    expect(result).toEqual({
      success: false,
      message: '当前无法发送输入状态',
    });
    expect(to).not.toHaveBeenCalled();
  });
});
