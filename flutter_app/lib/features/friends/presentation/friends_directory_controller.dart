import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pinyin/pinyin.dart';

import '../data/friend_relations_repository.dart';
import '../data/friends_socket_client.dart';
import '../domain/friend_messaging_models.dart';
import '../domain/friend_relation_models.dart';

class FriendDirectorySection {
  const FriendDirectorySection({required this.letter, required this.friends});

  final String letter;
  final List<FriendshipSummary> friends;
}

class FriendsDirectoryController extends ChangeNotifier {
  FriendsDirectoryController({
    required FriendRelationsRepositoryGateway repository,
    required FriendRelationsSocketGateway socket,
  }) : _repository = repository,
       _socket = socket;

  static const pageSize = 100;

  final FriendRelationsRepositoryGateway _repository;
  final FriendRelationsSocketGateway _socket;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  List<FriendshipSummary> _friends = const [];
  String _search = '';
  String? _errorMessage;
  int _pendingRequestCount = 0;
  bool _loading = true;
  bool _refreshing = false;
  bool _started = false;
  bool _disposed = false;

  List<FriendshipSummary> get friends =>
      List<FriendshipSummary>.unmodifiable(_friends);
  String get search => _search;
  String? get errorMessage => _errorMessage;
  int get pendingRequestCount => _pendingRequestCount;
  bool get loading => _loading;
  bool get refreshing => _refreshing;

  FriendshipSummary? friendById(int friendId) {
    for (final friend in _friends) {
      if (friend.friendId == friendId) return friend;
    }
    return null;
  }

  List<FriendshipSummary> get filteredFriends {
    final keyword = _search.trim().toLowerCase();
    if (keyword.isEmpty) return friends;
    return _friends
        .where(
          (friend) =>
              friend.displayName.toLowerCase().contains(keyword) ||
              friend.friendName.toLowerCase().contains(keyword),
        )
        .toList(growable: false);
  }

