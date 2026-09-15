import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/messaging/in_app_message_event.dart';
import 'package:pet_hospital_flutter/core/storage/conversation_visibility_store.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_media_content.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_messaging_models.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_media_controller.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/pages/friend_chat_media_viewer_page.dart';
import 'package:pet_hospital_flutter/features/marketplace_chat/data/marketplace_chat_database.dart';
import 'package:pet_hospital_flutter/features/marketplace_chat/data/marketplace_chat_local_store.dart';
import 'package:pet_hospital_flutter/features/marketplace_chat/data/marketplace_chat_repository.dart';
import 'package:pet_hospital_flutter/features/marketplace_chat/data/marketplace_chat_socket_client.dart';
import 'package:pet_hospital_flutter/features/marketplace_chat/domain/marketplace_chat_models.dart';
import 'package:pet_hospital_flutter/features/marketplace_chat/presentation/marketplace_chat_controller.dart';
import 'package:pet_hospital_flutter/features/marketplace_chat/presentation/marketplace_chat_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('商城会话支持加载下一页并合并本地列表', () async {
    final repository = _MarketplaceRepository()
      ..pages = {
        1: [_conversation('marketplace-1', updatedHour: 10)],
        2: [_conversation('marketplace-2', updatedHour: 11)],
      }
      ..totalPages = 2;
    final controller = await _controller(repository: repository);
    addTearDown(controller.close);

    await controller.start();
    expect(repository.requestedPages, [1]);
    expect(controller.hasMoreConversations, isTrue);

    await controller.loadMoreConversations();

    expect(repository.requestedPages, [1, 2]);
    expect(controller.conversations.map((item) => item.conversationId), [
      'marketplace-2',
      'marketplace-1',
    ]);
    expect(controller.hasMoreConversations, isFalse);
  });

  test('刷新商城会话后更新商品快照和本地列表', () async {
    final repository = _MarketplaceRepository()
      ..pages = {
        1: [_conversation('marketplace-1')],
      };
    final controller = await _controller(repository: repository);
    addTearDown(controller.close);
    await controller.start();
    repository.pages = {
      1: [
        _conversation(
          'marketplace-1',
          product: const MarketplaceProductSnapshot(
            id: 20,
            name: '已刷新的商品',
            price: 66,
            isActive: true,
            isSold: false,
          ),
        ),
      ],
    };

    final refreshed = await controller.refreshConversation('marketplace-1');

    expect(refreshed.product.name, '已刷新的商品');
    expect(controller.conversations.single.product.name, '已刷新的商品');
  });

  test('商城会话隐藏后在新消息到达时恢复', () async {
    final repository = _MarketplaceRepository()
      ..pages = {
        1: [_conversation('marketplace-1', unreadCount: 2)],
      };
    final socket = _MarketplaceSocket();
    final visibility = _VisibilityStore();
    final controller = await _controller(
      repository: repository,
      socket: socket,
      visibility: visibility,
    );
    addTearDown(controller.close);
    await controller.start();

    await controller.hideConversation(controller.conversations.single);

    expect(controller.conversations, isEmpty);
    expect(visibility.hidden, {'marketplace-1'});

    socket.emitMessage(
      FriendMessage(
        messageId: 'message-1',
        conversationId: 'marketplace-1',
        senderId: 9,
        receiverId: 1,
        messageType: 'text',
        content: '商品还在',
        sendStatus: MessageSendStatus.sent,
        isRead: false,
        readSynced: true,
        createdAt: DateTime.utc(2026, 7, 27, 12),
        updatedAt: DateTime.utc(2026, 7, 27, 12),
      ),
    );
    await _waitUntil(
      () => controller.conversations.any(
        (conversation) =>
            conversation.conversationId == 'marketplace-1' &&
            conversation.lastMessage?.content == '商品还在',
      ),
      description: '等待新消息恢复商城会话',
    );

    expect(controller.conversations.single.conversationId, 'marketplace-1');
    expect(controller.conversations.single.lastMessage?.content, '商品还在');
    expect(visibility.hidden, isEmpty);
  });

  test('商城实时消息落库后发布全局展示事件', () async {
    final repository = _MarketplaceRepository()
      ..pages = {
        1: [_conversation('marketplace-1')],
      };
    final socket = _MarketplaceSocket();
    final controller = await _controller(
      repository: repository,
      socket: socket,
    );
    addTearDown(controller.close);
    await controller.start();
    final events = <InAppMessageEvent>[];
    final subscription = controller.incomingMessageEvents.listen(events.add);
    addTearDown(subscription.cancel);

    socket.emitMessage(
      FriendMessage(
        messageId: 'banner-marketplace-1',
        conversationId: 'marketplace-1',
        senderId: 9,
        receiverId: 1,
        messageType: 'image',
        content: '{"url":"/image.jpg"}',
        sendStatus: MessageSendStatus.sent,
        isRead: false,
        readSynced: true,
        createdAt: DateTime.utc(2026, 7, 27, 12),
        updatedAt: DateTime.utc(2026, 7, 27, 12),
      ),
    );
    await _waitUntil(() => events.isNotEmpty, description: '等待商城全局展示事件');

    final event = events.single;
    expect(event.conversationId, 'marketplace-1');
    expect(event.preview, '[图片]');
    expect(event.title, '卖家marketplace-1');
  });

  testWidgets('商城买卖聊天在键盘出现和收发新消息后保持在最新位置', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    final conversation = _conversation('marketplace-1');
    final controller = _WidgetMarketplaceController(
      messages: List.generate(
        32,
        (index) => _marketplaceMessage(
          messageId: 'marketplace-history-$index',
          content: '商城历史消息 $index',
          createdAt: DateTime.utc(2026, 7, 27, 10, index),
        ),
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MarketplaceChatPage(
          controller: controller,
          conversation: conversation,
        ),
      ),
    );
    await _pumpUntilWidget(
      tester,
      find.byKey(const ValueKey('marketplace-chat-message-list')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2026-07-27 '), findsWidgets);
    final messageList = tester.widget<ListView>(
      find.byKey(const ValueKey('marketplace-chat-message-list')),
    );
    final scrollController = messageList.controller!;
    expect(messageList.reverse, isTrue);
    expect(scrollController.offset, scrollController.position.minScrollExtent);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(scrollController.offset, scrollController.position.minScrollExtent);

    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    controller.emitMessage(
      _marketplaceMessage(
        messageId: 'new-marketplace-message',
        content: '刚收到的商城消息',
        createdAt: DateTime.utc(2026, 7, 27, 11),
      ),
    );
    await _pumpUntilWidget(tester, find.text('刚收到的商城消息'));
    await tester.pumpAndSettle();
    expect(scrollController.offset, scrollController.position.minScrollExtent);

    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    await tester.enterText(find.byType(TextField), '刚发送的商城消息');
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await _pumpUntilWidget(tester, find.text('刚发送的商城消息'));
    await tester.pumpAndSettle();
    expect(scrollController.offset, scrollController.position.minScrollExtent);
    expect(tester.takeException(), isNull);
  });

  testWidgets('商城聊天刷新商品快照并点击可用商品', (tester) async {
    final refreshed = _conversation(
      'marketplace-1',
      role: 'seller',
      product: const MarketplaceProductSnapshot(
        id: 20,
        name: '刷新后的猫包',
        price: 68,
        isActive: true,
        isSold: false,
      ),
    );
    final controller = _WidgetMarketplaceController(
      messages: const [],
      refreshedConversation: refreshed,
    );
    addTearDown(controller.dispose);
    int? openedProductId;

    await tester.pumpWidget(
      MaterialApp(
        home: MarketplaceChatPage(
          controller: controller,
          conversation: _conversation('marketplace-1', role: 'seller'),
          onProductTap: (productId) async => openedProductId = productId,
        ),
      ),
    );
    await _pumpUntilWidget(tester, find.text('刷新后的猫包'));

    expect(find.text('¥68.00'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('marketplace-product-context')));
    await tester.pump();
    expect(openedProductId, 20);
  });

  testWidgets('商城聊天正确展示已售出、已下架和不可见商品状态', (tester) async {
    Future<void> pumpProduct(MarketplaceProductSnapshot product) async {
      final controller = _WidgetMarketplaceController(messages: const []);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceChatPage(
            key: ValueKey(product.name),
            controller: controller,
            conversation: _conversation(
              'marketplace-1',
              role: 'seller',
              product: product,
            ),
            onProductTap: (_) async {},
          ),
        ),
      );
      await tester.pump();
    }

    await pumpProduct(
      const MarketplaceProductSnapshot(
        id: 20,
        name: '已售商品',
        price: 88,
        isActive: false,
        isSold: true,
      ),
    );
    expect(find.text('已售出'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    await pumpProduct(
      const MarketplaceProductSnapshot(
        id: 20,
        name: '下架商品',
        price: 88,
        isActive: false,
        isSold: false,
      ),
    );
    expect(find.text('已下架'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

    await pumpProduct(
      const MarketplaceProductSnapshot(
        id: 20,
        name: '商品已不可见',
        isActive: true,
        isSold: false,
      ),
    );
    expect(find.text('商品已不可见'), findsNWidgets(2));
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('商城聊天支持图片视频混合多选并按顺序发送', (tester) async {
    const drafts = [
      FriendMediaSendRequest(
        type: FriendMediaType.image,
        localFilePath: '/tmp/marketplace-0.jpg',
        fileName: 'marketplace-0.jpg',
        mimeType: 'image/jpeg',
        size: 1,
      ),
      FriendMediaSendRequest(
        type: FriendMediaType.video,
        localFilePath: '/tmp/marketplace-1.mp4',
        fileName: 'marketplace-1.mp4',
        mimeType: 'video/mp4',
        size: 1,
        duration: 12,
      ),
      FriendMediaSendRequest(
        type: FriendMediaType.image,
        localFilePath: '/tmp/marketplace-2.jpg',
        fileName: 'marketplace-2.jpg',
        mimeType: 'image/jpeg',
        size: 1,
      ),
    ];
    final controller = _WidgetMarketplaceController(messages: const []);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MarketplaceChatPage(
          controller: controller,
          conversation: _conversation('marketplace-media'),
          mediaController: _SelectedMarketplaceMediaController(drafts),
        ),
      ),
    );
    await _pumpUntilWidget(
      tester,
      find.byKey(const ValueKey('marketplace-chat-media-toggle')),
    );

    await tester.tap(
      find.byKey(const ValueKey('marketplace-chat-media-toggle')),
    );
    await tester.pump();
    expect(find.text('相机'), findsOneWidget);
    await tester.tap(find.text('图片/视频'));
    await _pumpUntilWidget(tester, find.text('发送 3 个媒体'));

    expect(find.text('发送 3 个媒体'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('local-media-batch-send')));
    await _waitUntil(
      () => controller.sentMediaTypes.length == 3,
      description: '等待商城批量媒体发送',
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(controller.sentMediaTypes, [
      FriendMediaType.image,
      FriendMediaType.video,
      FriendMediaType.image,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('买家进入商城会话显示私下交易提醒并可关闭', (tester) async {
    final controller = _WidgetMarketplaceController(
      messages: [
        _marketplaceMessage(
          messageId: 'marketplace-reminder-message',
          content: '商品还在',
          createdAt: DateTime.utc(2026, 7, 27, 10),
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MarketplaceChatPage(
          controller: controller,
          conversation: _conversation('marketplace-1', role: 'buyer'),
        ),
      ),
    );
    await _pumpUntilWidget(
      tester,
      find.byKey(const ValueKey('marketplace-private-trade-reminder')),
    );

    expect(find.textContaining('请勿私下转账或交易'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('marketplace-private-trade-reminder-close')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('marketplace-private-trade-reminder')),
      findsNothing,
    );
  });

  testWidgets('买家私下交易提醒进入页面十秒后自动关闭', (tester) async {
    final controller = _WidgetMarketplaceController(
      messages: [
        _marketplaceMessage(
          messageId: 'marketplace-auto-dismiss-message',
          content: '商品还在',
          createdAt: DateTime.utc(2026, 7, 27, 10),
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MarketplaceChatPage(
          controller: controller,
          conversation: _conversation('marketplace-1', role: 'buyer'),
        ),
      ),
    );
    await _pumpUntilWidget(
      tester,
      find.byKey(const ValueKey('marketplace-private-trade-reminder')),
    );
    expect(
      find.byKey(const ValueKey('marketplace-private-trade-reminder')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 10));

    expect(
      find.byKey(const ValueKey('marketplace-private-trade-reminder')),
      findsNothing,
    );
  });

  testWidgets('卖家进入商城会话不显示私下交易提醒', (tester) async {
    final controller = _WidgetMarketplaceController(
      messages: [
        _marketplaceMessage(
          messageId: 'marketplace-seller-message',
          content: '商品还在',
          createdAt: DateTime.utc(2026, 7, 27, 10),
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MarketplaceChatPage(
          controller: controller,
          conversation: _conversation('marketplace-1', role: 'seller'),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('marketplace-private-trade-reminder')),
      findsNothing,
    );
  });

  testWidgets('商城聊天图片和视频可以按消息顺序左右滑动预览', (tester) async {
    final controller = _WidgetMarketplaceController(
      messages: [
        _marketplaceMessage(
          messageId: 'marketplace-image-1',
          messageType: 'image',
          content: const FriendMediaContent(
            url: 'unsupported://marketplace-image-1',
          ).toMessageContent(),
          createdAt: DateTime.utc(2026, 7, 27, 10),
        ),
        _marketplaceMessage(
          messageId: 'marketplace-video-1',
          messageType: 'video',
          content: const FriendMediaContent(
            url: 'unsupported://marketplace-video-1',
          ).toMessageContent(),
          createdAt: DateTime.utc(2026, 7, 27, 10, 1),
        ),
        _marketplaceMessage(
          messageId: 'marketplace-image-2',
          messageType: 'image',
          content: const FriendMediaContent(
            url: 'unsupported://marketplace-image-2',
          ).toMessageContent(),
          createdAt: DateTime.utc(2026, 7, 27, 10, 2),
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MarketplaceChatPage(
          controller: controller,
          conversation: _conversation('marketplace-1'),
        ),
      ),
    );
    await _pumpUntilWidget(
      tester,
      find.byKey(const ValueKey('friend-image-marketplace-image-1')),
    );
    await tester.pumpAndSettle();

    final firstImage = find.byKey(
      const ValueKey('friend-image-marketplace-image-1'),
    );
    await tester.ensureVisible(firstImage);
    await tester.pumpAndSettle();
    await tester.tap(firstImage);
    await tester.pumpAndSettle();

    expect(find.byType(FriendChatMediaViewerPage), findsOneWidget);
    final pageView = find.byKey(const ValueKey('friend-chat-media-page-view'));
    final pageController = tester.widget<PageView>(pageView).controller!;
    expect(pageController.page, 0);

    await tester.fling(pageView, const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(pageController.page, 1);
    expect(find.text('视频无法播放'), findsOneWidget);

    await tester.fling(pageView, const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(pageController.page, 2);

    await tester.fling(pageView, const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(pageController.page, 1);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpUntilWidget(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 10));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Widget was not found before timeout: $finder');
}

Future<void> _waitUntil(
  bool Function() condition, {
  required String description,
}) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('$description超时');
}

Future<MarketplaceChatController> _controller({
  required _MarketplaceRepository repository,
  _MarketplaceSocket? socket,
  _VisibilityStore? visibility,
}) async {
  final database = MarketplaceChatDatabase.withFactory(
    factory: databaseFactoryFfi,
    databasePath: inMemoryDatabasePath,
  );
  return MarketplaceChatController(
    ownerUserId: 1,
    repository: repository,
    localStore: MarketplaceChatLocalStore(database),
    socket: socket ?? _MarketplaceSocket(),
    visibilityStore: visibility ?? _VisibilityStore(),
    onSessionRevoked: () async {},
  );
}

MarketplaceConversation _conversation(
  String conversationId, {
  int unreadCount = 0,
  int updatedHour = 10,
  String role = 'buyer',
  MarketplaceProductSnapshot? product,
}) {
  return MarketplaceConversation(
    conversationId: conversationId,
    productId: 20,
    buyerId: 1,
    sellerId: 9,
    role: role,
    peer: MarketplacePeer(id: 9, nickname: '卖家$conversationId'),
    product:
        product ??
        const MarketplaceProductSnapshot(
          id: 20,
          name: '闲置猫包',
          isActive: true,
          isSold: false,
        ),
    unreadCount: unreadCount,
    createdAt: DateTime.utc(2026, 7, 27, 9),
    updatedAt: DateTime.utc(2026, 7, 27, updatedHour),
  );
}

FriendMessage _marketplaceMessage({
  required String messageId,
  required String content,
  required DateTime createdAt,
  String messageType = 'text',
}) {
  return FriendMessage(
    messageId: messageId,
    conversationId: 'marketplace-1',
    senderId: 9,
    receiverId: 1,
    messageType: messageType,
    content: content,
    sendStatus: MessageSendStatus.sent,
    isRead: false,
    readSynced: true,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

class _MarketplaceRepository implements MarketplaceChatRepositoryGateway {
  Map<int, List<MarketplaceConversation>> pages = const {};
  int totalPages = 1;
  int unreadCount = 0;
  final List<int> requestedPages = [];
  final List<String> markedConversationIds = [];

  @override
  Future<MarketplacePage<MarketplaceConversation>> loadConversations({
    int page = 1,
    int pageSize = 50,
  }) async {
    requestedPages.add(page);
    final items = pages[page] ?? const <MarketplaceConversation>[];
    return MarketplacePage(
      items: items,
      page: page,
      pageSize: pageSize,
      total: pages.values.fold(0, (total, items) => total + items.length),
      totalPages: totalPages,
    );
  }

  @override
  Future<MarketplaceConversation> loadConversation(
    String conversationId,
  ) async => pages.values
      .expand((items) => items)
      .firstWhere((item) => item.conversationId == conversationId);

  @override
  Future<MarketplaceConversation> openConversation(int productId) async =>
      pages.values.expand((items) => items).first;

  @override
  Future<MarketplacePage<FriendMessage>> loadMessages({
    required String conversationId,
    required int page,
    int pageSize = 50,
  }) async => MarketplacePage(
    items: const [],
    page: page,
    pageSize: pageSize,
    total: 0,
    totalPages: 0,
  );

  @override
  Future<int> loadUnreadCount() async => unreadCount;

  @override
  Future<void> markConversationRead(String conversationId) async {
    markedConversationIds.add(conversationId);
  }

  @override
  Future<void> blockUser(int userId) async {}

  @override
  Future<void> markMessageRead({
    required String messageId,
    required String conversationId,
  }) async {}

  @override
  Future<void> reportMessage(String messageId, {String? description}) async {}
}

class _MarketplaceSocket implements MarketplaceChatSocketGateway {
  final _messages = StreamController<FriendMessage>.broadcast(sync: true);
  bool _connected = false;

  @override
  bool get isConnected => _connected;
  @override
  Stream<FriendMessage> get messages => _messages.stream;
  @override
  Stream<FriendMessageAck> get acknowledgements => const Stream.empty();
  @override
  Stream<FriendReadReceipt> get readReceipts => const Stream.empty();
  @override
  Stream<SessionRevokedEvent> get sessionRevoked => const Stream.empty();
  @override
  Stream<bool> get connectionChanges => const Stream.empty();
  @override
  Stream<Object> get errors => const Stream.empty();

  @override
  Future<void> connect() async => _connected = true;
  @override
  Future<void> fetchOfflineMessages() async {}
  @override
  Future<void> acknowledgeOfflineMessages(List<String> messageIds) async {}
  @override
  Future<void> markMessageRead({
    required String messageId,
    required String conversationId,
  }) async {}
  @override
  Future<void> sendTyping({
    required String conversationId,
    required bool isTyping,
  }) async {}
  @override
  Future<FriendMessageAck> sendMessage({
    required String conversationId,
    required String messageType,
    required String content,
    required String tempMessageId,
  }) => throw UnimplementedError();
  @override
  Future<void> stop() async => _connected = false;
  @override
  Future<void> dispose() async {
    _connected = false;
    await _messages.close();
  }

  void emitMessage(FriendMessage message) => _messages.add(message);
}

class _WidgetMarketplaceController extends MarketplaceChatController {
  _WidgetMarketplaceController({
    required List<FriendMessage> messages,
    this.refreshedConversation,
  }) : _messages = [...messages],
       super(
         ownerUserId: 1,
         repository: _MarketplaceRepository(),
         localStore: MarketplaceChatLocalStore(
           MarketplaceChatDatabase.withFactory(
             factory: databaseFactoryFfi,
             databasePath: inMemoryDatabasePath,
           ),
         ),
         socket: _MarketplaceSocket(),
         onSessionRevoked: _noopSessionRevoked,
       );

  final List<FriendMessage> _messages;
  final MarketplaceConversation? refreshedConversation;
  final List<FriendMediaType> sentMediaTypes = [];

  @override
  Future<List<FriendMessage>> loadMessages(
    String conversationId, {
    int limit = MarketplaceChatController.pageSize,
  }) async {
    if (_messages.length <= limit) return [..._messages];
    return _messages.sublist(_messages.length - limit);
  }

  @override
  Future<int> messageCount(String conversationId) async => _messages.length;

  @override
  Future<MarketplaceConversation> refreshConversation(
    String conversationId,
  ) async {
    final refreshed = refreshedConversation;
    if (refreshed == null) throw StateError('refresh unavailable');
    return refreshed;
  }

  @override
  Future<void> syncConversation(
    MarketplaceConversation conversation, {
    int page = 1,
  }) async {}

  @override
  Future<void> setActiveConversation(
    MarketplaceConversation conversation,
  ) async {}

  @override
  void clearActiveConversation(String conversationId) {}

  @override
  Future<void> sendText(
    MarketplaceConversation conversation,
    String raw,
  ) async {
    final createdAt = _messages.last.createdAt.add(const Duration(minutes: 1));
    _append(
      FriendMessage(
        tempMessageId: 'marketplace-send-${_messages.length}',
        conversationId: conversation.conversationId,
        senderId: ownerUserId,
        receiverId: conversation.peer.id,
        messageType: 'text',
        content: raw.trim(),
        sendStatus: MessageSendStatus.sent,
        isRead: false,
        readSynced: true,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
  }

  @override
  Future<void> sendMedia(
    MarketplaceConversation conversation,
    FriendMediaSendRequest request,
  ) async {
    sentMediaTypes.add(request.type);
  }

  void emitMessage(FriendMessage message) => _append(message);

  void _append(FriendMessage message) {
    _messages.add(message);
    _messages.sort((left, right) => left.createdAt.compareTo(right.createdAt));
    notifyListeners();
  }
}

Future<void> _noopSessionRevoked() async {}

class _SelectedMarketplaceMediaController extends FriendMediaController {
  _SelectedMarketplaceMediaController(this.drafts);

  final List<FriendMediaSendRequest> drafts;

  @override
  Future<List<FriendMediaSendRequest>> pickMedia({
    BuildContext? context,
  }) async => drafts;
}

class _VisibilityStore implements ConversationVisibilityGateway {
  final Set<String> hidden = <String>{};

  @override
  Future<void> hideConversation({
    required int ownerUserId,
    required ConversationVisibilityScope scope,
    required String conversationId,
  }) async {
    hidden.add(conversationId);
  }

  @override
  Future<Set<String>> loadHiddenConversationIds({
    required int ownerUserId,
    required ConversationVisibilityScope scope,
  }) async => {...hidden};

  @override
  Future<void> restoreConversation({
    required int ownerUserId,
    required ConversationVisibilityScope scope,
    required String conversationId,
  }) async {
    hidden.remove(conversationId);
  }
}
