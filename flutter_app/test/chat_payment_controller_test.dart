import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/chat/data/chat_repository.dart';
import 'package:pet_hospital_flutter/features/chat/domain/chat_models.dart';
import 'package:pet_hospital_flutter/features/chat/presentation/chat_controller.dart';
import 'package:pet_hospital_flutter/features/mall/order/domain/order_models.dart';
import 'package:pet_hospital_flutter/features/mall/payment/domain/payment_models.dart';

void main() {
  const package = ChatPackage(
    id: 5,
    name: '图文咨询',
    duration: 30,
    price: 50,
    isActive: true,
  );

  test('取消支付宝支付时不会刷新或激活咨询会话', () async {
    final chatGateway = _ChatGateway();
    final purchaseGateway = _PurchaseGateway(
      sdkStatus: PaymentSdkStatus.cancelled,
    );
    final controller = ChatController(
      gateway: chatGateway,
      purchaseGateway: purchaseGateway,
      target: const ChatTarget(doctorId: 10, name: '张医生', avatarUrl: ''),
      currentUserId: 1,
      accessToken: 'token',
      connectRealtime: false,
      paymentDelay: (_) async {},
      paymentIdempotencyKeyFactory: () =>
          '550e8400-e29b-41d4-a716-446655440000',
    );
    await controller.initialize();

    controller.beginPurchase(package);
    final result = await controller.submit(PaymentChannel.alipay);

    expect(result.status, PaymentFlowStatus.cancelled);
    expect(chatGateway.refreshCalls, 0);
    expect(controller.canSend, isFalse);
    expect(controller.paymentRequired, isTrue);
    expect(purchaseGateway.idempotencyKeys.single, isNotEmpty);
  });

  test('同一套餐取消后重试复用原支付订单', () async {
    final purchaseGateway = _PurchaseGateway(
      sdkStatus: PaymentSdkStatus.cancelled,
    );
    var generatedKeyCount = 0;
    final controller = ChatController(
      gateway: _ChatGateway(),
      purchaseGateway: purchaseGateway,
      target: const ChatTarget(doctorId: 10, name: '张医生', avatarUrl: ''),
      currentUserId: 1,
      accessToken: 'token',
      connectRealtime: false,
      paymentIdempotencyKeyFactory: () {
        generatedKeyCount += 1;
        return '550e8400-e29b-41d4-a716-44665544000$generatedKeyCount';
      },
    );
    await controller.initialize();

    controller.beginPurchase(package);
    final firstResult = await controller.submit(PaymentChannel.alipay);
    controller.beginPurchase(package);
    final retryResult = await controller.submit(PaymentChannel.alipay);

    expect(firstResult.status, PaymentFlowStatus.cancelled);
    expect(retryResult.status, PaymentFlowStatus.cancelled);
    expect(generatedKeyCount, 1);
    expect(purchaseGateway.idempotencyKeys, hasLength(2));
    expect(
      purchaseGateway.idempotencyKeys[1],
      purchaseGateway.idempotencyKeys[0],
    );
  });

  test('服务端确认支付成功后才刷新并激活咨询会话', () async {
    final chatGateway = _ChatGateway();
    final purchaseGateway = _PurchaseGateway(
      sdkStatus: PaymentSdkStatus.success,
      confirmedStatus: ChatPackagePaymentStatus.success,
    );
    final controller = ChatController(
      gateway: chatGateway,
      purchaseGateway: purchaseGateway,
      target: const ChatTarget(doctorId: 10, name: '张医生', avatarUrl: ''),
      currentUserId: 1,
      accessToken: 'token',
      connectRealtime: false,
      paymentDelay: (_) async {},
    );
    await controller.initialize();

    controller.beginPurchase(package);
    final result = await controller.submit(PaymentChannel.alipay);

    expect(result.status, PaymentFlowStatus.success);
    expect(chatGateway.refreshCalls, 1);
    expect(controller.canSend, isTrue);
  });

  test('刷新切换会话时不会混入旧会话消息', () async {
    final controller = ChatController(
      gateway: _ChatGateway(switchConversationOnRefresh: true),
      target: const ChatTarget(doctorId: 10, name: '张医生', avatarUrl: ''),
      currentUserId: 1,
      accessToken: 'token',
      connectRealtime: false,
    );
    await controller.initialize();
    expect(controller.messages.single.content, '旧会话消息');

    await controller.refresh();

    expect(controller.session?.conversationId, 'conversation-2');
    expect(controller.messages, hasLength(1));
    expect(controller.messages.single.content, '新会话消息');
  });
}

class _ChatGateway implements ChatGateway {
  _ChatGateway({this.switchConversationOnRefresh = false});

  final bool switchConversationOnRefresh;
  int refreshCalls = 0;

  @override
  Future<ChatBootstrap> loadChat(int doctorId) async => _bootstrap(false);

  @override
  Future<ChatBootstrap> refreshChat(int doctorId) async {
    refreshCalls += 1;
    return _bootstrap(true);
  }

  ChatBootstrap _bootstrap(bool paid) {
    final conversationId = paid && switchConversationOnRefresh
        ? 'conversation-2'
        : 'conversation-1';
    return ChatBootstrap(
      session: ChatSession(
        conversationId: conversationId,
        userId: 1,
        doctorId: 10,
        status: paid ? ChatSessionStatus.paid : ChatSessionStatus.free,
        paymentRequired: !paid,
        serviceEndAt: paid
            ? DateTime.now().add(const Duration(minutes: 30))
            : null,
      ),
      canSend: paid,
      doctorOnline: true,
      availablePackages: const [],
      messages: [
        ChatMessage(
          id: paid ? 2 : 1,
          conversationId: conversationId,
          senderId: 10,
          receiverId: 1,
          content: paid ? '新会话消息' : '旧会话消息',
          type: ChatMessageType.text,
          isAutoReply: false,
          isRead: true,
          createdAt: DateTime(2026, 8, 2, 10, paid ? 1 : 0),
        ),
      ],
    );
  }

  @override
  Future<ChatBootstrap> loadOrderChat({
    required int doctorId,
    required int orderId,
    required bool viewOnly,
  }) => throw UnimplementedError();

  @override
  Future<void> purchasePackage({
    required int doctorId,
    required int serviceItemId,
    String? conversationId,
  }) => throw UnimplementedError();

  @override
  Future<ChatUploadResult> uploadMedia({
    required String path,
    required String fileName,
    required ChatMessageType type,
  }) => throw UnimplementedError();
}

class _PurchaseGateway implements ChatPurchaseGateway {
  _PurchaseGateway({
    required this.sdkStatus,
    this.confirmedStatus = ChatPackagePaymentStatus.pending,
  });

  final PaymentSdkStatus sdkStatus;
  final ChatPackagePaymentStatus confirmedStatus;
  final List<String> idempotencyKeys = [];

  @override
  Future<double> loadWalletBalance() async => 100;

  @override
  Future<ChatPackagePayment> purchasePackageForPayment({
    required int doctorId,
    required int serviceItemId,
    required PaymentChannel channel,
    required String idempotencyKey,
    String? conversationId,
  }) async {
    idempotencyKeys.add(idempotencyKey);
    return const ChatPackagePayment(
      orderId: 200,
      orderStatus: ChatPackageOrderStatus.pending,
      paymentNo: 'PAY_200',
      alipayOrderString: 'signed-order',
    );
  }

  @override
  Future<PaymentSdkResult> pay(String orderInfo) async =>
      PaymentSdkResult(status: sdkStatus);

  @override
  Future<ChatPackagePaymentStatus> loadPaymentStatus(String paymentNo) async =>
      confirmedStatus;
}
