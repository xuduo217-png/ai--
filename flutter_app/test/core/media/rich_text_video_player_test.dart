import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/media/rich_text_video_player.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  testWidgets('视频进入可视区域自动播放，离屏暂停，重新进入后继续自动播放', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalPlatform = VideoPlayerPlatform.instance;
    final videoPlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = videoPlatform;
    addTearDown(() async {
      VideoPlayerPlatform.instance = originalPlatform;
      await videoPlatform.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            key: const ValueKey('video-scroll'),
            children: [
              const SizedBox(height: 80),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: RichTextVideoPlayer(
                  source: RichTextVideoSource(
                    uri: Uri.parse('https://example.test/video.mp4'),
                  ),
                  width: 360,
                  semanticsKey: const ValueKey('viewport-video'),
                  semanticLabel: '测试视频播放器',
                  controlKeyPrefix: 'viewport-video',
                  accentColor: Colors.blue,
                  autoPlayWhenVisible: true,
                ),
              ),
              const SizedBox(height: 1200),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final firstPlayIndex = videoPlatform.operations.indexOf('play:0');
    expect(firstPlayIndex, greaterThanOrEqualTo(0));

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('video-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    scrollable.position.jumpTo(500);
    await tester.pump();
    await tester.pump();

    final pauseIndex = videoPlatform.operations.indexWhere(
      (operation) => operation == 'pause:0',
      firstPlayIndex + 1,
    );
    expect(pauseIndex, greaterThan(firstPlayIndex));

    scrollable.position.jumpTo(0);
    await tester.pump();
    await tester.pump();

    final replayIndex = videoPlatform.operations.indexWhere(
      (operation) => operation == 'play:0',
      pauseIndex + 1,
    );
    expect(replayIndex, greaterThan(pauseIndex));
  });

  testWidgets('全屏返回后重新挂载内嵌视频画面并恢复自动播放', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalPlatform = VideoPlayerPlatform.instance;
    final videoPlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = videoPlatform;
    addTearDown(() async {
      VideoPlayerPlatform.instance = originalPlatform;
      await videoPlatform.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichTextVideoPlayer(
            source: RichTextVideoSource(
              uri: Uri.parse('https://example.test/fullscreen.mp4'),
            ),
            width: 360,
            semanticsKey: const ValueKey('fullscreen-return-video'),
            semanticLabel: '全屏返回测试视频',
            controlKeyPrefix: 'fullscreen-return-video',
            accentColor: Colors.blue,
            autoPlayWhenVisible: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final playerFinder = find.byKey(const ValueKey('fullscreen-return-video'));
    final fullscreenFinder = find.byKey(
      const ValueKey('fullscreen-return-video-fullscreen'),
    );
    final centerControlFinder = find.byKey(
      const ValueKey('fullscreen-return-video-center-play'),
    );
    expect(playerFinder, findsOneWidget);
    expect(fullscreenFinder, findsOneWidget);
    expect(centerControlFinder, findsOneWidget);

    final centerControl = tester.widget<IconButton>(centerControlFinder);
    expect(centerControl.iconSize, 54);
    expect(
      (centerControl.icon as Icon).icon,
      Icons.pause_circle_filled_rounded,
    );
    final playerRect = tester.getRect(playerFinder);
    final fullscreenRect = tester.getRect(fullscreenFinder);
    expect(fullscreenRect.center.dx, greaterThan(playerRect.center.dx));
    expect(fullscreenRect.center.dy, lessThan(playerRect.center.dy));

    await tester.tap(fullscreenFinder);
    await tester.pumpAndSettle();

    final closeFinder = find.byKey(
      const ValueKey('fullscreen-return-video-fullscreen-close'),
    );
    expect(closeFinder, findsOneWidget);
    final mountsBeforeReturn = videoPlatform.operations
        .where((operation) => operation == 'mount:0')
        .length;
    expect(mountsBeforeReturn, greaterThanOrEqualTo(2));

    await tester.tap(closeFinder);
    await tester.pumpAndSettle();

    expect(closeFinder, findsNothing);
    final mountsAfterReturn = videoPlatform.operations
        .where((operation) => operation == 'mount:0')
        .length;
    expect(mountsAfterReturn, greaterThan(mountsBeforeReturn));
    expect(
      videoPlatform.operations.lastIndexOf('play:0'),
      greaterThan(videoPlatform.operations.lastIndexOf('pause:0')),
    );
  });
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final List<String> operations = [];
  final Map<int, StreamController<VideoEvent>> _streams = {};
  int _nextPlayerId = 0;

  @override
  Future<void> init() async {
    operations.add('init');
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final playerId = _nextPlayerId++;
    final stream = StreamController<VideoEvent>();
    _streams[playerId] = stream;
    operations.add('create:$playerId');
    stream.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        size: const Size(160, 90),
        duration: const Duration(seconds: 30),
      ),
    );
    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _streams[playerId]!.stream;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    return _TrackedVideoView(
      playerId: options.playerId,
      onMounted: (playerId) => operations.add('mount:$playerId'),
      onDisposed: (playerId) => operations.add('unmount:$playerId'),
    );
  }

  @override
  Future<void> play(int playerId) async {
    operations.add('play:$playerId');
  }

  @override
  Future<void> pause(int playerId) async {
    operations.add('pause:$playerId');
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    operations.add('looping:$playerId:$looping');
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> dispose(int playerId) async {
    operations.add('dispose:$playerId');
    await _streams.remove(playerId)?.close();
  }

  Future<void> close() async {
    final streams = _streams.values.toList(growable: false);
    _streams.clear();
    for (final stream in streams) {
      await stream.close();
    }
  }
}

class _TrackedVideoView extends StatefulWidget {
  const _TrackedVideoView({
    required this.playerId,
    required this.onMounted,
    required this.onDisposed,
  });

  final int playerId;
  final ValueChanged<int> onMounted;
  final ValueChanged<int> onDisposed;

  @override
  State<_TrackedVideoView> createState() => _TrackedVideoViewState();
}

class _TrackedVideoViewState extends State<_TrackedVideoView> {
  @override
  void initState() {
    super.initState();
    widget.onMounted(widget.playerId);
  }

  @override
  void dispose() {
    widget.onDisposed(widget.playerId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black);
  }
}
