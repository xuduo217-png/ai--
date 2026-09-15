import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/messaging/in_app_message_event.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_database.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_local_store.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_media_uploader.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_repository.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_socket_client.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_media_content.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_messaging_models.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_voice_content.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_chat_controller.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friends_messaging_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late FriendsDatabase database;
  late FriendsLocalStore store;
  late _FakeRepository repository;
  late _FakeSocket socket;
  late _FakeMediaUploader mediaUploader;
  late FriendsMessagingController controller;
  late Directory mediaDirectory;
  var sessionRevoked = false;

  setUp(() async {
    database = FriendsDatabase.withFactory(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    store = FriendsLocalStore(database);
    repository = _FakeRepository();
    socket = _FakeSocket();
    mediaUploader = _FakeMediaUploader();
    mediaDirectory = await Directory.systemTemp.createTemp(
      'friend-message-media-',
    );
    controller = FriendsMessagingController(
      ownerUserId: 1,
      repository: repository,
      localStore: store,
      socket: socket,
      mediaUploader: mediaUploader,
      onSessionRevoked: () async => sessionRevoked = true,
    );
  });

  tearDown(() async {
    await controller.close();
    controller.dispose();
    await database.close();
    await mediaDirectory.delete(recursive: true);
  });

  test('启动时本地会话先于网络连接展示', () async {
    await store.open();
    await store.persistMessage(
      ownerUserId: 1,
      message: _message(messageId: 'local-1'),
      friend: _friend,
      incrementUnread: true,
      restoreHidden: true,
    );
    socket.pauseConnection = true;

    final startup = controller.start();
    await _waitFor(() => controller.conversations.isNotEmpty);

    expect(controller.loading, isFalse);
    expect(controller.conversations.single.lastMessage, '你好');
    expect(socket.fetchOfflineCalls, 0);

    socket.completeConnection();
    await startup;
  });

  test('资料更新后活动聊天立即使用最新用户头像', () {
    final chatController = FriendChatController(
      messagingController: controller,
      friend: _friend,
    );
    addTearDown(chatController.dispose);
    var notifications = 0;
    chatController.addListener(() => notifications += 1);

    controller.updateCurrentUserAvatar(' /uploads/new-avatar.jpg ');

    expect(controller.currentUserAvatar, '/uploads/new-avatar.jpg');
    expect(chatController.currentUserAvatar, '/uploads/new-avatar.jpg');
    expect(notifications, 1);

    controller.updateCurrentUserAvatar('/uploads/new-avatar.jpg');
    expect(notifications, 1);

    controller.updateCurrentUserAvatar('  ');
    expect(controller.currentUserAvatar, isNull);
    expect(chatController.currentUserAvatar, isNull);
    expect(notifications, 2);
  });

  test('离线消息在落库后确认且重复事件不重复增加未读', () async {
    socket.onAcknowledgeOffline = (ids) async {
      expect(await store.getMessageCount(1, '1_2'), 1);
      expect(await store.getTotalUnreadCount(1), 1);
    };
    await controller.start();

    final offline = _message(messageId: 'offline-1', deliveryMode: 'offline');
    socket.emitMessage(offline);
    socket.emitMessage(offline);
    await _waitFor(() => socket.offlineAcknowledgements.length == 2);

    expect(await store.getMessageCount(1, '1_2'), 1);
    expect(controller.totalUnreadCount, 1);
    expect(socket.offlineAcknowledgements, [
      ['offline-1'],
      ['offline-1'],
    ]);
  });

  test('活跃会话收到消息立即清零未读并同步已读', () async {
    await controller.start();
    await controller.setActiveConversation(_friend);

    socket.emitMessage(_message(messageId: 'active-1'));
    await _waitFor(() => socket.readCalls.isNotEmpty);

    final saved = (await store.getMessages(1, '1_2')).single;
    expect(saved.isRead, isTrue);
    expect(saved.readSynced, isTrue);
    expect(controller.totalUnreadCount, 0);
    expect(socket.readCalls.single.messageId, 'active-1');
  });

  test('好友实时消息落库后发布一次全局展示事件', () async {
    repository.friends = [_friend];
    final events = <InAppMessageEvent>[];
    final subscription = controller.incomingMessageEvents.listen(events.add);
    addTearDown(subscription.cancel);
    await controller.start();

    final message = _message(messageId: 'banner-friend-1');
    socket.emitMessage(message);
    socket.emitMessage(message);
    await _waitFor(() => events.isNotEmpty);

    expect(events, hasLength(1));
    final event = events.single;
    expect(event.conversationId, '1_2');
    expect(event.title, _friend.displayName);
    expect(event.preview, '你好');
  });

  test('好友全分页同步且历史请求并发不超过 4，单项失败不清空其他会话', () async {
    repository.friends = List.generate(
      6,
      (index) => FriendshipSummary(
        friendId: index + 2,
        friendName: '好友${index + 2}',
        lastChatAt: DateTime.utc(2026, 7, 24, 8, index),
      ),
    );
    repository.friendPageSize = 3;
    repository.historyDelay = const Duration(milliseconds: 10);
    repository.failingHistoryFriendId = 4;
    for (final friend in repository.friends) {
      repository.histories[friend.friendId] = [
        _message(
          messageId: 'message-${friend.friendId}',
          conversationId: '1_${friend.friendId}',
          senderId: friend.friendId,
        ),
      ];
    }

    await controller.start();

    expect(repository.loadedFriendPages, [1, 2]);
    expect(repository.maxConcurrentHistoryLoads, lessThanOrEqualTo(4));
    expect(controller.conversations, hasLength(6));
    expect(await store.getMessageCount(1, '1_2'), 1);
    expect(await store.getMessageCount(1, '1_4'), 0);
    expect(controller.errorMessage, isNotNull);
  });

  test('乐观发送失败后可用原 tempMessageId 重试并替换服务端 ID', () async {
    socket.sendFailuresRemaining = 1;
    await controller.start();

    final tempId = await controller.sendText(_friend, '请问在吗');
    var saved = (await store.getMessages(1, '1_2')).single;
    expect(saved.tempMessageId, tempId);
    expect(saved.sendStatus, MessageSendStatus.failed);

    await controller.retryMessage(_friend, saved);
    saved = (await store.getMessages(1, '1_2')).single;
    expect(saved.tempMessageId, tempId);
    expect(saved.messageId, 'server-$tempId');
    expect(saved.sendStatus, MessageSendStatus.sent);
    expect(socket.sentTempIds, [tempId, tempId]);
  });

  test('图片上传成功后以结构化内容发送并保留本地预览路径', () async {
    final image = await File(
      '${mediaDirectory.path}/photo.jpg',
    ).writeAsBytes([1, 2, 3]);
    await controller.start();

    final tempId = await controller.sendMedia(
      _friend,
      FriendMediaSendRequest(
        type: FriendMediaType.image,
        localFilePath: image.path,
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        size: 3,
        width: 800,
        height: 600,
      ),
    );

    final saved = (await store.getMessages(1, '1_2')).single;
    final content = FriendMediaContent.parse(saved.content);
    expect(mediaUploader.imageCalls, 1);
    expect(mediaUploader.lastImageMimeType, 'image/jpeg');
    expect(socket.sentMessageTypes, ['image']);
    expect(saved.tempMessageId, tempId);
    expect(saved.messageId, 'server-$tempId');
    expect(saved.localFilePath, image.path);
    expect(saved.localFileExists, isTrue);
    expect(saved.mediaStage, MediaTransferStage.sent);
    expect(content?.url, '/uploads/friend-photo.jpg');
    expect(content?.width, 800);
    expect(content?.height, 600);
  });

  test('媒体上传后 Socket 失败，重试复用远端地址且不重复上传', () async {
    final video = await File(
      '${mediaDirectory.path}/clip.mp4',
    ).writeAsBytes([4, 5, 6]);
    socket.sendFailuresRemaining = 1;
    await controller.start();

    await controller.sendMedia(
      _friend,
      FriendMediaSendRequest(
        type: FriendMediaType.video,
        localFilePath: video.path,
        fileName: 'clip.mp4',
        mimeType: 'video/mp4',
        size: 3,
        duration: 65,
      ),
    );
    var saved = (await store.getMessages(1, '1_2')).single;
    final firstTempId = saved.tempMessageId;
    expect(saved.sendStatus, MessageSendStatus.failed);
    expect(FriendMediaContent.parse(saved.content)?.url, '/uploads/clip.mp4');

    await controller.retryMessage(_friend, saved);
    saved = (await store.getMessages(1, '1_2')).single;

    expect(mediaUploader.videoCalls, 1);
    expect(mediaUploader.lastVideoMimeType, 'video/mp4');
    expect(socket.sentMessageTypes, ['video', 'video']);
    expect(saved.tempMessageId, isNot(firstTempId));
    expect(saved.messageId, 'server-${saved.tempMessageId}');
    expect(saved.sendStatus, MessageSendStatus.sent);
    expect(await store.getMessageCount(1, '1_2'), 1);
  });

  test('语音上传后 Socket 失败，重试相对 URL 时不重复上传', () async {
    final voice = await File(
      '${mediaDirectory.path}/voice.m4a',
    ).writeAsBytes([7, 8, 9]);
    socket.sendFailuresRemaining = 1;
    await controller.start();

    await controller.sendVoice(
      _friend,
      FriendVoiceSendRequest(
        localFilePath: voice.path,
        duration: 7,
        fileName: 'voice.m4a',
        size: 3,
      ),
    );
    var saved = (await store.getMessages(1, '1_2')).single;
    final firstTempId = saved.tempMessageId;
    expect(saved.sendStatus, MessageSendStatus.failed);
    expect(saved.localFilePath, voice.path);
    expect(FriendVoiceContent.parse(saved.content)?.url, '/uploads/voice.m4a');
    expect(FriendVoiceContent.parse(saved.content)?.duration, 7);

    await controller.retryMessage(_friend, saved);
    saved = (await store.getMessages(1, '1_2')).single;

    expect(mediaUploader.voiceCalls, 1);
    expect(socket.sentMessageTypes, ['voice', 'voice']);
    expect(saved.tempMessageId, isNot(firstTempId));
    expect(saved.sendStatus, MessageSendStatus.sent);
    expect(saved.mediaStage, MediaTransferStage.sent);
  });

  test('语音本地文件失效且没有远程 URL 时不可重试', () async {
    await controller.start();
    final now = DateTime.utc(2026, 7, 24, 10);
    await store.persistMessage(
      ownerUserId: 1,
      message: FriendMessage(
        tempMessageId: 'missing-voice',
        conversationId: '1_2',
        senderId: 1,
        receiverId: 2,
        messageType: 'voice',
        content: const FriendVoiceContent(
          url: '/tmp/no-longer-exists.m4a',
          duration: 5,
        ).toMessageContent(),
        sendStatus: MessageSendStatus.failed,
        isRead: false,
        readSynced: true,
        createdAt: now,
        updatedAt: now,
        localFilePath: '/tmp/no-longer-exists.m4a',
        localFileExists: true,
        mediaStage: MediaTransferStage.failed,
      ),
      friend: _friend,
      incrementUnread: false,
      restoreHidden: true,
    );

    await controller.retryMessage(
      _friend,
      (await store.getMessages(1, '1_2')).single,
    );

    final saved = (await store.getMessages(1, '1_2')).single;
    expect(saved.sendStatus, MessageSendStatus.failed);
    expect(saved.localFileExists, isFalse);
    expect(controller.errorMessage, contains('重新录制'));
    expect(mediaUploader.voiceCalls, 0);
    expect(socket.sentMessageTypes, isEmpty);
  });

  test('媒体上传失败时保留单条失败消息且不调用 Socket', () async {
    final image = await File(
      '${mediaDirectory.path}/broken.jpg',
    ).writeAsBytes([1]);
    mediaUploader.failure = StateError('上传失败');
    await controller.start();

    await controller.sendMedia(
      _friend,
      FriendMediaSendRequest(
        type: FriendMediaType.image,
        localFilePath: image.path,
        fileName: 'broken.jpg',
        mimeType: 'image/jpeg',
        size: 1,
      ),
    );

    final saved = (await store.getMessages(1, '1_2')).single;
    expect(saved.sendStatus, MessageSendStatus.failed);
    expect(saved.mediaStage, MediaTransferStage.failed);
    expect(socket.sentTempIds, isEmpty);
    expect(await store.getMessageCount(1, '1_2'), 1);
  });

  test('重试时本地媒体已丢失则保持失败并提示重新选择', () async {
    await controller.start();
    final now = DateTime.utc(2026, 7, 24, 10);
    await store.persistMessage(
      ownerUserId: 1,
      message: FriendMessage(
        tempMessageId: 'missing-media',
        conversationId: '1_2',
        senderId: 1,
        receiverId: 2,
        messageType: 'image',
        content: const FriendMediaContent(
          url: '/tmp/no-longer-exists.jpg',
        ).toMessageContent(),
        sendStatus: MessageSendStatus.failed,
        isRead: false,
        readSynced: true,
        createdAt: now,
        updatedAt: now,
        localFilePath: '/tmp/no-longer-exists.jpg',
        localFileExists: true,
        mediaStage: MediaTransferStage.failed,
      ),
      friend: _friend,
      incrementUnread: false,
      restoreHidden: true,
    );

    final chatController = FriendChatController(
      messagingController: controller,
      friend: _friend,
    );
    addTearDown(chatController.dispose);
    await chatController.retry((await store.getMessages(1, '1_2')).single);

    final saved = (await store.getMessages(1, '1_2')).single;
    expect(saved.sendStatus, MessageSendStatus.failed);
    expect(saved.localFileExists, isFalse);
    expect(controller.errorMessage, contains('文件已失效'));
    expect(chatController.takeNotice(), '文件已失效，请重新选择');
    expect(mediaUploader.imageCalls, 0);
    expect(socket.sentTempIds, isEmpty);
  });

  test('session revoked 停止连接并只清理当前账号数据', () async {
    await store.open();
    await store.persistMessage(
      ownerUserId: 1,
      message: _message(messageId: 'owner-1'),
      friend: _friend,
      incrementUnread: true,
      restoreHidden: true,
    );
    await store.persistMessage(
      ownerUserId: 9,
      message: _message(messageId: 'owner-9'),
      friend: _friend,
      incrementUnread: false,
      restoreHidden: true,
    );
    await controller.start();

    socket.emitSessionRevoked();
    await _waitFor(() => sessionRevoked);

    expect(socket.stopCalls, greaterThan(0));
    expect(await store.getConversations(1), isEmpty);
    expect(await store.getMessages(9, '1_2'), hasLength(1));
  });
}

