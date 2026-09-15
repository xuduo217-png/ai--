import 'package:flutter/foundation.dart';

import '../domain/favorite_models.dart';

class FavoriteController extends ChangeNotifier {
  FavoriteController(this._gateway);
  final FavoriteGateway _gateway;

  List<FavoriteEntry> items = const [];
  int page = 1;
  bool hasMore = false;
  bool loading = false;
  bool loadingMore = false;
  String? errorMessage;
  int _requestRevision = 0;
  bool _disposed = false;

  Future<void> load() async {
    if (_disposed) return;
    final revision = ++_requestRevision;
    loading = true;
    loadingMore = false;
    errorMessage = null;
    _notify();
    try {
      final result = await _gateway.loadFavorites();
      if (!_isCurrent(revision)) return;
      items = result.items;
      page = result.page;
      hasMore = result.hasMore;
    } catch (error) {
      if (!_isCurrent(revision)) return;
      errorMessage = '$error';
    } finally {
      if (_isCurrent(revision)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (_disposed || !hasMore || loading || loadingMore) return;
    final revision = ++_requestRevision;
    final nextPage = page + 1;
    loadingMore = true;
    errorMessage = null;
    _notify();
    try {
      final result = await _gateway.loadFavorites(page: nextPage);
      if (!_isCurrent(revision)) return;
      final byId = <int, FavoriteEntry>{
        for (final item in items) item.id: item,
      };
      for (final item in result.items) {
        byId[item.id] = item;
      }
      items = byId.values.toList(growable: false);
      page = result.page;
      hasMore = result.hasMore;
    } catch (error) {
      if (!_isCurrent(revision)) return;
      errorMessage = '$error';
    } finally {
      if (_isCurrent(revision)) {
        loadingMore = false;
        _notify();
      }
    }
  }

  Future<void> remove(FavoriteEntry entry) async {
    if (_disposed) return;
    await _gateway.removeFavorite(entry.id);
    if (_disposed) return;
    items = items.where((item) => item.id != entry.id).toList(growable: false);
    _notify();
  }

  bool _isCurrent(int revision) => !_disposed && revision == _requestRevision;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestRevision += 1;
    super.dispose();
  }
}
