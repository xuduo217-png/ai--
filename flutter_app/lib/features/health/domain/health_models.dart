import 'diagnosis_assessment.dart';

export 'diagnosis_assessment.dart';

import '../../pets/domain/pet_models.dart';

enum HealthAppointmentType {
  vaccine('vaccine', '疫苗接种'),
  deworming('deworming', '驱虫'),
  checkup('checkup', '健康体检');

  const HealthAppointmentType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static HealthAppointmentType fromValue(Object? value) {
    final normalized = '$value'.toLowerCase();
    return values.firstWhere(
      (type) => type.wireValue == normalized,
      orElse: () => HealthAppointmentType.checkup,
    );
  }
}

enum HealthAppointmentStatus {
  pending('pending', '待确认'),
  confirmed('confirmed', '已确认'),
  completed('completed', '已完成'),
  cancelled('cancelled', '已取消');

  const HealthAppointmentStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static HealthAppointmentStatus fromValue(Object? value) {
    final normalized = '$value'.toLowerCase();
    return values.firstWhere(
      (status) => status.wireValue == normalized,
      orElse: () => HealthAppointmentStatus.pending,
    );
  }
}

class HealthMetric {
  const HealthMetric({
    this.count = 0,
    this.lastAt,
    this.nextAt,
    this.daysUntilNext,
  });

  factory HealthMetric.fromJson(Object? value) {
    final json = healthJsonMapOrEmpty(value);
    return HealthMetric(
      count: healthInt(json['count']),
      lastAt: healthDateTime(json['lastAt']),
      nextAt: healthDateTime(json['nextAt']),
      daysUntilNext: healthNullableInt(json['daysUntilNext']),
    );
  }

  final int count;
  final DateTime? lastAt;
  final DateTime? nextAt;
  final int? daysUntilNext;
}

class PetHealthStats {
  const PetHealthStats({
    required this.vaccine,
    required this.deworming,
    required this.checkup,
  });

  factory PetHealthStats.fromJson(Object? value) {
    final json = healthJsonMap(value, 'pet health stats');
    return PetHealthStats(
      vaccine: HealthMetric.fromJson(json['vaccine']),
      deworming: HealthMetric.fromJson(json['deworming']),
      checkup: HealthMetric.fromJson(json['checkup']),
    );
  }

  static const empty = PetHealthStats(
    vaccine: HealthMetric(),
    deworming: HealthMetric(),
    checkup: HealthMetric(),
  );

  final HealthMetric vaccine;
  final HealthMetric deworming;
  final HealthMetric checkup;

  HealthMetric metricFor(HealthAppointmentType type) => switch (type) {
    HealthAppointmentType.vaccine => vaccine,
    HealthAppointmentType.deworming => deworming,
    HealthAppointmentType.checkup => checkup,
  };
}

class HealthHospital {
  const HealthHospital({
    required this.id,
    required this.name,
    this.address = '',
    this.phone = '',
    this.logoUrl = '',
  });

  factory HealthHospital.fromJson(Object? value) {
    final json = healthJsonMap(value, 'hospital');
    return HealthHospital(
      id: healthRequiredInt(json['id'], 'hospital id'),
      name: healthString(json['name'], fallback: '宠物医院'),
      address: healthString(json['address']),
      phone: healthString(json['phone']),
      logoUrl: healthString(json['logo'] ?? json['logoUrl']),
    );
  }

  final int id;
  final String name;
  final String address;
  final String phone;
  final String logoUrl;
}

class HealthAppointment {
  const HealthAppointment({
    required this.id,
    required this.type,
    required this.status,
    required this.appointmentDate,
    required this.timeSlot,
    required this.petId,
    required this.hospitalId,
    this.notes = '',
    this.operationContent = '',
    this.detailContent = '',
    this.pet,
    this.hospital,
    this.doctorName = '',
    this.createdAt,
  });

