import 'package:flutter/foundation.dart';

import '../domain/activity_models.dart';

class ActivityListController extends ChangeNotifier {
  ActivityListController({
    required ActivityGateway gateway,
    required this.authenticated,
  }) : _gateway = gateway;

  final ActivityGateway _gateway;
  final bool authenticated;

  ActivityStatus selectedStatus = ActivityStatus.ongoing;
  String searchKeyword = '';
  List<ActivityItem> activities = const [];
  bool loading = true;
  bool refreshing = false;
  bool loadingMore = false;
  String? error;

  int _page = 0;
  int _totalPages = 0;
  int _generation = 0;
  bool _disposed = false;

  bool get hasMore => _page < _totalPages;

  Future<void> load() => _replace(showLoading: activities.isEmpty);

  Future<void> refresh() => _replace(showLoading: false, refresh: true);

  Future<void> retry() => activities.isEmpty ? load() : refresh();

  Future<void> selectStatus(ActivityStatus status) async {
    if (_disposed || status == selectedStatus) return;
    selectedStatus = status;
    activities = const [];
    await _replace(showLoading: true);
  }

  Future<void> search(String keyword) async {
    final normalized = keyword.trim();
    if (_disposed || normalized == searchKeyword) return;
    searchKeyword = normalized;
    activities = const [];
    await _replace(showLoading: true);
  }

  Future<void> loadMore() async {
    if (_disposed || loading || refreshing || loadingMore || !hasMore) return;
    final generation = _generation;
    loadingMore = true;
    error = null;
    _notify();
    try {
      final result = await _gateway.loadActivities(
        authenticated: authenticated,
        status: selectedStatus,
        keyword: searchKeyword,
        page: _page + 1,
      );
      if (!_isCurrent(generation)) return;
      activities = _sort(_merge(activities, result.items));
      _page = result.page;
      _totalPages = result.totalPages;
    } on Object {
      if (_isCurrent(generation)) error = '加载更多失败，请稍后重试';
    } finally {
      if (_isCurrent(generation)) {
        loadingMore = false;
        _notify();
      }
    }
  }

  Future<void> _replace({
    required bool showLoading,
    bool refresh = false,
  }) async {
    if (_disposed) return;
    final generation = ++_generation;
    loading = showLoading;
    refreshing = refresh;
    loadingMore = false;
    error = null;
    _notify();
    try {
      final result = await _gateway.loadActivities(
        authenticated: authenticated,
        status: selectedStatus,
        keyword: searchKeyword,
      );
      if (!_isCurrent(generation)) return;
      activities = _sort(result.items);
      _page = result.page;
      _totalPages = result.totalPages;
    } on Object {
      if (_isCurrent(generation)) error = '活动列表加载失败，请稍后重试';
    } finally {
      if (_isCurrent(generation)) {
        loading = false;
        refreshing = false;
        _notify();
      }
    }
  }

  List<ActivityItem> _merge(
    List<ActivityItem> current,
    List<ActivityItem> incoming,
  ) {
    final ids = current.map((item) => item.id).toSet();
    return [...current, ...incoming.where((item) => ids.add(item.id))];
  }

  List<ActivityItem> _sort(List<ActivityItem> source) {
    return [...source]..sort((left, right) {
      final statusOrder = _statusOrder(
        left.status,
      ).compareTo(_statusOrder(right.status));
      if (statusOrder != 0) return statusOrder;
      final startOrder = (right.startTime?.millisecondsSinceEpoch ?? 0)
          .compareTo(left.startTime?.millisecondsSinceEpoch ?? 0);
      if (startOrder != 0) return startOrder;
      return (right.updatedAt?.millisecondsSinceEpoch ?? 0).compareTo(
        left.updatedAt?.millisecondsSinceEpoch ?? 0,
      );
    });
  }

  int _statusOrder(ActivityStatus status) => switch (status) {
    ActivityStatus.ongoing => 0,
    ActivityStatus.upcoming => 1,
    ActivityStatus.expired => 2,
  };

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

class ActivityDetailController extends ChangeNotifier {
  ActivityDetailController({
    required ActivityGateway gateway,
    required this.activityId,
    required this.authenticated,
  }) : _gateway = gateway;

  final ActivityGateway _gateway;
  final int activityId;
  final bool authenticated;

  ActivityItem? activity;
  bool loading = true;
  bool actionLoading = false;
  bool mediaUploading = false;
  int? votingOptionId;
  String? error;

  int _generation = 0;
  bool _disposed = false;

  Future<void> load() => _load(showLoading: activity == null);

  Future<void> refresh() => _load(showLoading: false);

