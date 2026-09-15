enum SystemArticleType {
  privacy('privacy', '隐私协议'),
  userAgreement('user_agreement', '用户协议'),
  aboutUs('about_us', '关于我们');

  const SystemArticleType(this.wireValue, this.title);

  final String wireValue;
  final String title;

  static SystemArticleType? tryParse(Object? value) {
    final normalized = value?.toString().trim() ?? '';
    for (final type in values) {
      if (type.wireValue == normalized) return type;
    }
    return null;
  }
}

class ContactInfo {
  const ContactInfo({
    required this.hotline,
    required this.wechatQrCode,
    required this.workingHours,
  });

  static const empty = ContactInfo(
    hotline: '',
    wechatQrCode: '',
    workingHours: '',
  );

  final String hotline;
  final String wechatQrCode;
  final String workingHours;

  bool get hasHotline => hotline.isNotEmpty;
  bool get hasWechatQrCode => wechatQrCode.isNotEmpty;
  bool get hasWorkingHours => workingHours.isNotEmpty;
  bool get isEmpty => !hasHotline && !hasWechatQrCode && !hasWorkingHours;
}

class SystemArticle {
  const SystemArticle({
    required this.id,
    required this.type,
    required this.html,
  });

  final int id;
  final SystemArticleType type;
  final String html;

  bool get isEmpty => html.trim().isEmpty;
}

abstract interface class SettingsGateway {
  Future<ContactInfo> loadContactInfo();

  Future<SystemArticle?> loadArticle(SystemArticleType type);
}
