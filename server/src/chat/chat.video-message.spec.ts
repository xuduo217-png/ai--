import { ChatService } from './chat.service'
import { MessageType } from './entities/message.entity'

describe('ChatService video message handling', () => {
  it('keeps structured video payload untouched', async () => {
    const messageRepository = {
      create: jest.fn((value) => value),
      save: jest.fn(async (value) => value),
    }
    const sensitiveWordService = {
      process: jest.fn(),
    }
    const chatSessionService = {
      getPersistedSessionByConversationId: jest.fn().mockResolvedValue({
        userId: 1,
        doctorId: 2,
        conversationId: '1_2',
      }),
      updateSession: jest.fn(async (session) => session),
    }

    const service = new ChatService(
      messageRepository as any,
      {} as any,
      chatSessionService as any,
      {} as any,
      {} as any,
      {} as any,
      sensitiveWordService as any,
    )

    const content = JSON.stringify({
      url: '/uploads/chat/demo.mp4',
      fileName: 'demo.mp4',
      duration: 12,
    })

    const result = await service.saveMessage({
      conversationId: '1_2',
      senderId: 1,
      senderType: 'user',
      receiverId: 2,
      receiverType: 'doctor',
      content,
      type: MessageType.VIDEO,
    })

    expect(result.content).toBe(content)
    expect(sensitiveWordService.process).not.toHaveBeenCalled()
  })
})
