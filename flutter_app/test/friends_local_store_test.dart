import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_database.dart';
import 'package:pet_hospital_flutter/features/friends/data/friends_local_store.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_messaging_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late FriendsDatabase database;
  late FriendsLocalStore store;

  setUp(() async {
    database = FriendsDatabase.withFactory(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    store = FriendsLocalStore(database);
    await store.open();
  });

  tearDown(() => database.close());

  test('相同服务端消息只落库一次且不重复增加未读', () async {
    final message = _message(
      messageId: 'message-1',
      senderId: 2,
      receiverId: 1,
    );

    final first = await _persistIncoming(store, message);
    final duplicate = await _persistIncoming(store, message);

    expect(first.inserted, isTrue);
    expect(duplicate.inserted, isFalse);
    expect(await store.getMessageCount(1, '1_2'), 1);
    expect(await store.getTotalUnreadCount(1), 1);
  });

  test('乐观消息 ACK 后替换为服务端 ID 和已发送状态', () async {
    final temporary = _message(
      tempMessageId: 'temp-1',
      senderId: 1,
      receiverId: 2,
      status: MessageSendStatus.sending,
    );
    await store.persistMessage(
      ownerUserId: 1,
      message: temporary,
      friend: _friend,
      incrementUnread: false,
      restoreHidden: true,
    );

    await store.acknowledgeMessage(
      ownerUserId: 1,
      tempMessageId: 'temp-1',
      messageId: 'server-1',
    );

    final messages = await store.getMessages(1, '1_2');
    expect(messages, hasLength(1));
    expect(messages.single.messageId, 'server-1');
    expect(messages.single.tempMessageId, 'temp-1');
    expect(messages.single.sendStatus, MessageSendStatus.sent);
  });

  test('撤回事件覆盖已有消息、清除未读并更新会话预览', () async {
    final original = _message(
      messageId: 'message-recalled',
      senderId: 2,
      receiverId: 1,
    );
    await _persistIncoming(store, original);

    await store.persistMessage(
      ownerUserId: 1,
      message: original.copyWith(
        content: '消息已撤回',
        isRead: true,
        isRevoked: true,
        revokedAt: DateTime.utc(2026, 7, 20, 10, 1),
        updatedAt: DateTime.utc(2026, 7, 20, 10, 1),
      ),
      friend: _friend,
      incrementUnread: false,
      restoreHidden: false,
    );

    final saved = (await store.getMessages(1, '1_2')).single;
    final conversation = (await store.getConversations(1)).single;
    expect(saved.isRevoked, isTrue);
    expect(saved.content, '消息已撤回');
    expect(saved.isRead, isTrue);
    expect(conversation.lastMessage, '消息已撤回');
    expect(conversation.unreadCount, 0);
    expect(await store.getTotalUnreadCount(1), 0);
  });

  test('message:new 早于 ACK 时合并临时行与服务端行', () async {
    await store.persistMessage(
      ownerUserId: 1,
      message: _message(
        tempMessageId: 'temp-race',
        senderId: 1,
        receiverId: 2,
        status: MessageSendStatus.sending,
      ),
      friend: _friend,
      incrementUnread: false,
      restoreHidden: true,
    );
    await store.persistMessage(
      ownerUserId: 1,
      message: _message(messageId: 'server-race', senderId: 1, receiverId: 2),
      friend: _friend,
      incrementUnread: false,
      restoreHidden: true,
    );

    await store.acknowledgeMessage(
      ownerUserId: 1,
      tempMessageId: 'temp-race',
      messageId: 'server-race',
    );

    final messages = await store.getMessages(1, '1_2');
    expect(messages, hasLength(1));
    expect(messages.single.messageId, 'server-race');
  });

  test('会话按最后消息倒序排列并支持名称搜索', () async {
    await _persistIncoming(
      store,
      _message(
        messageId: 'older',
        senderId: 2,
        receiverId: 1,
        at: DateTime.utc(2026, 7, 20),
      ),
      friend: _friend,
    );
    await _persistIncoming(
      store,
      _message(
        messageId: 'newer',
        conversationId: '1_3',
        senderId: 3,
        receiverId: 1,
        at: DateTime.utc(2026, 7, 21),
      ),
      friend: const FriendshipSummary(friendId: 3, friendName: '李医生'),
    );

    final conversations = await store.getConversations(1);
    final searchResult = await store.getConversations(1, search: '小明');

    expect(conversations.map((item) => item.friendId), [3, 2]);
    expect(searchResult.map((item) => item.friendId), [2]);
  });

  test('打开会话清零未读并保留待同步已读记录', () async {
    await _persistIncoming(
      store,
      _message(messageId: 'unread-1', senderId: 2, receiverId: 1),
    );
    await _persistIncoming(
      store,
      _message(
        messageId: 'unread-2',
        senderId: 2,
        receiverId: 1,
        at: DateTime.utc(2026, 7, 20, 10, 1),
      ),
    );

    final changed = await store.markConversationRead(
      ownerUserId: 1,
      conversationId: '1_2',
    );

    expect(changed.map((message) => message.messageId), [
      'unread-1',
      'unread-2',
    ]);
    expect(await store.getTotalUnreadCount(1), 0);
    expect(await store.getPendingReadMessages(1), hasLength(2));

    await store.markReadSynced(1, 'unread-1');
    expect(
      (await store.getPendingReadMessages(1)).single.messageId,
      'unread-2',
    );
  });

  test('本地隐藏会话后新消息会自动恢复显示', () async {
    await _persistIncoming(
      store,
      _message(messageId: 'before-hide', senderId: 2, receiverId: 1),
    );
    await store.hideConversation(1, '1_2');

    expect(await store.getConversations(1), isEmpty);

    await _persistIncoming(
      store,
      _message(
        messageId: 'after-hide',
        senderId: 2,
        receiverId: 1,
        at: DateTime.utc(2026, 7, 20, 10, 2),
      ),
    );

    final conversations = await store.getConversations(1);
    expect(conversations, hasLength(1));
    expect(conversations.single.hidden, isFalse);
    expect(conversations.single.lastMessage, '你好');
  });

  test('账号数据按 ownerUserId 隔离', () async {
    final message = _message(
      messageId: 'shared-id',
      senderId: 2,
      receiverId: 1,
    );
    await _persistIncoming(store, message);
    await store.persistMessage(
      ownerUserId: 9,
      message: message,
      friend: _friend,
      incrementUnread: false,
      restoreHidden: true,
    );

    expect(await store.getMessages(1, '1_2'), hasLength(1));
    expect(await store.getMessages(9, '1_2'), hasLength(1));
  });

  test('退出清理只删除当前账号的数据', () async {
    final message = _message(
      messageId: 'shared-id',
      senderId: 2,
      receiverId: 1,
    );
    await _persistIncoming(store, message);
    await store.persistMessage(
      ownerUserId: 9,
      message: message,
      friend: _friend,
      incrementUnread: false,
      restoreHidden: true,
    );

    await store.clearOwnerData(1);

    expect(await store.getMessages(1, '1_2'), isEmpty);
    expect(await store.getConversations(1), isEmpty);
    expect(await store.getMessages(9, '1_2'), hasLength(1));
  });

  test('重启恢复时将遗留 sending 消息标记为 failed', () async {
    await store.persistMessage(
      ownerUserId: 1,
      message: _message(
        tempMessageId: 'pending',
        senderId: 1,
        receiverId: 2,
        status: MessageSendStatus.sending,
      ),
      friend: _friend,
      incrementUnread: false,
      restoreHidden: true,
    );

    await store.failPendingMessages(1);

    expect(
      (await store.getMessages(1, '1_2')).single.sendStatus,
      MessageSendStatus.failed,
    );
  });

  test('重启恢复时上传中的媒体保留本地路径并转为可重试失败状态', () async {
    final createdAt = DateTime.utc(2026, 7, 24, 10);
    await store.persistMessage(
      ownerUserId: 1,
      message: FriendMessage(
        tempMessageId: 'uploading-media',
        conversationId: '1_2',
        senderId: 1,
        receiverId: 2,
        messageType: 'video',
        content: '{"url":"/tmp/clip.mp4","duration":12}',
        sendStatus: MessageSendStatus.sending,
        isRead: false,
        readSynced: true,
        createdAt: createdAt,
        updatedAt: createdAt,
        localFilePath: '/tmp/clip.mp4',
        localThumbnailPath: '/tmp/clip-cover.jpg',
        localFileExists: true,
        mediaStage: MediaTransferStage.uploading,
      ),
      friend: _friend,
      incrementUnread: false,
      restoreHidden: true,
    );

    await store.failPendingMessages(1);

    final saved = (await store.getMessages(1, '1_2')).single;
    expect(saved.sendStatus, MessageSendStatus.failed);
    expect(saved.mediaStage, MediaTransferStage.failed);
    expect(saved.localFilePath, '/tmp/clip.mp4');
    expect(saved.localThumbnailPath, '/tmp/clip-cover.jpg');
    expect(saved.localFileExists, isTrue);
  });
}

const _friend = FriendshipSummary(friendId: 2, friendName: '小明');

Future<PersistMessageResult> _persistIncoming(
  FriendsLocalStore store,
  FriendMessage message, {
  FriendshipSummary friend = _friend,
}) {
  return store.persistMessage(
    ownerUserId: 1,
    message: message,
    friend: friend,
    incrementUnread: true,
    restoreHidden: true,
  );
}

FriendMessage _message({
  String? messageId,
  String? tempMessageId,
  String conversationId = '1_2',
  required int senderId,
  required int receiverId,
  MessageSendStatus status = MessageSendStatus.sent,
  DateTime? at,
}) {
  final createdAt = at ?? DateTime.utc(2026, 7, 20, 10);
  return FriendMessage(
    messageId: messageId,
    tempMessageId: tempMessageId,
    conversationId: conversationId,
    senderId: senderId,
    receiverId: receiverId,
    messageType: 'text',
    content: '你好',
    sendStatus: status,
    isRead: false,
    readSynced: true,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}
