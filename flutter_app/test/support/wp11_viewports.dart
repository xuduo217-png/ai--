import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Wp11Viewport = ({String label, Size size, double textScale});

const wp11Viewports = <Wp11Viewport>[
  (label: '小屏 Android', size: Size(320, 568), textScale: 1),
  (label: '常规 iPhone', size: Size(390, 844), textScale: 1),
  (label: '常规 Android', size: Size(402, 874), textScale: 1),
  (label: '大字体 1.3', size: Size(320, 568), textScale: 1.3),
  (label: '大字体 1.5', size: Size(390, 844), textScale: 1.5),
  (label: '横屏', size: Size(844, 390), textScale: 1),
];

void configureWp11Viewport(WidgetTester tester, Wp11Viewport viewport) {
  tester.view.physicalSize = viewport.size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

TransitionBuilder wp11TextScaleBuilder(double textScale) {
  return (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  );
}
