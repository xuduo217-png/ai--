import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/media/chat_media_display_size.dart';
import '../../../../core/network/asset_url_resolver.dart';
import '../../domain/friend_media_content.dart';
import '../../domain/friend_messaging_models.dart';
import '../pages/friend_image_viewer_page.dart';

class FriendImageMessage extends StatelessWidget {
  const FriendImageMessage({super.key, required this.message, this.onPreview});

  final FriendMessage message;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final content = FriendMediaContent.parse(message.content);
    if (content == null) return const _ImageError();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = chatMediaDisplaySize(
          viewportWidth: MediaQuery.sizeOf(context).width,
          availableWidth: constraints.maxWidth,
          sourceWidth: content.width,
          sourceHeight: content.height,
          fallbackAspectRatio: 4 / 3,
        );
        return GestureDetector(
          key: ValueKey('friend-image-${message.localKey}'),
          onTap:
              onPreview ??
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FriendImageViewerPage(
                    content: content,
                    localFilePath: message.localFilePath,
                  ),
                ),
              ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: _buildImage(context, content, size),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImage(
    BuildContext context,
    FriendMediaContent content,
    Size displaySize,
  ) {
    final localFile = resolveLocalFile(message.localFilePath);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (displaySize.width * pixelRatio).round();
    final cacheHeight = (displaySize.height * pixelRatio).round();
    if (message.localFileExists &&
        localFile != null &&
        localFile.existsSync()) {
      return Image.file(
        localFile,
        key: ValueKey('friend-image-local-${message.localKey}'),
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (_, _, _) => _remoteImage(
          content,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
        ),
      );
    }
    return _remoteImage(
      content,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  Widget _remoteImage(
    FriendMediaContent content, {
    required int cacheWidth,
    required int cacheHeight,
  }) {
    final urls = [content.url, content.thumbnail]
        .map(resolveAssetUrl)
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    return _remoteImageAt(
      urls,
      0,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  Widget _remoteImageAt(
    List<String> urls,
    int index, {
    required int cacheWidth,
    required int cacheHeight,
  }) {
    if (index >= urls.length) return const _ImageError();
    final url = urls[index];
    Widget fallback() => _remoteImageAt(
      urls,
      index + 1,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );

    if (url.startsWith('data:')) {
      final bytes = _decodeDataUri(url);
      if (bytes == null) return fallback();
      return Image.memory(
        bytes,
        key: ValueKey('friend-image-remote-${message.localKey}'),
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    final file = resolveLocalFile(url);
    if (file != null && file.existsSync()) {
      return Image.file(
        file,
        key: ValueKey('friend-image-remote-${message.localKey}'),
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        key: ValueKey('friend-image-remote-${message.localKey}'),
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    return fallback();
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE5E7EB),
      child: Center(
        child: Icon(Icons.broken_image_outlined, color: Color(0xFF6B7280)),
      ),
    );
  }
}

Uint8List? _decodeDataUri(String value) {
  final separator = value.indexOf(',');
  if (separator < 0 || !value.substring(0, separator).contains(';base64')) {
    return null;
  }
  try {
    return base64Decode(value.substring(separator + 1));
  } on FormatException {
    return null;
  }
}