const _friend = FriendshipSummary(friendId: 2, friendName: '小明');

FriendMessage _message({
  String? messageId,
  String? tempMessageId,
  String conversationId = '1_2',
  int senderId = 2,
  String? deliveryMode,
}) {
  final now = DateTime.utc(2026, 7, 24, 8);
  return FriendMessage(
    messageId: messageId,
    tempMessageId: tempMessageId,
    conversationId: conversationId,
    senderId: senderId,
    receiverId: senderId == 1 ? 2 : 1,
    messageType: 'text',
    content: '你好',
    sendStatus: MessageSendStatus.sent,
    isRead: false,
    readSynced: true,
    createdAt: now,
    updatedAt: now,
    deliveryMode: deliveryMode,
  );
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail('Condition was not met before timeout.');
}

class _FakeRepository implements FriendsRepositoryGateway {
  List<FriendshipSummary> friends = [];
  final Map<int, List<FriendMessage>> histories = {};
  final List<int> loadedFriendPages = [];
  int friendPageSize = 50;
  int unreadCount = 0;
  int? failingHistoryFriendId;
  Duration historyDelay = Duration.zero;
  int concurrentHistoryLoads = 0;
  int maxConcurrentHistoryLoads = 0;

  @override
  Future<FriendPage<FriendshipSummary>> loadFriends({
    required int page,
    required int pageSize,
  }) async {
    loadedFriendPages.add(page);
    final start = (page - 1) * friendPageSize;
    final end = (start + friendPageSize).clamp(0, friends.length);
    final items = start >= friends.length
        ? <FriendshipSummary>[]
        : friends.sublist(start, end);
    final totalPages = friends.isEmpty
        ? 0
        : (friends.length / friendPageSize).ceil();
    return FriendPage<FriendshipSummary>(
      items: items,
      page: page,
      pageSize: friendPageSize,
      total: friends.length,
      totalPages: totalPages,
    );
  }

