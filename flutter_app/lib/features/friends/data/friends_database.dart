import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class FriendsDatabase {
  FriendsDatabase._(this._open, {required this.closeOnDispose});

  factory FriendsDatabase.production({
    String fileName = 'friends_messaging.db',
  }) {
    return FriendsDatabase._(() async {
      final databasePath = path.join(await getDatabasesPath(), fileName);
      return databaseFactory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 3,
          onConfigure: (database) async {
            await database.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: createSchema,
          onUpgrade: upgradeSchema,
        ),
      );
    }, closeOnDispose: true);
  }

  factory FriendsDatabase.withFactory({
    required DatabaseFactory factory,
    required String databasePath,
    bool closeOnDispose = true,
  }) {
    return FriendsDatabase._(
      () => factory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 3,
          onConfigure: (database) async {
            await database.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: createSchema,
          onUpgrade: upgradeSchema,
        ),
      ),
      closeOnDispose: closeOnDispose,
    );
  }

  final Future<Database> Function() _open;
  final bool closeOnDispose;
  Future<Database>? _database;

  Future<Database> get database => _database ??= _open();

  static Future<void> createSchema(Database database, int version) async {
    await database.execute('''
      CREATE TABLE friend_conversations (
        owner_user_id INTEGER NOT NULL,
        conversation_id TEXT NOT NULL,
        friend_id INTEGER NOT NULL,
        friend_name TEXT NOT NULL,
        friend_avatar TEXT,
        friend_signature TEXT,
        last_message TEXT,
        last_message_type TEXT,
        last_message_at INTEGER NOT NULL,
        unread_count INTEGER NOT NULL DEFAULT 0,
        hidden INTEGER NOT NULL DEFAULT 0,
        hidden_at INTEGER,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (owner_user_id, conversation_id)
      )
    ''');
    await database.execute('''
      CREATE TABLE friend_messages (
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        owner_user_id INTEGER NOT NULL,
        message_id TEXT,
        temp_message_id TEXT,
        conversation_id TEXT NOT NULL,
        sender_id INTEGER NOT NULL,
        receiver_id INTEGER NOT NULL,
        message_type TEXT NOT NULL,
        content TEXT NOT NULL,
        send_status INTEGER NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        read_synced INTEGER NOT NULL DEFAULT 1,
        local_file_path TEXT,
        local_thumbnail_path TEXT,
        local_file_exists INTEGER NOT NULL DEFAULT 0,
        media_stage INTEGER NOT NULL DEFAULT 0,
        is_revoked INTEGER NOT NULL DEFAULT 0,
        revoked_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE UNIQUE INDEX idx_friend_messages_owner_message
      ON friend_messages(owner_user_id, message_id)
      WHERE message_id IS NOT NULL
    ''');
    await database.execute('''
      CREATE UNIQUE INDEX idx_friend_messages_owner_temp
      ON friend_messages(owner_user_id, temp_message_id)
      WHERE temp_message_id IS NOT NULL
    ''');
    await database.execute('''
      CREATE INDEX idx_friend_messages_conversation_time
      ON friend_messages(owner_user_id, conversation_id, created_at DESC)
    ''');
    await database.execute('''
      CREATE INDEX idx_friend_messages_unread
      ON friend_messages(owner_user_id, receiver_id, is_read, created_at)
    ''');
    await database.execute('''
      CREATE INDEX idx_friend_messages_read_sync
      ON friend_messages(owner_user_id, read_synced, receiver_id)
    ''');
    await database.execute('''
      CREATE INDEX idx_friend_conversations_sort
      ON friend_conversations(owner_user_id, hidden, last_message_at DESC)
    ''');
  }

  static Future<void> upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await database.execute('DROP TABLE IF EXISTS friend_messages');
      await database.execute('DROP TABLE IF EXISTS friend_conversations');
      await createSchema(database, newVersion);
      return;
    }
    if (oldVersion < 3) {
      await database.execute(
        'ALTER TABLE friend_messages ADD COLUMN is_revoked INTEGER NOT NULL DEFAULT 0',
      );
      await database.execute(
        'ALTER TABLE friend_messages ADD COLUMN revoked_at INTEGER',
      );
    }
  }

  Future<void> close() async {
    final pending = _database;
    _database = null;
    if (pending != null && closeOnDispose) {
      final database = await pending;
      if (database.isOpen) await database.close();
    }
  }
}