  factory HealthAppointment.fromJson(Object? value) {
    final json = healthJsonMap(value, 'health appointment');
    final doctor = healthJsonMapOrEmpty(json['doctor']);
    return HealthAppointment(
      id: healthRequiredInt(json['id'], 'appointment id'),
      type: HealthAppointmentType.fromValue(json['type']),
      status: HealthAppointmentStatus.fromValue(json['status']),
      appointmentDate: healthString(json['appointmentDate']),
      timeSlot: healthString(json['timeSlot']),
      petId: healthInt(json['petId']),
      hospitalId: healthInt(json['hospitalId']),
      notes: healthString(json['notes']),
      operationContent: healthString(json['operationContent']),
      detailContent: healthString(json['detailContent']),
      pet: json['pet'] == null
          ? null
          : Pet.fromJson(healthJsonMap(json['pet'], 'appointment pet')),
      hospital: json['hospital'] == null
          ? null
          : HealthHospital.fromJson(json['hospital']),
      doctorName: healthString(doctor['name']),
      createdAt: healthDateTime(json['createdAt']),
    );
  }

  final int id;
  final HealthAppointmentType type;
  final HealthAppointmentStatus status;
  final String appointmentDate;
  final String timeSlot;
  final int petId;
  final int hospitalId;
  final String notes;
  final String operationContent;
  final String detailContent;
  final Pet? pet;
  final HealthHospital? hospital;
  final String doctorName;
  final DateTime? createdAt;

  bool get isActive =>
      status == HealthAppointmentStatus.pending ||
      status == HealthAppointmentStatus.confirmed;
}

class AppointmentPage {
  const AppointmentPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<HealthAppointment> items;
  final int page;
  final int totalPages;
  final int total;
}

class CarePlan {
  const CarePlan({required this.nutrition, required this.care});

  factory CarePlan.fromJson(Object? value) {
    final json = healthJsonMap(value, 'care plan');
    return CarePlan(
      nutrition: NutritionPlan.fromJson(json['nutrition_plan']),
      care: CareAdvice.fromJson(json['care_plan']),
    );
  }

  final NutritionPlan nutrition;
  final CareAdvice care;
}

class NutritionPlan {
  const NutritionPlan({
    this.dailyCalories = '',
    this.protein = '',
    this.fat = '',
    this.carbs = '',
    this.recommendedFoods = const [],
    this.avoidFoods = const [],
    this.supplements = const [],
    this.feedingSchedule = const [],
  });

  factory NutritionPlan.fromJson(Object? value) {
    final json = healthJsonMapOrEmpty(value);
    final ratio = healthJsonMapOrEmpty(json['macro_ratio']);
    return NutritionPlan(
      dailyCalories: healthString(json['daily_calories']),
      protein: healthString(ratio['protein']),
      fat: healthString(ratio['fat']),
      carbs: healthString(ratio['carbs']),
      recommendedFoods: healthStringList(json['recommended_foods']),
      avoidFoods: healthStringList(json['avoid_foods']),
      supplements: healthStringList(json['supplements']),
      feedingSchedule: healthStringList(json['feeding_schedule']),
    );
  }

  final String dailyCalories;
  final String protein;
  final String fat;
  final String carbs;
  final List<String> recommendedFoods;
  final List<String> avoidFoods;
  final List<String> supplements;
  final List<String> feedingSchedule;
}

class CareAdvice {
  const CareAdvice({
    this.grooming = const [],
    this.medical = const [],
    this.exercise = const [],
    this.vaccination = const [],
    this.environment = const [],
  });

  factory CareAdvice.fromJson(Object? value) {
    final json = healthJsonMapOrEmpty(value);
    return CareAdvice(
      grooming: healthStringList(json['grooming']),
      medical: healthStringList(json['medical']),
      exercise: healthStringList(json['exercise']),
      vaccination: healthStringList(json['vaccination']),
      environment: healthStringList(json['environment']),
    );
  }

  final List<String> grooming;
  final List<String> medical;
  final List<String> exercise;
  final List<String> vaccination;
  final List<String> environment;
}

enum CarePlanStatus {
  notGenerated,
  generating,
  completed,
  failed;

  static CarePlanStatus fromValue(Object? value) =>
      switch ('$value'.toUpperCase()) {
        'GENERATING' => CarePlanStatus.generating,
        'COMPLETED' => CarePlanStatus.completed,
        'FAILED' => CarePlanStatus.failed,
        _ => CarePlanStatus.notGenerated,
      };
}

