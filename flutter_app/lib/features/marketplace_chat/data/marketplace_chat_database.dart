import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class MarketplaceChatDatabase {
  MarketplaceChatDatabase._(this._open, {required this.closeOnDispose});

  factory MarketplaceChatDatabase.production({
    String fileName = 'marketplace_chat.db',
  }) {
    return MarketplaceChatDatabase._(() async {
      final databasePath = path.join(await getDatabasesPath(), fileName);
      return databaseFactory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(version: 1, onCreate: createSchema),
      );
    }, closeOnDispose: true);
  }

  factory MarketplaceChatDatabase.withFactory({
    required DatabaseFactory factory,
    required String databasePath,
    bool closeOnDispose = true,
  }) {
    return MarketplaceChatDatabase._(
      () => factory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(version: 1, onCreate: createSchema),
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
      CREATE TABLE marketplace_conversations (
        owner_user_id INTEGER NOT NULL,
        conversation_id TEXT NOT NULL,
        peer_name TEXT NOT NULL,
        product_name TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        unread_count INTEGER NOT NULL DEFAULT 0,
        sort_time INTEGER NOT NULL,
        PRIMARY KEY (owner_user_id, conversation_id)
      )
    ''');
    await database.execute('''
      CREATE INDEX idx_marketplace_conversations_sort
      ON marketplace_conversations(owner_user_id, sort_time DESC)
    ''');
    await database.execute('''
      CREATE TABLE marketplace_messages (
        owner_user_id INTEGER NOT NULL,
        local_key TEXT NOT NULL,
        conversation_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (owner_user_id, local_key)
      )
    ''');
    await database.execute('''
      CREATE INDEX idx_marketplace_messages_conversation
      ON marketplace_messages(owner_user_id, conversation_id, created_at DESC)
    ''');
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
