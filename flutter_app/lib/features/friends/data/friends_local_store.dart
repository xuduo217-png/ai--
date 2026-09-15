import 'package:sqflite/sqflite.dart';

import '../domain/friend_messaging_models.dart';
import 'friends_database.dart';

class PersistMessageResult {
  const PersistMessageResult({
    required this.inserted,
    required this.totalUnreadCount,
  });

  final bool inserted;
  final int totalUnreadCount;
}

class FriendsLocalStore {
  FriendsLocalStore(this._friendsDatabase);

  final FriendsDatabase _friendsDatabase;

  Future<void> open() async {
    await _friendsDatabase.database;
  }

  Future<List<FriendConversation>> getConversations(
    int ownerUserId, {
    String search = '',
  }) async {
    final database = await _friendsDatabase.database;
    final normalizedSearch = search.trim();
    final rows = await database.query(
      'friend_conversations',
      where: normalizedSearch.isEmpty
          ? 'owner_user_id = ? AND hidden = 0'
          : 'owner_user_id = ? AND hidden = 0 AND friend_name LIKE ? ESCAPE \'\\\'',
      whereArgs: normalizedSearch.isEmpty
          ? [ownerUserId]
          : [ownerUserId, '%${_escapeLike(normalizedSearch)}%'],
      orderBy: 'last_message_at DESC, updated_at DESC',
    );
    return rows.map(_conversationFromRow).toList(growable: false);
  }

  Future<FriendConversation?> getConversation(
    int ownerUserId,
    String conversationId,
  ) async {
    final database = await _friendsDatabase.database;
    final rows = await database.query(
      'friend_conversations',
      where: 'owner_user_id = ? AND conversation_id = ?',
      whereArgs: [ownerUserId, conversationId],
      limit: 1,
    );
    return rows.isEmpty ? null : _conversationFromRow(rows.first);
  }