class PetCarePlanState {
  const PetCarePlanState({
    required this.pet,
    required this.status,
    this.plan,
    this.error = '',
    this.generatedAt,
  });

  factory PetCarePlanState.fromJson(Object? value) {
    final json = healthJsonMap(value, 'pet care plan');
    final rawPlan = json['carePlan'];
    return PetCarePlanState(
      pet: Pet.fromJson(json),
      status: CarePlanStatus.fromValue(json['carePlanStatus']),
      plan: rawPlan == null ? null : CarePlan.fromJson(rawPlan),
      error: healthString(json['carePlanError']),
      generatedAt: healthDateTime(json['carePlanGeneratedAt']),
    );
  }

  final Pet pet;
  final CarePlanStatus status;
  final CarePlan? plan;
  final String error;
  final DateTime? generatedAt;
}

class SelfCheckOption {
  const SelfCheckOption({
    required this.id,
    required this.text,
    this.imageUrl = '',
    this.sortOrder = 0,
  });

  factory SelfCheckOption.fromJson(Object? value) {
    final json = healthJsonMap(value, 'self check option');
    return SelfCheckOption(
      id: healthRequiredInt(json['id'], 'self check option id'),
      text: healthString(json['optionText']),
      imageUrl: healthString(json['optionImage']),
      sortOrder: healthInt(json['sortOrder']),
    );
  }

  final int id;
  final String text;
  final String imageUrl;
  final int sortOrder;
}

enum SelfCheckQuestionType {
  single,
  multiple,
  text;

  static SelfCheckQuestionType fromValue(Object? value) =>
      switch ('$value'.toUpperCase()) {
        'MULTIPLE' => SelfCheckQuestionType.multiple,
        'TEXT' => SelfCheckQuestionType.text,
        _ => SelfCheckQuestionType.single,
      };
}

class SelfCheckQuestion {
  const SelfCheckQuestion({
    required this.id,
    required this.text,
    required this.type,
    required this.required,
    required this.sortOrder,
    required this.options,
  });

  factory SelfCheckQuestion.fromJson(Object? value) {
    final json = healthJsonMap(value, 'self check question');
    return SelfCheckQuestion(
      id: healthRequiredInt(json['id'], 'self check question id'),
      text: healthString(json['questionText']),
      type: SelfCheckQuestionType.fromValue(json['questionType']),
      required: healthBool(json['required']),
      sortOrder: healthInt(json['sortOrder']),
      options: healthJsonList(
        json['options'],
      ).map(SelfCheckOption.fromJson).toList(growable: false),
    );
  }

  final int id;
  final String text;
  final SelfCheckQuestionType type;
  final bool required;
  final int sortOrder;
  final List<SelfCheckOption> options;
}

class SelfCheckList {
  const SelfCheckList({
    required this.id,
    required this.name,
    required this.type,
    required this.questions,
    this.description = '',
    this.categoryId,
  });

  factory SelfCheckList.fromJson(Object? value) {
    final json = healthJsonMap(value, 'self check list');
    return SelfCheckList(
      id: healthRequiredInt(json['id'], 'self check list id'),
      name: healthString(json['title'] ?? json['name']),
      description: healthString(json['description']),
      type: healthString(json['type'], fallback: 'PUBLIC'),
      categoryId: healthNullableInt(json['categoryId']),
      questions: healthJsonList(
        json['questions'],
      ).map(SelfCheckQuestion.fromJson).toList(growable: false),
    );
  }

  final int id;
  final String name;
  final String description;
  final String type;
  final int? categoryId;
  final List<SelfCheckQuestion> questions;
}

