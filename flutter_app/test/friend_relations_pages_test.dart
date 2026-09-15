import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/friends/data/friend_relations_repository.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_database.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_local_store.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_repository.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_socket_client.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_messaging_models.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_relation_models.dart';
import 'package:pet_hospital_flutter/features/friends/friends_feature_session.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_request_list_page.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_chat_blocks_controller.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_chat_blocks_page.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_requests_controller.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_search_controller.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friends_directory_controller.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friends_list_view.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friends_messaging_controller.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/search_user_page.dart';

void main() {
  testWidgets('添加好友页覆盖非法手机号、结果卡和申请状态提示', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _PageRelationsRepository()
      ..searchResult = const SearchUserResult(
        found: true,
        user: UserSearchResult(id: 8, username: '小顾', phone: '13800138000'),
      )
      ..sendResult = const SendFriendRequestResult(
        success: false,
        status: SendFriendRequestStatus.outgoingPending,
        message: '好友申请已发送，请耐心等待对方处理',
      );
    await tester.pumpWidget(
      MaterialApp(
        home: SearchUserPage(
          controller: FriendSearchController(
            ownerUserId: 1,
            repository: repository,
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('friend-phone-search-field')),
      '123',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('friend-search-submit')));
    await tester.pump();
    expect(find.text('请输入正确的手机号'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('friend-phone-search-field')),
      '13800138000',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('friend-search-submit')));
    await tester.pumpAndSettle();
    expect(find.text('小顾'), findsWidgets);
    expect(
      find.byKey(const ValueKey('friend-search-result-card')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('friend-search-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('friend-request-message-field')),
      List<String>.filled(50, '好').join(),
    );
    await tester.pump();
    expect(find.text('50/50'), findsOneWidget);
    final sendButton = find.byKey(const ValueKey('friend-request-send'));
    await tester.drag(
      find.byKey(const ValueKey('friend-search-list')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    final cancelButton = find.byKey(const ValueKey('friend-request-cancel'));
    expect(tester.getSize(cancelButton), tester.getSize(sendButton));
    expect(tester.getSize(cancelButton).height, 52);
    expect(tester.getCenter(sendButton).dy, lessThan(667));
    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    expect(find.text('温馨提示'), findsOneWidget);
    expect(find.text('好友申请已发送，请耐心等待对方处理'), findsOneWidget);
    expect(repository.lastMessage.length, 50);
    expect(tester.takeException(), isNull);
  });

  testWidgets('搜索本人时隐藏添加按钮', (tester) async {
    final repository = _PageRelationsRepository()
      ..searchResult = const SearchUserResult(
        found: true,
        user: UserSearchResult(id: 6, username: '当前用户', phone: '13900139000'),
      );
    await tester.pumpWidget(
      MaterialApp(
        home: SearchUserPage(
          controller: FriendSearchController(
            ownerUserId: 6,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('friend-phone-search-field')),
      '13900139000',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('friend-search-submit')));
    await tester.pumpAndSettle();

    expect(find.text('当前搜索结果是你自己'), findsOneWidget);
    expect(find.byKey(const ValueKey('friend-search-add')), findsNothing);
  });

  testWidgets('好友申请页接受后逐条移除并显示结果', (tester) async {
    final repository = _PageRelationsRepository()
      ..pendingRequests = [
        FriendRequest.fromJson({
          'id': 7,
          'requesterId': 8,
          'requesterName': '小顾',
          'requesterPhone': '13800138000',
          'message': '我是宠友群的小顾',
          'status': 'pending',
          'createdAt': '2026-07-25T08:00:00.000Z',
        }),
      ];
    final socket = _PageRelationsSocket();
    addTearDown(socket.close);
    await tester.pumpWidget(
      MaterialApp(
        home: FriendRequestListPage(
          controller: FriendRequestsController(
            repository: repository,
            socket: socket,
            onRequestResolved: ({required accepted}) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('小顾'), findsOneWidget);
    expect(find.text('138****8000'), findsOneWidget);
    expect(find.text('申请附言：我是宠友群的小顾'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('friend-request-accept-7')));
    await tester.pumpAndSettle();

    expect(repository.acceptCalls, 1);
    expect(find.text('暂无好友申请'), findsOneWidget);
    expect(find.text('已接受 小顾 的好友申请'), findsOneWidget);
  });

  testWidgets('通讯录展示分组角标并点击好友进入现有聊天页', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _PageRelationsRepository()
      ..friends = const [
        FriendshipSummary(
          friendId: 8,
          friendName: '张三',
          friendSignature: '今天也要照顾好毛孩子',
        ),
      ]
      ..relationshipSummary = const FriendRelationshipSummary(
        isFriend: true,
        outgoingPending: false,
        incomingPending: false,
      )
      ..pendingTotal = 105;
    final socket = FriendsSocketClient(
      baseUrl: 'https://example.test',
      accessTokenProvider: () async => 'token',
    );
    final directory = FriendsDirectoryController(
      repository: repository,
      socket: socket,
    );
    await directory.start();
    final session = FriendsFeatureSession(
      ownerUserId: 1,
      messagingController: _NoopMessagingController(socket),
      directoryController: directory,
      socket: socket,
      repository: repository,
    );
    addTearDown(directory.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FriendsListView(session: session)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final background = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('friends-directory-background')),
    );
    final gradient = (background.decoration as BoxDecoration).gradient!;
    expect((gradient as LinearGradient).colors, const [
      Color(0xFFDEE9FF),
      Color(0xFFFAFBFF),
    ]);
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey('friend-directory-section-Z')),
          )
          .color,
      Colors.transparent,
    );
    expect(find.text('通讯录'), findsOneWidget);
    expect(find.text('Z'), findsWidgets);
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('99+'), findsOneWidget);
    final directoryList = find.byKey(const ValueKey('friends-directory-list'));
    final alphabetIndex = find.byKey(
      const ValueKey('friends-directory-alphabet-index'),
    );
    expect(
      tester.widget<ListView>(directoryList).padding,
      const EdgeInsets.only(bottom: 24),
    );
    expect(tester.getRect(directoryList).right, 320);
    expect(tester.getRect(alphabetIndex).right, 320);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('friend-directory-header')),
        matching: find.byKey(const ValueKey('friend-chat-blocks-entry')),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('friend-chat-blocks-entry')));
    await tester.pumpAndSettle();
    expect(find.text('黑名单'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('friend-directory-8')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('暂无消息'), findsOneWidget);
    expect(find.text('张三'), findsWidgets);
    expect(find.byKey(const ValueKey('friend-chat-actions')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('friend-chat-actions')));
    await tester.pumpAndSettle();
    expect(find.text('拉黑'), findsOneWidget);
    expect(find.text('修改备注'), findsOneWidget);
    expect(find.text('删除好友'), findsOneWidget);

    await tester.tap(find.text('修改备注'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('friend-chat-remark-field')),
      '宠友张三',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repository.updatedFriendId, 8);
    expect(repository.updatedRemark, '宠友张三');
    expect(find.text('宠友张三'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('黑名单页展示已删除好友并可解除拉黑', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _PageRelationsRepository()
      ..chatBlocks = [
        FriendChatBlock(
          id: 3,
          blockedUserId: 8,
          blockedUserName: '已删除好友',
          blockedAt: DateTime.utc(2026, 7, 27),
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: FriendChatBlocksPage(
          controller: FriendChatBlocksController(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已删除好友'), findsOneWidget);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xFFDEE9FF));
    expect(find.widgetWithText(TextButton, '解除拉黑'), findsOneWidget);
    expect(find.byIcon(Icons.person_add_alt_rounded), findsNothing);
    await tester.tap(find.byKey(const ValueKey('friend-chat-unblock-8')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('解除').last);
    await tester.pumpAndSettle();

    expect(repository.unblockedUserIds, [8]);
    expect(find.text('黑名单为空'), findsOneWidget);
  });
}

class _PageRelationsRepository implements FriendRelationsRepositoryGateway {
  SearchUserResult searchResult = const SearchUserResult(found: false);
  SendFriendRequestResult sendResult = const SendFriendRequestResult(
    success: true,
    status: SendFriendRequestStatus.sent,
    message: '好友申请已发送',
  );
  List<FriendRequest> pendingRequests = [];
  List<FriendshipSummary> friends = [];
  int pendingTotal = 0;
  String lastMessage = '';
  int acceptCalls = 0;
  int? updatedFriendId;
  String? updatedRemark;
  List<FriendChatBlock> chatBlocks = [];
  final List<int> unblockedUserIds = [];
  FriendRelationshipSummary relationshipSummary =
      const FriendRelationshipSummary(
        isFriend: false,
        outgoingPending: false,
        incomingPending: false,
      );

  @override
  Future<void> acceptFriendRequest({required int requestId}) async {
    acceptCalls += 1;
  }

  @override
  Future<void> deleteFriend({required int friendId}) async {}

  @override
  Future<void> blockFriendChat({required int blockedUserId}) async {}

  @override
  Future<void> unblockFriendChat({required int blockedUserId}) async {
    unblockedUserIds.add(blockedUserId);
    chatBlocks = chatBlocks
        .where((item) => item.blockedUserId != blockedUserId)
        .toList();
  }

  @override
  Future<FriendPage<FriendChatBlock>> loadFriendChatBlocks({
    required int page,
    required int pageSize,
  }) async {
    return FriendPage<FriendChatBlock>(
      items: page == 1 ? chatBlocks : const [],
      page: page,
      pageSize: pageSize,
      total: chatBlocks.length,
      totalPages: chatBlocks.isEmpty ? 0 : 1,
    );
  }

  @override
  Future<FriendPage<FriendRequest>> loadFriendRequests({
    required FriendRequestStatus status,
    required int page,
    required int pageSize,
  }) async {
    return FriendPage<FriendRequest>(
      items: page == 1 ? pendingRequests : const [],
      page: page,
      pageSize: pageSize,
      total: pendingTotal == 0 ? pendingRequests.length : pendingTotal,
      totalPages: pendingRequests.isEmpty ? 0 : 1,
    );
  }

  @override
  Future<FriendPage<FriendshipSummary>> loadFriends({
    required int page,
    required int pageSize,
  }) async {
    return FriendPage<FriendshipSummary>(
      items: friends,
      page: page,
      pageSize: pageSize,
      total: friends.length,
      totalPages: friends.isEmpty ? 0 : 1,
    );
  }

  @override
  Future<FriendRelationshipSummary> loadRelationshipSummary({
    required int targetUserId,
  }) async {
    return relationshipSummary;
  }

  @override
  Future<void> rejectFriendRequest({required int requestId}) async {}

  @override
  Future<SearchUserResult> searchUserByPhone({required String phone}) async {
    return searchResult;
  }

  @override
  Future<SendFriendRequestResult> sendFriendRequest({
    required int receiverId,
    required String message,
  }) async {
    lastMessage = message;
    return sendResult;
  }

  @override
  Future<void> updateFriendRemark({
    required int friendId,
    required String remark,
  }) async {
    updatedFriendId = friendId;
    updatedRemark = remark;
  }
}

class _NoopMessagingController extends FriendsMessagingController {
  _NoopMessagingController(FriendsSocketClient socket)
    : super(
        ownerUserId: 1,
        repository: _NoopFriendsRepository(),
        localStore: FriendsLocalStore(
          FriendsDatabase.production(fileName: 'unused_directory_test.db'),
        ),
        socket: socket,
        onSessionRevoked: () async {},
      );

  @override
  Future<void> stop({bool clearLocalData = false}) async {}

  @override
  Future<void> close({bool clearLocalData = false}) async {}

  @override
  Future<List<FriendMessage>> loadMessages(
    String conversationId, {
    int limit = FriendsMessagingController.historyPageSize,
  }) async => const [];

  @override
  Future<void> setActiveConversation(FriendshipSummary friend) async {}

  @override
  Future<void> updateFriendSummary(FriendshipSummary friend) async {}

  @override
  Future<FriendPage<FriendMessage>> syncConversation(
    FriendshipSummary friend, {
    required int page,
  }) async {
    return FriendPage<FriendMessage>(
      items: const [],
      page: page,
      pageSize: FriendsMessagingController.historyPageSize,
      total: 0,
      totalPages: 0,
    );
  }
}

class _NoopFriendsRepository implements FriendsRepositoryGateway {
  @override
  Future<FriendPage<FriendshipSummary>> loadFriends({
    required int page,
    required int pageSize,
  }) async => FriendPage<FriendshipSummary>(
    items: const [],
    page: page,
    pageSize: pageSize,
    total: 0,
    totalPages: 0,
  );

  @override
  Future<FriendPage<FriendMessage>> loadMessageHistory({
    required int friendId,
    required int page,
    required int pageSize,
  }) async => FriendPage<FriendMessage>(
    items: const [],
    page: page,
    pageSize: pageSize,
    total: 0,
    totalPages: 0,
  );

  @override
  Future<int> loadUnreadCount() async => 0;

  @override
  Future<void> markMessageRead({
    required String messageId,
    required String conversationId,
  }) async {}
}

class _PageRelationsSocket implements FriendRelationsSocketGateway {
  final _newRequests = StreamController<FriendRequest>.broadcast();
  final _accepted = StreamController<FriendRequestAcceptedEvent>.broadcast();
  final _rejected = StreamController<FriendRequestRejectedEvent>.broadcast();
  final _deleted = StreamController<FriendshipDeletedEvent>.broadcast();

  @override
  Stream<FriendRequestAcceptedEvent> get acceptedFriendRequests =>
      _accepted.stream;
  @override
  Stream<FriendshipDeletedEvent> get deletedFriendships => _deleted.stream;
  @override
  Stream<FriendRequest> get newFriendRequests => _newRequests.stream;
  @override
  Stream<FriendRequestRejectedEvent> get rejectedFriendRequests =>
      _rejected.stream;

  Future<void> close() async {
    await _newRequests.close();
    await _accepted.close();
    await _rejected.close();
    await _deleted.close();
  }
}
