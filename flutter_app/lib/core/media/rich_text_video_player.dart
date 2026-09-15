import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'auto_hiding_video_controls.dart';
import 'route_aware_video_surface.dart';
import 'video_player_view_type.dart';

const _fallbackAspectRatio = 16 / 9;
const _minimumAspectRatio = 9 / 16;
const _maximumAspectRatio = 16 / 9;

final _richTextVideoPlaybackCoordinator = _RichTextVideoPlaybackCoordinator();

class RichTextVideoSource {
  const RichTextVideoSource({required this.uri, this.posterUri});

  final Uri uri;
  final Uri? posterUri;
}

class RichTextVideoPlayer extends StatefulWidget {
  const RichTextVideoPlayer({
    super.key,
    required this.source,
    required this.width,
    required this.semanticsKey,
    required this.semanticLabel,
    required this.controlKeyPrefix,
    required this.accentColor,
    this.autoPlayWhenVisible = false,
    this.onFullscreen,
  });

  final RichTextVideoSource source;
  final double width;
  final Key semanticsKey;
  final String semanticLabel;
  final String controlKeyPrefix;
  final Color accentColor;
  final bool autoPlayWhenVisible;
  final VoidCallback? onFullscreen;

  @override
  State<RichTextVideoPlayer> createState() => _RichTextVideoPlayerState();
}

