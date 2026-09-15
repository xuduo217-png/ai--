import '../../../../core/network/api_client.dart';
import '../../shared/mall_json.dart';
import '../domain/after_sale_models.dart';
import '../domain/order_models.dart';
import 'order_repository.dart';

class AfterSaleRepository implements AfterSaleGateway {
  AfterSaleRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<OrderAfterSale> createAfterSale(
    int orderId, {
    required AfterSaleType afterSaleType,
    required List<AfterSaleRequestItem> items,
    required String reasonCode,
    String? description,
    List<String> evidenceUrls = const [],
  }) {
    return _post(
      '/shop/orders/$orderId/after-sales',
      body: {
        'afterSaleType': afterSaleType.wireValue,
        'items': items.map((item) => item.toJson()).toList(growable: false),
        'reasonCode': reasonCode,
        'description': description?.trim(),
        'evidenceUrls': evidenceUrls,
      },
    );
  }

  @override
  Future<OrderAfterSale> loadAfterSale(int afterSaleId) async {
    final payload = await _apiClient.get('/shop/after-sales/$afterSaleId');
    return _parse(asJsonMap(unwrapData(payload)));
  }

  @override
  Future<OrderAfterSale> cancelAfterSale(int afterSaleId) =>
      _post('/shop/after-sales/$afterSaleId/cancel');

  @override
  Future<OrderAfterSale> approveAfterSale(
    int afterSaleId, {
    required bool returnRequired,
    String? returnAddress,
    String? reason,
  }) {
    return _post(
      '/shop/after-sales/$afterSaleId/seller/approve',
      body: {
        'returnRequired': returnRequired,
        'returnAddress': returnAddress?.trim(),
        'reason': reason?.trim(),
      },
    );
  }

  @override
  Future<OrderAfterSale> rejectAfterSale(
    int afterSaleId, {
    required String reason,
  }) => _post(
    '/shop/after-sales/$afterSaleId/seller/reject',
    body: {'reason': reason.trim()},
  );

  @override
  Future<OrderAfterSale> submitReturn(
    int afterSaleId, {
    String? trackingNumber,
    List<String> evidenceUrls = const [],
  }) => _post(
    '/shop/after-sales/$afterSaleId/return',
    body: {
      'trackingNumber': trackingNumber?.trim(),
      'evidenceUrls': evidenceUrls,
    },
  );

  @override
  Future<OrderAfterSale> confirmReturn(int afterSaleId) =>
      _post('/shop/after-sales/$afterSaleId/confirm-return');

  @override
  Future<OrderAfterSale> applyArbitration(
    int afterSaleId, {
    required String reason,
    List<String> evidenceUrls = const [],
  }) => _post(
    '/shop/after-sales/$afterSaleId/arbitration',
    body: {'reason': reason.trim(), 'evidenceUrls': evidenceUrls},
  );

  @override
  Future<String> uploadEvidence(String filePath) async {
    final payload = asJsonMap(
      unwrapData(
        await _apiClient.uploadFile(
          '/upload/image',
          filePath: filePath,
          fields: const {'category': 'shop-after-sale'},
        ),
      ),
    );
    final url = jsonString(payload['url']).trim();
    if (url.isEmpty) throw const ApiException('图片上传成功但未返回地址');
    return resolveMallImage(_apiClient.baseUrl, url);
  }

  Future<OrderAfterSale> _post(
    String path, {
    Map<String, Object?> body = const {},
  }) async {
    final payload = await _apiClient.post(
      path,
      authenticated: true,
      body: body,
    );
    return _parse(asJsonMap(unwrapData(payload)));
  }

