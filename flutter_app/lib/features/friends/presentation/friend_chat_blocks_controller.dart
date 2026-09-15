import 'package:flutter/foundation.dart';

import '../data/friend_relations_repository.dart';
import '../domain/friend_relation_models.dart';

class FriendChatBlocksController extends ChangeNotifier {
  FriendChatBlocksController({
    required FriendRelationsRepositoryGateway repository,
  }) : _repository = repository;

  static const int pageSize = 100;

  final FriendRelationsRepositoryGateway _repository;
  final Set<int> _unblockingUserIds = <int>{};

  List<FriendChatBlock> _blocks = const [];
  String? _errorMessage;
  bool _loading = true;
  bool _disposed = false;

  List<FriendChatBlock> get blocks =>
      List<FriendChatBlock>.unmodifiable(_blocks);
  String? get errorMessage => _errorMessage;
  bool get loading => _loading;
  bool isUnblocking(int userId) => _unblockingUserIds.contains(userId);

  Future<void> initialize() => refresh();

  Future<void> refresh() async {
    if (_disposed) return;
    _loading = true;
    _errorMessage = null;
    _safeNotify();
    try {
      final byUserId = <int, FriendChatBlock>{};
      var page = 1;
      var hasMore = true;
      while (hasMore) {
        final result = await _repository.loadFriendChatBlocks(
          page: page,
          pageSize: pageSize,
        );
        for (final block in result.items) {
          byUserId[block.blockedUserId] = block;
        }
        hasMore = result.hasMore;
        page += 1;
      }
      _blocks = byUserId.values.toList(growable: false)
        ..sort((first, second) => second.blockedAt.compareTo(first.blockedAt));
    } on Object catch (error) {
      _errorMessage = _readableError(error, '黑名单加载失败，请重试');
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  Future<bool> unblock(FriendChatBlock block) async {
    if (_unblockingUserIds.contains(block.blockedUserId)) return false;
    _unblockingUserIds.add(block.blockedUserId);
    _safeNotify();
    try {
      await _repository.unblockFriendChat(blockedUserId: block.blockedUserId);
      _blocks = _blocks
          .where((item) => item.blockedUserId != block.blockedUserId)
          .toList(growable: false);
      return true;
    } on Object catch (error) {
      _errorMessage = _readableError(error, '解除拉黑失败');
      return false;
    } finally {
      _unblockingUserIds.remove(block.blockedUserId);
      _safeNotify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}

String _readableError(Object error, String fallback) {
  final value = error.toString().trim();
  if (value.isEmpty) return fallback;
  return value.replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
}
