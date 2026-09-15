import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../friends/domain/friend_messaging_models.dart';
import '../domain/marketplace_chat_models.dart';
import 'marketplace_chat_database.dart';

class MarketplaceChatLocalStore {
  const MarketplaceChatLocalStore(this._database);

  final MarketplaceChatDatabase _database;

  Future<void> open() async {
    await _database.database;
  }

  Future<void> persistConversation(
    int ownerUserId,
    MarketplaceConversation conversation,
  ) async {
    final database = await _database.database;
    await database.insert(
      'marketplace_conversations',
      _conversationRow(ownerUserId, conversation),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> persistConversations(
    int ownerUserId,
    Iterable<MarketplaceConversation> conversations,
  ) async {
    final database = await _database.database;
    return database.transaction((transaction) async {
      for (final conversation in conversations) {
        await transaction.insert(
          'marketplace_conversations',
          _conversationRow(ownerUserId, conversation),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<MarketplaceConversation>> loadConversations(
    int ownerUserId, {
    String search = '',
  }) async {
    final database = await _database.database;
    final normalized = search.trim();
    final rows = await database.query(
      'marketplace_conversations',
      where: normalized.isEmpty
          ? 'owner_user_id = ?'
          : '''owner_user_id = ? AND (
              peer_name LIKE ? OR product_name LIKE ?
            )''',
      whereArgs: normalized.isEmpty
          ? [ownerUserId]
          : [ownerUserId, '%$normalized%', '%$normalized%'],
      orderBy: 'sort_time DESC',
    );
    return rows
        .map(
          (row) =>
              MarketplaceConversation.fromJson(_decode(row['payload_json'])),
        )
        .toList(growable: false);
  }

  Future<bool> persistMessage({
    required int ownerUserId,
    required FriendMessage message,
  }) async {
    final database = await _database.database;
    return database.transaction((transaction) async {
      final existing = await transaction.query(
        'marketplace_messages',
        columns: const ['local_key'],
        where: 'owner_user_id = ? AND local_key = ?',
        whereArgs: [ownerUserId, message.localKey],
        limit: 1,
      );
      await transaction.insert(
        'marketplace_messages',
        _messageRow(ownerUserId, message),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return existing.isEmpty;
    });
  }

  Future<void> replaceMessage({
    required int ownerUserId,
    required String previousLocalKey,
    required FriendMessage message,
  }) async {
    final database = await _database.database;
    return database.transaction((transaction) async {
      await transaction.delete(
        'marketplace_messages',
        where: 'owner_user_id = ? AND local_key = ?',
        whereArgs: [ownerUserId, previousLocalKey],
      );
      await transaction.insert(
        'marketplace_messages',
        _messageRow(ownerUserId, message),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<bool> applyRevokedMessage({
    required int ownerUserId,
    required FriendMessage message,
  }) async {
    final database = await _database.database;
    return database.transaction((transaction) async {
      final rows = await transaction.query(
        'marketplace_messages',
        columns: const ['local_key', 'payload_json'],
        where: 'owner_user_id = ? AND local_key = ?',
        whereArgs: [ownerUserId, message.messageId],
        limit: 1,
      );
      final previous = rows.isEmpty
          ? null
          : _messageFromJson(_decode(rows.first['payload_json']));
      await transaction.insert(
        'marketplace_messages',
        _messageRow(ownerUserId, message),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return previous != null &&
          previous.receiverId == ownerUserId &&
          !previous.isRead;
    });
  }

  Future<List<FriendMessage>> loadMessages(
    int ownerUserId,
    String conversationId, {
    int limit = 50,
  }) async {
    final database = await _database.database;
    final rows = await database.query(
      'marketplace_messages',
      where: 'owner_user_id = ? AND conversation_id = ?',
      whereArgs: [ownerUserId, conversationId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    final messages = rows
        .map((row) => _messageFromJson(_decode(row['payload_json'])))
        .toList(growable: true);
    messages.sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return messages;
  }

  Future<int> messageCount(int ownerUserId, String conversationId) async {
    final database = await _database.database;
    final result = await database.rawQuery(
      '''SELECT COUNT(*) AS count FROM marketplace_messages
         WHERE owner_user_id = ? AND conversation_id = ?''',
      [ownerUserId, conversationId],
    );
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  Future<List<FriendMessage>> markConversationRead(
    int ownerUserId,
    String conversationId,
  ) async {
    final database = await _database.database;
    return database.transaction((transaction) async {
      final rows = await transaction.query(
        'marketplace_messages',
        where: 'owner_user_id = ? AND conversation_id = ?',
        whereArgs: [ownerUserId, conversationId],
      );
      final incoming = <FriendMessage>[];
      for (final row in rows) {
        final message = _messageFromJson(_decode(row['payload_json']));
        if (message.receiverId != ownerUserId || message.isRead) continue;
        final read = message.copyWith(
          isRead: true,
          updatedAt: DateTime.now().toUtc(),
        );
        incoming.add(read);
        await transaction.update(
          'marketplace_messages',
          {'payload_json': jsonEncode(_messageToJson(read))},
          where: 'owner_user_id = ? AND local_key = ?',
          whereArgs: [ownerUserId, message.localKey],
        );
      }
      final conversationRows = await transaction.query(
        'marketplace_conversations',
        where: 'owner_user_id = ? AND conversation_id = ?',
        whereArgs: [ownerUserId, conversationId],
        limit: 1,
      );
      if (conversationRows.isNotEmpty) {
        final conversation = MarketplaceConversation.fromJson(
          _decode(conversationRows.first['payload_json']),
        ).copyWith(unreadCount: 0);
        await transaction.update(
          'marketplace_conversations',
          _conversationRow(ownerUserId, conversation),
          where: 'owner_user_id = ? AND conversation_id = ?',
          whereArgs: [ownerUserId, conversationId],
        );
      }
      return incoming;
    });
  }

  Future<bool> markMessageReadById(int ownerUserId, String messageId) async {
    final database = await _database.database;
    return database.transaction((transaction) async {
      final rows = await transaction.query(
        'marketplace_messages',
        where: 'owner_user_id = ? AND local_key = ?',
        whereArgs: [ownerUserId, messageId],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final message = _messageFromJson(_decode(rows.first['payload_json']));
      if (message.isRead) return false;
      final read = message.copyWith(
        isRead: true,
        updatedAt: DateTime.now().toUtc(),
      );
      await transaction.update(
        'marketplace_messages',
        {'payload_json': jsonEncode(_messageToJson(read))},
        where: 'owner_user_id = ? AND local_key = ?',
        whereArgs: [ownerUserId, messageId],
      );
      return true;
    });
  }

  Future<int> totalUnreadCount(
    int ownerUserId, {
    Set<String> excludedConversationIds = const {},
  }) async {
    final database = await _database.database;
    final excluded = excludedConversationIds.toList(growable: false);
    final exclusionClause = excluded.isEmpty
        ? ''
        : ' AND conversation_id NOT IN (${List.filled(excluded.length, '?').join(', ')})';
    final result = await database.rawQuery(
      '''SELECT COALESCE(SUM(unread_count), 0) AS count
         FROM marketplace_conversations
         WHERE owner_user_id = ?$exclusionClause''',
      [ownerUserId, ...excluded],
    );
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> failPendingMessages(int ownerUserId) async {
    final database = await _database.database;
    final rows = await database.query(
      'marketplace_messages',
      where: 'owner_user_id = ?',
      whereArgs: [ownerUserId],
    );
    final batch = database.batch();
    for (final row in rows) {
      final message = _messageFromJson(_decode(row['payload_json']));
      if (message.sendStatus != MessageSendStatus.sending) continue;
      final failed = message.copyWith(
        sendStatus: MessageSendStatus.failed,
        mediaStage: MediaTransferStage.failed,
      );
      batch.update(
        'marketplace_messages',
        {'payload_json': jsonEncode(_messageToJson(failed))},
        where: 'owner_user_id = ? AND local_key = ?',
        whereArgs: [ownerUserId, message.localKey],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearOwner(int ownerUserId) async {
    final database = await _database.database;
    await database.transaction((transaction) async {
      await transaction.delete(
        'marketplace_messages',
        where: 'owner_user_id = ?',
        whereArgs: [ownerUserId],
      );
      await transaction.delete(
        'marketplace_conversations',
        where: 'owner_user_id = ?',
        whereArgs: [ownerUserId],
      );
    });
  }

  Future<void> close() => _database.close();
}

Map<String, Object?> _conversationRow(
  int ownerUserId,
  MarketplaceConversation conversation,
) => {
  'owner_user_id': ownerUserId,
  'conversation_id': conversation.conversationId,
  'peer_name': conversation.peer.nickname,
  'product_name': conversation.product.name,
  'payload_json': jsonEncode(conversation.toJson()),
  'unread_count': conversation.unreadCount,
  'sort_time': conversation.sortTime.millisecondsSinceEpoch,
};

Map<String, Object?> _messageRow(int ownerUserId, FriendMessage message) => {
  'owner_user_id': ownerUserId,
  'local_key': message.localKey,
  'conversation_id': message.conversationId,
  'payload_json': jsonEncode(_messageToJson(message)),
  'created_at': message.createdAt.millisecondsSinceEpoch,
};

Map<String, Object?> _messageToJson(FriendMessage message) => {
  'messageId': message.messageId,
  'tempMessageId': message.tempMessageId,
  'conversationId': message.conversationId,
  'senderId': message.senderId,
  'receiverId': message.receiverId,
  'messageType': message.messageType,
  'content': message.content,
  'sendStatus': message.sendStatus.index,
  'isRead': message.isRead,
  'readSynced': message.readSynced,
  'createdAt': message.createdAt.toIso8601String(),
  'updatedAt': message.updatedAt.toIso8601String(),
  'deliveryMode': message.deliveryMode,
  'localFilePath': message.localFilePath,
  'localThumbnailPath': message.localThumbnailPath,
  'localFileExists': message.localFileExists,
  'mediaStage': message.mediaStage.index,
  'isRevoked': message.isRevoked,
  'revokedAt': message.revokedAt?.toIso8601String(),
};

FriendMessage _messageFromJson(Map<String, dynamic> json) {
  final createdAt =
      DateTime.tryParse('${json['createdAt']}') ?? DateTime.now().toUtc();
  return FriendMessage(
    messageId: _nullable(json['messageId']),
    tempMessageId: _nullable(json['tempMessageId']),
    conversationId: '${json['conversationId'] ?? ''}',
    senderId: _integer(json['senderId']),
    receiverId: _integer(json['receiverId']),
    messageType: '${json['messageType'] ?? 'text'}',
    content: '${json['content'] ?? ''}',
    sendStatus: MessageSendStatus
        .values[_bounded(json['sendStatus'], MessageSendStatus.values.length)],
    isRead: json['isRead'] == true || json['isRead'] == 1,
    readSynced: json['readSynced'] != false && json['readSynced'] != 0,
    createdAt: createdAt,
    updatedAt: DateTime.tryParse('${json['updatedAt']}') ?? createdAt,
    deliveryMode: _nullable(json['deliveryMode']),
    localFilePath: _nullable(json['localFilePath']),
    localThumbnailPath: _nullable(json['localThumbnailPath']),
    localFileExists:
        json['localFileExists'] == true || json['localFileExists'] == 1,
    mediaStage: MediaTransferStage
        .values[_bounded(json['mediaStage'], MediaTransferStage.values.length)],
    isRevoked: json['isRevoked'] == true || json['isRevoked'] == 1,
    revokedAt: DateTime.tryParse('${json['revokedAt'] ?? ''}'),
  );
}

Map<String, dynamic> _decode(Object? value) {
  final decoded = jsonDecode('$value');
  return decoded is Map
      ? Map<String, dynamic>.from(decoded)
      : const <String, dynamic>{};
}

String? _nullable(Object? value) {
  final text = value == null ? '' : '$value'.trim();
  return text.isEmpty || text == 'null' ? null : text;
}

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

int _bounded(Object? value, int length) => _integer(value).clamp(0, length - 1);
