import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/media/chat_media_display_size.dart';

void main() {
  test('390 宽屏幕使用 195 的最大边并保持横竖媒体比例', () {
    final landscape = chatMediaDisplaySize(
      viewportWidth: 390,
      availableWidth: 300,
      sourceWidth: 1920,
      sourceHeight: 1080,
      fallbackAspectRatio: 4 / 3,
    );
    final portrait = chatMediaDisplaySize(
      viewportWidth: 390,
      availableWidth: 300,
      sourceWidth: 1080,
      sourceHeight: 1920,
      fallbackAspectRatio: 4 / 3,
    );

    expect(landscape.width, 195);
    expect(landscape.height, closeTo(109.6875, 0.001));
    expect(portrait.width, closeTo(109.6875, 0.001));
    expect(portrait.height, 195);
  });

  test('大屏上限为 200 且窄容器不溢出', () {
    final capped = chatMediaDisplaySize(
      viewportWidth: 800,
      availableWidth: 500,
      fallbackAspectRatio: 1,
    );
    final constrained = chatMediaDisplaySize(
      viewportWidth: 390,
      availableWidth: 120,
      fallbackAspectRatio: 4 / 3,
    );

    expect(capped, const Size(200, 200));
    expect(constrained, const Size(120, 90));
  });
}
