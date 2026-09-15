import 'package:flutter/foundation.dart';

import '../domain/pet_models.dart';
import 'pet_editor_result.dart';

export 'pet_editor_result.dart';

enum PetDeleteResult { deleted }

class PetListController extends ChangeNotifier {
  PetListController({required PetGateway gateway}) : _gateway = gateway;

  final PetGateway _gateway;

  List<Pet> _pets = const [];
  List<PetCategory> _categories = const [];
  int? _selectedCategoryId;
  String? _errorMessage;
  String? _categoryError;
  bool _isInitialLoading = true;
  bool _disposed = false;
  int _refreshGeneration = 0;
  Future<void>? _loadFuture;
  final Map<int?, Future<void>> _activeRefreshes = {};
  final Map<int, Future<PetDeleteResult>> _activeDeletes = {};

  List<Pet> get pets => _pets;
  List<PetCategory> get categories => _categories;
  int? get selectedCategoryId => _selectedCategoryId;
  String? get errorMessage => _errorMessage;
  String? get categoryError => _categoryError;
  bool get isInitialLoading => _isInitialLoading;
  bool get isRefreshing => _activeRefreshes.isNotEmpty;

  Future<void> load() {
    if (_disposed) return Future<void>.value();
    final active = _loadFuture;
    if (active != null) return active;
    final load = _runLoad();
    _loadFuture = load;
    return load;
  }

  Future<void> _runLoad() async {
    _isInitialLoading = true;
    _notify();
    await Future.wait([_loadCategories(), refresh()]);
    if (_disposed) return;
    _isInitialLoading = false;
    _loadFuture = null;
    _notify();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _gateway.loadCategoryTree();
      if (_disposed) return;
      _categories = categories;
      _categoryError = null;
    } on Object {
      if (_disposed) return;
      _categoryError = '宠物类型加载失败，请稍后重试';
    }
  }

  Future<void> refresh() {
    if (_disposed) return Future<void>.value();
    final categoryId = _selectedCategoryId;
    final active = _activeRefreshes[categoryId];
    if (active != null) return active;

    final generation = ++_refreshGeneration;
    late final Future<void> refresh;
    refresh = _runRefresh(categoryId, generation).whenComplete(() {
      if (_activeRefreshes[categoryId] == refresh) {
        _activeRefreshes.remove(categoryId);
      }
      _notify();
    });
    _activeRefreshes[categoryId] = refresh;
    _notify();
    return refresh;
  }

  Future<void> _runRefresh(int? categoryId, int generation) async {
    try {
      final pets = await _gateway.loadMyPets(categoryId: categoryId);
      if (_disposed ||
          generation != _refreshGeneration ||
          categoryId != _selectedCategoryId) {
        return;
      }
      _pets = pets;
      _errorMessage = null;
    } on Object {
      if (_disposed ||
          generation != _refreshGeneration ||
          categoryId != _selectedCategoryId) {
        return;
      }
      _errorMessage = '宠物列表加载失败，请稍后重试';
    }
  }

  Future<void> retry() async {
    if (_categoryError != null) {
      await Future.wait([_loadCategories(), refresh()]);
      _notify();
      return;
    }
    await refresh();
  }

  Future<void> selectCategory(int? categoryId) {
    if (_disposed || _selectedCategoryId == categoryId) {
      return Future<void>.value();
    }
    _selectedCategoryId = categoryId;
    _notify();
    return refresh();
  }

  bool isDeleting(int petId) => _activeDeletes.containsKey(petId);

  Future<PetDeleteResult> deletePet(int petId) {
    if (_disposed) return Future.error(StateError('宠物列表控制器已释放'));
    final active = _activeDeletes[petId];
    if (active != null) return active;

    late final Future<PetDeleteResult> deletion;
    deletion = _runDelete(petId).whenComplete(() {
      if (_activeDeletes[petId] == deletion) _activeDeletes.remove(petId);
      _notify();
    });
    _activeDeletes[petId] = deletion;
    _notify();
    return deletion;
  }

  Future<PetDeleteResult> _runDelete(int petId) async {
    await _gateway.deletePet(petId);
    if (_disposed) throw StateError('宠物列表控制器已释放');
    _pets = _pets.where((pet) => pet.id != petId).toList(growable: false);
    _notify();
    return PetDeleteResult.deleted;
  }

  Future<void> handleEditorResult(PetEditorResult? result) {
    if (result == null) return Future<void>.value();
    return refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