  OrderAfterSale _parse(Map<String, dynamic> json) {
    final orderJson = asJsonMap(json['order']);
    return OrderAfterSale(
      id: jsonInt(json['id']),
      afterSaleNo: jsonString(json['afterSaleNo']),
      orderId: jsonInt(json['orderId']),
      orderType: jsonString(json['orderType'], 'second_hand'),
      handlerType: AfterSaleHandlerType.fromJson(json['handlerType']),
      afterSaleType: AfterSaleType.fromJson(json['afterSaleType']),
      status: AfterSaleStatus.fromJson(json['status']),
      reasonCode: jsonString(json['reasonCode']),
      description: jsonNullableString(json['description']),
      evidenceUrls: _urls(json['evidenceUrls']),
      handlerDecision: jsonNullableString(
        json['handlerDecision'] ?? json['sellerDecision'],
      ),
      handlerReason: jsonNullableString(
        json['handlerReason'] ?? json['sellerReason'],
      ),
      returnRequired: json['returnRequired'] == null
          ? null
          : jsonBool(json['returnRequired']),
      returnAddress: jsonNullableString(json['returnAddress']),
      returnTrackingNumber: jsonNullableString(json['returnTrackingNumber']),
      returnEvidenceUrls: _urls(json['returnEvidenceUrls']),
      arbitrationReason: jsonNullableString(json['arbitrationReason']),
      arbitrationEvidenceUrls: _urls(json['arbitrationEvidenceUrls']),
      arbitrationDecision: jsonNullableString(json['arbitrationDecision']),
      arbitrationRemark: jsonNullableString(json['arbitrationRemark']),
      currentDeadlineAt: jsonDateTime(json['currentDeadlineAt']),
      requestedAmount: jsonDouble(
        json['requestedAmount'],
        jsonDouble(json['refundAmount']),
      ),
      approvedAmount: json['approvedAmount'] == null
          ? null
          : jsonDouble(json['approvedAmount']),
      refundAmount: jsonDouble(
        json['refundAmount'],
        jsonDouble(json['requestedAmount']),
      ),
      refundFailureReason: jsonNullableString(json['refundFailureReason']),
      items: asJsonList(json['items'])
          .map(asJsonMap)
          .map(
            (item) => AfterSaleItem(
              lineKey: jsonString(item['lineKey']),
              productId: jsonInt(item['productId']),
              skuId: jsonInt(item['skuId']) > 0 ? jsonInt(item['skuId']) : null,
              productName: jsonString(item['productName']),
              skuName: jsonNullableString(item['skuName']),
              productImage: resolveMallImage(
                _apiClient.baseUrl,
                item['productImage'],
              ),
              requestedQuantity: jsonInt(item['requestedQuantity']),
              approvedQuantity: jsonInt(item['approvedQuantity']),
              refundedQuantity: jsonInt(item['refundedQuantity']),
              unitPrice: jsonDouble(item['unitPrice']),
              discountAmount: jsonDouble(item['discountAmount']),
              paidAmount: jsonDouble(item['paidAmount']),
              approvedAmount: jsonDouble(item['approvedAmount']),
              refundedAmount: jsonDouble(item['refundedAmount']),
              restockQuantity: jsonInt(item['restockQuantity']),
              inventoryRestoredQuantity: jsonInt(
                item['inventoryRestoredQuantity'],
              ),
            ),
          )
          .toList(growable: false),
      availableActions: _strings(json['availableActions']),
      logs: asJsonList(json['logs'])
          .map(asJsonMap)
          .map(
            (log) => AfterSaleLog(
              id: jsonInt(log['id']),
              action: jsonString(log['action']),
              operatorType: jsonString(log['operatorType']),
              description: jsonNullableString(log['description']),
              createdAt: jsonDateTime(log['createdAt']),
            ),
          )
          .toList(growable: false),
      order: orderJson.isEmpty
          ? null
          : parseShopOrder(orderJson, baseUrl: _apiClient.baseUrl),
      viewRole: OrderViewRole.fromJson(json['viewRole']),
    );
  }

  List<String> _strings(Object? value) => asJsonList(
    value,
  ).map(jsonString).where((item) => item.isNotEmpty).toList(growable: false);

  List<String> _urls(Object? value) => _strings(value)
      .map((url) => resolveMallImage(_apiClient.baseUrl, url))
      .toList(growable: false);
}