List<Map<String, Object?>> buildSelfCheckSnapshot({
  required List<SelfCheckList> lists,
  required Map<int, Set<int>> selectedOptions,
  Map<int, String> textAnswers = const {},
}) {
  final snapshot = <Map<String, Object?>>[];
  for (final list in lists) {
    final questions = <Map<String, Object?>>[];
    for (final question in list.questions) {
      final selectedIds = selectedOptions[question.id] ?? const <int>{};
      final answer = (textAnswers[question.id] ?? '').trim();
      final options = <Map<String, Object?>>[];

      if (answer.isNotEmpty) {
        options.add({
          'optionId': question.id,
          'optionText': answer,
          'selected': true,
        });
      } else if (question.options.isEmpty) {
        if (selectedIds.contains(question.id)) {
          options.add({
            'optionId': question.id,
            'optionText': question.text,
            'selected': true,
          });
        }
      } else {
        for (final option in question.options) {
          if (!selectedIds.contains(option.id)) continue;
          options.add({
            'optionId': option.id,
            'optionText': option.text,
            if (option.imageUrl.isNotEmpty) 'image': option.imageUrl,
            'selected': true,
          });
        }
      }

      if (options.isEmpty) continue;
      questions.add({
        'questionId': question.id,
        'questionText': question.text,
        'questionType': question.type.name.toUpperCase(),
        'sortOrder': question.sortOrder,
        'options': options,
      });
    }
    if (questions.isEmpty) continue;
    snapshot.add({
      'listId': list.id,
      'listName': list.name,
      'listType': list.type.toUpperCase() == 'SPECIFIC' ? 'SPECIFIC' : 'PUBLIC',
      if (list.categoryId != null) 'petCategoryId': list.categoryId,
      'questions': questions,
    });
  }
  return snapshot;
}

class AiDiagnosisConfig {
  const AiDiagnosisConfig({
    required this.bodyTemperatureOptions,
    required this.heartRateOptions,
    required this.breatheOptions,
    required this.disclaimerTitle,
    required this.disclaimerContent,
    required this.disclaimerConfirmText,
    required this.disclaimerCancelText,
  });

  factory AiDiagnosisConfig.fromJson(Object? value) {
    final root = healthJsonMapOrEmpty(value);
    final json = healthJsonMapOrEmpty(root['configValue']).isNotEmpty
        ? healthJsonMapOrEmpty(root['configValue'])
        : root;
    return AiDiagnosisConfig(
      bodyTemperatureOptions: _optionFallback(
        json['bodyTemperatureOptions'],
        fallback.bodyTemperatureOptions,
      ),
      heartRateOptions: _optionFallback(
        json['heartRateOptions'],
        fallback.heartRateOptions,
      ),
      breatheOptions: _optionFallback(
        json['breatheOptions'],
        fallback.breatheOptions,
      ),
      disclaimerTitle: healthString(
        json['disclaimerTitle'],
        fallback: fallback.disclaimerTitle,
      ),
      disclaimerContent: healthString(
        json['disclaimerContent'],
        fallback: fallback.disclaimerContent,
      ),
      disclaimerConfirmText: healthString(
        json['disclaimerConfirmText'],
        fallback: fallback.disclaimerConfirmText,
      ),
      disclaimerCancelText: healthString(
        json['disclaimerCancelText'],
        fallback: fallback.disclaimerCancelText,
      ),
    );
  }

  static const fallback = AiDiagnosisConfig(
    bodyTemperatureOptions: [
      '偏低（低于37.5℃）',
      '正常（37.5℃ - 39.2℃）',
      '偏高（39.3℃ - 40℃）',
      '高热（高于40℃）',
    ],
    heartRateOptions: ['偏慢', '正常', '偏快', '明显过快'],
    breatheOptions: ['偏慢', '正常', '偏快', '呼吸困难'],
    disclaimerTitle: '风险提示',
    disclaimerContent:
        '继续问诊将上传并处理宠物症状描述、自查表选择、诊断图片和体温、心率、呼吸等基础信息，用于生成 AI 问诊报告。AI 问诊结果仅供宠物健康管理参考，不能替代线下执业兽医的面诊、检查、诊断、处方或治疗建议。如宠物出现精神沉郁、持续呕吐腹泻、呼吸困难、抽搐、高热等紧急症状，请立即前往线下宠物医院就诊。',
    disclaimerConfirmText: '我已知晓，继续问诊',
    disclaimerCancelText: '再想想',
  );

