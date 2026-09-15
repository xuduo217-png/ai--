import { FriendRequestsService } from './friend-requests.service';
import { FriendRequestStatus } from '../entities/friend-request.entity';

/**
 * 局部 mock uuid，避免 Jest 在当前仓库配置下解析 ESM 版本时报语法错误。
 */
jest.mock('uuid', () => ({
  v4: jest.fn(() => 'mocked-uuid'),
}));

/**
 * 创建好友申请服务测试实例
 * 业务规则：这里只验证申请状态收敛，不引入数据库和 Nest 容器，避免测试被外围依赖放大。
 */
function createService() {
  const friendRequestRepository = {
    findOne: jest.fn(),
    exist: jest.fn(),
    save: jest.fn(),
    create: jest.fn((payload) => payload),
  };

  const userRepository = {
    findOne: jest.fn(),
  };

  const friendsService = {
    isFriend: jest.fn(),
  };

  const friendsGateway = {
    emitFriendRequestNew: jest.fn(),
    emitFriendRequestRejected: jest.fn(),
  };

  const friendChatBlocksService = {
    assertUsersCanBecomeFriends: jest.fn().mockResolvedValue(undefined),
    isBlockedBy: jest.fn().mockResolvedValue(false),
    hasBlockBetween: jest.fn().mockResolvedValue(false),
  };

  const service = new FriendRequestsService(
    friendRequestRepository as any,
    userRepository as any,
    friendsService as any,
    friendsGateway as any,
    friendChatBlocksService as any,
  );

  return {
    service,
    friendRequestRepository,
    userRepository,
    friendsService,
    friendsGateway,
    friendChatBlocksService,
  };
}

describe('FriendRequestsService', () => {
  it('should return incoming-pending status when reverse pending request already exists', async () => {
    const {
      service,
      friendRequestRepository,
      userRepository,
      friendsService,
      friendsGateway,
    } = createService();

    userRepository.findOne
      .mockResolvedValueOnce({ id: 1, username: 'A' })
      .mockResolvedValueOnce({ id: 2, username: 'B' });
    friendsService.isFriend.mockResolvedValue(false);
    friendRequestRepository.findOne.mockResolvedValueOnce({
      id: 9,
      requesterId: 2,
      receiverId: 1,
      status: FriendRequestStatus.PENDING,
    });

    await expect(
      service.sendFriendRequest(1, {
        receiverId: 2,
        message: '你好',
      } as any),
    ).resolves.toEqual({
      success: false,
      status: 'incoming_pending',
      message: '对方已向你发送好友申请，请直接处理对方申请',
    });

    expect(friendRequestRepository.save).not.toHaveBeenCalled();
    expect(friendsGateway.emitFriendRequestNew).not.toHaveBeenCalled();
  });

  it('should return already-friends status instead of throwing when users are already friends', async () => {
    const {
      service,
      userRepository,
      friendsService,
      friendRequestRepository,
      friendsGateway,
    } = createService();

    userRepository.findOne
      .mockResolvedValueOnce({ id: 1, username: 'A' })
      .mockResolvedValueOnce({ id: 2, username: 'B' });
    friendsService.isFriend.mockResolvedValue(true);

    await expect(
      service.sendFriendRequest(1, {
        receiverId: 2,
        message: '你好',
      } as any),
    ).resolves.toEqual({
      success: false,
      status: 'already_friends',
      message: '已经是好友，无需重复申请',
    });

    expect(friendRequestRepository.findOne).not.toHaveBeenCalled();
    expect(friendRequestRepository.save).not.toHaveBeenCalled();
    expect(friendsGateway.emitFriendRequestNew).not.toHaveBeenCalled();
  });

  it('should return outgoing-pending status when same pending request already exists', async () => {
    const {
      service,
      friendRequestRepository,
      userRepository,
      friendsService,
      friendsGateway,
    } = createService();

    userRepository.findOne
      .mockResolvedValueOnce({ id: 1, username: 'A' })
      .mockResolvedValueOnce({ id: 2, username: 'B' });
    friendsService.isFriend.mockResolvedValue(false);
    friendRequestRepository.findOne
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({
        id: 12,
        requesterId: 1,
        receiverId: 2,
        status: FriendRequestStatus.PENDING,
        expiresAt: new Date('2099-04-06T10:00:00.000Z'),
      });

    await expect(
      service.sendFriendRequest(1, {
        receiverId: 2,
        message: '你好',
      } as any),
    ).resolves.toEqual({
      success: false,
      status: 'outgoing_pending',
      requestId: 12,
      message: '好友申请已发送，请耐心等待对方处理',
    });

    expect(friendRequestRepository.save).not.toHaveBeenCalled();
    expect(friendsGateway.emitFriendRequestNew).not.toHaveBeenCalled();
  });

  it('should reject friend request without rejection reason', async () => {
    const { service, friendRequestRepository, userRepository, friendsGateway } =
      createService();
    const pendingRequest = {
      id: 12,
      requesterId: 8,
      receiverId: 3,
      status: FriendRequestStatus.PENDING,
      rejectionReason: '旧原因',
      updatedAt: new Date('2026-03-14T10:00:00.000Z'),
    };

    friendRequestRepository.findOne.mockResolvedValueOnce(pendingRequest);
    friendRequestRepository.save.mockImplementation(async (payload) => payload);
    userRepository.findOne.mockResolvedValueOnce({
      id: 3,
      username: '接收人',
    });

    await expect(service.rejectFriendRequest(12, 3)).resolves.toBeUndefined();

    expect(friendRequestRepository.save).toHaveBeenCalledWith(
      expect.objectContaining({
        status: FriendRequestStatus.REJECTED,
        rejectionReason: null,
      }),
    );
    expect(friendsGateway.emitFriendRequestRejected).toHaveBeenCalledWith(
      8,
      expect.objectContaining({
        requestId: '12',
        receiverId: 3,
        receiverName: '接收人',
        reason: null,
      }),
    );
  });

  it('should reject sending a friend request while either side has a chat block', async () => {
    const {
      service,
      userRepository,
      friendRequestRepository,
      friendChatBlocksService,
    } = createService();
    userRepository.findOne
      .mockResolvedValueOnce({ id: 1, username: 'A' })
      .mockResolvedValueOnce({ id: 2, username: 'B' });
    friendChatBlocksService.assertUsersCanBecomeFriends.mockRejectedValueOnce(
      new Error('当前无法进行好友申请操作'),
    );

    await expect(
      service.sendFriendRequest(1, { receiverId: 2 } as any),
    ).rejects.toThrow('当前无法进行好友申请操作');

    expect(friendRequestRepository.save).not.toHaveBeenCalled();
  });

  it('should keep messaging disabled when a removed friend is no longer blocked', async () => {
    const {
      service,
      friendRequestRepository,
      friendsService,
      friendChatBlocksService,
    } = createService();
    friendsService.isFriend.mockResolvedValueOnce(false);
    friendRequestRepository.exist
      .mockResolvedValueOnce(false)
      .mockResolvedValueOnce(false);
    friendChatBlocksService.isBlockedBy.mockResolvedValueOnce(false);
    friendChatBlocksService.hasBlockBetween.mockResolvedValueOnce(false);

    await expect(service.getRelationshipSummary(1, 2)).resolves.toEqual({
      isFriend: false,
      outgoingPending: false,
      incomingPending: false,
      blockedByMe: false,
      canSendMessage: false,
    });
  });
});