  Future<void> _load({required bool showLoading}) async {
    if (_disposed) return;
    final generation = ++_generation;
    loading = showLoading;
    error = null;
    _notify();
    try {
      final result = await _gateway.loadActivityDetail(
        activityId,
        authenticated: authenticated,
      );
      if (_isCurrent(generation)) activity = result;
    } on Object {
      if (_isCurrent(generation)) error = '加载活动详情失败，请稍后重试';
    } finally {
      if (_isCurrent(generation)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<ActivityActionResult<void>> register(String phone) async {
    return _runAction(() async {
      final result = await _gateway.registerActivity(activityId, phone: phone);
      if (result.success) await _reloadAfterAction();
      return result;
    });
  }

  Future<ActivityActionResult<void>> vote(int optionId) async {
    if (_disposed || actionLoading) throw StateError('操作正在进行中');
    votingOptionId = optionId;
    _notify();
    try {
      return await _runAction(() async {
        final result = await _gateway.voteActivity(
          activityId,
          optionId: optionId,
        );
        if (result.success) await _reloadAfterAction();
        return result;
      });
    } finally {
      if (!_disposed) {
        votingOptionId = null;
        _notify();
      }
    }
  }

  Future<ActivityActionResult<ActivityVoteOption>> saveVoteOption(
    ActivityVoteOptionDraft draft, {
    int? optionId,
  }) async {
    return _runAction(() async {
      final result = optionId == null
          ? await _gateway.createActivityVoteOption(activityId, draft)
          : await _gateway.updateActivityVoteOption(
              activityId,
              optionId,
              draft,
            );
      if (result.success) await _reloadAfterAction();
      return result;
    });
  }

  Future<ActivityActionResult<void>> deleteVoteOption(int optionId) {
    return _runAction(
      () => _gateway.deleteActivityVoteOption(activityId, optionId),
    );
  }

  Future<ActivityMediaUpload> uploadImage({
    required String filePath,
    String? filename,
  }) {
    return _upload(
      () =>
          _gateway.uploadActivityImage(filePath: filePath, filename: filename),
    );
  }

  Future<ActivityMediaUpload> uploadVideo({
    required String filePath,
    String? filename,
  }) {
    return _upload(
      () =>
          _gateway.uploadActivityVideo(filePath: filePath, filename: filename),
    );
  }

  Future<T> _runAction<T>(Future<T> Function() action) async {
    if (_disposed || actionLoading) throw StateError('操作正在进行中');
    actionLoading = true;
    _notify();
    try {
      return await action();
    } finally {
      if (!_disposed) {
        actionLoading = false;
        _notify();
      }
    }
  }

  Future<ActivityMediaUpload> _upload(
    Future<ActivityMediaUpload> Function() upload,
  ) async {
    if (_disposed || mediaUploading) throw StateError('文件正在上传中');
    mediaUploading = true;
    _notify();
    try {
      return await upload();
    } finally {
      if (!_disposed) {
        mediaUploading = false;
        _notify();
      }
    }
  }

  Future<void> _reloadAfterAction() async {
    final result = await _gateway.loadActivityDetail(
      activityId,
      authenticated: authenticated,
    );
    if (!_disposed) activity = result;
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

class ActivityCommentsController extends ChangeNotifier {
  ActivityCommentsController({
    required ActivityGateway gateway,
    required this.activityId,
    required this.authenticated,
    this.voteOptionId,
  }) : _gateway = gateway;

  final ActivityGateway _gateway;
  final int activityId;
  final int? voteOptionId;
  final bool authenticated;

  List<ActivityComment> comments = const [];
  int total = 0;
  bool loading = true;
  bool loadingMore = false;
  bool submitting = false;
  String? error;

  int _page = 0;
  int _totalPages = 0;
  int _generation = 0;
  bool _disposed = false;

  bool get hasMore => _page < _totalPages;

  Future<void> load() => _replace(showLoading: comments.isEmpty);

  Future<void> refresh() => _replace(showLoading: false);

  Future<void> _replace({required bool showLoading}) async {
    if (_disposed) return;
    final generation = ++_generation;
    loading = showLoading;
    error = null;
    _notify();
    try {
      final result = await _gateway.loadActivityComments(
        activityId,
        authenticated: authenticated,
        voteOptionId: voteOptionId,
      );
      if (!_isCurrent(generation)) return;
      comments = result.items;
      total = result.total;
      _page = result.page;
      _totalPages = result.totalPages;
    } on Object {
      if (_isCurrent(generation)) error = '评论加载失败，请稍后重试';
    } finally {
      if (_isCurrent(generation)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (_disposed || loading || loadingMore || !hasMore) return;
    final generation = _generation;
    loadingMore = true;
    error = null;
    _notify();
    try {
      final result = await _gateway.loadActivityComments(
        activityId,
        authenticated: authenticated,
        voteOptionId: voteOptionId,
        page: _page + 1,
      );
      if (!_isCurrent(generation)) return;
      final ids = comments.map((item) => item.id).toSet();
      comments = [
        ...comments,
        ...result.items.where((item) => ids.add(item.id)),
      ];
      total = result.total;
      _page = result.page;
      _totalPages = result.totalPages;
    } on Object {
      if (_isCurrent(generation)) error = '加载更多评论失败，请稍后重试';
    } finally {
      if (_isCurrent(generation)) {
        loadingMore = false;
        _notify();
      }
    }
  }

  Future<ActivityComment> submit(String content, {int? parentId}) async {
    if (_disposed || submitting) throw StateError('评论正在提交中');
    submitting = true;
    _notify();
    try {
      final comment = await _gateway.createActivityComment(
        activityId,
        content: content,
        voteOptionId: voteOptionId,
        parentId: parentId,
      );
      await refresh();
      return comment;
    } finally {
      if (!_disposed) {
        submitting = false;
        _notify();
      }
    }
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
