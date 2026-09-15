import 'package:flutter/foundation.dart';

import '../domain/lost_found_models.dart';

class LostFoundListController extends ChangeNotifier {
  LostFoundListController({
    required LostFoundGateway gateway,
    required this.authenticated,
    this.publisherId,
    LostFoundRecordType initialType = LostFoundRecordType.lost,
  }) : _gateway = gateway,
       _recordType = initialType;

  final LostFoundGateway _gateway;
  final bool authenticated;
  final int? publisherId;

  LostFoundRecordType _recordType;
  LostFoundRecordType get recordType => _recordType;

  List<LostFoundRecord> _records = const [];
  List<LostFoundRecord> get records => _records;

  bool _loading = false;
  bool get loading => _loading;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  String? _error;
  String? get error => _error;

  int _page = 1;
  int _totalPages = 1;
  bool get hasMore => _page < _totalPages;

  Future<void> load({bool refresh = false}) async {
    if (_loading || _loadingMore) return;
    final nextPage = refresh ? 1 : _page;
    if (!refresh && _records.isNotEmpty) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _gateway.loadLostFoundRecords(
        authenticated: authenticated,
        recordType: _recordType,
        publisherId: publisherId,
        page: nextPage,
      );
      _records = result.items;
      _page = result.page;
      _totalPages = result.totalPages;
    } on Object catch (error) {
      _error = '$error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(refresh: true);

  Future<void> selectType(LostFoundRecordType value) async {
    if (_recordType == value) return;
    _recordType = value;
    _records = const [];
    _page = 1;
    _totalPages = 1;
    notifyListeners();
    await load(refresh: true);
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !hasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final result = await _gateway.loadLostFoundRecords(
        authenticated: authenticated,
        recordType: _recordType,
        publisherId: publisherId,
        page: _page + 1,
      );
      final knownIds = _records.map((item) => item.id).toSet();
      _records = [
        ..._records,
        ...result.items.where((item) => knownIds.add(item.id)),
      ];
      _page = result.page;
      _totalPages = result.totalPages;
    } on Object catch (error) {
      _error = '$error';
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }
}

class LostFoundDetailController extends ChangeNotifier {
  LostFoundDetailController({
    required LostFoundGateway gateway,
    required this.recordId,
    required this.authenticated,
  }) : _gateway = gateway;

  final LostFoundGateway _gateway;
  final int recordId;
  final bool authenticated;

  LostFoundRecord? _record;
  LostFoundRecord? get record => _record;

  List<LostFoundComment> _comments = const [];
  List<LostFoundComment> get comments => _comments;

  int _commentTotal = 0;
  int get commentTotal => _commentTotal;

  int _commentPage = 1;
  int _commentTotalPages = 1;
  bool get hasMoreComments => _commentPage < _commentTotalPages;

  bool _loading = false;
  bool get loading => _loading;

  bool _working = false;
  bool get working => _working;

  String? _error;
  String? get error => _error;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final values = await Future.wait<Object>([
        _gateway.loadLostFoundRecord(recordId, authenticated: authenticated),
        _gateway.loadLostFoundComments(recordId, authenticated: authenticated),
      ]);
      _record = values[0] as LostFoundRecord;
      final comments = values[1] as LostFoundCommentPage;
      _comments = comments.items;
      _commentTotal = comments.total;
      _commentPage = comments.page;
      _commentTotalPages = comments.totalPages;
    } on Object catch (error) {
      _error = '$error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => load();

  Future<void> loadMoreComments() async {
    if (_working || !hasMoreComments) return;
    _working = true;
    notifyListeners();
    try {
      final page = await _gateway.loadLostFoundComments(
        recordId,
        authenticated: authenticated,
        page: _commentPage + 1,
      );
      final knownIds = _comments.map((item) => item.id).toSet();
      _comments = [
        ..._comments,
        ...page.items.where((item) => knownIds.add(item.id)),
      ];
      _commentTotal = page.total;
      _commentPage = page.page;
      _commentTotalPages = page.totalPages;
    } finally {
      _working = false;
      notifyListeners();
    }
  }

  Future<void> createComment(String content, {int? parentId}) async {
    if (_working) return;
    _working = true;
    notifyListeners();
    try {
      await _gateway.createLostFoundComment(
        recordId,
        content: content,
        parentId: parentId,
      );
      final page = await _gateway.loadLostFoundComments(
        recordId,
        authenticated: true,
      );
      _comments = page.items;
      _commentTotal = page.total;
      _commentPage = page.page;
      _commentTotalPages = page.totalPages;
    } finally {
      _working = false;
      notifyListeners();
    }
  }

  Future<void> markFound() async {
    _working = true;
    notifyListeners();
    try {
      _record = await _gateway.markLostFoundRecordFound(recordId);
    } finally {
      _working = false;
      notifyListeners();
    }
  }

  Future<void> delete() => _gateway.deleteLostFoundRecord(recordId);
}