  final List<String> bodyTemperatureOptions;
  final List<String> heartRateOptions;
  final List<String> breatheOptions;
  final String disclaimerTitle;
  final String disclaimerContent;
  final String disclaimerConfirmText;
  final String disclaimerCancelText;
}

class AiDiagnosisDraft {
  const AiDiagnosisDraft({
    required this.petId,
    required this.symptoms,
    required this.selfCheckSnapshot,
    required this.diagnosisImages,
    required this.bodyTemperature,
    required this.heartRate,
    required this.breathe,
  });

  final int petId;
  final String symptoms;
  final List<Map<String, Object?>> selfCheckSnapshot;
  final List<String> diagnosisImages;
  final String bodyTemperature;
  final String heartRate;
  final String breathe;

  Map<String, Object?> toJson() => {
    'petId': petId,
    'symptoms': symptoms.trim(),
    'selfCheckSnapshot': selfCheckSnapshot,
    if (diagnosisImages.isNotEmpty) 'diagnosisImages': diagnosisImages,
    'basicInfo': {
      'bodyTemperature': bodyTemperature,
      'heartRate': heartRate,
      'breathe': breathe,
    },
  };
}

enum AiDiagnosisStatus {
  pending,
  processing,
  completed,
  failed,
  timeout;

  static AiDiagnosisStatus fromValue(Object? value) =>
      switch ('$value'.toUpperCase()) {
        'PROCESSING' => AiDiagnosisStatus.processing,
        'COMPLETED' => AiDiagnosisStatus.completed,
        'FAILED' => AiDiagnosisStatus.failed,
        'TIMEOUT' => AiDiagnosisStatus.timeout,
        _ => AiDiagnosisStatus.pending,
      };

  String get label => switch (this) {
    AiDiagnosisStatus.pending => '等待分析',
    AiDiagnosisStatus.processing => '分析中',
    AiDiagnosisStatus.completed => '已完成',
    AiDiagnosisStatus.failed => '分析失败',
    AiDiagnosisStatus.timeout => '分析超时',
  };
}

class WesternDiagnosisItem {
  const WesternDiagnosisItem({
    required this.symptom,
    required this.reason,
    required this.probability,
  });

  factory WesternDiagnosisItem.fromJson(Object? value) {
    final json = healthJsonMap(value, 'western diagnosis');
    return WesternDiagnosisItem(
      symptom: healthString(json['symptom']),
      reason: healthString(json['reason']),
      probability: healthString(json['probability']),
    );
  }

  final String symptom;
  final String reason;
  final String probability;
}

class MedicationAdvice {
  const MedicationAdvice({
    required this.symptom,
    required this.drugName,
    required this.dosage,
    required this.frequency,
  });

  factory MedicationAdvice.fromJson(Object? value) {
    final json = healthJsonMap(value, 'medication advice');
    return MedicationAdvice(
      symptom: healthString(json['symptom']),
      drugName: healthString(json['drug_name'] ?? json['drugName']),
      dosage: healthString(json['dosage']),
      frequency: healthString(json['frequency']),
    );
  }

  final String symptom;
  final String drugName;
  final String dosage;
  final String frequency;
}

class TcmDiagnosisItem {
  const TcmDiagnosisItem({
    required this.name,
    required this.description,
    required this.probability,
    required this.therapy,
    required this.base,
    required this.prescription,
    required this.usage,
  });

  factory TcmDiagnosisItem.fromJson(Object? value) {
    final json = healthJsonMap(value, 'tcm diagnosis');
    return TcmDiagnosisItem(
      name: healthString(json['zhengming']),
      description: healthString(json['description']),
      probability: healthString(json['p']),
      therapy: healthString(json['therapy']),
      base: healthString(json['base']),
      prescription: healthString(json['base_prescription']),
      usage: healthString(json['base_prescription_usage']),
    );
  }

  final String name;
  final String description;
  final String probability;
  final String therapy;
  final String base;
  final String prescription;
  final String usage;
}

class AiSelfCheckOptionResult {
  const AiSelfCheckOptionResult({
    required this.text,
    this.imageUrl = '',
    this.selected = true,
  });

