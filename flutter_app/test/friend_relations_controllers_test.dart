import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/friends/data/friend_relations_repository.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_database.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_local_store.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_repository.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_socket_client.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_messaging_models.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_relation_models.dart';
import 'package:pet_hospital_flutter/features/friends/friends_feature_session.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_requests_controller.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_chat_blocks_controller.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_search_controller.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friends_directory_controller.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friends_messaging_controller.dart';

void main() {
  test('通讯录合并全部分页、按 friendId 去重并按拼音分组', () async {
    final repository = _FakeRelationsRepository()
      ..friendPages = {
        1: _friendPage(
          page: 1,
          totalPages: 2,
          items: const [
            FriendshipSummary(friendId: 1, friendName: '张三'),
            FriendshipSummary(friendId: 2, friendName: 'Alice'),
          ],
        ),
        2: _friendPage(
          page: 2,
          totalPages: 2,
          items: const [
            FriendshipSummary(friendId: 1, friendName: '张三'),
            FriendshipSummary(friendId: 3, friendName: '#客服'),
          ],
        ),
      }
      ..pendingTotal = 4;
    final socket = _FakeRelationsSocket();
    final controller = FriendsDirectoryController(
      repository: repository,
      socket: socket,
    );

    await controller.start();

    expect(controller.friends.map((item) => item.friendId), [2, 1, 3]);
    expect(controller.sections.map((item) => item.letter), ['A', 'Z', '#']);
    expect(controller.pendingRequestCount, 4);

    controller.updateSearch('张');
    expect(controller.filteredFriends.single.friendId, 1);
    controller.updateSearch('');

    await controller.updateRemark(controller.friends[1], '李四');
    expect(controller.sections.map((item) => item.letter), ['A', 'L', '#']);
    expect(controller.friends[1].displayName, '李四');

    await controller.deleteFriend(controller.friends.first);
    expect(controller.friends.map((item) => item.friendId), [1, 3]);

    repository.pendingTotal = 5;
    socket.newRequests.add(
      FriendRequest.fromJson({
        'id': 9,
        'requesterId': 9,
        'requesterName': '新用户',
        'status': 'pending',
        'createdAt': '2026-07-25T08:00:00.000Z',
      }),
    );
    await _drainEvents();
    expect(controller.pendingRequestCount, 5);

    await controller.stop();
    controller.dispose();
    await socket.close();
  });

  test('好友申请接受防重复提交并立即移除、刷新角标', () async {
    final request = FriendRequest.fromJson({
      'id': 7,
      'requesterId': 8,
      'requesterName': '小顾',
      'status': 'pending',
      'createdAt': '2026-07-25T08:00:00.000Z',
    });
    final repository = _FakeRelationsRepository()
      ..pendingRequests = [request]
      ..pendingTotal = 1
      ..acceptGate = Completer<void>();
    final socket = _FakeRelationsSocket();
    var resolvedCalls = 0;
    final controller = FriendRequestsController(
      repository: repository,
      socket: socket,
      onRequestResolved: ({required accepted}) async {
        expect(accepted, isTrue);
        resolvedCalls += 1;
      },
    );
    await controller.start();

    final first = controller.accept(request);
    final duplicate = controller.accept(request);
    await duplicate;
    expect(repository.acceptCalls, 1);
    expect(controller.isProcessing(request.id), isTrue);

    repository.acceptGate!.complete();
    expect(await first, isTrue);
    expect(controller.requests, isEmpty);
    expect(resolvedCalls, 1);
    expect(controller.takeNotice(), contains('已接受'));

    controller.dispose();
    await socket.close();
  });

  test('手机号校验、搜索本人和 50 字申请边界', () async {
    final repository = _FakeRelationsRepository()
      ..searchResult = const SearchUserResult(
        found: true,
        user: UserSearchResult(id: 6, username: '当前用户', phone: '13800138000'),
      )
      ..sendResult = const SendFriendRequestResult(
        success: true,
        status: SendFriendRequestStatus.sent,
        message: '已发送',
      );
    final controller = FriendSearchController(
      ownerUserId: 6,
      repository: repository,
    );

    expect(await controller.search('123'), isFalse);
    expect(controller.errorMessage, '请输入正确的手机号');
    expect(await controller.search('13800138000'), isTrue);
    expect(controller.isSelfResult, isTrue);
    expect(await controller.sendRequest('你好'), isNull);

    repository.searchResult = const SearchUserResult(
      found: true,
      user: UserSearchResult(id: 8, username: '好友', phone: '13900139000'),
    );
    await controller.search('13900139000');
    expect(
      await controller.sendRequest(List<String>.filled(50, '好').join()),
      isNotNull,
    );
    expect(repository.lastMessage.length, 50);
    expect(
      await controller.sendRequest(List<String>.filled(51, '好').join()),
      isNull,
    );
    expect(controller.errorMessage, '申请附言最多 50 字');

    controller.dispose();
  });

  test('好友 Session 在暂停、恢复和关闭时统一管理两个控制器', () async {
    final repository = _FakeRelationsRepository();
    final socket = FriendsSocketClient(
      baseUrl: 'https://example.test',
      accessTokenProvider: () async => 'token',
    );
    final messaging = _LifecycleMessagingController(socket);
    final directory = _LifecycleDirectoryController(repository, socket);
    final session = FriendsFeatureSession(
      ownerUserId: 24,
      messagingController: messaging,
      directoryController: directory,
      socket: socket,
      repository: repository,
    );

    await session.start();
    await session.start();
    expect(messaging.startCalls, 1);
    expect(directory.startCalls, 1);

    session.updateCurrentUserAvatar(' /uploads/current-user.jpg ');
    expect(messaging.currentUserAvatar, '/uploads/current-user.jpg');

    await session.pause();
    expect(messaging.stopCalls, 1);
    expect(directory.stopCalls, 1);

    await session.resume();
    expect(messaging.startCalls, 2);
    expect(directory.startCalls, 2);

    await session.resume();
    expect(messaging.resumeCalls, 1);
    expect(directory.resumeCalls, 1);

    await session.close(clearLocalData: true);
    await session.close(clearLocalData: true);
    expect(messaging.closeCalls, 1);
    expect(messaging.lastClearLocalData, isTrue);
    expect(directory.stopCalls, 2);
    expect(directory.disposeCalls, 1);
  });

  test('黑名单控制器合并分页并支持好友关系删除后解除拉黑', () async {
    final repository = _FakeRelationsRepository()
      ..chatBlockPages = {
        1: FriendPage<FriendChatBlock>(
          items: [
            FriendChatBlock(
              id: 7,
              blockedUserId: 8,
              blockedUserName: '小顾',
              blockedAt: DateTime.utc(2026, 7, 27),
            ),
          ],
          page: 1,
          pageSize: 100,
          total: 1,
          totalPages: 1,
        ),
      };
    final controller = FriendChatBlocksController(repository: repository);

    await controller.initialize();
    expect(controller.blocks.single.blockedUserName, '小顾');

    final removed = await controller.unblock(controller.blocks.single);
    expect(removed, isTrue);
    expect(controller.blocks, isEmpty);
    expect(repository.unblockedUserIds, [8]);

    controller.dispose();
  });
}

