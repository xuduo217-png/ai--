import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/theme/app_theme.dart';
import 'package:pet_hospital_flutter/core/widgets/app_permission_dialog.dart';

void main() {
  testWidgets('权限弹窗在常规手机宽度下并排操作按钮并返回选择', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  result = await showAppPermissionDialog(
                    context: context,
                    icon: Icons.photo_library_rounded,
                    title: '保存到相册',
                    description: '用于保存当前生成的图片。',
                    assurances: const ['只保存您选择的图片', '不会读取其他内容'],
                    cancelText: '暂不需要',
                    confirmText: '允许保存',
                    cancelButtonKey: const ValueKey('permission-cancel'),
                    confirmButtonKey: const ValueKey('permission-confirm'),
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byType(AppPermissionDialog), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    final cancelCenter = tester.getCenter(
      find.byKey(const ValueKey('permission-cancel')),
    );
    final confirmCenter = tester.getCenter(
      find.byKey(const ValueKey('permission-confirm')),
    );
    expect(cancelCenter.dx, lessThan(confirmCenter.dx));
    expect((cancelCenter.dy - confirmCenter.dy).abs(), lessThan(1));

    await tester.tap(find.byKey(const ValueKey('permission-confirm')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.byType(AppPermissionDialog), findsNothing);
  });

  testWidgets('权限弹窗在超大字体下保持内容可读且无溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const Scaffold(
          body: AppPermissionDialog(
            icon: Icons.mic_rounded,
            title: '需要麦克风权限',
            description: '开启后才能发送语音消息。',
            assurances: ['仅在您按住录音时使用'],
            confirmText: '允许使用麦克风',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('需要麦克风权限'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
