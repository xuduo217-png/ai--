import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/health/domain/health_models.dart';
import 'package:pet_hospital_flutter/features/health/presentation/pages/ai_diagnosis_pages.dart';

import 'ai_diagnosis_assessment_test.dart' as fixtures;

class _Gateway implements HealthGateway {
  _Gateway(this.results);
  final List<AiDiagnosisReport> results;
  int calls = 0;
  bool fail = false;
  @override
  Future<AiDiagnosisReport> loadAiDiagnosisReport(int reportId) async {
    calls += 1;
    if (fail) throw StateError('offline');
    return results[(calls - 1).clamp(0, results.length - 1)];
  }

  @override
  Future<AiDiagnosisConfig> loadAiDiagnosisConfig() async =>
      AiDiagnosisConfig.fallback;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('解析兼容旧西医对象/中医数组及完整 AI 响应包装', () {
    final old = fixtures.report(
      western: {
        'diagnosis': [
          {'symptom': '旧诊断'},
        ],
      },
      tcm: [
        {'zhengming': '旧证型'},
      ],
    );
    expect(old.westernDiagnosis.single.symptom, '旧诊断');
    expect(old.tcmDiagnosis.single.name, '旧证型');
    expect(old.westernAssessment, isNull);
    expect(old.tcmAssessment, isNull);
    final current = fixtures.report(
      western: {
        'data': {
          'diagnosis': [
            {'symptom': '新诊断'},
          ],
        },
        'assessment': fixtures.assessment('西医'),
      },
      tcm: {
        'data': [
          {'zhengming': '新证型'},
        ],
        'assessment': fixtures.assessment('中医'),
      },
    );
    expect(current.westernDiagnosis.single.symptom, '新诊断');
    expect(current.tcmDiagnosis.single.name, '新证型');
    expect(
      current.westernAssessment?.recommendedTests?.tests.first.name,
      '西医紧急检查',
    );
    expect(current.tcmAssessment?.emergency?.text('action'), '中医立即就医');
  });

  testWidgets('生成期间提前展示急诊评估，主诊断完成后停止轮询', (tester) async {
    final gateway = _Gateway([
      fixtures.report(
        status: 'processing',
        western: {'assessment': fixtures.assessment('西医')},
      ),
      fixtures.report(western: {'assessment': fixtures.assessment('西医')}),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: AiDiagnosisReportPage(gateway: gateway, reportId: 1)),
    );
    await tester.pumpAndSettle();
    expect(find.text('AI 正在分析中...'), findsOneWidget);
    // 用户端不再展示顶部紧急提示，但急诊评估仍在下方模块中可见。
    expect(find.text('西医紧急提示：西医立即就医'), findsNothing);
    expect(find.text('紧急情况识别'), findsOneWidget);
    expect(find.text('西医立即就医'), findsOneWidget);
    expect(gateway.calls, 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(gateway.calls, 2);
    expect(find.text('AI 正在分析中...'), findsNothing);
    await tester.pump(const Duration(seconds: 20));
    expect(gateway.calls, 2);
  });

  testWidgets('已完成旧报告不轮询，明确 pending 评估才继续', (tester) async {
    final old = _Gateway([fixtures.report()]);
    await tester.pumpWidget(
      MaterialApp(home: AiDiagnosisReportPage(gateway: old, reportId: 1)),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(old.calls, 1);
    final current = _Gateway([
      fixtures.report(
        western: {'assessment': fixtures.assessment('西医', status: 'pending')},
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: AiDiagnosisReportPage(
          key: const ValueKey('new'),
          gateway: current,
          reportId: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(current.calls, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(current.calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('网络失败保留已有急诊建议并停止自动轮询', (tester) async {
    final gateway = _Gateway([
      fixtures.report(
        status: 'processing',
        western: {'assessment': fixtures.assessment('西医')},
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: AiDiagnosisReportPage(gateway: gateway, reportId: 1)),
    );
    await tester.pumpAndSettle();
    gateway.fail = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('西医紧急提示：西医立即就医'), findsNothing);
    expect(find.text('报告详情加载失败，请稍后重试'), findsOneWidget);
    // 刷新失败不清空已有报告，急诊评估仍按旧数据展示。
    expect(find.text('紧急情况识别'), findsOneWidget);
    expect(find.text('西医立即就医'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(gateway.calls, 2);
  });

  testWidgets('用户端内容视图隐藏顶部紧急提示，医生端默认保留', (tester) async {
    final value = fixtures.report(
      western: {'assessment': fixtures.assessment('西医')},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AiDiagnosisReportContent(report: value)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('西医紧急提示：西医立即就医'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiDiagnosisReportContent(
            report: value,
            showEmergencyAlerts: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('西医紧急提示：西医立即就医'), findsNothing);
    // 隐藏提示不等于隐藏急诊信息，评估模块中的急诊结论必须保留。
    expect(find.text('西医立即就医'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏大字体中医急诊提示不会依赖当前西医标签', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: AiDiagnosisReportContent(
              report: fixtures.report(
                tcm: {'data': [], 'assessment': fixtures.assessment('中医')},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('中医紧急提示：中医立即就医'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
