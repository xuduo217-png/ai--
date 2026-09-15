import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_hospital_flutter/core/config/api_config.dart';
import 'package:pet_hospital_flutter/core/media/camera_media_picker.dart';
import 'package:pet_hospital_flutter/core/media/gallery_media_picker.dart';
import 'package:pet_hospital_flutter/features/chat/data/chat_repository.dart';
import 'package:pet_hospital_flutter/features/chat/domain/chat_models.dart';
import 'package:pet_hospital_flutter/features/chat/presentation/chat_controller.dart';
import 'package:pet_hospital_flutter/features/chat/presentation/chat_media_viewer_page.dart';
import 'package:pet_hospital_flutter/features/chat/presentation/chat_page.dart';
import 'package:pet_hospital_flutter/features/mall/order/domain/order_models.dart';
import 'package:pet_hospital_flutter/features/mall/payment/domain/payment_models.dart';

import 'support/image_picker_gallery_media_gateway.dart';

void main() {
  test('HTTP 与 Socket.IO 共用生产服务地址', () {
    expect(ApiConfig.baseUrl, 'https://gudeapi.zuoyongyoubao.com');
  });

  testWidgets('聊天页保留医生头部、消息气泡和固定输入区', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: ChatPage(controller: _buildController())),
    );
    await tester.pumpAndSettle();

    expect(find.text('张晶'), findsOneWidget);
    expect(find.text('在线'), findsOneWidget);
    expect(find.text('您好，我想咨询一下'), findsOneWidget);
    expect(find.text('请描述一下宠物的情况'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-composer')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-patient-record-entry')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('chat-message-input')), findsOneWidget);

    final inputContainer = tester.widget<Container>(
      find.byKey(const ValueKey('chat-message-input-container')),
    );
    final inputContainerDecoration =
        inputContainer.decoration! as BoxDecoration;
    expect(inputContainerDecoration.color, const Color(0xFFF3F4F6));
    final messageInput = tester.widget<TextField>(
      find.byKey(const ValueKey('chat-message-input')),
    );
    expect(messageInput.decoration?.filled, isFalse);

    final messageList = tester.widget<ListView>(
      find.byKey(const ValueKey('chat-message-list')),
    );
    expect(messageList.reverse, isFalse);
    final listTop = tester
        .getTopLeft(find.byKey(const ValueKey('chat-message-list')))
        .dy;
    final firstMessageTop = tester
        .getTopLeft(find.byKey(const ValueKey('chat-message-1')))
        .dy;
    final secondMessageTop = tester
        .getTopLeft(find.byKey(const ValueKey('chat-message-2')))
        .dy;
    expect(firstMessageTop - listTop, lessThan(20));
    expect(firstMessageTop, lessThan(secondMessageTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('键盘出现时仅按 viewInsets 上推并移除底部安全区', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(top: 47, bottom: 34),
            viewInsets: EdgeInsets.only(bottom: 300),
            disableAnimations: true,
          ),
          child: ChatPage(controller: _buildController()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final keyboardPadding = tester.widget<AnimatedPadding>(
      find.byKey(const ValueKey('chat-keyboard-inset')),
    );
    expect(keyboardPadding.padding, const EdgeInsets.only(bottom: 300));

    final composer = tester.widget<Container>(
      find.byKey(const ValueKey('chat-composer')),
    );
    final padding = composer.padding! as EdgeInsets;
    expect(padding.bottom, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('键盘出现后消息列表保持在底部', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          controller: _buildController(
            gateway: _FakeChatGateway(messageCount: 24),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollController = tester
        .widget<ListView>(find.byKey(const ValueKey('chat-message-list')))
        .controller!;
    expect(scrollController.offset, scrollController.position.maxScrollExtent);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(scrollController.offset, scrollController.position.maxScrollExtent);
    expect(tester.takeException(), isNull);
  });

  testWidgets('用户上拉查看历史后收发新消息都会自动回到底部', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = _FakeChatGateway(messageCount: 24);
    final controller = _buildController(gateway: gateway);
    await tester.pumpWidget(
      MaterialApp(home: ChatPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    final scrollController = tester
        .widget<ListView>(find.byKey(const ValueKey('chat-message-list')))
        .controller!;
    scrollController.jumpTo(0);
    expect(scrollController.offset, 0);

    gateway.messageCount = 25;
    await controller.refresh();
    await tester.pumpAndSettle();

    expect(find.text('历史消息 25'), findsOneWidget);
    expect(scrollController.offset, scrollController.position.maxScrollExtent);

    scrollController.jumpTo(0);
    controller.sendText('这是一条新消息');
    await tester.pumpAndSettle();

    expect(find.text('这是一条新消息'), findsOneWidget);
    expect(scrollController.offset, scrollController.position.maxScrollExtent);
    expect(tester.takeException(), isNull);
  });

  testWidgets('用户与医生聊天选择媒体后直接发送且最多发送 9 个', (tester) async {
    final picker = _ChatMediaPicker(
      List.generate(
        10,
        (index) => XFile(
          '/tmp/chat-media-$index.${index.isEven ? 'jpg' : 'mp4'}',
          name: 'chat-media-$index.${index.isEven ? 'jpg' : 'mp4'}',
          mimeType: index.isEven ? 'image/jpeg' : 'video/mp4',
        ),
      ),
    );
    final gateway = _FakeChatGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          controller: _buildController(gateway: gateway),
          galleryMediaPicker: GalleryMediaPicker(
            gateway: ImagePickerGalleryMediaGateway(picker),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('chat-media-toggle')));
    await tester.pump();
    await tester.tap(find.text('图片/视频'));
    await _pumpUntilChat(tester, () => gateway.uploadedTypes.length == 9);
    await tester.pump(const Duration(milliseconds: 250));

    expect(picker.limit, 9);
    expect(find.byKey(const ValueKey('local-media-batch-grid')), findsNothing);

    expect(gateway.uploadedTypes, hasLength(9));
    expect(gateway.uploadedTypes.first, ChatMessageType.image);
    expect(gateway.uploadedTypes[1], ChatMessageType.video);
    expect(tester.takeException(), isNull);
  });

  testWidgets('医生聊天图片和视频可以按消息顺序左右滑动预览', (tester) async {
    final gateway = _FakeChatGateway(
      messages: [
        _chatMediaMessage(
          id: 1,
          type: ChatMessageType.image,
          url: 'unsupported://image-1',
          at: DateTime(2026, 7, 23, 10),
        ),
        _chatMediaMessage(
          id: 2,
          type: ChatMessageType.video,
          url: 'unsupported://video-1',
          at: DateTime(2026, 7, 23, 10, 1),
        ),
        _chatMediaMessage(
          id: 3,
          type: ChatMessageType.image,
          url: 'unsupported://image-2',
          at: DateTime(2026, 7, 23, 10, 2),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(controller: _buildController(gateway: gateway)),
      ),
    );
    await tester.pumpAndSettle();

    final firstImage = find.byKey(const ValueKey('chat-image-1'));
    await tester.ensureVisible(firstImage);
    await tester.pumpAndSettle();
    await tester.tap(firstImage);
    await tester.pumpAndSettle();

    expect(find.byType(ChatMediaViewerPage), findsOneWidget);
    expect(find.text('1/3'), findsNothing);
    final pageController = tester
        .widget<PageView>(find.byKey(const ValueKey('chat-media-page-view')))
        .controller!;
    expect(pageController.page, 0);

    await tester.fling(
      find.byKey(const ValueKey('chat-media-page-view')),
      const Offset(-400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(pageController.page, 1);
    expect(find.text('视频无法播放'), findsOneWidget);

    await tester.fling(
      find.byKey(const ValueKey('chat-media-page-view')),
      const Offset(-400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(pageController.page, 2);

    await tester.fling(
      find.byKey(const ValueKey('chat-media-page-view')),
      const Offset(400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(pageController.page, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('医生聊天相机入口同时启用拍照和长按录像', (tester) async {
    var cameraLaunchCalls = 0;
    CameraMediaPickerOptions? cameraOptions;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          controller: _buildController(),
          cameraMediaPicker: CameraMediaPicker(
            targetPlatform: TargetPlatform.android,
            permissionStatusReader: (_) async =>
                const CameraMediaPermissionState(
                  cameraGranted: false,
                  microphoneGranted: false,
                ),
            captureLauncher: (_, options) async {
              cameraLaunchCalls += 1;
              cameraOptions = options;
              return null;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('chat-media-toggle')));
    await tester.pump();
    await tester.tap(find.text('相机'));
    await tester.pumpAndSettle();

    expect(find.text('需要相机和麦克风权限'), findsOneWidget);
    expect(cameraLaunchCalls, 0);
    await tester.tap(
      find.byKey(const ValueKey('camera-media-permission-confirm')),
    );
    await tester.pumpAndSettle();

    expect(cameraLaunchCalls, 1);
    expect(cameraOptions?.allowPhoto, isTrue);
    expect(cameraOptions?.allowVideo, isTrue);
    expect(cameraOptions?.needsMicrophonePermission, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已结束的历史咨询按订单加载并禁止发送', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = _FakeChatGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          controller: ChatController(
            gateway: gateway,
            target: const ChatTarget(doctorId: 2, name: '张晶', avatarUrl: ''),
            currentUserId: 8,
            accessToken: 'test-token',
            historyOrderId: 71,
            viewOnly: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(gateway.requestedOrderId, 71);
    expect(gateway.requestedViewOnly, isTrue);
    expect(find.text('这是一条历史订单消息'), findsOneWidget);
    expect(find.text('咨询已结束'), findsOneWidget);
    expect(find.text('已购买'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('chat-message-input')))
          .enabled,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('确认购买咨询套餐后打开统一支付页面', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = _FakeChatGateway(requiresPayment: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(controller: _buildController(gateway: gateway)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('图文咨询').first);
    await tester.pumpAndSettle();
    expect(find.text('确认购买'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(FilledButton, '确认购买'));
    await tester.pumpAndSettle();

    expect(find.text('选择支付方式'), findsOneWidget);
    expect(find.text('支付宝 App 安全支付'), findsOneWidget);
    expect(find.text('可用余额 ¥100.00'), findsOneWidget);
    expect(find.text('确认支付 ¥50.00'), findsOneWidget);
  });

  testWidgets('支付门禁下从支付宝返回不刷新会话或新增消息', (tester) async {
    final gateway = _FakeChatGateway(requiresPayment: true);
    final controller = _buildController(gateway: gateway);
    await tester.pumpWidget(
      MaterialApp(home: ChatPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    final originalMessages = controller.messages;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(controller.paymentRequired, isTrue);
    expect(gateway.refreshCalls, 0);
    expect(controller.messages, originalMessages);
    expect(controller.canSend, isFalse);
  });

  testWidgets('普通聊天从后台返回仍会同步消息', (tester) async {
    final gateway = _FakeChatGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(controller: _buildController(gateway: gateway)),
      ),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(gateway.refreshCalls, 1);
  });
}

Future<void> _pumpUntilChat(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var attempt = 0; attempt < 200; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 10));
    if (condition()) return;
  }
  fail('Condition was not met before timeout.');
}

ChatController _buildController({ChatGateway? gateway}) {
  return ChatController(
    gateway: gateway ?? _FakeChatGateway(),
    target: const ChatTarget(doctorId: 2, name: '张晶', avatarUrl: ''),
    currentUserId: 8,
    accessToken: 'test-token',
    connectRealtime: false,
  );
}

class _FakeChatGateway implements ChatGateway, ChatPurchaseGateway {
  _FakeChatGateway({
    this.messageCount = 2,
    this.messages,
    this.requiresPayment = false,
  });

  int messageCount;
  final List<ChatMessage>? messages;
  final bool requiresPayment;
  int? requestedOrderId;
  bool? requestedViewOnly;
  int refreshCalls = 0;
  final List<ChatMessageType> uploadedTypes = [];

  @override
  Future<ChatBootstrap> loadChat(int doctorId) async {
    return ChatBootstrap(
      session: ChatSession(
        conversationId: '8_2',
        userId: 8,
        doctorId: doctorId,
        status: ChatSessionStatus.free,
        paymentRequired: requiresPayment,
      ),
      canSend: !requiresPayment,
      doctorOnline: true,
      availablePackages: requiresPayment
          ? const [
              ChatPackage(
                id: 5,
                name: '图文咨询',
                duration: 30,
                price: 50,
                isActive: true,
              ),
            ]
          : const [],
      messages:
          messages ??
          List.generate(messageCount, (index) {
            final id = index + 1;
            return ChatMessage(
              id: id,
              conversationId: '8_2',
              senderId: id.isOdd ? 8 : 2,
              receiverId: id.isOdd ? 2 : 8,
              content: switch (id) {
                1 => '您好，我想咨询一下',
                2 => '请描述一下宠物的情况',
                _ => '历史消息 $id',
              },
              type: ChatMessageType.text,
              isAutoReply: false,
              isRead: id.isOdd,
              createdAt: DateTime(2026, 7, 23, 10, id),
            );
          }),
    );
  }

  @override
  Future<void> purchasePackage({
    required int doctorId,
    required int serviceItemId,
    String? conversationId,
  }) async {}

  @override
  Future<double> loadWalletBalance() async => 100;

  @override
  Future<ChatPackagePayment> purchasePackageForPayment({
    required int doctorId,
    required int serviceItemId,
    required PaymentChannel channel,
    required String idempotencyKey,
    String? conversationId,
  }) async => const ChatPackagePayment(
    orderId: 200,
    orderStatus: ChatPackageOrderStatus.pending,
    paymentNo: 'PAY_200',
    alipayOrderString: 'signed-order',
  );

  @override
  Future<PaymentSdkResult> pay(String orderInfo) async =>
      const PaymentSdkResult(status: PaymentSdkStatus.cancelled);

  @override
  Future<ChatPackagePaymentStatus> loadPaymentStatus(String paymentNo) async =>
      ChatPackagePaymentStatus.pending;

  @override
  Future<ChatBootstrap> loadOrderChat({
    required int doctorId,
    required int orderId,
    required bool viewOnly,
  }) async {
    requestedOrderId = orderId;
    requestedViewOnly = viewOnly;
    return ChatBootstrap(
      session: null,
      canSend: false,
      doctorOnline: false,
      availablePackages: const [],
      messages: [
        ChatMessage(
          id: 70,
          conversationId: '8_2',
          senderId: doctorId,
          receiverId: 8,
          content: '免费咨询次数已用完',
          type: ChatMessageType.paymentPrompt,
          isAutoReply: false,
          isRead: true,
          createdAt: DateTime(2026, 7, 22, 9, 59),
          packages: const [
            ChatPackage(
              id: 3,
              name: '咨询',
              duration: 1440,
              price: 20,
              isActive: true,
            ),
          ],
        ),
        ChatMessage(
          id: 71,
          conversationId: '8_2',
          senderId: doctorId,
          receiverId: 8,
          content: '这是一条历史订单消息',
          type: ChatMessageType.text,
          isAutoReply: false,
          isRead: true,
          createdAt: DateTime(2026, 7, 22, 10),
        ),
      ],
    );
  }

  @override
  Future<ChatBootstrap> refreshChat(int doctorId) {
    refreshCalls += 1;
    return loadChat(doctorId);
  }

  @override
  Future<ChatUploadResult> uploadMedia({
    required String path,
    required String fileName,
    required ChatMessageType type,
  }) async {
    uploadedTypes.add(type);
    return const ChatUploadResult(url: '/uploads/test.jpg');
  }
}

ChatMessage _chatMediaMessage({
  required int id,
  required ChatMessageType type,
  required String url,
  required DateTime at,
}) {
  return ChatMessage(
    id: id,
    conversationId: '8_2',
    senderId: 2,
    receiverId: 8,
    content: ChatMediaContent(url: url).toMessageContent(),
    type: type,
    isAutoReply: false,
    isRead: true,
    createdAt: at,
  );
}

class _ChatMediaPicker extends ImagePicker {
  _ChatMediaPicker(this.files);

  final List<XFile> files;
  int? limit;

  @override
  Future<List<XFile>> pickMultipleMedia({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    this.limit = limit;
    return files;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async => LostDataResponse.empty();
}
