import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/media/video_player_view_type.dart';
import 'package:video_player/video_player.dart';

void main() {
  test('Android 视频使用 platformView', () {
    expect(
      videoViewTypeForPlatform(TargetPlatform.android),
      VideoViewType.platformView,
    );
  });

  test('非 Android 视频保持 textureView', () {
    for (final platform in TargetPlatform.values) {
      if (platform == TargetPlatform.android) continue;
      expect(
        videoViewTypeForPlatform(platform),
        VideoViewType.textureView,
        reason: '$platform 应保持默认纹理渲染模式',
      );
    }
  });
}
