import { NotFoundException } from '@nestjs/common';
import { ChatController } from './chat.controller';

jest.mock('uuid', () => ({
  v4: jest.fn(() => 'mocked-id'),
}));

describe('ChatController debug room state', () => {
  const originalNodeEnv = process.env.NODE_ENV;

  const createController = () =>
    new ChatController(
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {
        debugRoomState: jest.fn().mockResolvedValue({ room: '1_2' }),
      } as any,
      {} as any,
      {} as any,
    );

  afterEach(() => {
    process.env.NODE_ENV = originalNodeEnv;
    jest.clearAllMocks();
  });

  it('should keep debug room state restricted to super admin role', () => {
    const controller = createController();
    const roles = Reflect.getMetadata('roles', controller.debugRoomState);

    expect(roles).toEqual(['SUPER_ADMIN']);
  });

  it('should hide debug room state in production environment', async () => {
    process.env.NODE_ENV = 'production';
    const controller = createController();

    await expect(
      controller.debugRoomState('1_2'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});

describe('ChatController message access', () => {
  const chatService = {
    assertConversationParticipant: jest.fn(),
    getMessagesByConversation: jest.fn().mockResolvedValue({ data: [] }),
  };
  const controller = new ChatController(
    chatService as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
  );

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should verify user and doctor participation before returning messages', async () => {
    await controller.getMessages(
      { id: 7, type: 'doctor' } as any,
      'session-1',
      '1',
      '50',
    );

    expect(chatService.assertConversationParticipant).toHaveBeenCalledWith(
      'session-1',
      7,
      'doctor',
    );
  });

  it('should preserve administrator access to chat records', async () => {
    await controller.getMessages(
      { id: 1, role: 'SUPER_ADMIN', type: 'user' } as any,
      'session-1',
      '1',
      '50',
    );

    expect(chatService.assertConversationParticipant).not.toHaveBeenCalled();
    expect(chatService.getMessagesByConversation).toHaveBeenCalledWith(
      'session-1',
      1,
      50,
      undefined,
      false,
    );
  });
});
