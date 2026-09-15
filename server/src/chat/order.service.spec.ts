import { OrderService } from './order.service';
import { ChatSession, SessionStatus } from './entities/chat-session.entity';
import { ChatOrder, OrderStatus } from './entities/chat-order.entity';
import { MessageType } from './entities/message.entity';
import {
  BusinessType,
  Payment,
  PaymentChannel,
  PaymentStatus,
} from '../payment/entities/payment.entity';
import { User } from '../users/entities/user.entity';

describe('OrderService', () => {
  let service: OrderService;

  const mockOrderRepository = {
    create: jest.fn((data) => data),
    save: jest.fn(),
    findOne: jest.fn(),
    findAndCount: jest.fn(),
  };

  const mockMessageRepository = {
    create: jest.fn((data) => ({
      id: 501,
      createdAt: new Date('2026-04-02T10:05:00.000Z'),
      ...data,
    })),
    save: jest.fn(),
    update: jest.fn(),
  };

  const mockChatSessionService = {
    getActiveSession: jest.fn(),
    getTempSession: jest.fn(),
    getOrCreatePersistedSessionForOrder: jest.fn(),
    deleteTempSession: jest.fn(),
  };

  const mockDoctorsService = {
    findServiceItemById: jest.fn(),
    incrementConsultation: jest.fn(),
  };

  const mockRedisService = {
    get: jest.fn(),
    lrange: jest.fn(),
    del: jest.fn(),
    hset: jest.fn(),
    hdel: jest.fn(),
    expire: jest.fn(),
  };

  const mockChatGateway = {
    notifyPaymentSuccess: jest.fn(),
  };

  const mockPaymentService = {
    createPayment: jest.fn(),
    payBusinessWithBalance: jest.fn(),
  };

  const mockDataSource = {
    transaction: jest.fn(async (callback) =>
      callback({
        createQueryBuilder: jest.fn(() => ({
          where: jest.fn().mockReturnThis(),
          setLock: jest.fn().mockReturnThis(),
          getOne: jest.fn().mockResolvedValue({ id: 1 }),
        })),
        findOne: jest.fn((_entity, options) =>
          mockOrderRepository.findOne(options),
        ),
        create: jest.fn((_entity, data) => mockOrderRepository.create(data)),
        save: jest.fn((_entity, data) => mockOrderRepository.save(data)),
      }),
    ),
  };

  beforeEach(() => {
    jest.clearAllMocks();

    service = new OrderService(
      mockOrderRepository as any,
      mockMessageRepository as any,
      mockChatSessionService as any,
      mockDoctorsService as any,
      mockRedisService as any,
      mockChatGateway as any,
      mockPaymentService as any,
      mockDataSource as any,
    );

    mockMessageRepository.save.mockResolvedValue([]);
    mockMessageRepository.update.mockResolvedValue({ affected: 0 });
    mockRedisService.del.mockResolvedValue(1);
    mockRedisService.get.mockResolvedValue(null);
    mockRedisService.hdel.mockResolvedValue(0);
    mockChatSessionService.deleteTempSession.mockResolvedValue(undefined);
    mockDoctorsService.incrementConsultation.mockResolvedValue(undefined);
  });

  it('should migrate temp messages from Redis to MySQL', async () => {
    const conversationId = 'session-uuid-1';
    const paymentPackages = [
      {
        id: 5,
        name: '图文咨询',
        price: 50,
        duration: 30,
      },
    ];
    const tempMessages = [
      JSON.stringify({
        conversationId: 'session-uuid-1',
        senderId: 1,
        receiverId: 10,
        content: '你好医生',
        type: 'TEXT',
        isAutoReply: false,
        isRead: true,
        isRevoked: true,
        revokedAt: '2025-01-21T10:01:00Z',
        createdAt: '2025-01-21T10:00:00Z',
      }),
      JSON.stringify({
        conversationId: 'session-uuid-1',
        senderId: 10,
        receiverId: 1,
        content: '您好，请问有什么可以帮您？',
        type: 'TEXT',
        isAutoReply: true,
        createdAt: '2025-01-21T10:00:01Z',
      }),
      JSON.stringify({
        conversationId: 'session-uuid-1',
        senderId: 10,
        receiverId: 1,
        content: '请先购买服务后继续咨询',
        type: MessageType.PAYMENT_PROMPT,
        packages: paymentPackages,
        isAutoReply: true,
        createdAt: '2025-01-21T10:00:02Z',
      }),
    ];

    mockRedisService.lrange.mockResolvedValue(tempMessages);
    mockMessageRepository.create.mockImplementation((data) => data);
    mockMessageRepository.save.mockResolvedValue([]);

    await service.migrateTempMessages(conversationId);

    expect(mockRedisService.lrange).toHaveBeenCalledWith(
      `chat:temp:${conversationId}`,
      0,
      -1,
    );
    expect(mockMessageRepository.save).toHaveBeenCalled();
    expect(mockMessageRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        conversationId: 'session-uuid-1',
        content: '你好医生',
        isRead: true,
        isRevoked: true,
        revokedAt: new Date('2025-01-21T10:01:00Z'),
      }),
    );
    expect(mockMessageRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        conversationId: 'session-uuid-1',
        type: MessageType.PAYMENT_PROMPT,
        packages: paymentPackages,
      }),
    );
    expect(mockRedisService.del).toHaveBeenCalledWith(
      `chat:temp:${conversationId}`,
    );
  });

  it('should preserve recalled state while preparing temp messages for payment', async () => {
    mockRedisService.lrange.mockResolvedValue([
      JSON.stringify({
        id: 101,
        conversationId: 'session-uuid-1',
        senderId: 1,
        senderType: 'user',
        receiverId: 10,
        receiverType: 'doctor',
        content: '原始内容',
        type: MessageType.TEXT,
        isRead: true,
        isAutoReply: false,
        isRevoked: true,
        revokedAt: '2026-08-12T10:01:00Z',
        createdAt: '2026-08-12T10:00:00Z',
      }),
    ]);
    mockMessageRepository.create.mockImplementation((data) => data);

    const prepared = await (service as any).prepareTempMessages(
      'session-uuid-1',
      200,
    );

    expect(prepared.entities).toEqual([
      expect.objectContaining({
        orderId: 200,
        content: '原始内容',
        isRead: true,
        isRevoked: true,
        revokedAt: new Date('2026-08-12T10:01:00Z'),
      }),
    ]);
  });

  it('should create a pending order and payment without activating chat', async () => {
    const serviceItem = {
      id: 5,
      name: '图文咨询',
      doctorId: 10,
      duration: 30,
      price: 50,
      isActive: true,
    };

    mockDoctorsService.findServiceItemById.mockResolvedValue(serviceItem);
    mockChatSessionService.getActiveSession.mockResolvedValue(null);
    mockChatSessionService.getTempSession.mockResolvedValue({
      userId: 1,
      doctorId: 10,
      conversationId: 'session-uuid-1',
      status: SessionStatus.FREE,
      isTemporary: true,
    });
    mockOrderRepository.save.mockImplementation(async (order) => ({
      id: 200,
      ...order,
    }));
    mockPaymentService.createPayment.mockResolvedValue({
      paymentNo: 'PAY_200',
      paymentParams: { alipayOrderString: 'signed-order' },
    });

    const result = await service.create(
      1,
      10,
      5,
      PaymentChannel.ALIPAY,
      '550e8400-e29b-41d4-a716-446655440000',
      'session-uuid-1',
    );

    expect(mockOrderRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        status: OrderStatus.PENDING,
        paidAt: undefined,
        serviceStartAt: undefined,
        serviceEndAt: undefined,
      }),
    );
    expect(mockPaymentService.createPayment).toHaveBeenCalledWith(
      expect.objectContaining({
        businessType: BusinessType.CHAT_PACKAGE,
        businessId: 200,
        channel: PaymentChannel.ALIPAY,
        metadata: expect.objectContaining({
          conversationId: 'session-uuid-1',
        }),
      }),
    );
    expect(result.order.status).toBe(OrderStatus.PENDING);
    expect(result.paymentParams.paymentNo).toBe('PAY_200');
    expect(
      mockChatSessionService.getOrCreatePersistedSessionForOrder,
    ).not.toHaveBeenCalled();
    expect(mockChatSessionService.deleteTempSession).not.toHaveBeenCalled();
    expect(mockMessageRepository.save).not.toHaveBeenCalled();
  });

  it('should activate and migrate the chat only after payment succeeds', async () => {
    const paidAt = new Date('2026-04-02T10:05:00.000Z');
    const order = {
      id: 200,
      orderNo: 'CHAT202604020001',
      userId: 1,
      doctorId: 10,
      serviceItemId: 5,
      durationMinutes: 30,
      amount: 50,
      status: OrderStatus.PENDING,
      serviceItem: { id: 5, name: '图文咨询' },
    } as ChatOrder;
    const payment = {
      id: 300,
      paymentNo: 'PAY_200',
      userId: 1,
      businessType: BusinessType.CHAT_PACKAGE,
      businessId: 200,
      amount: 50,
      status: PaymentStatus.SUCCESS,
      channel: PaymentChannel.ALIPAY,
      paidAt,
      metadata: { conversationId: 'session-uuid-1' },
    } as unknown as Payment;
    const queryBuilder = {
      leftJoinAndSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      setLock: jest.fn().mockReturnThis(),
      getOne: jest.fn().mockResolvedValue(order),
    };
    const manager = {
      createQueryBuilder: jest.fn().mockReturnValue(queryBuilder),
      findOne: jest.fn().mockResolvedValue(null),
      create: jest.fn((_entity, data) => ({ ...data })),
      save: jest.fn(async (entity, data) => {
        const value = data ?? entity;
        if (entity === ChatSession) return { id: 21, ...value };
        if (
          !Array.isArray(value) &&
          value.type === MessageType.PAYMENT_SUCCESS
        ) {
          return { id: 501, createdAt: paidAt, ...value };
        }
        return value;
      }),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    mockRedisService.lrange.mockResolvedValue([
      JSON.stringify({
        id: 'temp-1',
        conversationId: 'session-uuid-1',
        senderId: 1,
        senderType: 'user',
        receiverId: 10,
        receiverType: 'doctor',
        content: '你好医生',
        type: 'TEXT',
        createdAt: '2026-04-02T10:00:00.000Z',
      }),
    ]);
    mockChatSessionService.deleteTempSession.mockResolvedValue(undefined);

    const afterCommit = await service.fulfillSuccessfulPayment(
      manager as any,
      payment,
    );

    expect(order.status).toBe(OrderStatus.PAID);
    expect(mockDoctorsService.incrementConsultation).toHaveBeenCalledWith(
      10,
      manager,
    );
    expect(manager.createQueryBuilder).toHaveBeenCalledWith(User, 'user');
    expect(manager.save).toHaveBeenCalledWith(
      ChatSession,
      expect.objectContaining({
        conversationId: 'session-uuid-1',
        status: SessionStatus.PAID,
        orderId: 200,
      }),
    );
    expect(manager.save).toHaveBeenCalledWith(
      expect.anything(),
      expect.arrayContaining([
        expect.objectContaining({ content: '你好医生' }),
      ]),
    );
    expect(mockChatSessionService.deleteTempSession).not.toHaveBeenCalled();

    expect(afterCommit).toEqual(expect.any(Function));
    await (afterCommit as () => Promise<void>)();

    expect(mockChatSessionService.deleteTempSession).toHaveBeenCalledWith(
      1,
      10,
    );
    expect(mockChatGateway.notifyPaymentSuccess).toHaveBeenCalledWith(
      1,
      10,
      expect.objectContaining({ type: MessageType.PAYMENT_SUCCESS }),
    );
  });
});
