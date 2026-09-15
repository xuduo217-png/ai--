class ApiConfig {
  const ApiConfig._();

  static const String productionBaseUrl = 'https://gudeapi.zuoyongyoubao.com';
  static const String productionAssetBaseUrl =
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com';

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: productionBaseUrl,
  );

  static const String assetBaseUrl = String.fromEnvironment(
    'ASSET_BASE_URL',
    defaultValue: productionAssetBaseUrl,
  );

  static const Duration timeout = Duration(seconds: 15);
  // 大视频上传包含网络传输和服务端写入 COS，允许较长时间完成。
  static const Duration uploadTimeout = Duration(minutes: 10);
}
