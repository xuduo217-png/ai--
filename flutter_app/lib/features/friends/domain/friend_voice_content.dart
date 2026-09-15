import 'dart:convert';

const friendVoiceMimeType = 'audio/x-m4a';

class FriendVoiceContent {
  const FriendVoiceContent({required this.url, required this.duration});

  final String url;
  final int duration;

  bool get canPlay => url.trim().isNotEmpty;

  Map<String, Object> toJson() => <String, Object>{
    'url': url.trim(),
    'duration': normalizeFriendVoiceDuration(duration),
  };

  String toMessageContent() => jsonEncode(toJson());

  static FriendVoiceContent? parse(String? rawContent) {
    final content = _decodeHtmlEntities(rawContent?.trim() ?? '');
    if (content.isEmpty) return null;

    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        return fromJson(Map<String, Object?>.from(decoded));
      }
    } on FormatException {
      // Historical voice messages stored the URL directly.
    }
    return FriendVoiceContent(url: content, duration: 0);
  }

  static FriendVoiceContent? fromJson(Map<String, Object?> json) {
    final url = _optionalString(json['url']);
    if (url == null) return null;
    return FriendVoiceContent(
      url: url,
      duration: normalizeFriendVoiceDuration(json['duration']),
    );
  }
}

class FriendVoiceSendRequest {
  const FriendVoiceSendRequest({
    required this.localFilePath,
    required this.duration,
    required this.fileName,
    required this.size,
    this.mimeType = friendVoiceMimeType,
  });

  final String localFilePath;
  final int duration;
  final String fileName;
  final String mimeType;
  final int size;

  FriendVoiceContent get localContent => FriendVoiceContent(
    url: localFilePath,
    duration: normalizeFriendVoiceDuration(duration),
  );
}

int normalizeFriendVoiceDuration(Object? rawValue) {
  final value = switch (rawValue) {
    final num value => value.toDouble(),
    _ => double.tryParse('$rawValue'),
  };
  if (value == null || !value.isFinite || value <= 0) return 0;

  // Values above the protocol maximum cannot be valid seconds. Historical
  // clients may have stored milliseconds, so normalize those before clamping.
  final seconds = value > 60 ? value / 1000 : value;
  return seconds.round().clamp(1, 60).toInt();
}

String? _optionalString(Object? value) {
  final text = value == null ? '' : '$value'.trim();
  return text.isEmpty || text == 'null' ? null : text;
}

String _decodeHtmlEntities(String value) {
  return value
      .replaceAll('&quot;', '"')
      .replaceAll('&#x27;', "'")
      .replaceAll('&#x2F;', '/')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}