  @override
  Future<FriendPage<FriendMessage>> loadMessageHistory({
    required int friendId,
    required int page,
    required int pageSize,
  }) async {
    concurrentHistoryLoads += 1;
    if (concurrentHistoryLoads > maxConcurrentHistoryLoads) {
      maxConcurrentHistoryLoads = concurrentHistoryLoads;
    }
    try {
      if (historyDelay != Duration.zero) {
        await Future<void>.delayed(historyDelay);
      }
      if (friendId == failingHistoryFriendId) throw Exception('单项同步失败');
      final items = histories[friendId] ?? const <FriendMessage>[];
      return FriendPage<FriendMessage>(
        items: items,
        page: page,
        pageSize: pageSize,
        total: items.length,
        totalPages: items.isEmpty ? 0 : 1,
      );
    } finally {
      concurrentHistoryLoads -= 1;
    }
  }

  @override
  Future<int> loadUnreadCount() async => unreadCount;

  @override
  Future<void> markMessageRead({
    required String messageId,
    required String conversationId,
  }) async {}
}

class _ReadCall {
  const _ReadCall(this.messageId, this.conversationId);

  final String messageId;
  final String conversationId;
}

class _FakeSocket implements FriendsSocketGateway {
  final messageController = StreamController<FriendMessage>.broadcast(
    sync: true,
  );
  final ackController = StreamController<FriendMessageAck>.broadcast(
    sync: true,
  );
  final readController = StreamController<FriendReadReceipt>.broadcast(
    sync: true,
  );
  final friendshipController =
      StreamController<FriendshipDeletedEvent>.broadcast(sync: true);
  final revokedController = StreamController<SessionRevokedEvent>.broadcast(
    sync: true,
  );
  final connectionController = StreamController<bool>.broadcast(sync: true);
  final errorController = StreamController<Object>.broadcast(sync: true);

