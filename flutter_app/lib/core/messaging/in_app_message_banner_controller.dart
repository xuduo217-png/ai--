import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'in_app_message_event.dart';

class InAppMessageBannerItem {
  const InAppMessageBannerItem({required this.event, this.messageCount = 1});

  final InAppMessageEvent event;
  final int messageCount;

  InAppMessageBannerItem add(InAppMessageEvent next) {
    return InAppMessageBannerItem(event: next, messageCount: messageCount + 1);
  }
}

class InAppMessageBannerController extends ChangeNotifier {
  InAppMessageBannerController({
    this.displayDuration = const Duration(milliseconds: 4500),
    this.maxPendingBanners = 5,
  });

  final Duration displayDuration;
  final int maxPendingBanners;
  final ListQueue<InAppMessageBannerItem> _pending = ListQueue();
  final ListQueue<String> _recentEventKeys = ListQueue();
  final Set<String> _recentEventKeySet = <String>{};

  InAppMessageBannerItem? _current;
  Timer? _timer;
  bool _disposed = false;

  InAppMessageBannerItem? get current => _current;
  int get pendingCount => _pending.length;

  void show(InAppMessageEvent event) {
    if (_disposed || event.isOffline || event.conversationId.isEmpty) return;
    if (!_remember(event.eventKey)) return;

    final current = _current;
    if (current == null) {
      _current = InAppMessageBannerItem(event: event);
      _startTimer();
      notifyListeners();
      return;
    }
    if (_sameConversation(current.event, event)) {
      _current = current.add(event);
      _startTimer();
      notifyListeners();
      return;
    }

    final pendingItems = _pending.toList(growable: false);
    final existingIndex = pendingItems.indexWhere(
      (item) => _sameConversation(item.event, event),
    );
    if (existingIndex >= 0) {
      pendingItems[existingIndex] = pendingItems[existingIndex].add(event);
      _pending
        ..clear()
        ..addAll(pendingItems);
      return;
    }
    if (_pending.length >= maxPendingBanners && _pending.isNotEmpty) {
      _pending.removeFirst();
    }
    _pending.addLast(InAppMessageBannerItem(event: event));
  }

  void dismiss() {
    if (_disposed || _current == null) return;
    _timer?.cancel();
    _current = _pending.isEmpty ? null : _pending.removeFirst();
    if (_current != null) _startTimer();
    notifyListeners();
  }

  void clear() {
    _timer?.cancel();
    _current = null;
    _pending.clear();
    _recentEventKeys.clear();
    _recentEventKeySet.clear();
    if (!_disposed) notifyListeners();
  }

  bool _remember(String key) {
    if (key.isEmpty || !_recentEventKeySet.add(key)) return false;
    _recentEventKeys.addLast(key);
    while (_recentEventKeys.length > 200) {
      _recentEventKeySet.remove(_recentEventKeys.removeFirst());
    }
    return true;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(displayDuration, dismiss);
  }

  bool _sameConversation(InAppMessageEvent left, InAppMessageEvent right) {
    return left.channel == right.channel &&
        left.conversationId == right.conversationId;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _pending.clear();
    super.dispose();
  }
}
