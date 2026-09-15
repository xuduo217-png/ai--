import 'package:shared_preferences/shared_preferences.dart';

enum ConversationVisibilityScope { consultation, marketplace }

abstract interface class ConversationVisibilityGateway {
  Future<Set<String>> loadHiddenConversationIds({
    required int ownerUserId,
    required ConversationVisibilityScope scope,
  });

  Future<void> hideConversation({
    required int ownerUserId,
    required ConversationVisibilityScope scope,
    required String conversationId,
  });

  Future<void> restoreConversation({
    required int ownerUserId,
    required ConversationVisibilityScope scope,
    required String conversationId,
  });
}

class ConversationVisibilityStore implements ConversationVisibilityGateway {
  ConversationVisibilityStore();

  Future<void> _operation = Future<void>.value();

  @override
  Future<Set<String>> loadHiddenConversationIds({
    required int ownerUserId,
    required ConversationVisibilityScope scope,
  }) async {
    await _operation;
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_key(ownerUserId, scope))?.toSet() ??
        <String>{};
  }

  @override
  Future<void> hideConversation({
    required int ownerUserId,
    required ConversationVisibilityScope scope,
    required String conversationId,
  }) {
    return _update(
      ownerUserId: ownerUserId,
      scope: scope,
      update: (hidden) => hidden..add(conversationId),
    );
  }

  @override
  Future<void> restoreConversation({
    required int ownerUserId,
    required ConversationVisibilityScope scope,
    required String conversationId,
  }) {
    return _update(
      ownerUserId: ownerUserId,
      scope: scope,
      update: (hidden) => hidden..remove(conversationId),
    );
  }

  Future<void> _update({
    required int ownerUserId,
    required ConversationVisibilityScope scope,
    required Set<String> Function(Set<String>) update,
  }) {
    Future<void> write() async {
      final preferences = await SharedPreferences.getInstance();
      final key = _key(ownerUserId, scope);
      final hidden = preferences.getStringList(key)?.toSet() ?? <String>{};
      final updated = update(hidden).toList()..sort();
      await preferences.setStringList(key, updated);
    }

    final next = _operation.then((_) => write(), onError: (_) => write());
    _operation = next.catchError((Object _) {});
    return next;
  }

  String _key(int ownerUserId, ConversationVisibilityScope scope) =>
      'hidden_conversations_v1:${scope.name}:$ownerUserId';
}