  bool pauseConnection = false;
  bool _connected = false;
  Completer<void>? connectionCompleter;
  int fetchOfflineCalls = 0;
  int stopCalls = 0;
  int sendFailuresRemaining = 0;
  final List<List<String>> offlineAcknowledgements = [];
  final List<_ReadCall> readCalls = [];
  final List<String> sentTempIds = [];
  final List<String> sentMessageTypes = [];
  Future<void> Function(List<String> ids)? onAcknowledgeOffline;

  @override
  bool get isConnected => _connected;
  @override
  Stream<FriendMessage> get messages => messageController.stream;
  @override
  Stream<FriendMessageAck> get acknowledgements => ackController.stream;
  @override
  Stream<FriendReadReceipt> get readReceipts => readController.stream;
  @override
  Stream<FriendshipDeletedEvent> get friendshipDeleted =>
      friendshipController.stream;
  @override
  Stream<SessionRevokedEvent> get sessionRevoked => revokedController.stream;
  @override
  Stream<bool> get connectionChanges => connectionController.stream;
  @override
  Stream<Object> get errors => errorController.stream;

  @override
  Future<void> connect() async {
    if (_connected) return;
    if (pauseConnection) {
      connectionCompleter ??= Completer<void>();
      await connectionCompleter!.future;
    }
    _connected = true;
    connectionController.add(true);
  }

