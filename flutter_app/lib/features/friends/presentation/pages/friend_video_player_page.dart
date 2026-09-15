import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/media/auto_hiding_video_controls.dart';
import '../../../../core/media/route_aware_video_surface.dart';
import '../../../../core/media/video_player_view_type.dart';
import '../../../../core/network/asset_url_resolver.dart';

class FriendVideoPlayerPage extends StatelessWidget {
  const FriendVideoPlayerPage({
    super.key,
    required this.videoUrl,
    this.localFilePath,
  });

  final String videoUrl;
  final String? localFilePath;

  @override
  Widget build(BuildContext context) {
    return VideoRoutePopScope<void>(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('视频播放'),
        ),
        body: SafeArea(
          top: false,
          child: FriendVideoPlayerView(
            videoUrl: videoUrl,
            localFilePath: localFilePath,
          ),
        ),
      ),
    );
  }
}

class FriendVideoPlayerView extends StatefulWidget {
  const FriendVideoPlayerView({
    super.key,
    required this.videoUrl,
    this.localFilePath,
    this.active = true,
  });

  final String videoUrl;
  final String? localFilePath;
  final bool active;

  @override
  State<FriendVideoPlayerView> createState() => _FriendVideoPlayerViewState();
}

class _FriendVideoPlayerViewState extends State<FriendVideoPlayerView> {
  VideoPlayerController? _controller;
  Future<void>? _initialization;

  @override
  void initState() {
    super.initState();
    if (widget.active) _initialization = _initialize();
  }

  @override
  void didUpdateWidget(FriendVideoPlayerView oldWidget) {
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
    await controller.setLooping(false);
    if (widget.active) await controller.play();
    if (mounted) setState(() {});
  }

  File? _existingLocalFile() {
    for (final value in [widget.localFilePath, widget.videoUrl]) {
      final file = resolveLocalFile(value);
      if (file != null && file.existsSync()) return file;
    }
    return null;
  }

  Uri _remoteUri() {
    final url = resolveAssetUrl(widget.videoUrl);
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
          return const Center(
            child: Text('视频无法播放', style: TextStyle(color: Colors.white70)),
          );
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
            surfaceKey: const ValueKey('friend-video-player-surface'),
            controls: Column(
              children: [
                Expanded(
                  child: Center(
                    child: IconButton(
                      key: const ValueKey('friend-video-player-toggle'),
                      tooltip: value.isPlaying ? '暂停' : '播放',
                      onPressed: _togglePlayback,
                      iconSize: 64,
                      color: Colors.white,
                      icon: Icon(
                        value.isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                      ),
                    ),
                  ),
                ),
                VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFF6F8DEB),
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white24,
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                ),
              ],
            ),
            child: Center(
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: RouteAwareVideoSurface(
                  controller: controller,
                  detachedKey: const ValueKey('friend-video-player-detached'),
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null) return;
    controller.value.isPlaying ? controller.pause() : controller.play();
  }
}
