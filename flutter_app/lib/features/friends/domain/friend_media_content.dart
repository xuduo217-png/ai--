import 'dart:convert';

enum FriendMediaType { image, video }

class FriendMediaSendRequest {
  const FriendMediaSendRequest({
    required this.type,
    required this.localFilePath,
    required this.fileName,
    required this.mimeType,
    required this.size,
    this.localThumbnailPath,
    this.width,
    this.height,
    this.duration,
  });

  final FriendMediaType type;
  final String localFilePath;
  final String? localThumbnailPath;
  final String fileName;
  final String mimeType;
  final int size;
  final int? width;
  final int? height;
  final int? duration;

  FriendMediaContent get localContent => FriendMediaContent(
    url: localFilePath,
    width: width,
    height: height,
    duration: type == FriendMediaType.video ? duration : null,
    size: size,
    fileName: fileName,
    mimeType: mimeType,
  );
}

class FriendMediaContent {
  const FriendMediaContent({
    required this.url,
    this.thumbnail,
    this.width,
    this.height,
    this.duration,
    this.size,
    this.fileName,
    this.mimeType,
  });

  final String url;
  final String? thumbnail;
  final int? width;
  final int? height;
  final int? duration;
  final int? size;
  final String? fileName;
  final String? mimeType;

  bool get canDisplay => url.trim().isNotEmpty;

  Map<String, Object> toJson() => <String, Object>{
    'url': url.trim(),
    if (thumbnail != null && thumbnail!.trim().isNotEmpty)
      'thumbnail': thumbnail!.trim(),
    if (width != null && width! > 0) 'width': width!,
    if (height != null && height! > 0) 'height': height!,
    if (duration != null && duration! > 0) 'duration': duration!,
    if (size != null && size! > 0) 'size': size!,
    if (fileName != null && fileName!.trim().isNotEmpty)
      'fileName': fileName!.trim(),
    if (mimeType != null && mimeType!.trim().isNotEmpty)
      'mimeType': mimeType!.trim(),
  };

  String toMessageContent() => jsonEncode(toJson());

  static FriendMediaContent? parse(
    String? rawContent, {
    FriendMediaType type = FriendMediaType.image,
  }) {
    final content = _decodeHtmlEntities(rawContent?.trim() ?? '');
    if (content.isEmpty) return null;

    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        return fromJson(Map<String, Object?>.from(decoded), type: type);
      }
    } on FormatException {
      // Historical media messages stored the URL directly.
    }
    return FriendMediaContent(url: content);
  }

  static FriendMediaContent? fromJson(
    Map<String, Object?> json, {
    FriendMediaType type = FriendMediaType.image,
  }) {
    final url = _optionalString(json['url']);
    if (url == null) return null;
    return FriendMediaContent(
      url: url,
      thumbnail: _optionalString(json['thumbnail']),
      width: _positiveInt(json['width']),
      height: _positiveInt(json['height']),
      duration: type == FriendMediaType.video
          ? _durationSeconds(json['duration'])
          : null,
      size: _positiveInt(json['size']),
      fileName: _optionalString(json['fileName']),
      mimeType: _optionalString(json['mimeType'] ?? json['mime']),
    );
  }
}

int? _positiveInt(Object? value) {
  final number = switch (value) {
    final num value => value.toDouble(),
    _ => double.tryParse('$value'),
  };
  if (number == null || !number.isFinite || number <= 0) return null;
  return number.round();
}

int? _durationSeconds(Object? value) {
  final duration = _positiveInt(value);
  if (duration == null) return null;
  return duration > 1000 ? (duration / 1000).round() : duration;
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