  void completeConnection() {
    connectionCompleter?.complete();
  }

  @override
  Future<void> fetchOfflineMessages() async {
    fetchOfflineCalls += 1;
  }

  @override
  Future<void> acknowledgeOfflineMessages(List<String> messageIds) async {
    offlineAcknowledgements.add(List<String>.from(messageIds));
    await onAcknowledgeOffline?.call(messageIds);
  }

  @override
  Future<void> markMessageRead({
    required String messageId,
    required String conversationId,
  }) async {
    readCalls.add(_ReadCall(messageId, conversationId));
  }

  @override
  Future<FriendMessageAck> sendTextMessage({
    required int receiverId,
    required String content,
    required String tempMessageId,
  }) => sendMessage(
    receiverId: receiverId,
    messageType: 'text',
    content: content,
    tempMessageId: tempMessageId,
  );

  @override
  Future<FriendMessageAck> sendMessage({
    required int receiverId,
    required String messageType,
    required String content,
    required String tempMessageId,
  }) async {
    sentTempIds.add(tempMessageId);
    sentMessageTypes.add(messageType);
    if (sendFailuresRemaining > 0) {
      sendFailuresRemaining -= 1;
      throw TimeoutException('发送超时');
    }
    return FriendMessageAck(
      tempMessageId: tempMessageId,
      success: true,
      messageId: 'server-$tempMessageId',
    );
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    _connected = false;
  }

