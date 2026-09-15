import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/notification_models.dart';
import 'notification_badge_controller.dart';

enum NotificationMutationResult { succeeded, failed, busy, missing }

class NotificationListController extends ChangeNotifier {
  NotificationListController({
    required NotificationGateway gateway,
    required NotificationBadgeController badgeController,
  }) : _gateway = gateway,
       _badgeController = badgeController;

  final NotificationGateway _gateway;
  final NotificationBadgeController _badgeController;

  List<UserNotification> notifications = const [];
  int page = 1;
  bool hasMore = false;
  bool isInitialLoading = true;
  bool isRefreshing = false;
  bool isLoadingMore = false;
  bool isMarkingAll = false;
  String? errorMessage;
  String? loadMoreError;
  String? mutationError;

  final Set<int> _markingIds = {};
  Future<void>? _activeReplace;
  Future<void>? _activeLoadMore;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load() => _replace(refresh: false);

  Future<void> refresh() => _replace(refresh: true);

  Future<void> retry() => notifications.isEmpty ? load() : refresh();

  Future<void> _replace({required bool refresh}) {
    if (_disposed) return Future<void>.value();
    final active = _activeReplace;
    if (active != null) return active;
    final generation = ++_generation;
    _activeLoadMore = null;
    isLoadingMore = false;
    loadMoreError = null;
    late final Future<void> replacement;
    replacement = _runReplace(generation, refresh: refresh).whenComplete(() {
      if (_activeReplace == replacement) _activeReplace = null;
      _notify();
    });
    _activeReplace = replacement;
    _notify();
    return replacement;
  }

  Future<void> _runReplace(int generation, {required bool refresh}) async {
    isInitialLoading = !refresh && notifications.isEmpty;
    isRefreshing = refresh;
    errorMessage = null;
    _notify();
    try {
      final result = await _gateway.loadNotifications();
      if (!_isCurrent(generation)) return;
      notifications = result.items;
      page = result.page;
      hasMore = result.hasMore;
    } on Object {
      if (!_isCurrent(generation)) return;
      errorMessage = '通知加载失败，请稍后重试';
      if (notifications.isEmpty) hasMore = false;
    } finally {
      if (_isCurrent(generation)) {
        isInitialLoading = false;
        isRefreshing = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() {
    if (_disposed ||
        !hasMore ||
        isInitialLoading ||
        isRefreshing ||
        _activeReplace != null) {
      return Future<void>.value();
    }
    final active = _activeLoadMore;
    if (active != null) return active;
    final generation = _generation;
    late final Future<void> loading;
    loading = _runLoadMore(generation).whenComplete(() {
      if (_activeLoadMore == loading) _activeLoadMore = null;
      _notify();
    });
    _activeLoadMore = loading;
    _notify();
    return loading;
  }

  Future<void> _runLoadMore(int generation) async {
    isLoadingMore = true;
    loadMoreError = null;
    _notify();
    try {
      final result = await _gateway.loadNotifications(
        NotificationQuery(page: page + 1),
      );
      if (!_isCurrent(generation)) return;
      final existingIds = notifications.map((item) => item.id).toSet();
      notifications = [
        ...notifications,
        ...result.items.where((item) => existingIds.add(item.id)),
      ];
      page = result.page;
      hasMore = result.hasMore;
    } on Object {
      if (!_isCurrent(generation)) return;
      loadMoreError = '加载更多失败，请重试';
    } finally {
      if (_isCurrent(generation)) {
        isLoadingMore = false;
        _notify();
      }
    }
  }

  Future<NotificationMutationResult> markNotificationRead(int id) async {
    if (_disposed) return NotificationMutationResult.missing;
    final index = notifications.indexWhere((item) => item.id == id);
    if (index < 0) return NotificationMutationResult.missing;
    if (_markingIds.contains(id) || isMarkingAll) {
      return NotificationMutationResult.busy;
    }
    if (notifications[index].isRead) {
      return NotificationMutationResult.succeeded;
    }
    _markingIds.add(id);

    mutationError = null;
    final original = notifications[index];
    final generation = _generation;
    final badgeMutation = _badgeController.applyLocalDelta(-1);
    _replaceNotification(
      index,
      original.withReadState(isRead: true, readAt: DateTime.now()),
    );
    _notify();
    try {
      await _gateway.markRead(id);
      if (_isCurrent(generation)) {
        unawaited(_badgeController.refresh());
      }
      return NotificationMutationResult.succeeded;
    } on Object {
      if (_isCurrent(generation)) {
        final currentIndex = notifications.indexWhere((item) => item.id == id);
        if (currentIndex >= 0) _replaceNotification(currentIndex, original);
        mutationError = '标记已读失败，请稍后重试';
        _notify();
      }
      _badgeController.rollback(badgeMutation);
      return NotificationMutationResult.failed;
    } finally {
      _markingIds.remove(id);
      _notify();
    }
  }

  Future<NotificationMutationResult> markAllRead() async {
    if (_disposed) return NotificationMutationResult.missing;
    if (isMarkingAll || _markingIds.isNotEmpty) {
      return NotificationMutationResult.busy;
    }
    if (notifications.every((item) => item.isRead)) {
      return NotificationMutationResult.succeeded;
    }

    isMarkingAll = true;
    mutationError = null;
    final generation = _generation;
    final originals = {for (final item in notifications) item.id: item};
    final badgeMutation = _badgeController.markAllReadLocally();
    final readAt = DateTime.now();
    notifications = notifications
        .map(
          (item) => item.isRead
              ? item
              : item.withReadState(isRead: true, readAt: readAt),
        )
        .toList(growable: false);
    _notify();
    try {
      await _gateway.markAllRead();
      if (_isCurrent(generation)) {
        unawaited(_badgeController.refresh());
      }
      return NotificationMutationResult.succeeded;
    } on Object {
      if (_isCurrent(generation)) {
        notifications = notifications
            .map((item) => originals[item.id] ?? item)
            .toList(growable: false);
        mutationError = '全部标记已读失败，请稍后重试';
        _notify();
      }
      _badgeController.rollback(badgeMutation);
      return NotificationMutationResult.failed;
    } finally {
      isMarkingAll = false;
      _notify();
    }
  }

  void _replaceNotification(int index, UserNotification notification) {
    notifications = [...notifications]..[index] = notification;
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    super.dispose();
  }
}
