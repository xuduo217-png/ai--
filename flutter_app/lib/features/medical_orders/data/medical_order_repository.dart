import '../../../core/network/api_client.dart';
import '../domain/medical_order_models.dart';

class MedicalOrderRepository implements MedicalOrderGateway {
  const MedicalOrderRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<MedicalOrderPage> loadOrders([
    MedicalOrderQuery query = const MedicalOrderQuery(),
  ]) async {
    final response = await _apiClient.get(
      '/chat/orders',
      queryParameters: query.toQueryParameters(),
    );
    final root = _asMap(response, 'medical orders response');
    final data = root['data'];
    if (data is! List) {
      throw const FormatException('medical orders data must be a list.');
    }
    final total = _requiredInt(root['total'], 'total');
    final page = _requiredInt(root['page'], 'page');
    final pageSize = _requiredInt(root['pageSize'], 'pageSize');
    final totalPages = _requiredInt(root['totalPages'], 'totalPages');
    if (total < 0 || page < 1 || pageSize < 1 || totalPages < 0) {
      throw const FormatException('medical orders pagination is invalid.');
    }

    return MedicalOrderPage(
      items: data
          .map(
            (item) => MedicalServiceOrder.fromJson(
              _asMap(item, 'medical order item'),
            ),
          )
          .toList(growable: false),
      total: total,
      page: page,
      pageSize: pageSize,
      totalPages: totalPages,
    );
  }
}

Map<String, Object?> _asMap(Object? value, String label) {
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  throw FormatException('$label must be an object.');
}

int _requiredInt(Object? value, String label) {
  final parsed = switch (value) {
    final int number => number,
    final num number when number.isFinite && number == number.roundToDouble() =>
      number.toInt(),
    final String text => int.tryParse(text.trim()),
    _ => null,
  };
  if (parsed == null) throw FormatException('$label must be an integer.');
  return parsed;
}
