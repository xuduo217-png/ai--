import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_hospital_flutter/core/media/camera_media_picker.dart';
import 'package:pet_hospital_flutter/core/media/gallery_media_picker.dart';
import 'package:pet_hospital_flutter/features/health/domain/health_models.dart';
import 'package:pet_hospital_flutter/features/health/presentation/pages/ai_diagnosis_pages.dart';
import 'package:pet_hospital_flutter/features/health/presentation/pages/care_plan_page.dart';
import 'package:pet_hospital_flutter/features/health/presentation/pages/health_knowledge_pages.dart';
import 'package:pet_hospital_flutter/features/health/presentation/pages/health_assessment_page.dart';

import 'support/image_picker_gallery_media_gateway.dart';
import 'package:pet_hospital_flutter/features/health/presentation/pages/health_page.dart';
import 'package:pet_hospital_flutter/features/health/presentation/pages/health_record_pages.dart';
import 'package:pet_hospital_flutter/features/pets/domain/pet_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('营养师主页对齐 RN 的宠物卡、提醒和渐变功能卡', (tester) async {
    final gateway = _HealthGateway();

    await tester.pumpWidget(MaterialApp(home: HealthPage(gateway: gateway)));
    await tester.pumpAndSettle();

    expect(find.text('宠智灵营养师'), findsOneWidget);
    expect(find.text('团子'), findsOneWidget);
    expect(find.text('体重: 5.5kg'), findsOneWidget);
    expect(find.text('疫苗接种'), findsOneWidget);
    expect(find.text('3针'), findsOneWidget);
    expect(find.text('健康提醒'), findsOneWidget);
    expect(find.text('护理建议'), findsOneWidget);
    expect(find.text('查看详情'), findsOneWidget);
    expect(find.text('健康档案'), findsOneWidget);
    expect(find.text('健康知识'), findsOneWidget);
    expect(find.text('春季宠物护理指南'), findsOneWidget);
    expect(find.byKey(const ValueKey('health-pet-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('health-reminder-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('health-care-plan-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('health-record-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('health-knowledge-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('预约时间段选中后不显示对号', (tester) async {
    final gateway = _HealthGateway();

    await tester.pumpWidget(MaterialApp(home: HealthPage(gateway: gateway)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('预约').first);
    await tester.pumpAndSettle();

    final slotFinder = find.widgetWithText(ChoiceChip, '09:00-10:00');
    expect(slotFinder, findsOneWidget);
    expect(tester.widget<ChoiceChip>(slotFinder).showCheckmark, isFalse);
    final notesField = tester.widget<TextField>(
      find.widgetWithText(TextField, '备注（选填）'),
    );
    expect(notesField.decoration?.alignLabelWithHint, isTrue);
    expect(find.byType(DropdownButtonFormField<HealthHospital>), findsNothing);

    await tester.tap(find.text('提交预约'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('appointment-incomplete-dialog')),
      findsOneWidget,
    );
    expect(find.text('预约信息未填写完整'), findsOneWidget);
    expect(find.text('请先选择预约日期、预约时间段、预约医院，再提交预约。'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.text('预约疫苗接种'), findsOneWidget);

    final expectedDate = DateTime.now().add(const Duration(days: 1));
    await tester.tap(find.text('选择预约日期'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoPicker), findsNWidgets(3));
    expect(find.text('确定'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text(formatPetDate(expectedDate)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('health-hospital-picker')));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoPicker), findsOneWidget);
    expect(find.text('选择预约医院'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('宠物医院'), findsOneWidget);

    await tester.tap(slotFinder);
    await tester.pumpAndSettle();

    final selectedChip = tester.widget<ChoiceChip>(slotFinder);
    expect(selectedChip.selected, isTrue);
    expect(selectedChip.showCheckmark, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('健康知识分类选中后不显示对号', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HealthKnowledgeListPage(gateway: _HealthGateway())),
    );
    await tester.pumpAndSettle();

    final categoryChips = tester.widgetList<ChoiceChip>(
      find.byType(ChoiceChip),
    );
    expect(categoryChips, isNotEmpty);
    expect(categoryChips.every((chip) => chip.showCheckmark == false), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('健康档案列表还原 RN 筛选栏和记录卡片', (tester) async {
    final gateway = _HealthGateway(
      appointments: const [
        HealthAppointment(
          id: 12,
          type: HealthAppointmentType.vaccine,
          status: HealthAppointmentStatus.completed,
          appointmentDate: '2026-08-07',
          timeSlot: '09:00-10:00',
          petId: 8,
          hospitalId: 1,
          operationContent: '年度疫苗接种',
          doctorName: '王医生',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HealthRecordListPage(gateway: gateway, pet: gateway.pet),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('团子的健康档案'), findsOneWidget);
    expect(find.byKey(const ValueKey('health-record-filters')), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('疫苗'), findsOneWidget);
    expect(find.text('驱虫'), findsOneWidget);
    expect(find.text('体检'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('health-record-filters'))).width,
      greaterThan(300),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('health-record-filter-all')))
          .height,
      greaterThanOrEqualTo(38),
    );
    expect(
      tester
          .widget<Material>(
            find.byKey(const ValueKey('health-record-filter-all')),
          )
          .color,
      healthPrimary,
    );
    expect(find.text('年度疫苗接种'), findsOneWidget);
    expect(find.text('2026-08-07 · 疫苗 · 王医生'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('health-record-list-item-12')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('health-record-filter-deworming')),
    );
    await tester.pumpAndSettle();
    expect(gateway.lastAppointmentType, HealthAppointmentType.deworming);
    expect(tester.takeException(), isNull);
  });

  testWidgets('健康档案详情按 RN 分卡展示并支持富文本图片和视频', (tester) async {
    const summary = HealthAppointment(
      id: 12,
      type: HealthAppointmentType.vaccine,
      status: HealthAppointmentStatus.completed,
      appointmentDate: '2026-08-07',
      timeSlot: '10:00-11:00',
      petId: 8,
      hospitalId: 1,
      operationContent: '年度疫苗接种',
    );
    const detail = HealthAppointment(
      id: 12,
      type: HealthAppointmentType.vaccine,
      status: HealthAppointmentStatus.completed,
      appointmentDate: '2026-08-07',
      timeSlot: '10:00-11:00',
      petId: 8,
      hospitalId: 1,
      hospital: HealthHospital(id: 1, name: '谷德宠物医院华亭店'),
      doctorName: '杨斌',
      operationContent: '年度疫苗接种',
      detailContent:
          '<p>接种后观察</p><img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHEklEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg=="><div data-w-e-type="video"><video poster="/uploads/cover.jpg"><source src="/uploads/record.mov"></video></div>',
      notes: '三天内避免洗澡',
    );
    final gateway = _HealthGateway(appointmentDetail: detail);

    await tester.pumpWidget(
      MaterialApp(
        home: HealthRecordDetailPage(
          gateway: gateway,
          appointmentId: 12,
          initialRecord: summary,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(gateway.loadAppointmentCalls, 1);
    expect(
      find.byKey(const ValueKey('health-record-type-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('health-record-info-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('health-record-detail-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('health-record-notes-card')),
      findsOneWidget,
    );
    expect(find.text('预约日期'), findsOneWidget);
    expect(find.text('谷德宠物医院华亭店'), findsOneWidget);
    expect(find.text('接种后观察'), findsOneWidget);
    expect(find.byKey(const ValueKey('aid-guide-image-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('aid-guide-video-0')), findsOneWidget);
    expect(find.text('三天内避免洗澡'), findsOneWidget);
  });

  testWidgets('护理计划详情还原 RN 实心 Tab 和分类内容卡', (tester) async {
    final gateway = _HealthGateway(
      carePlanState: PetCarePlanState(
        pet: _pet(8, '团子'),
        status: CarePlanStatus.completed,
        plan: const CarePlan(
          nutrition: NutritionPlan(
            dailyCalories: '500 kcal',
            protein: '45%',
            fat: '30%',
            carbs: '25%',
            recommendedFoods: ['无谷高蛋白猫粮'],
            avoidFoods: ['牛奶及乳制品'],
            supplements: ['鱼油'],
            feedingSchedule: ['08:00 早餐'],
          ),
          care: CareAdvice(
            grooming: ['每周梳毛'],
            medical: ['每年体检'],
            exercise: ['每日互动 20 分钟'],
            vaccination: ['按时接种'],
            environment: ['保持通风'],
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: CarePlanPage(gateway: gateway, petId: 8)),
    );
    await tester.pumpAndSettle();

    expect(gateway.loadCarePlanCalls, 1);
    expect(find.text('专属护理方案'), findsNothing);
    expect(find.text('团子的专属方案'), findsNothing);
    expect(find.byKey(const ValueKey('care-plan-tabs')), findsOneWidget);
    expect(
      tester
          .widget<Material>(
            find.byKey(const ValueKey('care-plan-tab-nutrition')),
          )
          .color,
      healthPrimary,
    );
    expect(find.text('每日卡路里需求'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
    expect(find.text('营养比例'), findsOneWidget);
    expect(find.text('推荐食物'), findsOneWidget);
    expect(find.text('避免的食物'), findsOneWidget);
    expect(find.text('营养补充剂'), findsOneWidget);
    expect(find.text('喂养时间表'), findsOneWidget);
    expect(find.byType(Chip), findsNothing);

    await tester.tap(find.byKey(const ValueKey('care-plan-tab-care')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Material>(find.byKey(const ValueKey('care-plan-tab-care')))
          .color,
      healthPrimary,
    );
    expect(find.text('美容护理'), findsOneWidget);
    expect(find.text('医疗护理'), findsOneWidget);
    expect(find.text('运动建议'), findsOneWidget);
    expect(find.text('疫苗接种'), findsOneWidget);
    expect(find.text('环境管理'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI 问诊列表按宠物展示报告并可进入健康评估', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _HealthGateway();

    await tester.pumpWidget(
      MaterialApp(home: AiDiagnosisListPage(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI 问诊记录'), findsOneWidget);
    expect(find.text('风险提示'), findsOneWidget);
    expect(find.text('开始 AI 问诊'), findsOneWidget);
    expect(find.text('精神不振，食欲下降'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline_rounded), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ai-diagnosis-new')));
    await tester.pumpAndSettle();

    expect(find.text('AI问诊'), findsOneWidget);
    expect(find.text('AI诊断自查表勾选'), findsOneWidget);
    expect(find.text('详细描述'), findsOneWidget);
    expect(find.text('基础信息'), findsOneWidget);
    expect(find.text('上传图片（选填）'), findsOneWidget);
    expect(find.text('AI诊断提示'), findsOneWidget);
    expect(find.text('保存草稿'), findsOneWidget);
    expect(find.text('开始诊断'), findsOneWidget);
    expect(find.byKey(const ValueKey('assessment-option-体温:')), findsOneWidget);
    expect(find.byKey(const ValueKey('assessment-option-心率:')), findsOneWidget);
    expect(find.byKey(const ValueKey('assessment-option-呼吸:')), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('assessment-option-体温:')),
    );
    await tester.tap(find.byKey(const ValueKey('assessment-option-体温:')));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoPicker), findsOneWidget);
    expect(find.text('选择体温'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('偏低（低于37.5℃）'), findsOneWidget);

    await tester.tap(find.text('开始填表'));
    await tester.pumpAndSettle();

    expect(find.text('症状自查表'), findsOneWidget);
    expect(
      tester
          .widget<Image>(
            find.byKey(const ValueKey('assessment-check-image-11-112')),
          )
          .fit,
      BoxFit.contain,
    );
    expect(find.text('(0)'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    expect(find.text('清空'), findsOneWidget);
    expect(find.text('注意事项：无异常不用勾选'), findsWidgets);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    final normalOptionFinder = find.byKey(
      const ValueKey('assessment-check-option-11-111'),
    );
    expect(normalOptionFinder, findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);

    await tester.tap(normalOptionFinder);
    await tester.pump();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('(1)'), findsOneWidget);
    expect(find.text('已选 1'), findsOneWidget);
    final checklistImage = tester.widget<Image>(
      find.byKey(const ValueKey('assessment-check-image-11-112')),
    );
    expect(
      (checklistImage.image as NetworkImage).url,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/images/limp.jpg',
    );
    await tester.tap(
      find.byKey(const ValueKey('assessment-check-image-11-112')),
    );
    await tester.pumpAndSettle();
    final fullscreenPreview = find.byKey(
      const ValueKey('fullscreen-network-image-preview'),
    );
    expect(fullscreenPreview, findsOneWidget);
    expect(tester.getSize(fullscreenPreview), const Size(390, 844));
    await tester.tap(
      find.byKey(const ValueKey('fullscreen-network-image-close')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 1 项'), findsOneWidget);
    expect(find.text('已选择的症状：'), findsOneWidget);
    expect(find.text('常见症状：正常'), findsOneWidget);
  });

  testWidgets('详细描述标红加星号并作为必填项阻断提交', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: HealthAssessmentPage(
          gateway: _HealthGateway(),
          pet: _pet(8, '团子'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 标签标红，并在右上角带必填星号。
    final label = tester.widget<Text>(find.text('详细描述'));
    expect(label.style?.color, healthRequired);
    expect(
      find.descendant(
        of: find
            .ancestor(of: find.text('详细描述'), matching: find.byType(Row))
            .first,
        matching: find.text('*'),
      ),
      findsOneWidget,
    );

    // 未填写时提交被拦截，不会进入免责确认弹窗。
    await tester.tap(find.text('开始诊断'));
    await tester.pumpAndSettle();
    expect(find.text('我已知晓，继续问诊'), findsNothing);

    // SnackBar 提示消失后，输入框下方的就地错误仍然保留。
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('请填写详细症状描述'), findsOneWidget);

    // 补全描述后错误提示消失，可以继续下一步。
    await tester.enterText(
      find.byKey(const ValueKey('health-assessment-symptoms')),
      '小白从昨天开始食欲不振，今天早上还出现了呕吐',
    );
    await tester.pumpAndSettle();
    expect(find.text('请填写详细症状描述'), findsNothing);

    // 描述已通过校验，拦截点推进到下一个必填项。
    await tester.tap(find.text('开始诊断'));
    await tester.pumpAndSettle();
    expect(find.text('请选择宠物体温'), findsOneWidget);
    expect(find.text('我已知晓，继续问诊'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android 健康评估拍照先显示相机权限说明', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final picker = _RecordingHealthImagePicker();
      var cameraLaunchCalls = 0;
      CameraMediaPickerOptions? cameraOptions;
      await tester.pumpWidget(
        MaterialApp(
          home: HealthAssessmentPage(
            gateway: _HealthGateway(),
            pet: _pet(8, '团子'),
            galleryMediaPicker: GalleryMediaPicker(
              gateway: ImagePickerGalleryMediaGateway(picker),
            ),
            cameraMediaPicker: CameraMediaPicker(
              targetPlatform: TargetPlatform.android,
              permissionStatusReader: (_) async =>
                  const CameraMediaPermissionState(
                    cameraGranted: false,
                    microphoneGranted: false,
                  ),
              captureLauncher: (_, options) async {
                cameraLaunchCalls += 1;
                cameraOptions = options;
                return null;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .widget<InkWell>(
            find.ancestor(
              of: find.text('添加图片'),
              matching: find.byType(InkWell),
            ),
          )
          .onTap!();
      await tester.pumpAndSettle();
      await tester.tap(find.text('拍照'));
      await tester.pumpAndSettle();

      expect(find.text('需要相机权限'), findsOneWidget);
      expect(cameraLaunchCalls, 0);
      await tester.tap(
        find.byKey(const ValueKey('camera-media-permission-confirm')),
      );
      await tester.pumpAndSettle();
      expect(cameraLaunchCalls, 1);
      expect(cameraOptions?.allowPhoto, isTrue);
      expect(cameraOptions?.allowVideo, isFalse);
      expect(cameraOptions?.needsMicrophonePermission, isFalse);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS 健康评估拍照不显示自绘权限弹窗', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final picker = _RecordingHealthImagePicker();
      var cameraLaunchCalls = 0;
      CameraMediaPickerOptions? cameraOptions;
      await tester.pumpWidget(
        MaterialApp(
          home: HealthAssessmentPage(
            gateway: _HealthGateway(),
            pet: _pet(8, '团子'),
            galleryMediaPicker: GalleryMediaPicker(
              gateway: ImagePickerGalleryMediaGateway(picker),
            ),
            cameraMediaPicker: CameraMediaPicker(
              targetPlatform: TargetPlatform.iOS,
              permissionStatusReader: (_) async =>
                  throw StateError('iOS 不应预读相机权限'),
              captureLauncher: (_, options) async {
                cameraLaunchCalls += 1;
                cameraOptions = options;
                return null;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .widget<InkWell>(
            find.ancestor(
              of: find.text('添加图片'),
              matching: find.byType(InkWell),
            ),
          )
          .onTap!();
      await tester.pumpAndSettle();
      await tester.tap(find.text('拍照'));
      await tester.pumpAndSettle();

      expect(find.text('需要相机权限'), findsNothing);
      expect(cameraLaunchCalls, 1);
      expect(cameraOptions?.allowVideo, isFalse);
      expect(cameraOptions?.needsMicrophonePermission, isFalse);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('AI 问诊报告详情按 RN 层级展示并支持诊断切换', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final report = AiDiagnosisReport(
      id: 91,
      petId: 8,
      status: AiDiagnosisStatus.completed,
      symptoms: '精神不振，食欲下降',
      diagnosisImages: const [],
      basicInfo: const {
        'bodyTemperature': '正常',
        'heartRate': '正常',
        'breathe': '正常',
      },
      westernDiagnosis: const [
        WesternDiagnosisItem(
          symptom: '肠胃不适',
          reason: '结合持续食欲下降、精神不振和排便变化等表现综合判断，需要继续观察进食和饮水情况。',
          probability: '0.8',
        ),
        WesternDiagnosisItem(
          symptom: '轻度脱水',
          reason: '近期摄入量下降，需要留意皮肤弹性和排尿次数。',
          probability: '65%',
        ),
      ],
      medications: const [
        MedicationAdvice(
          symptom: '轻度脱水',
          drugName: '宠物电解质补充液',
          dosage: '按体重少量多次补充',
          frequency: '每日 2-3 次',
        ),
        MedicationAdvice(
          symptom: '肠胃不适',
          drugName: '宠物益生菌',
          dosage: '每次一袋',
          frequency: '每日一次',
        ),
      ],
      tcmDiagnosis: const [
        TcmDiagnosisItem(
          name: '脾胃虚弱',
          description: '脾胃运化偏弱，表现为食欲下降、精神欠佳，需要结合后续症状变化持续判断。',
          probability: '0.8',
          therapy: '健脾和胃',
          base: '清淡饮食',
          prescription: '四君子汤加减',
          usage: '具体剂量和疗程请由执业兽医面诊后确定',
        ),
      ],
      selfCheckSnapshot: const [
        AiSelfCheckSectionResult(
          name: '消化系统自查',
          questions: [
            AiSelfCheckQuestionResult(
              text: '是否呕吐？',
              options: [
                AiSelfCheckOptionResult(
                  text: '是',
                  imageUrl: '/images/symptom1.jpg',
                ),
              ],
            ),
          ],
        ),
      ],
      petSnapshot: const {
        'name': '团子',
        'subCategoryName': '英短',
        'gender': 1,
        'birthDate': '2024-01-01',
        'weight': 5.5,
      },
      createdAt: DateTime(2026, 7, 25, 9, 30),
    );
    final gateway = _HealthGateway(aiDiagnosisReport: report);

    // 医生端（默认视图）保留自查表结果，供医生核对问诊填写内容。
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiDiagnosisReportContent(
            report: report,
            config: AiDiagnosisConfig.fallback,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('自查表结果'), findsOneWidget);
    expect(find.text('消化系统自查'), findsOneWidget);
    expect(find.text('是否呕吐？'), findsOneWidget);
    expect(find.text('是'), findsOneWidget);
    expect(
      tester
          .widget<Image>(
            find.byKey(const ValueKey('ai-self-check-image-0-0-0')),
          )
          .fit,
      BoxFit.contain,
    );
    final selfCheckImage = tester.widget<Image>(
      find.byKey(const ValueKey('ai-self-check-image-0-0-0')),
    );
    expect(
      (selfCheckImage.image as NetworkImage).url,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/images/symptom1.jpg',
    );

    // 用户端详情页不展示自查表结果，但报告其余层级保持不变。
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: AiDiagnosisReportPage(gateway: gateway, reportId: report.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI问诊报告详情'), findsOneWidget);
    expect(find.text('报告信息'), findsOneWidget);
    expect(find.text('报告描述'), findsOneWidget);
    expect(find.text('自查表结果'), findsNothing);
    expect(find.text('消化系统自查'), findsNothing);
    expect(find.text('是否呕吐？'), findsNothing);
    expect(find.text('风险提示'), findsOneWidget);
    expect(find.text('西医诊断'), findsOneWidget);
    expect(find.text('用户悉知'), findsOneWidget);
    expect(find.text('肠胃不适'), findsOneWidget);
    expect(find.text('西医诊断方案'), findsNothing);
    expect(find.text('诊断依据'), findsNWidgets(2));
    expect(find.text('用药建议'), findsNWidgets(2));
    expect(find.text('概率很高'), findsOneWidget);
    expect(find.text('概率较高'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    final westernProgress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('western-probability-1')),
    );
    expect(westernProgress.value, 0.8);
    expect(westernProgress.backgroundColor, const Color(0xFFE5E7EB));

    final gastrointestinalCard = find.byKey(
      const ValueKey('western-diagnosis-card-0'),
    );
    final dehydrationCard = find.byKey(
      const ValueKey('western-diagnosis-card-1'),
    );
    expect(
      find.descendant(of: gastrointestinalCard, matching: find.text('宠物益生菌')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: gastrointestinalCard,
        matching: find.text('宠物电解质补充液'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: dehydrationCard, matching: find.text('宠物电解质补充液')),
      findsOneWidget,
    );

    final tcmTab = find.text('中医诊断');
    await tester.drag(find.byType(ListView).last, const Offset(0, -520));
    await tester.pumpAndSettle();
    await tester.tap(tcmTab);
    await tester.pumpAndSettle();

    expect(find.text('脾胃虚弱'), findsOneWidget);
    expect(find.text('中医辨证方案'), findsNothing);
    expect(find.text('证候描述'), findsOneWidget);
    expect(find.text('治疗原则'), findsOneWidget);
    expect(find.text('基础建议'), findsOneWidget);
    expect(find.text('方药'), findsOneWidget);
    expect(find.text('概率很高'), findsOneWidget);
    final tcmProgress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('tcm-probability-1')),
    );
    expect(tcmProgress.value, 0.8);
    final tcmCard = find.byKey(const ValueKey('tcm-diagnosis-card-0'));
    expect(
      find.descendant(of: tcmCard, matching: find.text('四君子汤加减')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tcmCard, matching: find.text('具体剂量和疗程请由执业兽医面诊后确定')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _HealthGateway implements HealthGateway {
  _HealthGateway({
    this.appointments = const [],
    this.appointmentDetail,
    this.carePlanState,
    this.aiDiagnosisReport,
  });

  final pet = _pet(8, '团子');
  final List<HealthAppointment> appointments;
  final HealthAppointment? appointmentDetail;
  final PetCarePlanState? carePlanState;
  final AiDiagnosisReport? aiDiagnosisReport;
  HealthAppointmentType? lastAppointmentType;
  int loadAppointmentCalls = 0;
  int loadCarePlanCalls = 0;

  @override
  Future<List<Pet>> loadHealthPets() async => [pet];

  @override
  Future<PetHealthStats> loadPetHealthStats(int petId) async {
    return const PetHealthStats(
      vaccine: HealthMetric(count: 3, daysUntilNext: 7),
      deworming: HealthMetric(count: 5, daysUntilNext: 2),
      checkup: HealthMetric(count: 1, daysUntilNext: 30),
    );
  }

  @override
  Future<AppointmentPage> loadAppointments({
    required int petId,
    int page = 1,
    int pageSize = 20,
    HealthAppointmentType? type,
    HealthAppointmentStatus? status,
  }) async {
    lastAppointmentType = type;
    return AppointmentPage(
      items: appointments,
      page: 1,
      totalPages: 1,
      total: appointments.length,
    );
  }

  @override
  Future<List<HealthHospital>> loadHealthHospitals() async => const [
    HealthHospital(id: 1, name: '宠物医院'),
  ];

  @override
  Future<HealthAppointment> loadAppointment(int appointmentId) async {
    loadAppointmentCalls += 1;
    final detail = appointmentDetail;
    if (detail == null) throw StateError('No appointment detail configured.');
    return detail;
  }

  @override
  Future<PetCarePlanState> loadCarePlan(int petId) async {
    loadCarePlanCalls += 1;
    final state = carePlanState;
    if (state == null) throw StateError('No care plan configured.');
    return state;
  }

  @override
  Future<AiDiagnosisPage> loadAiDiagnosisReports({
    int? petId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return AiDiagnosisPage(
      items: [
        AiDiagnosisReport(
          id: 91,
          petId: 8,
          status: AiDiagnosisStatus.completed,
          symptoms: '精神不振，食欲下降',
          diagnosisImages: const [],
          basicInfo: const {},
          westernDiagnosis: const [],
          medications: const [],
          tcmDiagnosis: const [],
          petSnapshot: const {'name': '团子'},
          createdAt: DateTime(2026, 7, 25, 9, 30),
        ),
      ],
      page: 1,
      totalPages: 1,
      total: 1,
    );
  }

  @override
  Future<List<SelfCheckList>> loadSelfCheckLists(int petId) async => const [
    SelfCheckList(
      id: 1,
      name: '常见症状',
      type: 'PUBLIC',
      questions: [
        SelfCheckQuestion(
          id: 11,
          text: '行动',
          type: SelfCheckQuestionType.single,
          required: false,
          sortOrder: 1,
          options: [
            SelfCheckOption(id: 111, text: '正常'),
            SelfCheckOption(id: 112, text: '跛行', imageUrl: '/images/limp.jpg'),
          ],
        ),
      ],
    ),
  ];

  @override
  Future<AiDiagnosisConfig> loadAiDiagnosisConfig() async =>
      AiDiagnosisConfig.fallback;

  @override
  Future<AiDiagnosisReport> loadAiDiagnosisReport(int reportId) async {
    final report = aiDiagnosisReport;
    if (report == null) throw StateError('No AI diagnosis report configured.');
    return report;
  }

  @override
  Future<List<HealthArticleCategory>> loadHealthArticleCategories() async =>
      const [HealthArticleCategory(id: 1, name: '日常护理')];

  @override
  Future<HealthArticlePage> loadHealthArticles({
    int? categoryId,
    int page = 1,
    int pageSize = 20,
  }) async =>
      const HealthArticlePage(items: [], page: 1, totalPages: 1, total: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Pet _pet(int id, String name) => Pet(
  id: id,
  name: name,
  avatarUrl: '',
  categoryId: 1,
  subCategoryId: 2,
  gender: PetGender.male,
  birthDate: DateTime(2024, 1, 1),
  weight: 5.5,
  isNeutered: true,
  vaccineCount: 3,
  category: const PetCategory(id: 1, name: '猫', parentId: null, sortOrder: 1),
  subCategory: const PetCategory(id: 2, name: '英短', parentId: 1, sortOrder: 1),
  ownerId: 5,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 7, 1),
);

class _RecordingHealthImagePicker extends ImagePicker {
  ImageSource? lastSource;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    lastSource = source;
    return null;
  }
}