  List<FriendDirectorySection> get sections {
    final grouped = <String, List<FriendshipSummary>>{};
    for (final friend in filteredFriends) {
      grouped
          .putIfAbsent(_initialFor(friend.displayName), () => [])
          .add(friend);
    }
    final letters = grouped.keys.toList()
      ..sort((first, second) {
        if (first == '#') return 1;
        if (second == '#') return -1;
        return first.compareTo(second);
      });
    return [
      for (final letter in letters)
        FriendDirectorySection(
          letter: letter,
          friends: List<FriendshipSummary>.unmodifiable(grouped[letter]!),
        ),
    ];
  }

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _listenToSocket();
    await _reload(showInitialLoading: true);
  }

  Future<void> refresh() => _reload(showInitialLoading: false);

  Future<void> resume() => refresh();

  void updateSearch(String value) {
    if (_search == value) return;
    _search = value;
    _safeNotify();
  }

  Future<void> updateRemark(FriendshipSummary friend, String rawRemark) async {
    final remark = rawRemark.trim();
    if (remark.isEmpty) throw ArgumentError('备注名不能为空');
    if (remark.length > 100) throw ArgumentError('备注名最多 100 字');
    await _repository.updateFriendRemark(
      friendId: friend.friendId,
      remark: remark,
    );
    _friends = [
      for (final item in _friends)
        if (item.friendId == friend.friendId)
          item.copyWith(remark: remark)
        else
          item,
    ];
    _sortFriends();
    _safeNotify();
  }

  Future<void> deleteFriend(FriendshipSummary friend) async {
    await _repository.deleteFriend(friendId: friend.friendId);
    _removeFriend(friend.friendId);
  }

  Future<void> refreshAfterRequestChanged({required bool accepted}) async {
    await _loadPendingRequestCount();
    if (accepted) await _loadFriends();
    _safeNotify();
  }

  Future<void> stop() async {
    _started = false;
    final subscriptions = List<StreamSubscription<Object?>>.from(
      _subscriptions,
    );
    _subscriptions.clear();
    await Future.wait<void>(subscriptions.map((item) => item.cancel()));
  }

  void _listenToSocket() {
    if (_subscriptions.isNotEmpty) return;
    _subscriptions.addAll(<StreamSubscription<Object?>>[
      _socket.newFriendRequests.listen((_) {
        unawaited(_refreshPendingCountPreservingError());
      }),
      _socket.acceptedFriendRequests.listen((_) {
        unawaited(_refreshRelationsFromSocket());
      }),
      _socket.rejectedFriendRequests.listen((_) {
        unawaited(_refreshPendingCountPreservingError());
      }),
      _socket.deletedFriendships.listen((event) {
        _removeFriend(event.friendId);
        unawaited(_refreshPendingCountPreservingError());
      }),
    ]);
  }

  Future<void> _reload({required bool showInitialLoading}) async {
    if (_refreshing || _disposed) return;
    _refreshing = !showInitialLoading;
    if (showInitialLoading && _friends.isEmpty) _loading = true;
    _errorMessage = null;
    _safeNotify();
    try {
      await Future.wait<void>([_loadFriends(), _loadPendingRequestCount()]);
    } on Object catch (error) {
      _errorMessage = _readableError(error, '通讯录加载失败，请重试');
    } finally {
      _loading = false;
      _refreshing = false;
      _safeNotify();
    }
  }

  Future<void> _loadFriends() async {
    final byFriendId = <int, FriendshipSummary>{};
    var page = 1;
    var hasMore = true;
    while (hasMore) {
      final result = await _repository.loadFriends(
        page: page,
        pageSize: pageSize,
      );
      for (final friend in result.items) {
        byFriendId[friend.friendId] = friend;
      }
      hasMore = result.hasMore;
      page += 1;
    }
    _friends = byFriendId.values.toList(growable: false);
    _sortFriends();
  }

  Future<void> _loadPendingRequestCount() async {
    final result = await _repository.loadFriendRequests(
      status: FriendRequestStatus.pending,
      page: 1,
      pageSize: 1,
    );
    _pendingRequestCount = result.total;
  }

  Future<void> _refreshRelationsFromSocket() async {
    try {
      await Future.wait<void>([_loadFriends(), _loadPendingRequestCount()]);
      _errorMessage = null;
    } on Object catch (error) {
      _errorMessage = _readableError(error, '好友列表实时刷新失败');
    }
    _safeNotify();
  }

  Future<void> _refreshPendingCountPreservingError() async {
    try {
      await _loadPendingRequestCount();
    } on Object catch (error) {
      _errorMessage ??= _readableError(error, '好友申请数量刷新失败');
    }
    _safeNotify();
  }

  void _removeFriend(int friendId) {
    final next = _friends.where((item) => item.friendId != friendId).toList();
    if (next.length == _friends.length) return;
    _friends = next;
    _safeNotify();
  }

  void _sortFriends() {
    _friends = List<FriendshipSummary>.from(_friends)
      ..sort((first, second) {
        final firstInitial = _initialFor(first.displayName);
        final secondInitial = _initialFor(second.displayName);
        if (firstInitial == '#' && secondInitial != '#') return 1;
        if (secondInitial == '#' && firstInitial != '#') return -1;
        final initialResult = firstInitial.compareTo(secondInitial);
        if (initialResult != 0) return initialResult;
        return _sortablePinyin(
          first.displayName,
        ).compareTo(_sortablePinyin(second.displayName));
      });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}

String _initialFor(String rawName) {
  final name = rawName.trim();
  if (name.isEmpty) return '#';
  final firstCharacter = String.fromCharCode(name.runes.first);
  if (RegExp(r'^[A-Za-z]$').hasMatch(firstCharacter)) {
    return firstCharacter.toUpperCase();
  }
  final pinyin = PinyinHelper.getFirstWordPinyin(firstCharacter);
  if (pinyin.isEmpty || !RegExp(r'^[A-Za-z]').hasMatch(pinyin)) return '#';
  return pinyin[0].toUpperCase();
}

String _sortablePinyin(String rawName) {
  final name = rawName.trim();
  if (name.isEmpty) return '';
  return PinyinHelper.getShortPinyin(name).toLowerCase();
}

String _readableError(Object error, String fallback) {
  final text = error.toString().trim();
  if (text.isEmpty) return fallback;
  return text
      .replaceFirst('Exception: ', '')
      .replaceFirst('Invalid argument(s): ', '')
      .replaceFirst('Bad state: ', '');
}
