class ShippingAddress {
  const ShippingAddress({
    required this.id,
    required this.receiverName,
    required this.receiverPhone,
    required this.provinceCode,
    required this.provinceName,
    required this.cityCode,
    required this.cityName,
    required this.districtCode,
    required this.districtName,
    required this.detailAddress,
    required this.isDefault,
    this.userId = 0,
  });

  final int id;
  final int userId;
  final String receiverName;
  final String receiverPhone;
  final String provinceCode;
  final String provinceName;
  final String cityCode;
  final String cityName;
  final String districtCode;
  final String districtName;
  final String detailAddress;
  final bool isDefault;

  String get region => '$provinceName$cityName$districtName';
  String get fullAddress => '$region$detailAddress';

  AddressInput toInput() => AddressInput(
    receiverName: receiverName,
    receiverPhone: receiverPhone,
    provinceCode: provinceCode,
    provinceName: provinceName,
    cityCode: cityCode,
    cityName: cityName,
    districtCode: districtCode,
    districtName: districtName,
    detailAddress: detailAddress,
    isDefault: isDefault,
  );
}

class AddressInput {
  const AddressInput({
    required this.receiverName,
    required this.receiverPhone,
    required this.provinceCode,
    required this.provinceName,
    required this.cityCode,
    required this.cityName,
    required this.districtCode,
    required this.districtName,
    required this.detailAddress,
    this.isDefault = false,
  });

  final String receiverName;
  final String receiverPhone;
  final String provinceCode;
  final String provinceName;
  final String cityCode;
  final String cityName;
  final String districtCode;
  final String districtName;
  final String detailAddress;
  final bool isDefault;

  String? validate() {
    if (receiverName.trim().isEmpty) return '请输入收货人姓名';
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(receiverPhone.trim())) {
      return '请输入正确的手机号码';
    }
    if (provinceCode.isEmpty || cityCode.isEmpty || districtCode.isEmpty) {
      return '请选择所在地区';
    }
    if (detailAddress.trim().isEmpty) return '请输入详细地址';
    if (detailAddress.trim().length > 200) return '详细地址不能超过200个字符';
    return null;
  }

  Map<String, Object?> toJson() => {
    'receiverName': receiverName.trim(),
    'receiverPhone': receiverPhone.trim(),
    'provinceCode': provinceCode,
    'provinceName': provinceName,
    'cityCode': cityCode,
    'cityName': cityName,
    'districtCode': districtCode,
    'districtName': districtName,
    'detailAddress': detailAddress.trim(),
    'isDefault': isDefault,
  };
}

abstract interface class AddressGateway {
  Future<List<ShippingAddress>> loadAddresses();
  Future<ShippingAddress> createAddress(AddressInput input);
  Future<ShippingAddress> updateAddress(int id, AddressInput input);
  Future<void> deleteAddress(int id);
  Future<void> setDefaultAddress(int id);
}
