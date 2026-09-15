import 'package:flutter/foundation.dart';

import '../domain/cart_models.dart';

class CartController extends ChangeNotifier {
  CartController(this._gateway);
  final CartGateway _gateway;

  List<CartItem> items = const [];
  bool loading = false;
  bool managing = false;
  String? errorMessage;

  List<CartItem> get selectedItems =>
      items.where((item) => item.selected && item.available).toList();
  bool get allSelected =>
      items.isNotEmpty &&
      items.every((item) => item.selected || !item.available);
  double get total => selectedItems.fold(0, (sum, item) => sum + item.subtotal);

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      items = await _gateway.loadCart();
    } catch (error) {
      errorMessage = '$error';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void toggleItem(int id) {
    items = items
        .map(
          (item) =>
              item.id == id ? item.copyWith(selected: !item.selected) : item,
        )
        .toList(growable: false);
    notifyListeners();
  }

  void toggleAll() {
    final selected = !allSelected;
    items = items
        .map(
          (item) => item.available
              ? item.copyWith(selected: selected)
              : item.copyWith(selected: false),
        )
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> updateQuantity(CartItem item, int quantity) async {
    final next = quantity.clamp(1, item.stock);
    final updated = await _gateway.updateQuantity(item.id, next);
    items = items
        .map(
          (current) => current.id == item.id
              ? updated.copyWith(selected: current.selected)
              : current,
        )
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> removeSelected() async {
    final selected = items.where((item) => item.selected).toList();
    await removeByIds(selected.map((item) => item.id));
  }

  Future<void> removeByIds(Iterable<int> cartItemIds) async {
    final ids = cartItemIds.toSet();
    if (ids.isEmpty) return;
    Object? firstError;
    for (final id in ids) {
      try {
        await _gateway.removeItem(id);
      } catch (error) {
        firstError ??= error;
      }
    }
    await load();
    if (firstError != null) throw firstError;
  }

  void toggleManaging() {
    managing = !managing;
    notifyListeners();
  }
}
