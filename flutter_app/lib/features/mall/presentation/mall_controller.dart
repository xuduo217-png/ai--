import 'package:flutter/foundation.dart';

import '../domain/mall_models.dart';

class MallController extends ChangeNotifier {
  MallController({required MallGateway gateway, required this.authenticated})
    : _gateway = gateway;

  final MallGateway _gateway;
  final bool authenticated;

  MallSnapshot snapshot = const MallSnapshot();
  bool loading = true;
  bool refreshing = false;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      snapshot = await _gateway.loadMall(authenticated: authenticated);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    refreshing = true;
    notifyListeners();
    try {
      snapshot = await _gateway.loadMall(authenticated: authenticated);
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  Future<MallProduct> loadProduct(int productId) {
    return _gateway.loadProduct(productId);
  }

  Future<void> addToCart({
    required int productId,
    required int? skuId,
    required int quantity,
  }) async {
    await _gateway.addToCart(
      productId: productId,
      skuId: skuId,
      quantity: quantity,
    );
    final hasItems = await _gateway.loadCartBadge();
    snapshot = snapshot.copyWith(hasCartItems: hasItems);
    notifyListeners();
  }
}
