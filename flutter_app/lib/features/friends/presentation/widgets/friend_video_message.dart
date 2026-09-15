import 'package:flutter/material.dart';

import '../../../../core/media/chat_media_display_size.dart';
import '../../../../core/network/asset_url_resolver.dart';
import '../../domain/friend_media_content.dart';
import '../../domain/friend_messaging_models.dart';
import '../pages/friend_video_player_page.dart';

class FriendVideoMessage extends StatelessWidget {
  const FriendVideoMessage({super.key, required this.message, this.onPreview});

  final FriendMessage message;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final content = FriendMediaContent.parse(
      message.content,
      type: FriendMediaType.video,
    );
    if (content == null) return const _VideoPlaceholder(error: true);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = chatMediaDisplaySize(
          viewportWidth: MediaQuery.sizeOf(context).width,
          availableWidth: constraints.maxWidth,
          sourceWidth: content.width,
          sourceHeight: content.height,
          fallbackAspectRatio: 16 / 9,
        );
        return GestureDetector(
          key: ValueKey('friend-video-${message.localKey}'),
          onTap:
              onPreview ??
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FriendVideoPlayerPage(
                    videoUrl: content.url,
                    localFilePath: message.localFilePath,
                  ),
                ),
              ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnail(context, content, size.width, size.height),
                  const ColoredBox(color: Color(0x24000000)),
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xB3000000),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        child: Text(
                          formatFriendVideoDuration(content.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(
    BuildContext context,
    FriendMediaContent content,
    double width,
    double height,
  ) {
    final localThumbnail = resolveLocalFile(message.localThumbnailPath);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (width * pixelRatio).round();
    final cacheHeight = (height * pixelRatio).round();
    if (localThumbnail != null && localThumbnail.existsSync()) {
      return Image.file(
        localThumbnail,
        key: ValueKey('friend-video-local-thumbnail-${message.localKey}'),
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (_, _, _) =>
            _remoteThumbnail(content, cacheWidth, cacheHeight),
      );
    }
    return _remoteThumbnail(content, cacheWidth, cacheHeight);
  }

  Widget _remoteThumbnail(
    FriendMediaContent content,
    int cacheWidth,
    int cacheHeight,
  ) {
    final thumbnail = resolveAssetUrl(content.thumbnail);
    if (thumbnail.startsWith('http://') || thumbnail.startsWith('https://')) {
      return Image.network(
        thumbnail,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (_, _, _) => const _VideoPlaceholder(),
      );
    }
    final thumbnailFile = resolveLocalFile(thumbnail);
    if (thumbnailFile != null && thumbnailFile.existsSync()) {
      return Image.file(
        thumbnailFile,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
      );
    }
    return const _VideoPlaceholder();
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({this.error = false});

  final bool error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF273244),
      child: Center(
        child: Icon(
          error ? Icons.videocam_off_outlined : Icons.videocam_outlined,
          color: Colors.white54,
          size: 40,
        ),
      ),
    );
  }
}

String formatFriendVideoDuration(int? duration) {
  if (duration == null || duration <= 0) return '--:--';
  final minutes = duration ~/ 60;
  final seconds = duration % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
