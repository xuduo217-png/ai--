import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from "@nestjs/common";
import { ChatService } from "./chat.service";
import { DoctorPatientRecordService } from "./doctor-patient-record.service";

describe("ChatService error contract", () => {
  const createService = () => {
    const chatSessionService = {
      getSessionByConversationId: jest.fn().mockResolvedValue(null),
      getPersistedSessionByConversationId: jest.fn().mockResolvedValue(null),
      getOrCreateSession: jest.fn(),
      getPreviousSession: jest.fn(),
      getSession: jest.fn(),
      updateSession: jest.fn(),
    };

    return new ChatService(
      {
        create: jest.fn((data) => data),
        save: jest.fn(),
      } as any,
      {} as any,
      chatSessionService as any,
      {} as any,
      {
        getServiceItems: jest.fn().mockResolvedValue([]),
      } as any,
      {
        hget: jest.fn(),
        lrange: jest.fn(),
      } as any,
      {
        process: jest.fn(),
      } as any,
    );
  };

  it("should throw BadRequestException for invalid conversationId", async () => {
    const service = createService();

    await expect(
      service.getMessagesByConversation("invalid-conversation-id"),
    ).rejects.toBeInstanceOf(BadRequestException);
    await expect(
      service.getMessagesByConversation("invalid-conversation-id"),
    ).rejects.toThrow("无效的 conversationId");
  });

  it("should throw BadRequestException for invalid beforeConversationId", async () => {
    const service = createService();

    await expect(
      service.getPreviousSession(
        1,
        "user",
        2,
        "invalid-before-conversation-id",
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    await expect(
      service.getPreviousSession(
        1,
        "user",
        2,
        "invalid-before-conversation-id",
      ),
    ).rejects.toThrow("无效的 beforeConversationId");
  });
});

describe("DoctorPatientRecordService access contract", () => {
  const createService = () => {
    const repositories = {
      sessions: { findOne: jest.fn() },
      users: { findOne: jest.fn() },
      pets: { find: jest.fn(), findOne: jest.fn() },
      reports: { findAndCount: jest.fn(), findOne: jest.fn() },
      appointments: { findAndCount: jest.fn(), findOne: jest.fn() },
      messages: { findAndCount: jest.fn(), createQueryBuilder: jest.fn() },
    };
    const service = new DoctorPatientRecordService(
      repositories.sessions as any,
      repositories.users as any,
      repositories.pets as any,
      repositories.reports as any,
      repositories.appointments as any,
      repositories.messages as any,
    );
    return { service, repositories };
  };

  it("rejects a doctor who does not own the consultation session", async () => {
    const { service, repositories } = createService();
    repositories.sessions.findOne.mockResolvedValue({
      conversationId: "conversation-1",
      userId: 12,
      doctorId: 7,
    });

    await expect(
      service.getPatient("conversation-1", 8),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(repositories.users.findOne).not.toHaveBeenCalled();
  });

  it("rejects a pet that does not belong to the consultation user", async () => {
    const { service, repositories } = createService();
    repositories.sessions.findOne.mockResolvedValue({
      conversationId: "conversation-1",
      userId: 12,
      doctorId: 7,
    });
    repositories.pets.findOne.mockResolvedValue(null);

    await expect(
      service.getAppointments("conversation-1", 7, 99, 1, 20),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(repositories.appointments.findAndCount).not.toHaveBeenCalled();
  });

  it("rejects history that belongs to another patient", async () => {
    const { service, repositories } = createService();
    repositories.sessions.findOne
      .mockResolvedValueOnce({
        id: 10,
        conversationId: "current-session",
        userId: 12,
        doctorId: 7,
      })
      .mockResolvedValueOnce({
        id: 9,
        conversationId: "history-session",
        userId: 13,
        doctorId: 7,
        status: "EXPIRED",
      });

    await expect(
      service.getHistoryMessages(
        "current-session",
        "history-session",
        7,
        1,
        50,
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(repositories.messages.findAndCount).not.toHaveBeenCalled();
  });

  it("returns history messages oldest first and hides revoked content", async () => {
    const { service, repositories } = createService();
    repositories.sessions.findOne
      .mockResolvedValueOnce({
        id: 10,
        conversationId: "current-session",
        userId: 12,
        doctorId: 7,
      })
      .mockResolvedValueOnce({
        id: 9,
        conversationId: "history-session",
        userId: 12,
        doctorId: 7,
        status: "EXPIRED",
      });
    repositories.messages.findAndCount.mockResolvedValue([
      [
        {
          id: 2,
          conversationId: "history-session",
          senderId: 7,
          senderType: "doctor",
          receiverId: 12,
          receiverType: "user",
          content: "不应暴露的内容",
          type: "TEXT",
          isAutoReply: false,
          isRead: true,
          isRevoked: true,
          createdAt: new Date("2026-07-10T09:02:00.000Z"),
        },
        {
          id: 1,
          conversationId: "history-session",
          senderId: 12,
          senderType: "user",
          receiverId: 7,
          receiverType: "doctor",
          content: "宠物昨晚开始呕吐",
          type: "TEXT",
          isAutoReply: false,
          isRead: true,
          isRevoked: false,
          createdAt: new Date("2026-07-10T09:00:00.000Z"),
        },
      ],
      2,
    ]);

    const result = await service.getHistoryMessages(
      "current-session",
      "history-session",
      7,
      1,
      50,
    );

    expect(result.data.map((message) => message.id)).toEqual([1, 2]);
    expect(result.data[1].content).toBe("消息已撤回");
    expect(result.data[1].type).toBe("TEXT");
    expect(result.data[1].packages).toEqual([]);
  });
});
