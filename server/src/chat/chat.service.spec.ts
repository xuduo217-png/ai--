import { BadRequestException, ForbiddenException } from "@nestjs/common";
import { ChatService } from "./chat.service";
import { MessageType } from "./entities/message.entity";
import { SessionStatus } from "./entities/chat-session.entity";
import { OrderStatus } from "./entities/chat-order.entity";

describe("ChatService", () => {
  let service: ChatService;

  const mockMessageRepository = {
    create: jest.fn((data) => data),
    save: jest.fn(),
    findOne: jest.fn(),
    count: jest.fn(),
    update: jest.fn(),
    createQueryBuilder: jest.fn(),
  };

  const mockOrderRepository = {
    findOne: jest.fn(),
    findAndCount: jest.fn(),
  };

  const mockChatSessionService = {
    getSession: jest.fn(),
    getOrCreateSession: jest.fn(),
    getSessionByConversationId: jest.fn(),
    getPersistedSessionByConversationId: jest.fn(),
    getPreviousSession: jest.fn(),
    updateSession: jest.fn(),
    persistTempSession: jest.fn(),
    markTempSessionPaymentRequired: jest.fn(),
    getUserRuntimeSessions: jest.fn(),
    getSessions: jest.fn(),
  };

  const mockAutoReplyService = {
    getReplyByIndex: jest.fn(),
    getActiveReplies: jest.fn(),
  };

  const mockDoctorsService = {
    getServiceItems: jest.fn(),
    findOne: jest.fn(),
  };

  const mockRedisService = {
    get: jest.fn(),
    set: jest.fn(),
    expire: jest.fn(),
    hget: jest.fn(),
    hset: jest.fn(),
    hgetall: jest.fn(),
    hdel: jest.fn(),
    lpush: jest.fn(),
    lrange: jest.fn(),
    lset: jest.fn(),
    llen: jest.fn(),
    scan: jest.fn(),
  };

  const mockSensitiveWordService = {
    process: jest.fn().mockResolvedValue({ action: "REVIEW", words: [] }),
  };

  beforeEach(() => {
    jest.clearAllMocks();

    service = new ChatService(
      mockMessageRepository as any,
      mockOrderRepository as any,
      mockChatSessionService as any,
      mockAutoReplyService as any,
      mockDoctorsService as any,
      mockRedisService as any,
      mockSensitiveWordService as any,
    );

    mockDoctorsService.getServiceItems.mockResolvedValue([]);
    mockDoctorsService.findOne.mockImplementation(async (id: number) => ({
      id,
      name: `医生${id}`,
      avatar: `/doctor-${id}.png`,
    }));
    mockRedisService.get.mockResolvedValue(null);
    mockRedisService.set.mockResolvedValue("OK");
    mockRedisService.expire.mockResolvedValue(1);
    mockRedisService.lpush.mockResolvedValue(1);
    mockRedisService.hgetall.mockResolvedValue({});
    mockRedisService.hdel.mockResolvedValue(0);
    mockRedisService.scan.mockResolvedValue(["0", []]);
    mockMessageRepository.save.mockResolvedValue({});
    mockChatSessionService.updateSession.mockImplementation(
      async (session) => session,
    );
    mockChatSessionService.persistTempSession.mockResolvedValue(undefined);
    mockChatSessionService.markTempSessionPaymentRequired.mockResolvedValue(
      undefined,
    );
    mockChatSessionService.getUserRuntimeSessions.mockResolvedValue([]);
  });

  it("should use conversationId-based init key for new FREE session", async () => {
    mockChatSessionService.getOrCreateSession.mockResolvedValue({
      id: 1,
      conversationId: "session-uuid-1",
      status: SessionStatus.FREE,
      autoReplyCount: 0,
      maxFreeReplies: 3,
      paymentRequired: false,
      serviceStartAt: null,
      serviceEndAt: null,
      order: null,
    });
    mockAutoReplyService.getActiveReplies.mockResolvedValue([
      { id: 1 },
      { id: 2 },
      { id: 3 },
      { id: 4 },
    ]);

    const sendInitialAutoReplySpy = jest
      .spyOn(service, "sendInitialAutoReply")
      .mockResolvedValue(undefined);

    const result = (await service.getOrCreateSession(1, 2)) as {
      maxFreeReplies: number;
      paymentRequired: boolean;
    };

    expect(mockRedisService.get).toHaveBeenCalledWith(
      "chat:init:session-uuid-1",
    );
    expect(mockRedisService.set).toHaveBeenCalledWith(
      "chat:init:session-uuid-1",
      "1",
    );
    expect(sendInitialAutoReplySpy).toHaveBeenCalledWith(
      "session-uuid-1",
      1,
      2,
    );
    expect(result.maxFreeReplies).toBe(4);
    expect(result.paymentRequired).toBe(false);
  });

  it("should allow the fourth configured auto reply after three replies", async () => {
    mockChatSessionService.getSessionByConversationId.mockResolvedValue({
      userId: 1,
      doctorId: 10,
      conversationId: "free-session",
      status: SessionStatus.FREE,
      autoReplyCount: 3,
      maxFreeReplies: 3,
      paymentRequired: false,
      isTemporary: true,
    });
    mockAutoReplyService.getActiveReplies.mockResolvedValue([
      { id: 1 },
      { id: 2 },
      { id: 3 },
      { id: 4 },
    ]);

    const result = await service.canSendMessage(
      1,
      10,
      "user",
      "doctor",
      "free-session",
    );

    expect(result).toMatchObject({
      canSend: true,
      session: {
        paymentRequired: false,
      },
    });
  });

  it("should allow one user message after all configured auto replies are used", async () => {
    mockChatSessionService.getSessionByConversationId.mockResolvedValue({
      userId: 1,
      doctorId: 10,
      conversationId: "free-session",
      status: SessionStatus.FREE,
      autoReplyCount: 4,
      maxFreeReplies: 3,
      paymentRequired: false,
      isTemporary: true,
    });
    mockAutoReplyService.getActiveReplies.mockResolvedValue([
      { id: 1 },
      { id: 2 },
      { id: 3 },
      { id: 4 },
    ]);

    const result = await service.canSendMessage(
      1,
      10,
      "user",
      "doctor",
      "free-session",
    );

    expect(result).toMatchObject({
      canSend: true,
      session: {
        paymentRequired: false,
      },
    });
  });

  it("should require payment after the payment prompt has been sent", async () => {
    mockChatSessionService.getSessionByConversationId.mockResolvedValue({
      userId: 1,
      doctorId: 10,
      conversationId: "free-session",
      status: SessionStatus.FREE,
      autoReplyCount: 4,
      maxFreeReplies: 3,
      paymentRequired: true,
      isTemporary: true,
    });
    mockAutoReplyService.getActiveReplies.mockResolvedValue([
      { id: 1 },
      { id: 2 },
      { id: 3 },
      { id: 4 },
    ]);

    const result = await service.canSendMessage(
      1,
      10,
      "user",
      "doctor",
      "free-session",
    );

    expect(result).toMatchObject({
      canSend: false,
      reason: "FREE_LIMIT_EXCEEDED",
      session: {
        paymentRequired: true,
      },
    });
  });

  it("should prompt after a user message when all dynamic auto replies are used", async () => {
    mockChatSessionService.getSessionByConversationId.mockResolvedValue({
      userId: 1,
      doctorId: 10,
      conversationId: "free-session",
      status: SessionStatus.FREE,
      autoReplyCount: 4,
      paymentRequired: false,
      isTemporary: true,
    });
    mockAutoReplyService.getActiveReplies.mockResolvedValue([
      { id: 1 },
      { id: 2 },
      { id: 3 },
      { id: 4 },
    ]);

    const result =
      await service.shouldSendPaymentPromptAfterMessage("free-session");

    expect(result).toBe(true);
  });

  it("should send message with persisted conversationId in PAID session", async () => {
    const paidSession = {
      id: 1,
      userId: 1,
      doctorId: 10,
      conversationId: "session-uuid-1",
      status: SessionStatus.PAID,
      orderId: 123,
      autoReplyCount: 0,
      maxFreeReplies: 3,
      serviceEndAt: new Date("2036-05-01T00:00:00.000Z"),
      isTemporary: false,
    };
    mockChatSessionService.getSessionByConversationId.mockResolvedValue({
      ...paidSession,
    });
    mockChatSessionService.getPersistedSessionByConversationId.mockResolvedValue(
      paidSession,
    );

    const createdAt = new Date("2026-07-28T10:00:00.000Z");
    mockMessageRepository.save.mockResolvedValue({ createdAt });

    await service.sendMessage(
      "session-uuid-1",
      1,
      "user",
      10,
      "doctor",
      "你好医生",
      MessageType.TEXT,
    );

    expect(mockMessageRepository.save).toHaveBeenCalled();
    expect(mockChatSessionService.updateSession).toHaveBeenCalledWith(
      expect.objectContaining({ lastMessageAt: createdAt }),
    );
  });

  it("should enrich doctor sessions with latest message and unread count", async () => {
    mockChatSessionService.getSessions.mockResolvedValue({
      data: [
        {
          id: 1,
          conversationId: "doctor-session",
          doctorId: 7,
          userId: 12,
          updatedAt: new Date("2026-07-28T08:00:00.000Z"),
        },
      ],
      total: 1,
      page: 1,
      limit: 20,
      totalPages: 1,
    });
    const latestSubQuery = _queryBuilder({
      getQuery: () => "latest-message-sub-query",
      getParameters: () => ({ isDeleted: false }),
    });
    const latestMessageQuery = _queryBuilder({
      getMany: async () => [
        {
          id: 101,
          conversationId: "doctor-session",
          senderId: 12,
          receiverId: 7,
          content: "宠物刚刚吐了",
          type: MessageType.TEXT,
          createdAt: new Date("2026-07-28T10:00:00.000Z"),
        },
      ],
    });
    const unreadQuery = _queryBuilder({
      getRawMany: async () => [
        { conversationId: "doctor-session", unreadCount: "3" },
      ],
    });
    mockMessageRepository.createQueryBuilder
      .mockReturnValueOnce(latestSubQuery)
      .mockReturnValueOnce(latestMessageQuery)
      .mockReturnValueOnce(unreadQuery);

    const result = await service.getDoctorSessions({ doctorId: 7 });

    expect(result.data[0]).toEqual(
      expect.objectContaining({
        conversationId: "doctor-session",
        unreadCount: 3,
        lastMessage: expect.objectContaining({ content: "宠物刚刚吐了" }),
      }),
    );
    expect(unreadQuery.andWhere).toHaveBeenCalledWith(
      "message.receiverType = :receiverType",
      { receiverType: "doctor" },
    );
  });

  it("should combine typed persisted and FREE-session unread messages", async () => {
    mockChatSessionService.getUserRuntimeSessions.mockResolvedValue([
      {
        conversationId: "paid-session",
        isTemporary: false,
      },
      {
        conversationId: "free-session",
        isTemporary: true,
      },
    ]);
    mockMessageRepository.count.mockResolvedValue(2);
    mockRedisService.get.mockResolvedValue("1");
    mockRedisService.hgetall.mockResolvedValue({
      "free-session:101": "free-session",
      "free-session:102": "free-session",
      "paid-session:103": "paid-session",
    });

    await expect(service.getUnreadCount(1, "user")).resolves.toBe(4);

    expect(mockMessageRepository.count).toHaveBeenCalledWith({
      where: {
        conversationId: expect.anything(),
        receiverId: 1,
        receiverType: "user",
        isRead: false,
        isDeleted: false,
      },
    });
    expect(mockRedisService.hgetall).toHaveBeenCalledWith("chat:unread:user:1");
  });

  it("should exclude unread entries whose conversation is no longer visible", async () => {
    mockChatSessionService.getUserRuntimeSessions.mockResolvedValue([
      {
        conversationId: "visible-free-session",
        isTemporary: true,
      },
    ]);
    mockRedisService.hgetall.mockResolvedValue({
      "visible-free-session:101": "visible-free-session",
      "orphan-session:102": "orphan-session",
    });

    await expect(service.getUnreadCount(1, "user")).resolves.toBe(1);
    expect(mockMessageRepository.count).not.toHaveBeenCalled();
  });

  it("should mark only the authenticated participant conversation as read", async () => {
    mockChatSessionService.getSessionByConversationId.mockResolvedValue({
      userId: 1,
      doctorId: 10,
      conversationId: "session-uuid-1",
    });
    mockRedisService.get.mockResolvedValue("1");
    mockRedisService.hgetall.mockResolvedValue({
      "session-uuid-1:101": "session-uuid-1",
      "session-uuid-2:102": "session-uuid-2",
    });

    await service.markConversationAsRead("session-uuid-1", 1, "user");

    expect(mockMessageRepository.update).toHaveBeenCalledWith(
      expect.objectContaining({
        conversationId: "session-uuid-1",
        receiverId: 1,
        receiverType: "user",
      }),
      expect.objectContaining({ isRead: true }),
    );
    expect(mockRedisService.hdel).toHaveBeenCalledWith(
      "chat:unread:user:1",
      "session-uuid-1:101",
    );

    await expect(
      service.markConversationAsRead("session-uuid-1", 1, "doctor"),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it("should merge paid and FREE sessions into a sorted conversation list", async () => {
    mockChatSessionService.getUserRuntimeSessions.mockResolvedValue([
      {
        id: 1,
        userId: 1,
        doctorId: 10,
        conversationId: "paid-session",
        status: SessionStatus.PAID,
        orderId: 88,
        isTemporary: false,
        createdAt: new Date("2026-04-01T00:00:00.000Z"),
        updatedAt: new Date("2026-04-01T00:00:00.000Z"),
      },
      {
        userId: 1,
        doctorId: 11,
        conversationId: "free-session",
        status: SessionStatus.FREE,
        paymentRequired: false,
        isTemporary: true,
        createdAt: new Date("2026-04-02T00:00:00.000Z"),
        updatedAt: new Date("2026-04-02T00:00:00.000Z"),
      },
    ]);

    const latestSubQuery = _queryBuilder({
      getQuery: () => "latest-message-sub-query",
      getParameters: () => ({ isDeleted: false }),
    });
    const latestMessageQuery = _queryBuilder({
      getMany: async () => [
        {
          id: 101,
          conversationId: "paid-session",
          senderId: 10,
          receiverId: 1,
          content: "付费咨询回复",
          type: MessageType.TEXT,
          createdAt: new Date("2026-04-02T10:00:00.000Z"),
        },
      ],
    });
    const unreadQuery = _queryBuilder({
      getRawMany: async () => [
        { conversationId: "paid-session", unreadCount: "2" },
      ],
    });
    mockMessageRepository.createQueryBuilder
      .mockReturnValueOnce(latestSubQuery)
      .mockReturnValueOnce(latestMessageQuery)
      .mockReturnValueOnce(unreadQuery);
    mockRedisService.get.mockResolvedValue("1");
    mockRedisService.hgetall.mockResolvedValue({
      "free-session:201": "free-session",
    });
    mockRedisService.lrange.mockImplementation(async (key: string) =>
      key === "chat:temp:free-session"
        ? [
            JSON.stringify({
              id: 201,
              conversationId: "free-session",
              senderId: 11,
              receiverId: 1,
              content: "免费咨询回复",
              type: MessageType.TEXT,
              createdAt: "2026-04-03T10:00:00.000Z",
            }),
          ]
        : [],
    );

    const result = await service.getConversationList(1, 1, 20);

    expect(result.data.map((item) => item.conversationId)).toEqual([
      "free-session",
      "paid-session",
    ]);
    expect(result.data[0]).toEqual(
      expect.objectContaining({
        doctorName: "医生11",
        unreadCount: 1,
        isTemporary: true,
      }),
    );
    expect(result.data[1]).toEqual(
      expect.objectContaining({
        orderId: 88,
        unreadCount: 2,
      }),
    );
    expect(result.total).toBe(2);
  });

  it("should reject invalid conversationId when loading message history", async () => {
    mockChatSessionService.getSessionByConversationId.mockResolvedValue(null);

    await expect(
      service.getMessagesByConversation("invalid-session-id"),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it("should return Redis-only FREE session history", async () => {
    const conversationId = "session-uuid-1";

    mockChatSessionService.getSessionByConversationId.mockResolvedValue({
      id: 1,
      userId: 1,
      doctorId: 10,
      conversationId,
      status: SessionStatus.FREE,
      isTemporary: true,
    });
    mockRedisService.lrange.mockResolvedValue([
      JSON.stringify({
        id: 101,
        conversationId,
        senderId: 1,
        receiverId: 10,
        content: "医生你好",
        type: MessageType.TEXT,
        createdAt: "2026-04-22T05:00:00.000Z",
      }),
      JSON.stringify({
        id: 201,
        conversationId,
        senderId: null,
        receiverId: 1,
        content: "免费咨询次数已用完，请选择套餐继续咨询",
        type: MessageType.PAYMENT_PROMPT,
        createdAt: "2026-04-22T05:00:01.000Z",
      }),
    ]);

    const result = await service.getMessagesByConversation(conversationId);

    expect(result.data).toHaveLength(2);
    expect(result.data.map((message) => message.type)).toEqual([
      MessageType.TEXT,
      MessageType.PAYMENT_PROMPT,
    ]);
  });

  it("should sync Redis-only FREE session messages", async () => {
    const conversationId = "session-uuid-1";
    const since = new Date("2026-04-22T05:00:00.500Z");

    mockChatSessionService.getSessionByConversationId.mockResolvedValue({
      id: 1,
      userId: 1,
      doctorId: 10,
      conversationId,
      status: SessionStatus.FREE,
      isTemporary: true,
    });
    mockRedisService.lrange.mockResolvedValue([
      JSON.stringify({
        id: 102,
        conversationId,
        senderId: 1,
        receiverId: 10,
        content: "第一条免费消息",
        type: MessageType.TEXT,
        createdAt: "2026-04-22T05:00:00.000Z",
      }),
      JSON.stringify({
        id: 103,
        conversationId,
        senderId: 10,
        receiverId: 1,
        content: "后续自动回复",
        type: MessageType.TEXT,
        createdAt: "2026-04-22T05:00:03.000Z",
      }),
    ]);
    const result = await service.syncMessages(conversationId, since, 50);

    expect(result.total).toBe(1);
    expect(result.data.map((message) => message.type)).toEqual([
      MessageType.TEXT,
    ]);
    expect(result.lastTimestamp).toBe("2026-04-22T05:00:03.000Z");
  });

  it("should avoid relation joins when syncing paid session messages", async () => {
    const where = jest.fn().mockReturnThis();
    const andWhere = jest.fn().mockReturnThis();
    const orderBy = jest.fn().mockReturnThis();
    const addOrderBy = jest.fn().mockReturnThis();
    const take = jest.fn().mockReturnThis();
    const getMany = jest.fn().mockResolvedValue([]);

    mockChatSessionService.getSessionByConversationId.mockResolvedValue({
      id: 1,
      userId: 1,
      doctorId: 10,
      conversationId: "paid-session-1",
      status: SessionStatus.PAID,
      isTemporary: false,
    });
    mockMessageRepository.createQueryBuilder.mockReturnValue({
      where,
      andWhere,
      orderBy,
      addOrderBy,
      take,
      getMany,
    } as any);

    await service.syncMessages("paid-session-1", undefined, 50);

    expect(mockMessageRepository.createQueryBuilder).toHaveBeenCalledWith(
      "message",
    );
    expect(addOrderBy).toHaveBeenCalledWith("message.id", "ASC");
  });

  it("should return sync upper bound when paid session has no new messages", async () => {
    jest.useFakeTimers().setSystemTime(new Date("2026-04-22T05:00:10.000Z"));

    try {
      const where = jest.fn().mockReturnThis();
      const andWhere = jest.fn().mockReturnThis();
      const orderBy = jest.fn().mockReturnThis();
      const addOrderBy = jest.fn().mockReturnThis();
      const take = jest.fn().mockReturnThis();
      const getMany = jest.fn().mockResolvedValue([]);

      mockChatSessionService.getSessionByConversationId.mockResolvedValue({
        id: 1,
        userId: 1,
        doctorId: 10,
        conversationId: "paid-session-1",
        status: SessionStatus.PAID,
        isTemporary: false,
      });
      mockMessageRepository.createQueryBuilder.mockReturnValue({
        where,
        andWhere,
        orderBy,
        addOrderBy,
        take,
        getMany,
      } as any);

      const result = await service.syncMessages(
        "paid-session-1",
        undefined,
        50,
      );

      expect(result.lastTimestamp).toBe("2026-04-22T05:00:10.000Z");
    } finally {
      jest.useRealTimers();
    }
  });

  it("should push payment prompt into Redis temp messages", async () => {
    mockChatSessionService.getSession.mockResolvedValue({
      userId: 1,
      doctorId: 10,
      conversationId: "session-uuid-1",
      status: SessionStatus.FREE,
      isTemporary: true,
    });

    const message = await service.sendPaymentPromptMessage(1, 10, [
      { id: 1, name: "三天图文咨询", duration: 4320, price: 29.9 },
    ]);

    expect(message.type).toBe(MessageType.PAYMENT_PROMPT);
    expect(
      mockChatSessionService.markTempSessionPaymentRequired,
    ).toHaveBeenCalledWith("session-uuid-1");
    expect(mockRedisService.lpush).toHaveBeenCalled();
  });

  it("should reject non-participant previous-session access", async () => {
    mockChatSessionService.getPersistedSessionByConversationId.mockResolvedValue(
      {
        id: 1,
        userId: 1,
        doctorId: 10,
        conversationId: "session-uuid-1",
        status: SessionStatus.PAID,
      },
    );

    await expect(
      service.getPreviousSession(999, "user", 10, "session-uuid-1"),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it("should not treat a doctor id collision as user participation", async () => {
    mockChatSessionService.getSessionByConversationId.mockResolvedValue({
      id: 1,
      userId: 7,
      doctorId: 10,
      conversationId: "session-uuid-1",
      status: SessionStatus.PAID,
    });

    await expect(
      service.assertConversationParticipant("session-uuid-1", 7, "doctor"),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it("should revoke and redact a recent paid doctor-chat message", async () => {
    jest.useFakeTimers().setSystemTime(new Date("2026-08-12T10:02:00.000Z"));
    try {
      mockChatSessionService.getSessionByConversationId.mockResolvedValue({
        id: 1,
        userId: 1,
        doctorId: 10,
        conversationId: "paid-session-1",
        status: SessionStatus.PAID,
        isTemporary: false,
      });
      mockMessageRepository.findOne.mockResolvedValue({
        id: 91,
        conversationId: "paid-session-1",
        senderId: 1,
        senderType: "user",
        receiverId: 10,
        receiverType: "doctor",
        type: MessageType.IMAGE,
        content: "https://example.com/original.png",
        packages: [],
        isAutoReply: false,
        isRead: false,
        isRevoked: false,
        createdAt: new Date("2026-08-12T10:00:01.000Z"),
      });
      mockMessageRepository.save.mockImplementation(async (value) => value);

      const result = await service.revokeMessage(
        "paid-session-1",
        91,
        1,
        "user",
      );

      expect(mockMessageRepository.save).toHaveBeenCalledWith(
        expect.objectContaining({
          content: "https://example.com/original.png",
          isRevoked: true,
          isRead: true,
        }),
      );
      expect(result).toEqual(
        expect.objectContaining({
          type: MessageType.TEXT,
          content: "消息已撤回",
          isRevoked: true,
        }),
      );
    } finally {
      jest.useRealTimers();
    }
  });

  it("should replace a recent free-session Redis message in place", async () => {
    jest.useFakeTimers().setSystemTime(new Date("2026-08-12T10:02:00.000Z"));
    try {
      mockChatSessionService.getSessionByConversationId.mockResolvedValue({
        userId: 1,
        doctorId: 10,
        conversationId: "free-session-1",
        status: SessionStatus.FREE,
        isTemporary: true,
      });
      mockRedisService.lrange.mockResolvedValue([
        JSON.stringify({
          id: 92,
          conversationId: "free-session-1",
          senderId: 1,
          senderType: "user",
          receiverId: 10,
          receiverType: "doctor",
          type: MessageType.TEXT,
          content: "原始内容",
          isAutoReply: false,
          isRead: false,
          isRevoked: false,
          createdAt: "2026-08-12T10:00:01.000Z",
        }),
      ]);

      const result = await service.revokeMessage(
        "free-session-1",
        92,
        1,
        "user",
      );

      expect(mockRedisService.lset).toHaveBeenCalledWith(
        "chat:temp:free-session-1",
        0,
        expect.stringContaining('"isRevoked":true'),
      );
      expect(mockRedisService.hdel).toHaveBeenCalledWith(
        "chat:unread:doctor:10",
        "free-session-1:92",
      );
      expect(result).toEqual(
        expect.objectContaining({
          content: "消息已撤回",
          isRevoked: true,
        }),
      );
    } finally {
      jest.useRealTimers();
    }
  });

  it("should scope history consultations to the user, paid orders, and doctor", async () => {
    mockOrderRepository.findAndCount.mockResolvedValue([
      [
        {
          id: 71,
          orderNo: "CHAT-71",
          userId: 1,
          doctorId: 10,
          durationMinutes: 1440,
          amount: 39,
          status: OrderStatus.PAID,
          paidAt: new Date("2026-08-01T10:00:00.000Z"),
          serviceStartAt: new Date("2026-08-01T10:00:00.000Z"),
          serviceEndAt: new Date("2026-08-02T10:00:00.000Z"),
          doctor: { id: 10, name: "林医生", avatar: "/doctor.png" },
        },
      ],
      1,
    ]);

    const result = await service.getHistoryConsultations(1, 1, 3, 10);

    expect(mockOrderRepository.findAndCount).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { userId: 1, doctorId: 10, status: OrderStatus.PAID },
      }),
    );
    expect(result.data).toHaveLength(1);
    expect(result.data[0]).toEqual(
      expect.objectContaining({ id: 71, doctorId: 10 }),
    );
  });
});

function _queryBuilder(overrides: Record<string, unknown> = {}) {
  const builder: Record<string, jest.Mock | unknown> = {};
  for (const method of [
    "select",
    "addSelect",
    "where",
    "andWhere",
    "groupBy",
    "innerJoin",
    "setParameters",
  ]) {
    builder[method] = jest.fn(() => builder);
  }
  builder.getQuery = jest.fn(() => "query");
  builder.getParameters = jest.fn(() => ({}));
  builder.getMany = jest.fn(async () => []);
  builder.getRawMany = jest.fn(async () => []);
  return Object.assign(builder, overrides);
}
