import '../../../../core/network/api_client.dart';
import '../../shared/mall_json.dart';
import '../domain/address_models.dart';

class AddressRepository implements AddressGateway {
  AddressRepository(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<List<ShippingAddress>> loadAddresses() async {
    final payload = await _apiClient.get('/addresses');
    return asJsonList(
      unwrapData(payload),
    ).map((item) => _parse(asJsonMap(item))).toList(growable: false);
  }

  @override
  Future<ShippingAddress> createAddress(AddressInput input) async {
    final payload = await _apiClient.post(
      '/addresses',
      authenticated: true,
      body: input.toJson(),
    );
    return _parse(asJsonMap(unwrapData(payload)));
  }

  @override
  Future<ShippingAddress> updateAddress(int id, AddressInput input) async {
    final payload = await _apiClient.put(
      '/addresses/$id',
      body: input.toJson(),
    );
    return _parse(asJsonMap(unwrapData(payload)));
  }

  @override
  Future<void> deleteAddress(int id) async {
    await _apiClient.delete('/addresses/$id');
  }

  @override
  Future<void> setDefaultAddress(int id) async {
    await _apiClient.patch('/addresses/$id/default');
  }

  ShippingAddress _parse(Map<String, dynamic> json) {
    return ShippingAddress(
      id: jsonInt(json['id']),
      userId: jsonInt(json['userId']),
      receiverName: jsonString(json['receiverName']),
      receiverPhone: jsonString(json['receiverPhone']),
      provinceCode: jsonString(json['provinceCode']),
      provinceName: jsonString(json['provinceName']),
      cityCode: jsonString(json['cityCode']),
      cityName: jsonString(json['cityName']),
      districtCode: jsonString(json['districtCode']),
      districtName: jsonString(json['districtName']),
      detailAddress: jsonString(json['detailAddress']),
      isDefault: jsonBool(json['isDefault']),
    );
  }
}
