import '../../catalog/domain/catalog_models.dart';

class CartItem {
  const CartItem({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.product,
    this.skuId,
    this.sku,
    this.selected = true,
  });

  final int id;
  final int productId;
  final int? skuId;
  final int quantity;
  final CatalogProduct product;
  final ProductSku? sku;
  final bool selected;

  double get unitPrice => sku?.price ?? product.price;
  double get subtotal => unitPrice * quantity;
  int get stock => sku?.stock ?? product.stock;
  bool get available => product.isActive && stock > 0;
  String get specification => sku?.specification ?? '';

  CartItem copyWith({int? quantity, bool? selected}) {
    return CartItem(
      id: id,
      productId: productId,
      skuId: skuId,
      quantity: quantity ?? this.quantity,
      product: product,
      sku: sku,
      selected: selected ?? this.selected,
    );
  }
}

abstract interface class CartGateway {
  Future<List<CartItem>> loadCart();
  Future<CartItem> addItem({
    required int productId,
    int? skuId,
    required int quantity,
  });
  Future<CartItem> updateQuantity(int cartItemId, int quantity);
  Future<void> removeItem(int cartItemId);
  Future<void> clear();
  Future<int> loadCount();
}
