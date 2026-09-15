import 'package:flutter/material.dart';

import '../../domain/diagnosis_assessment.dart';

/// 两种诊断共用布局，但始终使用各自评估，不跨诊断补值。
class DiagnosisAssessmentPanel extends StatelessWidget {
  const DiagnosisAssessmentPanel({
    super.key,
    required this.assessment,
    this.disclaimer = '',
  });
  final DiagnosisAssessment? assessment;
  final String disclaimer;

  @override
  Widget build(BuildContext context) {
    final value = assessment;
    if (value == null && disclaimer.isEmpty) return const SizedBox.shrink();
    final emergency = value?.emergency;
    final tests = value?.recommendedTests;
    final care = value?.temporaryCare;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (value?.status == 'partial') _note('部分评估暂不可用，请结合兽医意见'),
        if (value?.status == 'pending') _note('评估生成中，请勿等待结果而延误就医'),
        if (value?.status == 'unavailable') _note('评估暂不可用，请联系兽医'),
        if (emergency != null)
          _card('紧急情况识别', Icons.health_and_safety_outlined, [
            Text(
              emergency.status == 'pending'
                  ? '紧急情况评估中'
                  : switch (emergency.text('level')) {
                      'emergency' => '立即急诊',
                      'urgent' => '尽快就医',
                      'routine' => '暂未识别到急症信号（不代表排除疾病）',
                      _ => '紧急程度待确认',
                    },
              style: TextStyle(
                color: _emergencyColor(emergency),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (emergency.status == 'unavailable') _note('紧急情况评估暂不可用，请联系兽医'),
            // 即使评估未完成，仍显示接口提供的安全行动建议。
            if (emergency.text('action').isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  emergency.text('action'),
                  style: TextStyle(
                    color: _emergencyColor(emergency),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ..._lines('判断依据', emergency.strings('reasons')),
            ..._lines(
              '待补充信息',
              emergency
                  .strings('missing_information')
                  .where((item) => item != '无')
                  .toList(),
            ),
          ], color: _emergencyColor(emergency)),
        if (tests != null)
          _card('建议检查项目', Icons.biotech_outlined, [
            if (tests.status == 'pending')
              _note('检查建议生成中')
            else ...[
              if (tests.status == 'unavailable') _note('检查建议暂不可用，请咨询兽医'),
              if (tests.tests.isEmpty && tests.status != 'unavailable')
                _note('暂无具体检查项目，请咨询兽医'),
              for (final item in tests.tests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        switch (item.priority) {
                          'urgent' => '优先级：紧急',
                          'recommended' => '优先级：推荐',
                          'conditional' => '优先级：有条件进行',
                          _ => '优先级：待确认',
                        },
                        style: TextStyle(
                          fontSize: 12,
                          color: item.priority == 'urgent'
                              ? Colors.red.shade700
                              : Colors.blueGrey,
                        ),
                      ),
                      ..._lines('检查目的', [item.purpose]),
                      if (item.condition != '无附加条件')
                        ..._lines('执行条件', [item.condition]),
                    ],
                  ),
                ),
            ],
          ]),
        if (care != null)
          _card('临时处置建议', Icons.home_outlined, [
            _note('仅用于就医前临时护理，不作为治疗方案'),
            if (care.status == 'pending') _note('临时处置建议生成中'),
            if (care.status == 'unavailable') _note('临时处置评估暂不可用，请联系兽医'),
            ..._lines('可以做', care.strings('actions')),
            ..._lines('避免事项', care.strings('avoid')),
            ..._lines(
              '出现以下情况及时就医',
              care.strings('escalation_signs'),
              warning: true,
            ),
          ]),
        for (final warning in value?.warnings ?? <String>[]) _note(warning),
        if (disclaimer.isNotEmpty) _note(disclaimer),
      ],
    );
  }

  Color _emergencyColor(AssessmentModule value) =>
      switch (value.text('level')) {
        'emergency' => Colors.red.shade700,
        'urgent' => Colors.orange.shade800,
        _ => Colors.blueGrey.shade700,
      };

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF626A78),
        height: 1.5,
      ),
    ),
  );

  List<Widget> _lines(
    String label,
    List<String> values, {
    bool warning = false,
  }) {
    final nonEmpty = values.where((item) => item.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return const [];
    return [
      const SizedBox(height: 6),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: warning ? Colors.red.shade700 : const Color(0xFF626A78),
          fontWeight: FontWeight.w600,
        ),
      ),
      for (final value in nonEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(value, style: const TextStyle(fontSize: 13, height: 1.5)),
        ),
    ];
  }

  Widget _card(
    String title,
    IconData icon,
    List<Widget> children, {
    Color color = const Color(0xFF7189D9),
  }) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );
}
