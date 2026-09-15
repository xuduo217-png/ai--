import 'package:flutter/foundation.dart';

import '../domain/catalog_models.dart';

class CategoryBrowserController extends ChangeNotifier {
  CategoryBrowserController({
    required CatalogGateway gateway,
    this.source = ProductSource.admin,
    this.initialFirstCategoryId,
  }) : _gateway = gateway;

  final CatalogGateway _gateway;
  final ProductSource source;
  final int? initialFirstCategoryId;

  List<CatalogCategory> categories = const [];
  int? selectedFirstCategoryId;
  Map<int, int> selectedSecondCategoryIds = const {};
  bool loading = false;
  String? errorMessage;

  CatalogCategory? get selectedFirstCategory {
    final selectedId = selectedFirstCategoryId;
    if (selectedId == null) return null;
    return categories.where((item) => item.id == selectedId).firstOrNull;
  }

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final loaded = await _gateway.loadCategoryTree(source: source);
      categories = loaded;
      _syncSelections();
    } catch (error) {
      errorMessage = '$error';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  void selectFirstCategory(int categoryId) {
    if (selectedFirstCategoryId == categoryId) return;
    selectedFirstCategoryId = categoryId;
    notifyListeners();
  }

  void selectSecondCategory(int firstCategoryId, int secondCategoryId) {
    if (selectedSecondCategoryIds[firstCategoryId] == secondCategoryId) return;
    selectedSecondCategoryIds = {
      ...selectedSecondCategoryIds,
      firstCategoryId: secondCategoryId,
    };
    notifyListeners();
  }

  CatalogCategory? selectedSecondCategory(CatalogCategory firstCategory) {
    if (firstCategory.children.isEmpty) return null;
    final selectedId = selectedSecondCategoryIds[firstCategory.id];
    return firstCategory.children
            .where((item) => item.id == selectedId)
            .firstOrNull ??
        firstCategory.children.first;
  }

  List<CatalogProduct> productsFor(CatalogCategory firstCategory) {
    return selectedSecondCategory(firstCategory)?.products ??
        firstCategory.products;
  }

  void _syncSelections() {
    if (categories.isEmpty) {
      selectedFirstCategoryId = null;
      selectedSecondCategoryIds = const {};
      return;
    }

    final currentFirstIsValid = categories.any(
      (item) => item.id == selectedFirstCategoryId,
    );
    final initialFirstIsValid = categories.any(
      (item) => item.id == initialFirstCategoryId,
    );
    selectedFirstCategoryId = currentFirstIsValid
        ? selectedFirstCategoryId
        : initialFirstIsValid
        ? initialFirstCategoryId
        : categories.first.id;

    final nextSelections = <int, int>{};
    for (final category in categories) {
      if (category.children.isEmpty) continue;
      final currentSecondId = selectedSecondCategoryIds[category.id];
      nextSelections[category.id] =
          category.children.any((item) => item.id == currentSecondId)
          ? currentSecondId!
          : category.children.first.id;
    }
    selectedSecondCategoryIds = nextSelections;
  }
}
