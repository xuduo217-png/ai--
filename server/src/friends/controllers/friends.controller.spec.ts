jest.mock('uuid', () => ({
  v4: () => 'mock-friend-message-uuid',
}));

import { Test, TestingModule } from '@nestjs/testing';
import { FriendsController } from './friends.controller';
import { FriendsService } from '../services/friends.service';
import { FriendRequestsService } from '../services/friend-requests.service';
import { FriendMessagesService } from '../services/friend-messages.service';
import { FriendsGateway } from '../gateways/friends.gateway';
import { UsersService } from '../../users/users.service';
import { FriendChatBlocksService } from '../services/friend-chat-blocks.service';

describe('FriendsController', () => {
  let controller: FriendsController;

  const mockFriendsService = {
    getFriendsList: jest.fn(),
    updateFriendRemark: jest.fn(),
    deleteFriendship: jest.fn(),
  };

  const mockFriendRequestsService = {
    sendFriendRequest: jest.fn(),
    getFriendRequests: jest.fn(),
    acceptFriendRequest: jest.fn(),
    rejectFriendRequest: jest.fn(),
  };

  const mockFriendMessagesService = {
    sendMessage: jest.fn(),
    getMessages: jest.fn(),
    markMessageAsRead: jest.fn(),
  };

  const mockFriendChatBlocksService = {
    blockUser: jest.fn(),
    unblockUser: jest.fn(),
    getBlockedUsers: jest.fn(),
  };

  const mockFriendsGateway = {
    emitFriendshipDeleted: jest.fn(),
  };

  const mockUsersService = {
    findByPhone: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [FriendsController],
      providers: [
        { provide: FriendsService, useValue: mockFriendsService },
        { provide: FriendRequestsService, useValue: mockFriendRequestsService },
        { provide: FriendMessagesService, useValue: mockFriendMessagesService },
        {
          provide: FriendChatBlocksService,
          useValue: mockFriendChatBlocksService,
        },
        { provide: FriendsGateway, useValue: mockFriendsGateway },
        { provide: UsersService, useValue: mockUsersService },
      ],
    }).compile();

    controller = module.get<FriendsController>(FriendsController);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should return a normal not-found payload when user does not exist', async () => {
    mockUsersService.findByPhone.mockResolvedValue(null);

    const result = await controller.searchUserByPhone({ phone: '13800138001' });

    expect(result).toEqual({
      found: false,
      user: null,
      message: '用户不存在',
    });
  });

  it('should return found user payload when user exists', async () => {
    mockUsersService.findByPhone.mockResolvedValue({
      id: 3,
      username: '张三',
      avatar: '/uploads/avatar.png',
      phone: '13800138000',
    });

    const result = await controller.searchUserByPhone({ phone: '13800138000' });

    expect(result).toEqual({
      found: true,
      user: {
        id: 3,
        username: '张三',
        avatar: '/uploads/avatar.png',
        phone: '13800138000',
      },
      message: '搜索成功',
    });
  });

  it('should allow rejecting friend request without request body', async () => {
    mockFriendRequestsService.rejectFriendRequest.mockResolvedValue(undefined);

    const result = await controller.rejectFriendRequest(
      { id: 5 },
      12,
      undefined,
    );

    expect(mockFriendRequestsService.rejectFriendRequest).toHaveBeenCalledWith(
      12,
      5,
      undefined,
    );
    expect(result).toEqual({
      success: true,
    });
  });

  it('should return business status payload for friendly friend-request responses', async () => {
    mockFriendRequestsService.sendFriendRequest.mockResolvedValue({
      success: false,
      status: 'incoming_pending',
      message: '对方已向你发送好友申请，请直接处理对方申请',
    });

    const result = await controller.sendFriendRequest(
      { id: 5 },
      { receiverId: 12, message: '你好' },
    );

    expect(mockFriendRequestsService.sendFriendRequest).toHaveBeenCalledWith(
      5,
      {
        receiverId: 12,
        message: '你好',
      },
    );
    expect(result).toEqual({
      success: false,
      status: 'incoming_pending',
      message: '对方已向你发送好友申请，请直接处理对方申请',
    });
  });

  it('should expose friend chat block operations', async () => {
    const blockedAt = new Date('2026-07-27T08:00:00.000Z');
    const page = {
      data: [],
      total: 0,
      page: 1,
      pageSize: 20,
      totalPages: 0,
    };
    mockFriendChatBlocksService.blockUser.mockResolvedValue({
      id: 7,
      blockedUserId: 12,
      createdAt: blockedAt,
    });
    mockFriendChatBlocksService.unblockUser.mockResolvedValue(undefined);
    mockFriendChatBlocksService.getBlockedUsers.mockResolvedValue(page);

    await expect(
      controller.blockFriendChat({ id: 5 }, { blockedUserId: 12 }),
    ).resolves.toEqual({
      success: true,
      data: { id: 7, blockedUserId: 12, blockedAt },
    });
    await expect(controller.unblockFriendChat({ id: 5 }, 12)).resolves.toEqual({
      success: true,
    });
    await expect(
      controller.getFriendChatBlocks({ id: 5 }, { page: 1, pageSize: 20 }),
    ).resolves.toEqual(page);

    expect(mockFriendChatBlocksService.blockUser).toHaveBeenCalledWith(5, 12);
    expect(mockFriendChatBlocksService.unblockUser).toHaveBeenCalledWith(5, 12);
    expect(mockFriendChatBlocksService.getBlockedUsers).toHaveBeenCalledWith(
      5,
      { page: 1, pageSize: 20 },
    );
  });
});