  Future<List<FriendMessage>> getMessages(
    int ownerUserId,
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final database = await _friendsDatabase.database;
    final rows = await database.query(
      'friend_messages',
      where: 'owner_user_id = ? AND conversation_id = ?',
      whereArgs: [ownerUserId, conversationId],
      orderBy: 'created_at DESC, local_id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.reversed.map(_messageFromRow).toList(growable: false);
  }

  Future<int> getMessageCount(int ownerUserId, String conversationId) async {
    final database = await _friendsDatabase.database;
    final result = await database.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM friend_messages
      WHERE owner_user_id = ? AND conversation_id = ?
      ''',
      [ownerUserId, conversationId],
    );
    return _toInt(result.first['count']);
  }

  Future<PersistMessageResult> persistMessage({
    required int ownerUserId,
    required FriendMessage message,
    required FriendshipSummary friend,
    required bool incrementUnread,
    required bool restoreHidden,
  }) async {
    final database = await _friendsDatabase.database;
    return database.transaction((transaction) async {
      final inserted = await _persistMessage(
        transaction,
        ownerUserId: ownerUserId,
        message: message,
        friend: friend,
        incrementUnread: incrementUnread,
        restoreHidden: restoreHidden,
      );
      return PersistMessageResult(
        inserted: inserted,
        totalUnreadCount: await _totalUnread(transaction, ownerUserId),
      );
    });
  }

  Future<PersistMessageResult> persistMessages({
    required int ownerUserId,
    required List<FriendMessage> messages,
    required FriendshipSummary friend,
    bool countIncomingUnread = true,
    bool restoreHidden = false,
  }) async {
    final database = await _friendsDatabase.database;
    return database.transaction((transaction) async {
      var insertedAny = false;
      for (final message in messages) {
        final inserted = await _persistMessage(
          transaction,
          ownerUserId: ownerUserId,
          message: message,
          friend: friend,
          incrementUnread:
              countIncomingUnread &&
              message.isIncomingFor(ownerUserId) &&
              !message.isRead,
          restoreHidden: restoreHidden,
        );
        insertedAny = insertedAny || inserted;
      }
      return PersistMessageResult(
        inserted: insertedAny,
        totalUnreadCount: await _totalUnread(transaction, ownerUserId),
      );
    });
  }

  Future<void> upsertConversationFromFriend({
    required int ownerUserId,
    required FriendshipSummary friend,
  }) async {
    final database = await _friendsDatabase.database;
    final conversationId = friend.conversationIdFor(ownerUserId);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await database.rawInsert(
      '''
      INSERT INTO friend_conversations (
        owner_user_id, conversation_id, friend_id, friend_name,
        friend_avatar, friend_signature, last_message_at, unread_count,
        hidden, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0, ?)
      ON CONFLICT(owner_user_id, conversation_id) DO UPDATE SET
        friend_id = excluded.friend_id,
        friend_name = excluded.friend_name,
        friend_avatar = excluded.friend_avatar,
        friend_signature = excluded.friend_signature,
        updated_at = excluded.updated_at
      ''',
      [
        ownerUserId,
        conversationId,
        friend.friendId,
        friend.displayName,
        friend.friendAvatar,
        friend.friendSignature,
        (friend.lastChatAt ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
            .millisecondsSinceEpoch,
        now,
      ],
    );
  }

  Future<void> acknowledgeMessage({
    required int ownerUserId,
    required String tempMessageId,
    required String messageId,
    FriendMessage? serverMessage,
  }) async {
    final database = await _friendsDatabase.database;
    await database.transaction((transaction) async {
      final temporaryRows = await transaction.query(
        'friend_messages',
        where: 'owner_user_id = ? AND temp_message_id = ?',
        whereArgs: [ownerUserId, tempMessageId],
        limit: 1,
      );
      if (temporaryRows.isEmpty) return;

      final duplicateRows = await transaction.query(
        'friend_messages',
        where: 'owner_user_id = ? AND message_id = ?',
        whereArgs: [ownerUserId, messageId],
        limit: 1,
      );
      final temporaryLocalId = _toInt(temporaryRows.first['local_id']);
      if (duplicateRows.isNotEmpty &&
          _toInt(duplicateRows.first['local_id']) != temporaryLocalId) {
        await transaction.update(
          'friend_messages',
          {
            'local_file_path': temporaryRows.first['local_file_path'],
            'local_thumbnail_path': temporaryRows.first['local_thumbnail_path'],
            'local_file_exists': temporaryRows.first['local_file_exists'],
            'media_stage': MediaTransferStage.sent.index,
          },
          where: 'local_id = ?',
          whereArgs: [duplicateRows.first['local_id']],
        );
        await transaction.delete(
          'friend_messages',
          where: 'local_id = ?',
          whereArgs: [temporaryLocalId],
        );
      } else {
        final values = <String, Object?>{
          'message_id': messageId,
          'send_status': MessageSendStatus.sent.index,
          'media_stage': MediaTransferStage.sent.index,
          'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        };
        if (serverMessage != null) {
          values.addAll(
            _messageValues(
              ownerUserId,
              serverMessage.copyWith(
                tempMessageId: tempMessageId,
                localFilePath: _nullableText(
                  temporaryRows.first['local_file_path'],
                ),
                localThumbnailPath: _nullableText(
                  temporaryRows.first['local_thumbnail_path'],
                ),
                localFileExists:
                    _toInt(temporaryRows.first['local_file_exists']) == 1,
                mediaStage: MediaTransferStage.sent,
              ),
            ),
          );
        }
        await transaction.update(
          'friend_messages',
          values,
          where: 'local_id = ?',
          whereArgs: [temporaryLocalId],
        );
      }

      final conversationId = '${temporaryRows.first['conversation_id']}';
      await _refreshConversationLastMessage(
        transaction,
        ownerUserId,
        conversationId,
      );
    });
  }

  Future<void> markMessageFailed(int ownerUserId, String tempMessageId) async {
    final database = await _friendsDatabase.database;
    await database.rawUpdate(
      '''
      UPDATE friend_messages
      SET send_status = ?,
          media_stage = CASE WHEN media_stage = ? THEN ? ELSE ? END,
          updated_at = ?
      WHERE owner_user_id = ? AND temp_message_id = ?
      ''',
      [
        MessageSendStatus.failed.index,
        MediaTransferStage.none.index,
        MediaTransferStage.none.index,
        MediaTransferStage.failed.index,
        DateTime.now().toUtc().millisecondsSinceEpoch,
        ownerUserId,
        tempMessageId,
      ],
    );
  }

  Future<void> markMessageSending(int ownerUserId, String tempMessageId) async {
    final database = await _friendsDatabase.database;
    await database.rawUpdate(
      '''
      UPDATE friend_messages
      SET send_status = ?,
          media_stage = CASE WHEN media_stage = ? THEN ? ELSE ? END,
          updated_at = ?
      WHERE owner_user_id = ? AND temp_message_id = ?
      ''',
      [
        MessageSendStatus.sending.index,
        MediaTransferStage.none.index,
        MediaTransferStage.none.index,
        MediaTransferStage.sending.index,
        DateTime.now().toUtc().millisecondsSinceEpoch,
        ownerUserId,
        tempMessageId,
      ],
    );
  }

  Future<void> failPendingMessages(int ownerUserId) async {
    final database = await _friendsDatabase.database;
    await database.rawUpdate(
      '''
      UPDATE friend_messages
      SET send_status = ?,
          media_stage = CASE WHEN media_stage = ? THEN ? ELSE ? END,
          updated_at = ?
      WHERE
        owner_user_id = ? AND (
          send_status = ? OR media_stage IN (?, ?, ?)
        )
      ''',
      [
        MessageSendStatus.failed.index,
        MediaTransferStage.none.index,
        MediaTransferStage.none.index,
        MediaTransferStage.failed.index,
        DateTime.now().toUtc().millisecondsSinceEpoch,
        ownerUserId,
        MessageSendStatus.sending.index,
        MediaTransferStage.uploading.index,
        MediaTransferStage.readyToSend.index,
        MediaTransferStage.sending.index,
      ],
    );
  }

  Future<void> updateMediaMessage({
    required int ownerUserId,
    required String tempMessageId,
    String? nextTempMessageId,
    String? content,
    MessageSendStatus? sendStatus,
    MediaTransferStage? mediaStage,
    bool? localFileExists,
  }) async {
    final values = <String, Object?>{
      if (sendStatus != null) 'send_status': sendStatus.index,
      if (mediaStage != null) 'media_stage': mediaStage.index,
      if (localFileExists != null) 'local_file_exists': localFileExists ? 1 : 0,
      'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    };
    if (nextTempMessageId != null) {
      values['temp_message_id'] = nextTempMessageId;
    }
    if (content != null) values['content'] = content;
    if (values.length == 1) return;
    final database = await _friendsDatabase.database;
    await database.update(
      'friend_messages',
      values,
      where: 'owner_user_id = ? AND temp_message_id = ?',
      whereArgs: [ownerUserId, tempMessageId],
    );
  }

  Future<List<FriendMessage>> markConversationRead({
    required int ownerUserId,
    required String conversationId,
  }) async {
    final database = await _friendsDatabase.database;
    return database.transaction((transaction) async {
      final rows = await transaction.query(
        'friend_messages',
        where: '''
          owner_user_id = ? AND conversation_id = ? AND receiver_id = ?
          AND is_read = 0 AND message_id IS NOT NULL
        ''',
        whereArgs: [ownerUserId, conversationId, ownerUserId],
        orderBy: 'created_at ASC',
      );
      await transaction.update(
        'friend_messages',
        {
          'is_read': 1,
          'read_synced': 0,
          'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        },
        where: '''
          owner_user_id = ? AND conversation_id = ? AND receiver_id = ?
          AND is_read = 0
        ''',
        whereArgs: [ownerUserId, conversationId, ownerUserId],
      );
      await transaction.update(
        'friend_conversations',
        {
          'unread_count': 0,
          'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        },
        where: 'owner_user_id = ? AND conversation_id = ?',
        whereArgs: [ownerUserId, conversationId],
      );
      return rows.map(_messageFromRow).toList(growable: false);
    });
  }

  Future<List<FriendMessage>> getPendingReadMessages(int ownerUserId) async {
    final database = await _friendsDatabase.database;
    final rows = await database.query(
      'friend_messages',
      where: '''
        owner_user_id = ? AND receiver_id = ? AND is_read = 1
        AND read_synced = 0 AND message_id IS NOT NULL
      ''',
      whereArgs: [ownerUserId, ownerUserId],
      orderBy: 'created_at ASC',
    );
    return rows.map(_messageFromRow).toList(growable: false);
  }

  Future<void> markReadSynced(int ownerUserId, String messageId) async {
    final database = await _friendsDatabase.database;
    await database.update(
      'friend_messages',
      {'read_synced': 1},
      where: 'owner_user_id = ? AND message_id = ?',
      whereArgs: [ownerUserId, messageId],
    );
  }

  Future<void> applyReadReceipt(int ownerUserId, String messageId) async {
    final database = await _friendsDatabase.database;
    await database.update(
      'friend_messages',
      {
        'is_read': 1,
        'read_synced': 1,
        'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      },
      where: 'owner_user_id = ? AND message_id = ?',
      whereArgs: [ownerUserId, messageId],
    );
  }

  Future<void> hideConversation(int ownerUserId, String conversationId) async {
    final database = await _friendsDatabase.database;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await database.update(
      'friend_conversations',
      {'hidden': 1, 'hidden_at': now, 'unread_count': 0, 'updated_at': now},
      where: 'owner_user_id = ? AND conversation_id = ?',
      whereArgs: [ownerUserId, conversationId],
    );
  }

  Future<void> deleteConversationData(
    int ownerUserId,
    String conversationId,
  ) async {
    final database = await _friendsDatabase.database;
    await database.transaction((transaction) async {
      await transaction.delete(
        'friend_messages',
        where: 'owner_user_id = ? AND conversation_id = ?',
        whereArgs: [ownerUserId, conversationId],
      );
      await transaction.delete(
        'friend_conversations',
        where: 'owner_user_id = ? AND conversation_id = ?',
        whereArgs: [ownerUserId, conversationId],
      );
    });
  }

  Future<int> getTotalUnreadCount(int ownerUserId) async {
    final database = await _friendsDatabase.database;
    return _totalUnread(database, ownerUserId);
  }

  Future<void> clearOwnerData(int ownerUserId) async {
    final database = await _friendsDatabase.database;
    await database.transaction((transaction) async {
      await transaction.delete(
        'friend_messages',
        where: 'owner_user_id = ?',
        whereArgs: [ownerUserId],
      );
      await transaction.delete(
        'friend_conversations',
        where: 'owner_user_id = ?',
        whereArgs: [ownerUserId],
      );
    });
  }

  Future<bool> _persistMessage(
    Transaction transaction, {
    required int ownerUserId,
    required FriendMessage message,
    required FriendshipSummary friend,
    required bool incrementUnread,
    required bool restoreHidden,
  }) async {
    final existing = await _findExistingMessage(
      transaction,
      ownerUserId,
      message,
    );
    if (existing != null) {
      if (message.messageId != null) {
        final values = <String, Object?>{
          'is_read': message.isRead ? 1 : existing['is_read'],
          'read_synced': message.isRead ? 1 : existing['read_synced'],
          'send_status': MessageSendStatus.sent.index,
          'updated_at': message.updatedAt.millisecondsSinceEpoch,
        };
        if (message.isRevoked) {
          values.addAll({
            'message_type': message.messageType,
            'content': message.content,
            'is_revoked': 1,
            'revoked_at': message.revokedAt?.millisecondsSinceEpoch,
            'local_file_path': null,
            'local_thumbnail_path': null,
            'local_file_exists': 0,
            'media_stage': MediaTransferStage.none.index,
          });
        }
        await transaction.update(
          'friend_messages',
          values,
          where: 'local_id = ?',
          whereArgs: [existing['local_id']],
        );
        if (message.isRevoked) {
          await _refreshConversationLastMessage(
            transaction,
            ownerUserId,
            message.conversationId,
          );
          await transaction.rawUpdate(
            '''
            UPDATE friend_conversations
            SET unread_count = (
              SELECT COUNT(*) FROM friend_messages
              WHERE owner_user_id = ? AND conversation_id = ?
                AND receiver_id = ? AND is_read = 0
            ), updated_at = ?
            WHERE owner_user_id = ? AND conversation_id = ?
            ''',
            [
              ownerUserId,
              message.conversationId,
              ownerUserId,
              DateTime.now().toUtc().millisecondsSinceEpoch,
              ownerUserId,
              message.conversationId,
            ],
          );
        }
      }
      return false;
    }

    await transaction.insert(
      'friend_messages',
      _messageValues(ownerUserId, message),
    );
    await _upsertConversationForMessage(
      transaction,
      ownerUserId: ownerUserId,
      message: message,
      friend: friend,
      incrementUnread: incrementUnread,
      restoreHidden: restoreHidden,
    );
    return true;
  }

  Future<Map<String, Object?>?> _findExistingMessage(
    DatabaseExecutor executor,
    int ownerUserId,
    FriendMessage message,
  ) async {
    if (message.messageId != null) {
      final rows = await executor.query(
        'friend_messages',
        where: 'owner_user_id = ? AND message_id = ?',
        whereArgs: [ownerUserId, message.messageId],
        limit: 1,
      );
      if (rows.isNotEmpty) return rows.first;
    }
    if (message.tempMessageId != null) {
      final rows = await executor.query(
        'friend_messages',
        where: 'owner_user_id = ? AND temp_message_id = ?',
        whereArgs: [ownerUserId, message.tempMessageId],
        limit: 1,
      );
      if (rows.isNotEmpty) return rows.first;
    }
    return null;
  }

  Future<void> _upsertConversationForMessage(
    DatabaseExecutor executor, {
    required int ownerUserId,
    required FriendMessage message,
    required FriendshipSummary friend,
    required bool incrementUnread,
    required bool restoreHidden,
  }) async {
    final timestamp = message.createdAt.millisecondsSinceEpoch;
    final preview = _messagePreview(message);
    await executor.rawInsert(
      '''
      INSERT INTO friend_conversations (
        owner_user_id, conversation_id, friend_id, friend_name,
        friend_avatar, friend_signature, last_message, last_message_type,
        last_message_at, unread_count, hidden, hidden_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, NULL, ?)
      ON CONFLICT(owner_user_id, conversation_id) DO UPDATE SET
        friend_id = excluded.friend_id,
        friend_name = excluded.friend_name,
        friend_avatar = COALESCE(excluded.friend_avatar, friend_conversations.friend_avatar),
        friend_signature = COALESCE(excluded.friend_signature, friend_conversations.friend_signature),
        last_message = CASE
          WHEN excluded.last_message_at >= friend_conversations.last_message_at
          THEN excluded.last_message ELSE friend_conversations.last_message END,
        last_message_type = CASE
          WHEN excluded.last_message_at >= friend_conversations.last_message_at
          THEN excluded.last_message_type ELSE friend_conversations.last_message_type END,
        last_message_at = MAX(friend_conversations.last_message_at, excluded.last_message_at),
        unread_count = friend_conversations.unread_count + ?,
        hidden = CASE WHEN ? = 1 THEN 0 ELSE friend_conversations.hidden END,
        hidden_at = CASE WHEN ? = 1 THEN NULL ELSE friend_conversations.hidden_at END,
        updated_at = MAX(friend_conversations.updated_at, excluded.updated_at)
      ''',
      [
        ownerUserId,
        message.conversationId,
        friend.friendId,
        friend.displayName,
        friend.friendAvatar,
        friend.friendSignature,
        preview,
        message.messageType,
        timestamp,
        incrementUnread ? 1 : 0,
        message.updatedAt.millisecondsSinceEpoch,
        incrementUnread ? 1 : 0,
        restoreHidden ? 1 : 0,
        restoreHidden ? 1 : 0,
      ],
    );
  }

  Future<void> _refreshConversationLastMessage(
    DatabaseExecutor executor,
    int ownerUserId,
    String conversationId,
  ) async {
    final rows = await executor.query(
      'friend_messages',
      where: 'owner_user_id = ? AND conversation_id = ?',
      whereArgs: [ownerUserId, conversationId],
      orderBy: 'created_at DESC, local_id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return;
    final message = _messageFromRow(rows.first);
    await executor.update(
      'friend_conversations',
      {
        'last_message': _messagePreview(message),
        'last_message_type': message.messageType,
        'last_message_at': message.createdAt.millisecondsSinceEpoch,
        'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      },
      where: 'owner_user_id = ? AND conversation_id = ?',
      whereArgs: [ownerUserId, conversationId],
    );
  }

  Future<int> _totalUnread(DatabaseExecutor executor, int ownerUserId) async {
    final result = await executor.rawQuery(
      '''
      SELECT COALESCE(SUM(unread_count), 0) AS total
      FROM friend_conversations
      WHERE owner_user_id = ? AND hidden = 0
      ''',
      [ownerUserId],
    );
    return _toInt(result.first['total']);
  }

  static Map<String, Object?> _messageValues(
    int ownerUserId,
    FriendMessage message,
  ) {
    return {
      'owner_user_id': ownerUserId,
      'message_id': message.messageId,
      'temp_message_id': message.tempMessageId,
      'conversation_id': message.conversationId,
      'sender_id': message.senderId,
      'receiver_id': message.receiverId,
      'message_type': message.messageType,
      'content': message.content,
      'send_status': message.sendStatus.index,
      'is_read': message.isRead ? 1 : 0,
      'read_synced': message.readSynced ? 1 : 0,
      'local_file_path': message.localFilePath,
      'local_thumbnail_path': message.localThumbnailPath,
      'local_file_exists': message.localFileExists ? 1 : 0,
      'media_stage': message.mediaStage.index,
      'is_revoked': message.isRevoked ? 1 : 0,
      'revoked_at': message.revokedAt?.toUtc().millisecondsSinceEpoch,
      'created_at': message.createdAt.toUtc().millisecondsSinceEpoch,
      'updated_at': message.updatedAt.toUtc().millisecondsSinceEpoch,
    };
  }

  static FriendMessage _messageFromRow(Map<String, Object?> row) {
    return FriendMessage(
      messageId: _nullableText(row['message_id']),
      tempMessageId: _nullableText(row['temp_message_id']),
      conversationId: '${row['conversation_id']}',
      senderId: _toInt(row['sender_id']),
      receiverId: _toInt(row['receiver_id']),
      messageType: '${row['message_type']}',
      content: '${row['content'] ?? ''}',
      sendStatus:
          MessageSendStatus.values[_toInt(
            row['send_status'],
          ).clamp(0, MessageSendStatus.values.length - 1)],
      isRead: _toInt(row['is_read']) == 1,
      readSynced: _toInt(row['read_synced']) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        _toInt(row['created_at']),
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        _toInt(row['updated_at']),
        isUtc: true,
      ),
      localFilePath: _nullableText(row['local_file_path']),
      localThumbnailPath: _nullableText(row['local_thumbnail_path']),
      localFileExists: _toInt(row['local_file_exists']) == 1,
      mediaStage:
          MediaTransferStage.values[_toInt(
            row['media_stage'],
          ).clamp(0, MediaTransferStage.values.length - 1)],
      isRevoked: _toInt(row['is_revoked']) == 1,
      revokedAt: row['revoked_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              _toInt(row['revoked_at']),
              isUtc: true,
            ),
    );
  }

  static FriendConversation _conversationFromRow(Map<String, Object?> row) {
    return FriendConversation(
      conversationId: '${row['conversation_id']}',
      friendId: _toInt(row['friend_id']),
      friendName: '${row['friend_name']}',
      friendAvatar: _nullableText(row['friend_avatar']),
      friendSignature: _nullableText(row['friend_signature']),
      lastMessage: _nullableText(row['last_message']),
      lastMessageType: _nullableText(row['last_message_type']),
      lastMessageAt: DateTime.fromMillisecondsSinceEpoch(
        _toInt(row['last_message_at']),
        isUtc: true,
      ),
      unreadCount: _toInt(row['unread_count']),
      hidden: _toInt(row['hidden']) == 1,
    );
  }

  static String _messagePreview(FriendMessage message) {
    return switch (message.messageType) {
      'image' => '[图片]',
      'voice' => '[语音]',
      'video' => '[视频]',
      _ =>
        message.content.length > 100
            ? message.content.substring(0, 100)
            : message.content,
    };
  }

  static String _escapeLike(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  static int _toInt(Object? value) => switch (value) {
    final int number => number,
    final num number => number.toInt(),
    _ => int.tryParse('$value') ?? 0,
  };

  static String? _nullableText(Object? value) {
    if (value == null) return null;
    final text = '$value';
    return text.isEmpty ? null : text;
  }
}
