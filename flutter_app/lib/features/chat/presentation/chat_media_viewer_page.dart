import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/auto_hiding_video_controls.dart';
import '../../../core/media/route_aware_video_surface.dart';
import '../../../core/media/video_player_view_type.dart';
import '../../../core/network/asset_url_resolver.dart';
import '../domain/chat_models.dart';
import 'chat_widgets.dart';

class ChatMediaViewerItem {
  const ChatMediaViewerItem({required this.message, required this.content});

  final ChatMessage message;
  final ChatMediaContent content;

  static ChatMediaViewerItem? fromMessage(ChatMessage message) {
    if (message.type != ChatMessageType.image &&
        message.type != ChatMessageType.video) {
      return null;
    }
    final content = message.mediaContent;
    if (content == null ||
        (content.url.trim().isEmpty &&
            (message.localMediaPath?.trim().isEmpty ?? true))) {
      return null;
    }
    return ChatMediaViewerItem(message: message, content: content);
  }
}

class ChatMediaViewerPage extends StatefulWidget {
  const ChatMediaViewerPage({
    super.key,
    required this.items,
    required this.initialIndex,
  }) : assert(items.length > 0),
       assert(initialIndex >= 0 && initialIndex < items.length);

  final List<ChatMediaViewerItem> items;
  final int initialIndex;

  @override
  State<ChatMediaViewerPage> createState() => _ChatMediaViewerPageState();
}

class _ChatMediaViewerPageState extends State<ChatMediaViewerPage> {
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
          key: const ValueKey('chat-media-page-view'),
          controller: _pageController,
          itemCount: widget.items.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
            final item = widget.items[index];
            if (item.message.type == ChatMessageType.image) {
              return InteractiveViewer(
                key: ValueKey('chat-media-image-${item.message.id}'),
                minScale: 0.8,
                maxScale: 5,
                child: Center(
                  child: _ChatFullscreenImage(
                    imageUrl: item.content.url,
                    localPath: item.message.localMediaPath,
                  ),
                ),
              );
            }
            return ChatVideoPlayerView(
              key: ValueKey('chat-media-video-${item.message.id}'),
              videoUrl: item.content.url,
              localPath: item.message.localMediaPath,
              active: index == _currentIndex,
            );
          },
        ),
      ),
    );
  }
}

class _ChatFullscreenImage extends StatelessWidget {
  const _ChatFullscreenImage({required this.imageUrl, this.localPath});

  final String imageUrl;
  final String? localPath;

  @override
  Widget build(BuildContext context) {
    final localFile = _existingLocalFile();
    if (localFile != null) {
      return Image.file(
        localFile,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const _MediaLoadError(label: '图片无法显示'),
      );
    }
    final resolvedUrl = resolveChatUrl(imageUrl);
    if (resolvedUrl.isEmpty) {
      return const _MediaLoadError(label: '图片无法显示');
    }
    return Image.network(
      resolvedUrl,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const _MediaLoadError(label: '图片无法显示'),
    );
  }

  File? _existingLocalFile() {
    for (final value in [localPath, imageUrl]) {
      final file = resolveLocalFile(value);
      if (file != null && file.existsSync()) return file;
    }
    return null;
  }
}

class ChatVideoPlayerView extends StatefulWidget {
  const ChatVideoPlayerView({
    super.key,
    required this.videoUrl,
    this.localPath,
    this.active = true,
  });

  final String videoUrl;
  final String? localPath;
  final bool active;

  @override
  State<ChatVideoPlayerView> createState() => _ChatVideoPlayerViewState();
}

class _ChatVideoPlayerViewState extends State<ChatVideoPlayerView> {
  VideoPlayerController? _controller;
  Future<void>? _initialization;

  @override
  void initState() {
    super.initState();
    if (widget.active) _initialization = _initialize();
  }

  @override
  void didUpdateWidget(ChatVideoPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    final controller = _controller;
    if (!widget.active) {
      if (controller != null) unawaited(controller.pause());
      return;
    }
    if (_initialization == null) {
      _initialization = _initialize();
    } else if (controller?.value.isInitialized == true) {
      unawaited(controller!.play());
    }
  }

  Future<void> _initialize() async {
    final localFile = _existingLocalFile();
    final controller = localFile != null
        ? VideoPlayerController.file(
            localFile,
            viewType: platformAdaptiveVideoViewType,
          )
        : VideoPlayerController.networkUrl(
            _remoteUri(),
            viewType: platformAdaptiveVideoViewType,
          );
    _controller = controller;
    await controller.initialize();
    await controller.setLooping(true);
    if (widget.active) await controller.play();
    if (mounted) setState(() {});
  }

  File? _existingLocalFile() {
    for (final value in [widget.localPath, widget.videoUrl]) {
      final file = resolveLocalFile(value);
      if (file != null && file.existsSync()) return file;
    }
    return null;
  }

  Uri _remoteUri() {
    final url = resolveChatUrl(widget.videoUrl);
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw StateError('视频地址无效');
    }
    return uri;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialization = _initialization;
    if (initialization == null) {
      return const Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: Colors.white70,
          size: 64,
        ),
      );
    }
    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _MediaLoadError(label: '视频无法播放');
        }
        final controller = _controller;
        if (snapshot.connectionState != ConnectionState.done ||
            controller == null ||
            !controller.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        final aspectRatio = controller.value.aspectRatio > 0
            ? controller.value.aspectRatio
            : 16 / 9;
        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) => AutoHidingVideoControls(
            isPlaying: value.isPlaying,
            surfaceKey: const ValueKey('chat-video-player-surface'),
            controls: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 20,
                ),
                child: IconButton.filled(
                  key: const ValueKey('chat-video-player-toggle'),
                  tooltip: value.isPlaying ? '暂停' : '播放',
                  onPressed: () =>
                      value.isPlaying ? controller.pause() : controller.play(),
                  icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
              ),
            ),
            child: Center(
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: RouteAwareVideoSurface(
                  controller: controller,
                  detachedKey: const ValueKey('chat-video-player-detached'),
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MediaLoadError extends StatelessWidget {
  const _MediaLoadError({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label, style: const TextStyle(color: Colors.white70)),
    );
  }
}