class _RichTextVideoPlayerState extends State<RichTextVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  ScrollableState? _scrollable;
  Object? _error;
  bool _initialized = false;
  bool _appIsActive = true;
  bool _routeIsActive = true;
  bool _manualPause = false;
  bool _fullscreenOpen = false;
  bool _visibilityUpdateScheduled = false;
  double _visibleFraction = 0;
  int _controllerGeneration = 0;
  int _inlineVideoViewGeneration = 0;

  bool get _isPlaying => _controller?.value.isPlaying ?? false;

  bool get _canAutoPlay {
    final controller = _controller;
    return mounted &&
        widget.autoPlayWhenVisible &&
        _appIsActive &&
        (_fullscreenOpen ||
            (_routeIsActive && (ModalRoute.of(context)?.isCurrent ?? true))) &&
        !_manualPause &&
        controller != null &&
        _initialized &&
        controller.value.isInitialized;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appIsActive = switch (WidgetsBinding.instance.lifecycleState) {
      null || AppLifecycleState.resumed => true,
      _ => false,
    };
    _createController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateScrollableSubscription();
    _routeIsActive = TickerMode.of(context);
    _scheduleVisibilityUpdate();
  }

  @override
  void didUpdateWidget(covariant RichTextVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoPlayWhenVisible != widget.autoPlayWhenVisible) {
      if (!widget.autoPlayWhenVisible) {
        _richTextVideoPlaybackCoordinator.unregister(this);
        unawaited(_pauseFromCoordinator());
      }
      _updateScrollableSubscription();
      _manualPause = false;
      _visibleFraction = 0;
      _scheduleVisibilityUpdate();
    }
    if (oldWidget.source.uri != widget.source.uri) {
      _richTextVideoPlaybackCoordinator.unregister(this);
      _manualPause = false;
      _visibleFraction = 0;
      unawaited(_resetController());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsActive = state == AppLifecycleState.resumed;
    if (_appIsActive) {
      _scheduleVisibilityUpdate();
    } else if (widget.autoPlayWhenVisible) {
      _richTextVideoPlaybackCoordinator.deactivate(this);
    } else {
      unawaited(_controller?.pause());
    }
  }

  @override
  void dispose() {
    _controllerGeneration += 1;
    WidgetsBinding.instance.removeObserver(this);
    _scrollable?.position.removeListener(_scheduleVisibilityUpdate);
    _richTextVideoPlaybackCoordinator.unregister(this);
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  void _createController() {
    final generation = ++_controllerGeneration;
    final controller = VideoPlayerController.networkUrl(
      widget.source.uri,
      viewType: platformAdaptiveVideoViewType,
    );
    _controller = controller;
    _error = null;
    _initialized = false;
    unawaited(_initializeController(controller, generation));
  }

  Future<void> _initializeController(
    VideoPlayerController controller,
    int generation,
  ) async {
    try {
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted ||
          generation != _controllerGeneration ||
          _controller != controller) {
        await controller.dispose();
        return;
      }
      setState(() => _initialized = true);
      _scheduleVisibilityUpdate();
    } catch (error) {
      if (!mounted ||
          generation != _controllerGeneration ||
          _controller != controller) {
        return;
      }
      await controller.dispose();
      if (!mounted || generation != _controllerGeneration) return;
      setState(() {
        _controller = null;
        _initialized = false;
        _error = error;
      });
    }
  }

  Future<void> _resetController() async {
    final previous = _controller;
    _controllerGeneration += 1;
    if (mounted) {
      setState(() {
        _controller = null;
        _initialized = false;
        _error = null;
      });
    }
    if (previous != null) await previous.dispose();
    if (!mounted) return;
    setState(_createController);
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (!_initialized || controller == null) return;
    if (widget.autoPlayWhenVisible) {
      if (controller.value.isPlaying) {
        _manualPause = true;
        _richTextVideoPlaybackCoordinator.pauseManually(this);
      } else {
        _manualPause = false;
        _richTextVideoPlaybackCoordinator.playManually(this);
      }
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (!_initialized || controller == null) return;
    if (widget.onFullscreen != null) {
      if (widget.autoPlayWhenVisible) {
        await _richTextVideoPlaybackCoordinator.pauseForNavigation(this);
      } else {
        await controller.pause();
      }
      if (mounted) widget.onFullscreen!();
      return;
    }
    _fullscreenOpen = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _FullscreenVideoPage(
            controller: controller,
            posterUri: widget.source.posterUri,
            onTogglePlayback: _togglePlayback,
            controlKeyPrefix: widget.controlKeyPrefix,
            accentColor: widget.accentColor,
          ),
        ),
      );
    } finally {
      _fullscreenOpen = false;
      if (mounted && identical(_controller, controller)) {
        setState(() {
          // Android 全屏页会接管同一播放器的 Surface。返回后重建内嵌
          // VideoPlayer，使现有 controller 重新绑定可见的原生渲染视图。
          _inlineVideoViewGeneration += 1;
        });
        _scheduleVisibilityUpdate();
      }
    }
  }

  void _updateScrollableSubscription() {
    final nextScrollable = widget.autoPlayWhenVisible
        ? Scrollable.maybeOf(context)
        : null;
    if (identical(_scrollable, nextScrollable)) return;
    _scrollable?.position.removeListener(_scheduleVisibilityUpdate);
    _scrollable = nextScrollable;
    _scrollable?.position.addListener(_scheduleVisibilityUpdate);
  }

  void _scheduleVisibilityUpdate() {
    if (!mounted || !widget.autoPlayWhenVisible || _visibilityUpdateScheduled) {
      return;
    }
    _visibilityUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityUpdateScheduled = false;
      if (mounted) _updateVisibility();
    });
  }

  void _updateVisibility() {
    final videoBox = context.findRenderObject();
    final viewportBox = _scrollable?.context.findRenderObject();
    var visibleFraction = 0.0;

    if (videoBox is RenderBox && videoBox.hasSize && videoBox.size.height > 0) {
      final videoRect = videoBox.localToGlobal(Offset.zero) & videoBox.size;
      final viewportRect = viewportBox is RenderBox && viewportBox.hasSize
          ? viewportBox.localToGlobal(Offset.zero) & viewportBox.size
          : Offset.zero & MediaQuery.sizeOf(context);
      final intersection = videoRect.intersect(viewportRect);
      if (!intersection.isEmpty) {
        visibleFraction = (intersection.height / videoRect.height)
            .clamp(0.0, 1.0)
            .toDouble();
      }
    }

    final wasAutoPlayVisible =
        _visibleFraction >=
        _RichTextVideoPlaybackCoordinator.autoPlayVisibilityThreshold;
    _visibleFraction = visibleFraction;
    final isAutoPlayVisible =
        visibleFraction >=
        _RichTextVideoPlaybackCoordinator.autoPlayVisibilityThreshold;
    if (wasAutoPlayVisible && !isAutoPlayVisible) _manualPause = false;
    _richTextVideoPlaybackCoordinator.updateVisibility(this, visibleFraction);
  }

  Future<void> _playFromCoordinator() async {
    final controller = _controller;
    if (!_canAutoPlay || controller == null || controller.value.isPlaying) {
      return;
    }
    try {
      await controller.play();
    } on Object {
      if (identical(_controller, controller)) {
        try {
          await controller.pause();
        } on Object {
          // 原生播放器异常不应阻断页面滚动和其他视频切换。
        }
      }
    }
  }

  Future<void> _pauseFromCoordinator() async {
    final controller = _controller;
    if (controller == null || !controller.value.isPlaying) return;
    try {
      await controller.pause();
    } on Object {
      // 页面切换和可见性变化不能被原生播放器暂停异常阻断。
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final aspectRatio = _initialized && controller != null
        ? _clampAspectRatio(controller.value.aspectRatio)
        : _fallbackAspectRatio;
    return Semantics(
      key: widget.semanticsKey,
      label: widget.semanticLabel,
      value: widget.source.uri.toString(),
      child: SizedBox(
        width: widget.width,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildContent(controller),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(VideoPlayerController? controller) {
    if (_error != null) {
      return _VideoFailure(
        keyPrefix: widget.controlKeyPrefix,
        onRetry: _resetController,
      );
    }
    if (!_initialized || controller == null) {
      return _VideoLoading(posterUri: widget.source.posterUri);
    }
    return _ReadyVideoSurface(
      controller: controller,
      posterUri: widget.source.posterUri,
      onTogglePlayback: _togglePlayback,
      onFullscreen: _openFullscreen,
      controlKeyPrefix: widget.controlKeyPrefix,
      accentColor: widget.accentColor,
      videoViewKey: ValueKey<String>(
        '${widget.controlKeyPrefix}-inline-view-$_inlineVideoViewGeneration',
      ),
    );
  }
}

class _RichTextVideoPlaybackCoordinator {
  static const double autoPlayVisibilityThreshold = 0.6;

  final Map<_RichTextVideoPlayerState, double> _visibleFractions = {};
  _RichTextVideoPlayerState? _activeVideo;
  bool _evaluationScheduled = false;
  int _activationEpoch = 0;

  void updateVisibility(
    _RichTextVideoPlayerState video,
    double visibleFraction,
  ) {
    _visibleFractions[video] = visibleFraction;
    _scheduleEvaluation();
  }

  void unregister(_RichTextVideoPlayerState video) {
    _visibleFractions.remove(video);
    if (identical(_activeVideo, video)) {
      _activeVideo = null;
      _activationEpoch += 1;
    }
    _scheduleEvaluation();
  }

  void deactivate(_RichTextVideoPlayerState video) {
    if (identical(_activeVideo, video)) _switchTo(null);
  }

  void playManually(_RichTextVideoPlayerState video) {
    _switchTo(video);
  }

  void pauseManually(_RichTextVideoPlayerState video) {
    if (identical(_activeVideo, video)) {
      _activeVideo = null;
      _activationEpoch += 1;
    }
    unawaited(video._pauseFromCoordinator());
  }

  Future<void> pauseForNavigation(_RichTextVideoPlayerState video) async {
    if (identical(_activeVideo, video)) {
      _activeVideo = null;
      _activationEpoch += 1;
    }
    await video._pauseFromCoordinator();
  }

  void _scheduleEvaluation() {
    if (_evaluationScheduled) return;
    _evaluationScheduled = true;
    scheduleMicrotask(() {
      _evaluationScheduled = false;
      _evaluate();
    });
  }

  void _evaluate() {
    _RichTextVideoPlayerState? nextVideo;
    var largestVisibleFraction = -1.0;

    final current = _activeVideo;
    final currentFraction = _visibleFractions[current];
    if (current != null &&
        current._canAutoPlay &&
        currentFraction != null &&
        currentFraction >= autoPlayVisibilityThreshold) {
      nextVideo = current;
      largestVisibleFraction = currentFraction;
    }

    for (final entry in _visibleFractions.entries) {
      if (!entry.key._canAutoPlay ||
          entry.value < autoPlayVisibilityThreshold ||
          entry.value <= largestVisibleFraction) {
        continue;
      }
      nextVideo = entry.key;
      largestVisibleFraction = entry.value;
    }

    _switchTo(nextVideo);
  }

  void _switchTo(_RichTextVideoPlayerState? nextVideo) {
    final previousVideo = _activeVideo;
    if (identical(previousVideo, nextVideo)) {
      if (nextVideo != null && !nextVideo._isPlaying) {
        unawaited(nextVideo._playFromCoordinator());
      }
      return;
    }

    _activeVideo = nextVideo;
    final epoch = ++_activationEpoch;
    unawaited(_completeSwitch(previousVideo, nextVideo, epoch));
  }

  Future<void> _completeSwitch(
    _RichTextVideoPlayerState? previousVideo,
    _RichTextVideoPlayerState? nextVideo,
    int epoch,
  ) async {
    await previousVideo?._pauseFromCoordinator();
    if (epoch != _activationEpoch || !identical(_activeVideo, nextVideo)) {
      return;
    }
    await nextVideo?._playFromCoordinator();
  }
}

class _ReadyVideoSurface extends StatelessWidget {
  const _ReadyVideoSurface({
    required this.controller,
    required this.posterUri,
    required this.onTogglePlayback,
    required this.controlKeyPrefix,
    required this.accentColor,
    required this.videoViewKey,
    this.onFullscreen,
  });

  final VideoPlayerController controller;
  final Uri? posterUri;
  final Future<void> Function() onTogglePlayback;
  final Future<void> Function()? onFullscreen;
  final String controlKeyPrefix;
  final Color accentColor;
  final Key videoViewKey;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final showPoster =
            posterUri != null &&
            value.position == Duration.zero &&
            !value.isPlaying;
        return AutoHidingVideoControls(
          isPlaying: value.isPlaying,
          surfaceKey: ValueKey<String>('$controlKeyPrefix-surface'),
          controls: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: IconButton(
                  key: ValueKey('$controlKeyPrefix-center-play'),
                  tooltip: value.isPlaying ? '暂停' : '播放',
                  onPressed: onTogglePlayback,
                  iconSize: 54,
                  color: Colors.white,
                  icon: Icon(
                    value.isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                  ),
                ),
              ),
              if (onFullscreen != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filledTonal(
                    key: ValueKey('$controlKeyPrefix-fullscreen'),
                    tooltip: '全屏播放',
                    onPressed: onFullscreen,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0x990F172A),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.fullscreen_rounded, size: 26),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: accentColor,
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white24,
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                ),
              ),
            ],
          ),
          child: ColoredBox(
            color: const Color(0xFF171719),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RouteAwareVideoSurface(
                  controller: controller,
                  detachedKey: ValueKey(
                    '$controlKeyPrefix-route-exit-placeholder',
                  ),
                  placeholder: _VideoExitPlaceholder(posterUri: posterUri),
                  child: Center(
                    child: VideoPlayer(controller, key: videoViewKey),
                  ),
                ),
                if (showPoster)
                  Image.network(
                    posterUri.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                if (value.isBuffering)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FullscreenVideoPage extends StatelessWidget {
  const _FullscreenVideoPage({
    required this.controller,
    required this.posterUri,
    required this.onTogglePlayback,
    required this.controlKeyPrefix,
    required this.accentColor,
  });

  final VideoPlayerController controller;
  final Uri? posterUri;
  final Future<void> Function() onTogglePlayback;
  final String controlKeyPrefix;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return VideoRoutePopScope<void>(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _clampAspectRatio(
                      controller.value.aspectRatio,
                    ),
                    child: _ReadyVideoSurface(
                      controller: controller,
                      posterUri: posterUri,
                      onTogglePlayback: onTogglePlayback,
                      controlKeyPrefix: controlKeyPrefix,
                      accentColor: accentColor,
                      videoViewKey: ValueKey<String>(
                        '$controlKeyPrefix-fullscreen-view',
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton.filledTonal(
                  key: ValueKey('$controlKeyPrefix-fullscreen-close'),
                  tooltip: '退出全屏',
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoLoading extends StatelessWidget {
  const _VideoLoading({required this.posterUri});

  final Uri? posterUri;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF171719),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (posterUri != null)
            Image.network(
              posterUri.toString(),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}

class _VideoExitPlaceholder extends StatelessWidget {
  const _VideoExitPlaceholder({required this.posterUri});

  final Uri? posterUri;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF171719),
      child: posterUri == null
          ? null
          : Image.network(
              posterUri.toString(),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
    );
  }
}

class _VideoFailure extends StatelessWidget {
  const _VideoFailure({required this.keyPrefix, required this.onRetry});

  final String keyPrefix;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF171719),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined, color: Colors.white70),
            const SizedBox(height: 8),
            const Text(
              '视频加载失败',
              style: TextStyle(color: Colors.white, letterSpacing: 0),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              key: ValueKey('$keyPrefix-retry'),
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class UnavailableRichTextVideo extends StatelessWidget {
  const UnavailableRichTextVideo({
    super.key,
    this.foregroundColor = const Color(0xFF766B6D),
    this.backgroundColor = const Color(0xFFF5F5F6),
  });

  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off_outlined, color: foregroundColor),
          const SizedBox(width: 8),
          Text(
            '视频地址无效',
            style: TextStyle(color: foregroundColor, letterSpacing: 0),
          ),
        ],
      ),
    );
  }
}

double _clampAspectRatio(double value) {
  if (!value.isFinite || value <= 0) return _fallbackAspectRatio;
  return math.max(_minimumAspectRatio, math.min(_maximumAspectRatio, value));
}