  factory AiSelfCheckOptionResult.fromJson(Object? value) {
    final json = healthJsonMap(value, 'ai self check option result');
    return AiSelfCheckOptionResult(
      text: healthString(json['optionText'] ?? json['text']),
      imageUrl: healthString(
        json['image'] ?? json['optionImage'] ?? json['imageUrl'],
      ),
      selected: json.containsKey('selected')
          ? healthBool(json['selected'])
          : true,
    );
  }

  final String text;
  final String imageUrl;
  final bool selected;
}

class AiSelfCheckQuestionResult {
  const AiSelfCheckQuestionResult({required this.text, required this.options});

  factory AiSelfCheckQuestionResult.fromJson(Object? value) {
    final json = healthJsonMap(value, 'ai self check question result');
    return AiSelfCheckQuestionResult(
      text: healthString(json['questionText'] ?? json['text']),
      options: healthJsonList(
        json['options'],
      ).map(AiSelfCheckOptionResult.fromJson).toList(growable: false),
    );
  }

  final String text;
  final List<AiSelfCheckOptionResult> options;
}

class AiSelfCheckSectionResult {
  const AiSelfCheckSectionResult({required this.name, required this.questions});

  factory AiSelfCheckSectionResult.fromJson(Object? value) {
    final json = healthJsonMap(value, 'ai self check section result');
    return AiSelfCheckSectionResult(
      name: healthString(
        json['listName'] ?? json['name'] ?? json['title'],
        fallback: '自查表',
      ),
      questions: healthJsonList(
        json['questions'],
      ).map(AiSelfCheckQuestionResult.fromJson).toList(growable: false),
    );
  }

  final String name;
  final List<AiSelfCheckQuestionResult> questions;
}

class AiDiagnosisReport {
  const AiDiagnosisReport({
    required this.id,
    required this.petId,
    required this.status,
    required this.symptoms,
    required this.diagnosisImages,
    required this.basicInfo,
    required this.westernDiagnosis,
    required this.medications,
    required this.tcmDiagnosis,
    required this.petSnapshot,
    required this.createdAt,
    this.westernAssessment,
    this.tcmAssessment,
    this.westernDisclaimer = '',
    this.tcmDisclaimer = '',
    this.selfCheckSnapshot = const [],
    this.errorMessage = '',
    this.completedAt,
  });

  factory AiDiagnosisReport.fromJson(Object? value) {
    final json = healthJsonMap(value, 'ai diagnosis report');
    final westernEnvelope = healthJsonMapOrEmpty(json['westernDiagnosis']);
    final western = westernEnvelope['data'] is Map
        ? healthJsonMapOrEmpty(westernEnvelope['data'])
        : westernEnvelope;
    final rawTcm = json['tcmDiagnosis'];
    final tcmEnvelope = healthJsonMapOrEmpty(rawTcm);
    final tcmList = rawTcm is List
        ? rawTcm
        : healthJsonList(healthJsonMapOrEmpty(rawTcm)['data']);
    return AiDiagnosisReport(
      id: healthRequiredInt(json['id'], 'ai diagnosis report id'),
      petId: healthInt(json['petId']),
      status: AiDiagnosisStatus.fromValue(json['status']),
      symptoms: healthString(json['symptoms']),
      diagnosisImages: healthStringList(json['diagnosisImages']),
      basicInfo: healthJsonMapOrEmpty(json['basicInfo']),
      westernAssessment: DiagnosisAssessment.parse(
        westernEnvelope['assessment'],
      ),
      tcmAssessment: DiagnosisAssessment.parse(tcmEnvelope['assessment']),
      westernDisclaimer: healthString(westernEnvelope['disclaimer']),
      tcmDisclaimer: healthString(tcmEnvelope['disclaimer']),
      westernDiagnosis: healthJsonList(
        western['diagnosis'],
      ).map(WesternDiagnosisItem.fromJson).toList(growable: false),
      medications: healthJsonList(
        western['medications'],
      ).map(MedicationAdvice.fromJson).toList(growable: false),
      tcmDiagnosis: tcmList
          .map(TcmDiagnosisItem.fromJson)
          .toList(growable: false),
      petSnapshot: healthJsonMapOrEmpty(json['petSnapshot'] ?? json['petInfo']),
      createdAt: healthDateTime(json['createdAt']) ?? DateTime.now(),
      selfCheckSnapshot: healthJsonList(
        json['selfCheckSnapshot'],
      ).map(AiSelfCheckSectionResult.fromJson).toList(growable: false),
      completedAt: healthDateTime(json['completedAt']),
      errorMessage: healthString(json['errorMessage'] ?? json['failureReason']),
    );
  }