FriendPage<FriendshipSummary> _friendPage({
  required int page,
  required int totalPages,
  required List<FriendshipSummary> items,
}) {
  return FriendPage<FriendshipSummary>(
    items: items,
    page: page,
    pageSize: 100,
    total: 4,
    totalPages: totalPages,
  );
}

Future<void> _drainEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeRelationsRepository implements FriendRelationsRepositoryGateway {
  Map<int, FriendPage<FriendChatBlock>> chatBlockPages = {};
  final List<int> unblockedUserIds = [];
  Map<int, FriendPage<FriendshipSummary>> friendPages = {
    1: _friendPage(page: 1, totalPages: 1, items: const []),
  };
  List<FriendRequest> pendingRequests = [];
  int pendingTotal = 0;
  int acceptCalls = 0;
  Completer<void>? acceptGate;
  SearchUserResult searchResult = const SearchUserResult(found: false);
  SendFriendRequestResult sendResult = const SendFriendRequestResult(
    success: false,
    status: SendFriendRequestStatus.outgoingPending,
    message: '等待处理',
  );
  String lastMessage = '';

  @override
  Future<void> acceptFriendRequest({required int requestId}) async {
    acceptCalls += 1;
    await acceptGate?.future;
  }

  @override
  Future<void> deleteFriend({required int friendId}) async {}

  @override
  Future<void> blockFriendChat({required int blockedUserId}) async {}

  @override
  Future<void> unblockFriendChat({required int blockedUserId}) async {
    unblockedUserIds.add(blockedUserId);
  }

  @override
  Future<FriendPage<FriendChatBlock>> loadFriendChatBlocks({
    required int page,
    required int pageSize,
  }) async {
    return chatBlockPages[page] ??
        FriendPage<FriendChatBlock>(
          items: const [],
          page: page,
          pageSize: pageSize,
          total: 0,
          totalPages: 0,
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
      total: pendingTotal,
      totalPages: pendingTotal == 0 ? 0 : 1,
    );
  }

  @override
  Future<FriendPage<FriendshipSummary>> loadFriends({
    required int page,
    required int pageSize,
  }) async {
    return friendPages[page] ??
        _friendPage(page: page, totalPages: page, items: const []);
  }

  @override
  Future<FriendRelationshipSummary> loadRelationshipSummary({
    required int targetUserId,
  }) async {
    return const FriendRelationshipSummary(
      isFriend: false,
      outgoingPending: false,
      incomingPending: false,
    );
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
  }) async {}
}

