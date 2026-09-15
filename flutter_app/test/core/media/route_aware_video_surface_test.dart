import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/media/android_video_surface_exit.dart';
import 'package:pet_hospital_flutter/core/media/route_aware_video_surface.dart';
import 'package:video_player/video_player.dart';

void main() {
  const surfaceExitChannel = MethodChannel(
    'com.good.pet.hospital/video_surface_exit',
  );

  tearDown(() async {
    AndroidVideoSurfaceExit.debugPlatformIsAndroid = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(surfaceExitChannel, null);
  });

  testWidgets('路由返回动画开始时先暂停并移除 PlatformView 视频面', (tester) async {
    final controller = _FakeVideoPlayerController();
    await controller.play();

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
    final routeFuture = navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          key: const ValueKey('video-test-page'),
          body: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: RouteAwareVideoSurface(
                controller: controller,
                detachedKey: const ValueKey('video-test-detached'),
                child: const ColoredBox(
                  key: ValueKey('native-video-surface'),
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const ValueKey('native-video-surface')), findsOneWidget);
    navigatorKey.currentState!.pop();
    await tester.pump();

    expect(find.byKey(const ValueKey('video-test-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('video-test-detached')), findsOneWidget);
    expect(find.byKey(const ValueKey('native-video-surface')), findsNothing);
    expect(
      controller.operations.lastIndexOf('pause'),
      greaterThan(controller.operations.lastIndexOf('play')),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.byKey(const ValueKey('video-test-page')), findsNothing);
    expect(tester.takeException(), isNull);
    await routeFuture;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await controller.dispose();
  });

  testWidgets('原生 Surface 确认前不启动路由返回动画', (tester) async {
    AndroidVideoSurfaceExit.debugPlatformIsAndroid = true;
    final nativeAcknowledgement = Completer<void>();
    final nativeCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(surfaceExitChannel, (call) async {
          nativeCalls.add(call.method);
          if (call.method == 'prepareForExit') {
            await nativeAcknowledgement.future;
            return <String, Object>{'hiddenCount': 1, 'timedOut': false};
          }
          return null;
        });

    final controller = _FakeVideoPlayerController();
    await controller.play();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
    final routeFuture = navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VideoRoutePopScope<void>(
          child: Scaffold(
            key: const ValueKey('coordinated-video-page'),
            body: RouteAwareVideoSurface(
              controller: controller,
              detachedKey: const ValueKey('coordinated-video-detached'),
              child: const ColoredBox(
                key: ValueKey('coordinated-native-video'),
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump();

    expect(nativeCalls, ['prepareForExit']);
    expect(controller.value.isPlaying, isFalse);
    expect(
      find.byKey(const ValueKey('coordinated-video-page')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coordinated-native-video')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coordinated-video-detached')),
      findsNothing,
    );

    nativeAcknowledgement.complete();
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('coordinated-video-page')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coordinated-video-detached')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coordinated-native-video')),
      findsNothing,
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coordinated-video-page')), findsNothing);
    await routeFuture;

    await controller.dispose();
    AndroidVideoSurfaceExit.debugPlatformIsAndroid = null;
  });
}

class _FakeVideoPlayerController extends VideoPlayerController {
  _FakeVideoPlayerController()
    : super.networkUrl(
        Uri.parse('https://example.test/video.mp4'),
        viewType: VideoViewType.platformView,
      ) {
    value = const VideoPlayerValue(
      duration: Duration(seconds: 30),
      size: Size(160, 90),
      isInitialized: true,
    );
  }

  final List<String> operations = [];

  @override
  Future<void> play() async {
    operations.add('play');
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    operations.add('pause');
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> dispose() async {
    operations.add('dispose');
    await super.dispose();
  }
}
