import '../../shared/mall_json.dart';
import '../domain/catalog_models.dart';

CatalogProduct catalogProductFromJson(
  Map<String, dynamic> json, {
  required String baseUrl,
}) {
  final imageValues = asJsonList(json['images'])
      .map((image) => resolveMallImage(baseUrl, image))
      .where((image) => image.isNotEmpty)
      .toList(growable: false);
  final primaryImage = imageValues.isNotEmpty
      ? imageValues.first
      : resolveMallImage(baseUrl, json['image']);
  final publisherJson = asJsonMap(json['publisher']);
  return CatalogProduct(
    id: jsonInt(json['id']),
    name: jsonString(json['name'] ?? json['title']),
    description: jsonString(json['description']),
    price: jsonDouble(json['price']),
    originalPrice: json['originalPrice'] == null
        ? null
        : jsonDouble(json['originalPrice']),
    stock: jsonInt(json['stock']),
    imageUrl: primaryImage,
    images: imageValues.isEmpty && primaryImage.isNotEmpty
        ? [primaryImage]
        : imageValues,
    isActive: jsonBool(json['isActive'], true),
    categoryId: jsonInt(json['categoryId']) > 0
        ? jsonInt(json['categoryId'])
        : null,
    hasSku: jsonBool(json['hasSku']),
    skus: asJsonList(json['skus'])
        .map((item) => catalogSkuFromJson(asJsonMap(item), baseUrl: baseUrl))
        .toList(growable: false),
    sells: jsonInt(json['sells']),
    isHot: jsonBool(json['isHot']),
    isTop: jsonBool(json['isTop']),
    isFavorited: jsonBool(json['isFavorited']),
    source: ProductSource.fromJson(json['publishSource']),
    publishedBy: jsonInt(json['publishedBy']) > 0
        ? jsonInt(json['publishedBy'])
        : null,
    publisher: publisherJson.isEmpty
        ? null
        : ProductPublisher(
            id: jsonInt(publisherJson['id']),
            nickname: jsonString(publisherJson['nickname']),
            username: jsonString(publisherJson['username']),
            phone: jsonString(publisherJson['phone']),
          ),
    condition: jsonNullableString(json['condition']),
    negotiable: jsonBool(json['negotiable']),
    shippingFee: jsonDouble(json['shippingFee']),
  );
}

ProductSku catalogSkuFromJson(
  Map<String, dynamic> json, {
  required String baseUrl,
}) {
  return ProductSku(
    id: jsonInt(json['id']),
    name: jsonString(json['name']),
    specs: asJsonMap(
      json['specs'],
    ).map((key, value) => MapEntry(key, jsonString(value))),
    price: jsonDouble(json['price']),
    originalPrice: json['originalPrice'] == null
        ? null
        : jsonDouble(json['originalPrice']),
    stock: jsonInt(json['stock']),
    status: jsonString(json['status']).toUpperCase(),
    imageUrl: resolveMallImage(baseUrl, json['image']),
    skuCode: jsonString(json['skuCode']),
  );
}
