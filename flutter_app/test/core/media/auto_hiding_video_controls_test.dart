import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/media/auto_hiding_video_controls.dart';

void main() {
  testWidgets('播放后隐藏控制层，点击画面只唤出控制层', (tester) async {
    var playing = false;
    var toggleCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 240,
            height: 160,
            child: StatefulBuilder(
              builder: (context, setState) {
                return AutoHidingVideoControls(
                  isPlaying: playing,
                  autoHideDelay: const Duration(milliseconds: 300),
                  fadeDuration: const Duration(milliseconds: 100),
                  surfaceKey: const ValueKey('video-surface'),
                  controlsKey: const ValueKey('video-controls'),
                  controls: Center(
                    child: IconButton(
                      key: const ValueKey('video-toggle'),
                      onPressed: () {
                        toggleCount += 1;
                        setState(() => playing = !playing);
                      },
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    ),
                  ),
                  child: const ColoredBox(color: Colors.black),
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(_controlsOpacity(tester), 1);
    await tester.tap(find.byKey(const ValueKey('video-toggle')));
    await tester.pump();
    expect(toggleCount, 1);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_controlsOpacity(tester), 0);

    await tester.tap(find.byKey(const ValueKey('video-surface')));
    await tester.pump();
    expect(_controlsOpacity(tester), 1);
    expect(toggleCount, 1);

    await tester.tap(find.byKey(const ValueKey('video-toggle')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(toggleCount, 2);
    expect(_controlsOpacity(tester), 1);
  });
}

double _controlsOpacity(WidgetTester tester) {
  return tester
      .widget<AnimatedOpacity>(find.byKey(const ValueKey('video-controls')))
      .opacity;
}
