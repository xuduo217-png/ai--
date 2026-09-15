import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/network/asset_url_resolver.dart';
import '../../domain/friend_media_content.dart';

class FriendImageViewerPage extends StatelessWidget {
  const FriendImageViewerPage({
    super.key,
    required this.content,
    this.localFilePath,
  });

  final FriendMediaContent content;
  final String? localFilePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('图片预览'),
      ),
      body: SafeArea(
        top: false,
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Center(
            child: FriendFullscreenImage(
              content: content,
              localFilePath: localFilePath,
            ),
          ),
        ),
      ),
    );
  }
}

class FriendFullscreenImage extends StatelessWidget {
  const FriendFullscreenImage({
    super.key,
    required this.content,
    this.localFilePath,
  });

  final FriendMediaContent content;
  final String? localFilePath;

  @override
  Widget build(BuildContext context) => _buildImage();

  Widget _buildImage() {
    final localFile = resolveLocalFile(localFilePath);
    if (localFile != null && localFile.existsSync()) {
      return Image.file(localFile, fit: BoxFit.contain);
    }

    final url = resolveAssetUrl(content.url);
    if (url.startsWith('data:')) {
      final bytes = _decodeDataUri(url);
      if (bytes != null) return Image.memory(bytes, fit: BoxFit.contain);
    }
    if (url.startsWith('file://') || isLocalMediaPath(url)) {
      final file = resolveLocalFile(url);
      if (file != null && file.existsSync()) {
        return Image.file(file, fit: BoxFit.contain);
      }
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const _ViewerError(),
      );
    }
    return const _ViewerError();
  }
}

class _ViewerError extends StatelessWidget {
  const _ViewerError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.white70, size: 44),
          SizedBox(height: 10),
          Text('图片无法加载', style: TextStyle(color: Colors.white70)),
        ],
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
