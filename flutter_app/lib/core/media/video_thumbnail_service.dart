import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

typedef VideoThumbnailFileGenerator =
    Future<String?> Function(String videoPath);

class VideoThumbnailService {
  const VideoThumbnailService._();

  static Future<String?> generate(String videoPath) async {
    final normalizedPath = videoPath.trim();
    if (normalizedPath.isEmpty || !await File(normalizedPath).exists()) {
      return null;
    }

    final directory = await getTemporaryDirectory();
    final thumbnailPath = path.join(
      directory.path,
      'video_cover_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final generatedPath = await VideoThumbnail.thumbnailFile(
      video: normalizedPath,
      thumbnailPath: thumbnailPath,
      imageFormat: ImageFormat.JPEG,
      timeMs: 1000,
      maxWidth: 1080,
      quality: 82,
    );
    if (generatedPath == null || generatedPath.trim().isEmpty) return null;
    return await File(generatedPath).exists() ? generatedPath : null;
  }
}

Future<T> withGeneratedVideoThumbnail<T>({
  required String videoPath,
  required Future<T> Function(String? thumbnailPath) action,
  VideoThumbnailFileGenerator? generator,
}) async {
  String? thumbnailPath;
  try {
    thumbnailPath = await (generator ?? VideoThumbnailService.generate)(
      videoPath,
    );
  } on Object {
    // 服务端仍会在客户端抽帧失败时尝试生成封面。
    thumbnailPath = null;
  }

  try {
    return await action(thumbnailPath);
  } finally {
    if (thumbnailPath != null) {
      try {
        final thumbnail = File(thumbnailPath);
        if (await thumbnail.exists()) await thumbnail.delete();
      } on Object {
        // 临时目录由系统清理，删除失败不应影响上传结果。
      }
    }
  }
}