  final int id;
  final int petId;
  final AiDiagnosisStatus status;
  final String symptoms;
  final List<String> diagnosisImages;
  final Map<String, Object?> basicInfo;
  final DiagnosisAssessment? westernAssessment;
  final DiagnosisAssessment? tcmAssessment;
  final String westernDisclaimer;
  final String tcmDisclaimer;
  final List<WesternDiagnosisItem> westernDiagnosis;
  final List<MedicationAdvice> medications;
  final List<TcmDiagnosisItem> tcmDiagnosis;
  final Map<String, Object?> petSnapshot;
  final DateTime createdAt;
  final List<AiSelfCheckSectionResult> selfCheckSnapshot;
  final DateTime? completedAt;
  final String errorMessage;
}

class AiDiagnosisPage {
  const AiDiagnosisPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<AiDiagnosisReport> items;
  final int page;
  final int totalPages;
  final int total;
}

class HealthArticleCategory {
  const HealthArticleCategory({
    required this.id,
    required this.name,
    this.iconUrl = '',
    this.articleCount = 0,
  });

  factory HealthArticleCategory.fromJson(Object? value) {
    final json = healthJsonMap(value, 'health article category');
    return HealthArticleCategory(
      id: healthRequiredInt(json['id'], 'health article category id'),
      name: healthString(json['name']),
      iconUrl: healthString(json['icon']),
      articleCount: healthInt(json['articleCount']),
    );
  }

  final int id;
  final String name;
  final String iconUrl;
  final int articleCount;
}

class HealthArticle {
  const HealthArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.categoryId,
    required this.createdAt,
    this.coverImageUrl = '',
    this.categoryName = '',
    this.viewCount = 0,
  });

  factory HealthArticle.fromJson(Object? value) {
    final json = healthJsonMap(value, 'health article');
    final category = healthJsonMapOrEmpty(json['category']);
    return HealthArticle(
      id: healthRequiredInt(json['id'], 'health article id'),
      title: healthString(json['title']),
      summary: healthString(json['summary']),
      content: healthString(json['content']),
      coverImageUrl: healthString(json['coverImage']),
      categoryId: healthInt(json['categoryId']),
      categoryName: healthString(category['name']),
      viewCount: healthInt(json['viewCount']),
      createdAt:
          healthDateTime(json['publishedAt'] ?? json['createdAt']) ??
          DateTime.now(),
    );
  }

  final int id;
  final String title;
  final String summary;
  final String content;
  final String coverImageUrl;
  final int categoryId;
  final String categoryName;
  final int viewCount;
  final DateTime createdAt;
}

class HealthArticlePage {
  const HealthArticlePage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<HealthArticle> items;
  final int page;
  final int totalPages;
  final int total;
}

class HealthConsultation {
  const HealthConsultation({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.doctorAvatarUrl,
    required this.status,
    this.paidAt,
    this.serviceStartAt,
    this.serviceEndAt,
    this.lastMessage,
    this.lastMessageAt,
  });

  factory HealthConsultation.fromJson(Object? value) {
    final json = healthJsonMap(value, 'health consultation');
    final lastMessage = healthJsonMapOrEmpty(json['lastMessage']);
    final content = healthString(lastMessage['content']);
    final type = healthString(lastMessage['type']).toUpperCase();
    return HealthConsultation(
      id: healthRequiredInt(json['id'], 'health consultation id'),
      doctorId: healthInt(json['doctorId']),
      doctorName: healthString(json['doctorName'], fallback: '宠物医生'),
      doctorAvatarUrl: healthString(json['doctorAvatar']),
      status: healthString(json['status'], fallback: 'EXPIRED'),
      paidAt: healthDateTime(json['paidAt']),
      serviceStartAt: healthDateTime(json['serviceStartAt']),
      serviceEndAt: healthDateTime(json['serviceEndAt']),
      lastMessage: content.isEmpty
          ? null
          : switch (type) {
              'IMAGE' => '[图片]',
              'VIDEO' => '[视频]',
              _ => content,
            },
      lastMessageAt: healthDateTime(lastMessage['createdAt']),
    );
  }

