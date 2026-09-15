import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { FriendMessagesService } from './friend-messages.service';
import { MessageType } from '../entities/friend-message.entity';

/**
 * 局部 mock uuid，避免 Jest 在当前仓库配置下解析 ESM 版本时报语法错误。
 */
jest.mock('uuid', () => ({
  v4: jest.fn(() => 'mocked-uuid'),
}));

/**
 * 创建消息服务测试实例
 * 业务规则：这里只验证好友消息内容规范化，不引入数据库或 Nest 容器。
 */
function createService() {
  const messageRepository = {
    create: jest.fn((payload) => payload),
    save: jest.fn(async (payload) => payload),
    findOne: jest.fn(),
  };

  const friendsService = {
    isFriend: jest.fn().mockResolvedValue(true),
    updateLastChatTime: jest.fn().mockResolvedValue(undefined),
  };

  const friendChatBlocksService = {
    assertUsersCanChat: jest.fn().mockResolvedValue(undefined),
  };

  const service = new FriendMessagesService(
    messageRepository as any,
    friendsService as any,
    {} as any,
    {} as any,
    friendChatBlocksService as any,
  );

  return {
    service,
    messageRepository,
    friendsService,
    friendChatBlocksService,
  };
}

describe('FriendMessagesService', () => {
  it('should normalize legacy image url content to json', async () => {
    const { service, messageRepository } = createService();

    await service.sendMessage(1, {
      receiverId: 2,
      messageType: MessageType.IMAGE,
      content: 'https://example.com/image.png',
    } as any);

    expect(messageRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        messageId: expect.any(String),
        conversationId: '1_2',
        senderId: 1,
        receiverId: 2,
        messageType: MessageType.IMAGE,
        content: JSON.stringify({ url: 'https://example.com/image.png' }),
        cloudFileUrl: 'https://example.com/image.png',
      }),
    );
  });

  it('should preserve voice duration when content is json', async () => {
    const { service, messageRepository } = createService();

    await service.sendMessage(1, {
      receiverId: 2,
      messageType: MessageType.VOICE,
      content: JSON.stringify({
        url: 'https://example.com/voice.m4a',
        duration: 18,
      }),
    } as any);

    expect(messageRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        content: JSON.stringify({
          url: 'https://example.com/voice.m4a',
          duration: 18,
        }),
        cloudFileUrl: 'https://example.com/voice.m4a',
      }),
    );
  });

  it('should preserve video payload fields when content is json', async () => {
    const { service, messageRepository } = createService();

    await service.sendMessage(1, {
      receiverId: 2,
      messageType: 'video',
      content: JSON.stringify({
        url: 'https://example.com/video.mp4',
        thumbnail: 'https://example.com/video-cover.jpg',
        width: 720,
        height: 1280,
        duration: 12,
      }),
    } as any);

    expect(messageRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        content: JSON.stringify({
          url: 'https://example.com/video.mp4',
          thumbnail: 'https://example.com/video-cover.jpg',
          width: 720,
          height: 1280,
          duration: 12,
        }),
        cloudFileUrl: 'https://example.com/video.mp4',
      }),
    );
  });

  it('should reject empty media content', async () => {
    const { service } = createService();

    await expect(
      service.sendMessage(1, {
        receiverId: 2,
        messageType: MessageType.IMAGE,
        content: '   ',
      } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('should reject a message before persisting when either side has a friend chat block', async () => {
    const { service, messageRepository, friendChatBlocksService } =
      createService();
    friendChatBlocksService.assertUsersCanChat.mockRejectedValueOnce(
      new Error('当前无法发送好友消息'),
    );

    await expect(
      service.sendMessage(1, {
        receiverId: 2,
        messageType: MessageType.TEXT,
        content: '你好',
      } as any),
    ).rejects.toThrow('当前无法发送好友消息');

    expect(friendChatBlocksService.assertUsersCanChat).toHaveBeenCalledWith(
      1,
      2,
    );
    expect(messageRepository.save).not.toHaveBeenCalled();
  });

  it('should reject a message when users are no longer friends after unblocking', async () => {
    const {
      service,
      messageRepository,
      friendsService,
      friendChatBlocksService,
    } = createService();
    friendsService.isFriend.mockResolvedValueOnce(false);

    await expect(
      service.sendMessage(1, {
        receiverId: 2,
        messageType: MessageType.TEXT,
        content: '还能收到吗',
      } as any),
    ).rejects.toThrow('只能给好友发送消息');

    expect(friendChatBlocksService.assertUsersCanChat).not.toHaveBeenCalled();
    expect(messageRepository.save).not.toHaveBeenCalled();
  });

  it('should revoke the sender message within two minutes and redact client content', async () => {
    jest.useFakeTimers().setSystemTime(new Date('2026-08-12T10:02:00.000Z'));
    try {
      const { service, messageRepository } = createService();
      messageRepository.findOne.mockResolvedValue({
        messageId: 'message-1',
        conversationId: '1_2',
        senderId: 1,
        receiverId: 2,
        messageType: MessageType.IMAGE,
        content: JSON.stringify({ url: 'https://example.com/original.png' }),
        cloudFileUrl: 'https://example.com/original.png',
        isRead: 0,
        isRevoked: 0,
        revokedAt: null,
        createdAt: new Date('2026-08-12T10:00:01.000Z'),
      });

      const result = await service.revokeMessage('message-1', 1);

      expect(messageRepository.save).toHaveBeenCalledWith(
        expect.objectContaining({ isRevoked: 1, isRead: 1 }),
      );
      expect(result).toEqual(
        expect.objectContaining({
          messageType: MessageType.TEXT,
          content: '消息已撤回',
          cloudFileUrl: null,
          isRevoked: 1,
        }),
      );
    } finally {
      jest.useRealTimers();
    }
  });

  it('should reject recall from anyone except the sender', async () => {
    const { service, messageRepository } = createService();
    messageRepository.findOne.mockResolvedValue({
      messageId: 'message-1',
      senderId: 1,
      createdAt: new Date(),
      isRevoked: 0,
    });

    await expect(service.revokeMessage('message-1', 2)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(messageRepository.save).not.toHaveBeenCalled();
  });
});
