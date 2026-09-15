enum InAppMessageChannel { friend, consultation, marketplace }

class InAppMessageEvent {
  const InAppMessageEvent({
    required this.eventKey,
    required this.channel,
    required this.conversationId,
    required this.title,
    required this.preview,
    required this.createdAt,
    this.senderId,
    this.avatarUrl,
    this.isOffline = false,
  });

  final String eventKey;
  final InAppMessageChannel channel;
  final String conversationId;
  final int? senderId;
  final String title;
  final String preview;
  final String? avatarUrl;
  final DateTime createdAt;
  final bool isOffline;

  String get channelLabel => switch (channel) {
    InAppMessageChannel.friend => '好友消息',
    InAppMessageChannel.consultation => '医生咨询',
    InAppMessageChannel.marketplace => '商城消息',
  };
}

String inAppMessagePreview({
  required String messageType,
  required String content,
}) {
  return switch (messageType.trim().toLowerCase()) {
    'image' => '[图片]',
    'video' => '[视频]',
    'voice' => '[语音]',
    'ai_consultation' => '[AI 问诊]',
    'payment_success' => '[支付成功]',
    'payment_prompt' => '[待购买服务]',
    _ => _plainTextPreview(content),
  };
}

String _plainTextPreview(String content) {
  final value = content.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (value.isEmpty) return '收到一条新消息';
  return value.length > 100 ? '${value.substring(0, 100)}...' : value;
}
