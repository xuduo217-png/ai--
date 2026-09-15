import 'package:flutter/material.dart';

import '../../../../core/media/route_aware_video_surface.dart';
import '../../domain/friend_media_content.dart';
import '../../domain/friend_messaging_models.dart';
import 'friend_image_viewer_page.dart';
import 'friend_video_player_page.dart';

class FriendChatMediaItem {
  const FriendChatMediaItem({
    required this.message,
    required this.type,
    required this.content,
  });

  final FriendMessage message;
  final FriendMediaType type;
  final FriendMediaContent content;

  static FriendChatMediaItem? fromMessage(FriendMessage message) {
    final type = switch (message.messageType) {
      'image' => FriendMediaType.image,
      'video' => FriendMediaType.video,
      _ => null,
    };
    if (type == null) return null;
    final content = FriendMediaContent.parse(message.content, type: type);
    if (content == null || !content.canDisplay) return null;
    return FriendChatMediaItem(message: message, type: type, content: content);
  }
}

class FriendChatMediaViewerPage extends StatefulWidget {
  const FriendChatMediaViewerPage({
    super.key,
    required this.items,
    required this.initialIndex,
  }) : assert(items.length > 0),
       assert(initialIndex >= 0 && initialIndex < items.length);

  final List<FriendChatMediaItem> items;
  final int initialIndex;

  @override
  State<FriendChatMediaViewerPage> createState() =>
      _FriendChatMediaViewerPageState();
}

class _FriendChatMediaViewerPageState extends State<FriendChatMediaViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VideoRoutePopScope<void>(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: PageView.builder(
          key: const ValueKey('friend-chat-media-page-view'),
          controller: _pageController,
          itemCount: widget.items.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
            final item = widget.items[index];
            return switch (item.type) {
              FriendMediaType.image => InteractiveViewer(
                key: ValueKey(
                  'friend-chat-media-image-${item.message.localKey}',
                ),
                minScale: 0.8,
                maxScale: 5,
                child: Center(
                  child: FriendFullscreenImage(
                    content: item.content,
                    localFilePath: item.message.localFilePath,
                  ),
                ),
              ),
              FriendMediaType.video => FriendVideoPlayerView(
                key: ValueKey(
                  'friend-chat-media-video-${item.message.localKey}',
                ),
                videoUrl: item.content.url,
                localFilePath: item.message.localFilePath,
                active: index == _currentIndex,
              ),
            };
          },
        ),
      ),
    );
  }
}
