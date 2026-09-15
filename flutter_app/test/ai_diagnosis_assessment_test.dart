import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/health/domain/health_models.dart';
import 'package:pet_hospital_flutter/features/health/presentation/pages/ai_diagnosis_pages.dart';

Map<String, Object?> assessment(String prefix, {String status = 'completed'}) =>
    {
      'status': status,
      'emergency': {
        'status': status,
        'level': 'emergency',
        'action': '$prefix立即就医',
        'reasons': ['$prefix危险信号'],
        'missing_information': ['无'],
      },
      'recommended_tests': {
        'status': status,
        'items': [
          {
            'name': '$prefix条件检查',
            'priority': 'conditional',
            'purpose': '确认症状来源',
            'condition': '持续时',
            'related_findings': ['相关症状'],
          },
          {'name': '$prefix紧急检查', 'priority': 'urgent'},
          {'name': '$prefix推荐检查', 'priority': 'recommended'},
        ],
      },
      'temporary_care': {
        'status': status,
        'actions': ['$prefix临时护理'],
        'avoid': ['$prefix避免自行用药'],
        'escalation_signs': ['$prefix症状加重'],
      },
      'warnings': ['$prefix仅供辅助'],
    };

AiDiagnosisReport report({
  Object? western,
  Object? tcm,
  String status = 'completed',
}) => AiDiagnosisReport.fromJson({
  'id': 1,
  'petId': 1,
  'status': status,
  'symptoms': '测试症状',
  'createdAt': '2026-09-10T00:00:00Z',
  'westernDiagnosis': western,
  'tcmDiagnosis': tcm,
});

Future<void> showReport(WidgetTester tester, AiDiagnosisReport value) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: AiDiagnosisReportContent(report: value)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('中西医分别展示三个评估模块并按优先级排序', (tester) async {
    await showReport(
      tester,
      report(
        western: {
          'diagnosis': [],
          'assessment': assessment('西医'),
          'disclaimer': '西医接口声明',
        },
        tcm: {
          'data': [],
          'assessment': assessment('中医'),
          'disclaimer': '中医接口声明',
        },
      ),
    );
    expect(find.text('西医立即就医'), findsOneWidget);
    expect(find.text('紧急情况识别'), findsOneWidget);
    expect(find.text('建议检查项目'), findsOneWidget);
    expect(find.text('临时处置建议'), findsOneWidget);
    expect(find.text('西医临时护理'), findsOneWidget);
    expect(find.text('西医仅供辅助'), findsOneWidget);
    expect(find.text('西医接口声明'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('西医紧急检查')).dy,
      lessThan(tester.getTopLeft(find.text('西医推荐检查')).dy),
    );
    expect(
      tester.getTopLeft(find.text('西医推荐检查')).dy,
      lessThan(tester.getTopLeft(find.text('西医条件检查')).dy),
    );
    await tester.ensureVisible(find.text('中医诊断'));
    await tester.tap(find.text('中医诊断'));
    await tester.pumpAndSettle();
    expect(find.text('中医立即就医'), findsOneWidget);
    expect(find.text('中医临时护理'), findsOneWidget);
    expect(find.text('中医接口声明'), findsOneWidget);
    expect(find.text('西医立即就医'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('历史数据无评估或字段为空不显示模块不崩溃', (tester) async {
    for (final value in [null, {}, [], 'invalid']) {
      await showReport(tester, report(western: {'assessment': value}, tcm: []));
      expect(find.text('紧急情况识别'), findsNothing);
      expect(find.text('建议检查项目'), findsNothing);
      expect(find.text('临时处置建议'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('pending 不把占位检查作为正式建议，更新后展示实际结果', (tester) async {
    await showReport(
      tester,
      report(
        status: 'processing',
        western: {'assessment': assessment('西医', status: 'pending')},
      ),
    );
    expect(find.text('西医条件检查'), findsNothing);
    expect(find.text('检查建议生成中'), findsOneWidget);
    await showReport(tester, report(western: {'assessment': assessment('西医')}));
    expect(find.text('西医条件检查'), findsOneWidget);
    expect(find.text('检查建议生成中'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('部分模块异常仍显示有效急诊建议，不把未知状态当正常', (tester) async {
    await showReport(
      tester,
      report(
        western: {
          'assessment': {
            'status': 'partial',
            'emergency': {
              'status': 'completed',
              'level': 'future-level',
              'action': '联系兽医',
            },
            'recommended_tests': {
              'status': 'unavailable',
              'items': [null, 1],
            },
            'temporary_care': null,
            'warnings': [null, {}, '有效警示'],
          },
        },
      ),
    );
    expect(find.text('联系兽医'), findsOneWidget);
    expect(find.text('紧急程度待确认'), findsOneWidget);
    expect(find.text('检查建议暂不可用，请咨询兽医'), findsOneWidget);
    expect(find.text('有效警示'), findsOneWidget);
    expect(find.text('临时处置建议'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
