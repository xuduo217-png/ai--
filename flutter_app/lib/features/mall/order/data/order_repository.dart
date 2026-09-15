import '../../../../core/network/api_client.dart';
import '../../shared/mall_json.dart';
import '../domain/order_models.dart';

class OrderRepository implements OrderGateway, SecondHandOrderGateway {
  OrderRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<OrderPage> loadOrders(OrderQuery query) async {
    final payload = await _apiClient.get(
      query.viewRole == OrderViewRole.seller
          ? '/shop/orders/sales'
          : '/shop/orders/purchases',
      queryParameters: query.toQueryParameters(),
    );
    final root = asJsonMap(payload);
    final data = root.containsKey('data') ? root['data'] : payload;
    final items = asJsonList(data)
        .map(
          (item) =>
              parseShopOrder(asJsonMap(item), baseUrl: _apiClient.baseUrl),
        )
        .toList(growable: false);
    final pagination = root.containsKey('pagination')
        ? asJsonMap(root['pagination'])
        : root;
    final total = jsonInt(pagination['total'], items.length);
    final pageSize = jsonInt(
      pagination['pageSize'] ?? pagination['limit'],
      query.pageSize,
    );
    return OrderPage(
      items: items,
      total: total,
      page: jsonInt(pagination['page'], query.page),
      pageSize: pageSize,
      totalPages: jsonInt(
        pagination['totalPages'],
        pageSize == 0 ? 0 : (total / pageSize).ceil(),
      ),
    );
  }

  @override
  Future<ShopOrder> loadOrder(int orderId) async {
    return parseShopOrder(
      asJsonMap(unwrapData(await _apiClient.get('/shop/orders/$orderId'))),
      baseUrl: _apiClient.baseUrl,
    );
  }

  @override
  Future<ShopOrder> cancelOrder(int orderId, {String? reason}) async {
    final payload = await _apiClient.post(
      '/shop/orders/$orderId/cancel',
      authenticated: true,
      body: {'reason': reason},
    );
    return parseShopOrder(
      asJsonMap(unwrapData(payload)),
      baseUrl: _apiClient.baseUrl,
    );
  }

  @override
  Future<ShopOrder> confirmOrder(int orderId) async {
    final payload = await _apiClient.post(
      '/shop/orders/$orderId/confirm-receipt',
      authenticated: true,
    );
    return parseShopOrder(
      asJsonMap(unwrapData(payload)),
      baseUrl: _apiClient.baseUrl,
    );
  }

  @override
  Future<OrderPayment> payOrder(int orderId, PaymentChannel channel) async {
    final payload = asJsonMap(
      unwrapData(
        await _apiClient.post(
          '/shop/orders/$orderId/pay',
          authenticated: true,
          body: {'paymentChannel': channel.wireValue},
        ),
      ),
    );
    return OrderPayment(
      order: parseShopOrder(
        asJsonMap(payload['order']),
        baseUrl: _apiClient.baseUrl,
      ),
      paymentParams: asJsonMap(payload['paymentParams']),
    );
  }

  @override
  Future<ShopOrder> shipOrder(int orderId, {String? trackingNumber}) async {
    final payload = await _apiClient.post(
      '/shop/orders/$orderId/ship',
      authenticated: true,
      body: {'trackingNumber': trackingNumber?.trim()},
    );
    return parseShopOrder(
      asJsonMap(unwrapData(payload)),
      baseUrl: _apiClient.baseUrl,
    );
  }

  @override
  Future<ShopOrder> updateTracking(
    int orderId, {
    String? trackingNumber,
  }) async {
    final payload = await _apiClient.patch(
      '/shop/orders/$orderId/tracking',
      body: {'trackingNumber': trackingNumber?.trim()},
    );
    return parseShopOrder(
      asJsonMap(unwrapData(payload)),
      baseUrl: _apiClient.baseUrl,
    );
  }