class _FakeRelationsSocket implements FriendRelationsSocketGateway {
  final newRequests = StreamController<FriendRequest>.broadcast(sync: true);
  final acceptedRequests =
      StreamController<FriendRequestAcceptedEvent>.broadcast(sync: true);
  final rejectedRequests =
      StreamController<FriendRequestRejectedEvent>.broadcast(sync: true);
  final deletions = StreamController<FriendshipDeletedEvent>.broadcast(
    sync: true,
  );

  @override
  Stream<FriendRequestAcceptedEvent> get acceptedFriendRequests =>
      acceptedRequests.stream;

  @override
  Stream<FriendshipDeletedEvent> get deletedFriendships => deletions.stream;

  @override
  Stream<FriendRequest> get newFriendRequests => newRequests.stream;

  @override
  Stream<FriendRequestRejectedEvent> get rejectedFriendRequests =>
      rejectedRequests.stream;

  Future<void> close() async {
    await newRequests.close();
    await acceptedRequests.close();
    await rejectedRequests.close();
    await deletions.close();
  }
}

class _LifecycleDirectoryController extends FriendsDirectoryController {
  _LifecycleDirectoryController(
    FriendRelationsRepositoryGateway repository,
    FriendRelationsSocketGateway socket,
  ) : super(repository: repository, socket: socket);

  int startCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> start() async => startCalls += 1;

  @override
  Future<void> resume() async => resumeCalls += 1;

  @override
  Future<void> stop() async => stopCalls += 1;

  @override
  void dispose() {
    disposeCalls += 1;
    super.dispose();
  }
}

class _LifecycleMessagingController extends FriendsMessagingController {
  _LifecycleMessagingController(FriendsSocketClient socket)
    : super(
        ownerUserId: 24,
        repository: _LifecycleFriendsRepository(),
        localStore: FriendsLocalStore(
          FriendsDatabase.production(fileName: 'unused_lifecycle_test.db'),
        ),
        socket: socket,
        onSessionRevoked: () async {},
      );

  int startCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  int closeCalls = 0;
  bool? lastClearLocalData;

  @override
  Future<void> start() async => startCalls += 1;

  @override
  Future<void> resume() async => resumeCalls += 1;

  @override
  Future<void> stop({bool clearLocalData = false}) async {
    stopCalls += 1;
    lastClearLocalData = clearLocalData;
  }

  @override
  Future<void> close({bool clearLocalData = false}) async {
    closeCalls += 1;
    lastClearLocalData = clearLocalData;
  }
}

class _LifecycleFriendsRepository implements FriendsRepositoryGateway {
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