  @override
  Future<void> dispose() async {
    await messageController.close();
    await ackController.close();
    await readController.close();
    await friendshipController.close();
    await revokedController.close();
    await connectionController.close();
    await errorController.close();
  }

  void emitMessage(FriendMessage message) => messageController.add(message);

  void emitSessionRevoked() {
    revokedController.add(const SessionRevokedEvent(reason: 'logout'));
  }
}

class _FakeMediaUploader implements FriendsMediaUploaderGateway {
  int imageCalls = 0;
  int videoCalls = 0;
  int voiceCalls = 0;
  String? lastImageMimeType;
  String? lastVideoMimeType;
  Object? failure;

  @override
  Future<FriendsMediaUploadResult> uploadImage({
    required String filePath,
    required String fileName,
    required String mimeType,
  }) async {
    imageCalls += 1;
    lastImageMimeType = mimeType;
    final error = failure;
    if (error != null) throw error;
    return const FriendsMediaUploadResult(
      url: '/uploads/friend-photo.jpg',
      width: 800,
      height: 600,
      size: 3,
      originalName: 'photo.jpg',
    );
  }

  @override
  Future<FriendsMediaUploadResult> uploadVideo({
    required String filePath,
    required String fileName,
    required String mimeType,
    String? thumbnailPath,
  }) async {
    videoCalls += 1;
    lastVideoMimeType = mimeType;
    final error = failure;
    if (error != null) throw error;
    return const FriendsMediaUploadResult(
      url: '/uploads/clip.mp4',
      thumbnail: '/uploads/clip-cover.jpg',
      size: 3,
      originalName: 'clip.mp4',
    );
  }

  @override
  Future<FriendsMediaUploadResult> uploadVoice({
    required String filePath,
    required String fileName,
    required String mimeType,
  }) async {
    voiceCalls += 1;
    final error = failure;
    if (error != null) throw error;
    return const FriendsMediaUploadResult(
      url: '/uploads/voice.m4a',
      size: 3,
      originalName: 'voice.m4a',
    );
  }
}
