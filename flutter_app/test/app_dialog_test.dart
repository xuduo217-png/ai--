import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/theme/app_theme.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

void main() {
  testWidgets('AppDialog 使用白色面板和等宽操作按钮', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AppDialog(
                  icon: const AppDialogIcon(icon: Icons.info_outline_rounded),
                  title: const Text('确认操作'),
                  content: const Text('确认继续执行当前操作吗？'),
                  actions: [
                    TextButton(
                      key: const ValueKey('dialog-cancel'),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      key: const ValueKey('dialog-confirm'),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('确认'),
                    ),
                  ],
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final panel = tester.widget<Container>(
      find.byKey(const ValueKey('app-dialog-panel')),
    );
    final decoration = panel.decoration! as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('dialog-cancel'))).width,
      moreOrLessEquals(
        tester.getSize(find.byKey(const ValueKey('dialog-confirm'))).width,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppDialog 在小屏和大字体下纵向排列按钮', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.6),
          ),
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AppDialog(
                    title: const Text('确认删除这条内容'),
                    content: const Text('删除后无法恢复，请确认是否继续。这里使用较长的说明验证弹窗滚动和布局。'),
                    actions: [
                      TextButton(
                        key: const ValueKey('large-dialog-cancel'),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('再想想'),
                      ),
                      FilledButton(
                        key: const ValueKey('large-dialog-confirm'),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('确认删除'),
                      ),
                    ],
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final confirmTop = tester
        .getTopLeft(find.byKey(const ValueKey('large-dialog-confirm')))
        .dy;
    final cancelTop = tester
        .getTopLeft(find.byKey(const ValueKey('large-dialog-cancel')))
        .dy;
    expect(confirmTop, lessThan(cancelTop));
    expect(tester.takeException(), isNull);
  });
}