describe('FriendsService.getFriendsList', () => {
  function createFriendsService(
    relationshipCount: number,
    friendships: any[] = [],
    total: number = friendships.length,
  ) {
    const queryBuilder = {
      innerJoinAndSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getManyAndCount: jest.fn().mockResolvedValue([friendships, total]),
    };
    const friendshipRepository = {
      count: jest.fn().mockResolvedValue(relationshipCount),
      createQueryBuilder: jest.fn().mockReturnValue(queryBuilder),
    };
    const service = new FriendsService(
      friendshipRepository as any,
      {} as any,
    );

    return { service, friendshipRepository, queryBuilder };
  }

  it('should return an empty page without querying relations when the user has no friends', async () => {
    const { service, friendshipRepository, queryBuilder } =
      createFriendsService(0);

    await expect(
      service.getFriendsList(7, { page: 1, pageSize: 20 }),
    ).resolves.toEqual({
      data: [],
      total: 0,
      page: 1,
      pageSize: 20,
      totalPages: 0,
    });

    expect(friendshipRepository.count).toHaveBeenCalledWith({
      where: { userId: 7 },
    });
    expect(friendshipRepository.createQueryBuilder).not.toHaveBeenCalled();
    expect(queryBuilder.innerJoinAndSelect).not.toHaveBeenCalled();
    expect(queryBuilder.getManyAndCount).not.toHaveBeenCalled();
  });

  it('should map valid friendships without changing pagination', async () => {
    const createdAt = new Date('2026-08-13T00:00:00.000Z');
    const { service } = createFriendsService(
      1,
      [
        {
          id: 11,
          userId: 7,
          friendId: 9,
          friend: {
            username: '李四',
            avatar: '/uploads/avatar.png',
            phone: '13800138001',
          },
          remark: '同事',
          direction: 'sent',
          lastChatAt: null,
          createdAt,
        },
      ],
    );

    await expect(
      service.getFriendsList(7, { page: 1, pageSize: 20 }),
    ).resolves.toEqual({
      data: [
        {
          id: 11,
          userId: 7,
          friendId: 9,
          friendName: '李四',
          friendAvatar: '/uploads/avatar.png',
          friendPhone: '13800138001',
          remark: '同事',
          direction: 'sent',
          lastChatAt: null,
          createdAt,
        },
      ],
      total: 1,
      page: 1,
      pageSize: 20,
      totalPages: 1,
    });
  });
});