  final int id;
  final int doctorId;
  final String doctorName;
  final String doctorAvatarUrl;
  final String status;
  final DateTime? paidAt;
  final DateTime? serviceStartAt;
  final DateTime? serviceEndAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  bool get isActive => status.toUpperCase() != 'EXPIRED';
}

class ConsultationPage {
  const ConsultationPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<HealthConsultation> items;
  final int page;
  final int totalPages;
  final int total;
}

abstract interface class HealthGateway {
  Future<List<Pet>> loadHealthPets();

  Future<PetHealthStats> loadPetHealthStats(int petId);

  Future<AppointmentPage> loadAppointments({
    required int petId,
    int page = 1,
    int pageSize = 20,
    HealthAppointmentType? type,
    HealthAppointmentStatus? status,
  });

  Future<HealthAppointment> loadAppointment(int appointmentId);

  Future<HealthAppointment> createAppointment({
    required int petId,
    required int hospitalId,
    required HealthAppointmentType type,
    required String appointmentDate,
    required String timeSlot,
    String notes = '',
  });

  Future<void> cancelAppointment(int appointmentId);

  Future<List<HealthHospital>> loadHealthHospitals();

  Future<PetCarePlanState> loadCarePlan(int petId);

  Future<void> generateCarePlan(int petId);

  Future<List<SelfCheckList>> loadSelfCheckLists(int petId);

  Future<AiDiagnosisConfig> loadAiDiagnosisConfig();

  Future<String> uploadDiagnosisImage(String filePath);

  Future<AiDiagnosisReport> createAiDiagnosisReport(AiDiagnosisDraft draft);

  Future<AiDiagnosisPage> loadAiDiagnosisReports({
    int? petId,
    int page = 1,
    int pageSize = 20,
  });

  Future<AiDiagnosisReport> loadAiDiagnosisReport(int reportId);

  Future<List<HealthArticleCategory>> loadHealthArticleCategories();

  Future<HealthArticlePage> loadHealthArticles({
    int? categoryId,
    int page = 1,
    int pageSize = 20,
  });

  Future<HealthArticle> loadHealthArticle(int articleId);

  Future<ConsultationPage> loadHealthConsultations({
    int? doctorId,
    int page = 1,
    int pageSize = 20,
  });
}

Map<String, Object?> healthJsonMap(Object? value, String name) {
  if (value is Map) return Map<String, Object?>.from(value);
  throw FormatException('$name must be a JSON object.');
}

Map<String, Object?> healthJsonMapOrEmpty(Object? value) {
  if (value is Map) return Map<String, Object?>.from(value);
  return const {};
}

List<Object?> healthJsonList(Object? value) {
  if (value is List) return List<Object?>.from(value);
  if (value is Map && value['data'] is List) {
    return List<Object?>.from(value['data'] as List);
  }
  return const [];
}

String healthString(Object? value, {String fallback = ''}) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? fallback : normalized;
}

int healthInt(Object? value) => healthNullableInt(value) ?? 0;

int healthRequiredInt(Object? value, String name) {
  final parsed = healthNullableInt(value);
  if (parsed != null) return parsed;
  throw FormatException('$name must be an integer.');
}

int? healthNullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}

bool healthBool(Object? value) =>
    value == true || value == 1 || value == '1' || value == 'true';

DateTime? healthDateTime(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : DateTime.tryParse(normalized);
}

List<String> healthStringList(Object? value) => healthJsonList(
  value,
).map(healthString).where((item) => item.isNotEmpty).toList(growable: false);

List<String> _optionFallback(Object? value, List<String> fallback) {
  final parsed = healthStringList(value);
  return parsed.isEmpty ? fallback : parsed;
}