  @override
  Future<OrderActionSummary> loadActionSummary() async {
    final data = asJsonMap(
      unwrapData(await _apiClient.get('/shop/orders/action-summary')),
    );
    final purchases = asJsonMap(data['purchases']);
    final sales = asJsonMap(data['sales']);
    return OrderActionSummary(
      pendingReceipt: jsonInt(purchases['pendingReceipt']),
      afterSaleResult: jsonInt(purchases['afterSaleResult']),
      pendingShipment: jsonInt(sales['pendingShipment']),
      pendingAfterSale: jsonInt(sales['pendingAfterSale']),
    );
  }
}

ShopOrder parseShopOrder(Map<String, dynamic> json, {String baseUrl = ''}) {
  final afterSaleJson = asJsonMap(json['afterSaleSummary']);
  return ShopOrder(
    id: jsonInt(json['id']),
    orderNo: jsonString(json['orderNo']),
    orderType: jsonString(json['orderType'], 'normal'),
    status: ShopOrderStatus.fromJson(json['status']),
    totalAmount: jsonDouble(json['totalAmount']),
    originalAmount: jsonDouble(
      json['originalAmount'],
      jsonDouble(json['totalAmount']),
    ),
    couponDiscount: jsonDouble(json['couponDiscount']),
    items: asJsonList(json['items'])
        .map((item) => parseShopOrderItem(asJsonMap(item), baseUrl: baseUrl))
        .toList(growable: false),
    shippingAddress: jsonNullableString(json['shippingAddress']),
    receiverName: jsonNullableString(json['receiverName']),
    receiverPhone: jsonNullableString(json['receiverPhone']),
    remark: jsonNullableString(json['remark']),
    paymentMethod: jsonNullableString(json['paymentMethod']),
    paymentNo: jsonNullableString(json['paymentNo']),
    transactionId: jsonNullableString(json['transactionId']),
    createdAt: jsonDateTime(json['createdAt']),
    paidAt: jsonDateTime(json['paidAt']),
    shippedAt: jsonDateTime(json['shippedAt']),
    completedAt: jsonDateTime(json['completedAt']),
    cancelledAt: jsonDateTime(json['cancelledAt']),
    cancelReason: jsonNullableString(json['cancelReason']),
    trackingNumber: jsonNullableString(json['trackingNumber']),
    viewRole: OrderViewRole.fromJson(json['viewRole']),
    availableActions: asJsonList(json['availableActions'])
        .map((item) => jsonString(item))
        .where((item) => item.isNotEmpty)
        .toList(growable: false),
    afterSaleSummary: afterSaleJson.isEmpty
        ? null
        : OrderAfterSaleSummary(
            id: jsonInt(afterSaleJson['id']),
            afterSaleNo: jsonString(afterSaleJson['afterSaleNo']),
            status: jsonString(afterSaleJson['status']),
            refundAmount: jsonDouble(afterSaleJson['refundAmount']),
            updatedAt: jsonDateTime(afterSaleJson['updatedAt']),
          ),
    autoConfirmAt: jsonDateTime(json['autoConfirmAt']),
    settlementStatus: jsonNullableString(json['settlementStatus']),
    charityDonationAmount: json['charityDonationAmount'] == null
        ? null
        : jsonDouble(json['charityDonationAmount']),
  );
}

ShopOrderItem parseShopOrderItem(
  Map<String, dynamic> json, {
  String baseUrl = '',
}) {
  return ShopOrderItem(
    productId: jsonInt(json['productId']),
    productName: jsonString(json['productName']),
    productImage: resolveMallImage(baseUrl, json['productImage']),
    skuId: jsonInt(json['skuId']) > 0 ? jsonInt(json['skuId']) : null,
    skuName: jsonNullableString(json['skuName']),
    quantity: jsonInt(json['quantity'], 1),
    price: jsonDouble(json['price']),
    lineKey: jsonString(json['lineKey']),
    discountAmount: jsonDouble(json['discountAmount']),
    paidAmount: jsonDouble(json['paidAmount']),
  );
}
