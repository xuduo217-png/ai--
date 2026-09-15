/// AI 返回的增量评估；旧报告缺少该对象时不推断为“正常”。
class DiagnosisAssessment {
  DiagnosisAssessment._(Map<String, Object?> json)
    : status = _text(json['status']),
      emergency = _module(json['emergency']),
      recommendedTests = _module(json['recommended_tests']),
      temporaryCare = _module(json['temporary_care']),
      warnings = assessmentStrings(json['warnings']);

  static DiagnosisAssessment? parse(Object? value) {
    final json = _map(value);
    if (json.isEmpty) return null;
    final result = DiagnosisAssessment._(json);
    return result.status.isEmpty &&
            result.emergency == null &&
            result.recommendedTests == null &&
            result.temporaryCare == null &&
            result.warnings.isEmpty
        ? null
        : result;
  }

  final String status;
  final AssessmentModule? emergency;
  final AssessmentModule? recommendedTests;
  final AssessmentModule? temporaryCare;
  final List<String> warnings;

  bool get isPending =>
      status == 'pending' ||
      [
        emergency,
        recommendedTests,
        temporaryCare,
      ].any((item) => item?.status == 'pending');
}

/// 对新增模块做局部容错，单个脏字段不影响原有诊断结果。
class AssessmentModule {
  AssessmentModule._(this._json);
  final Map<String, Object?> _json;
  String get status => text('status');
  String text(String key) => _text(_json[key]);
  List<String> strings(String key) => assessmentStrings(_json[key]);

  List<RecommendedTest> get tests {
    final raw = _json['items'];
    if (raw is! List) return const [];
    final items = raw
        .whereType<Map>()
        .map((item) => RecommendedTest._(_map(item)))
        .where((item) => item.name.isNotEmpty)
        .toList();
    // 同优先级保持接口顺序。
    return [
      for (final rank in [0, 1, 2, 3])
        ...items.where((item) => item.priorityRank == rank),
    ];
  }
}

class RecommendedTest {
  RecommendedTest._(this._json);
  final Map<String, Object?> _json;
  String get name => _text(_json['name']);
  String get purpose => _text(_json['purpose']);
  String get priority => _text(_json['priority']);
  String get condition => _text(_json['condition']);
  List<String> get relatedFindings =>
      assessmentStrings(_json['related_findings']);
  int get priorityRank => switch (priority) {
    'urgent' => 0,
    'recommended' => 1,
    'conditional' => 2,
    _ => 3,
  };
}

AssessmentModule? _module(Object? value) {
  final json = _map(value);
  return json.isEmpty ? null : AssessmentModule._(json);
}

Map<String, Object?> _map(Object? value) => value is Map
    ? {
        for (final entry in value.entries)
          if (entry.key is String) entry.key as String: entry.value,
      }
    : const {};
String _text(Object? value) => value is String ? value.trim() : '';
List<String> assessmentStrings(Object? value) => value is List
    ? value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
    : const [];
