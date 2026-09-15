import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

VideoViewType get platformAdaptiveVideoViewType =>
    videoViewTypeForPlatform(defaultTargetPlatform);

VideoViewType videoViewTypeForPlatform(TargetPlatform platform) {
  return platform == TargetPlatform.android
      ? VideoViewType.platformView
      : VideoViewType.textureView;
}
