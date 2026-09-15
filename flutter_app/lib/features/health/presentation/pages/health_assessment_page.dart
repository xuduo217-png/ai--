import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pickers/pickers.dart';
import 'package:flutter_pickers/style/default_style.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/media/camera_media_picker.dart';
import '../../../../core/media/gallery_media_picker.dart';
import '../../../../core/network/asset_url_resolver.dart';
import '../../../../core/widgets/fullscreen_network_image_preview.dart';
import '../../../pets/domain/pet_models.dart';
import '../../domain/health_models.dart';
import 'health_page.dart';

enum _HealthImageSource { gallery, camera }

class HealthAssessmentPage extends StatefulWidget {
  const HealthAssessmentPage({
    super.key,
    required this.gateway,
    required this.pet,
    this.galleryMediaPicker,
    this.cameraMediaPicker,
  });

  final HealthGateway gateway;
  final Pet pet;
  final GalleryMediaPicker? galleryMediaPicker;
  final CameraMediaPicker? cameraMediaPicker;

  @override
  State<HealthAssessmentPage> createState() => _HealthAssessmentPageState();
}

class _HealthAssessmentPageState extends State<HealthAssessmentPage> {
  late final GalleryMediaPicker _galleryMediaPicker;
  late final CameraMediaPicker _cameraMediaPicker;
  late final TextEditingController _symptomsController;
  List<SelfCheckList> _selfCheckLists = const [];
  AiDiagnosisConfig _config = AiDiagnosisConfig.fallback;
  final Map<int, Set<int>> _selectedOptions = {};
  final Map<int, String> _textAnswers = {};
  List<XFile> _images = const [];
  String? _bodyTemperature;
  String? _heartRate;
  String? _breathe;
  bool _loading = true;
  bool _submitting = false;
  bool _saving = false;
  String? _error;
  /// 详细描述为必填项，提交校验失败后在输入框上就地提示。
  bool _symptomsError = false;

  String get _draftKey => 'health_assessment_draft_${widget.pet.id}';

  @override
  void initState() {
    super.initState();
    _galleryMediaPicker = widget.galleryMediaPicker ?? GalleryMediaPicker();
    _cameraMediaPicker = widget.cameraMediaPicker ?? CameraMediaPicker();
    _symptomsController = TextEditingController();
    _symptomsController.addListener(_clearSymptomsError);
    _initialize();
  }

  void _clearSymptomsError() {
    if (!_symptomsError) return;
    if (_symptomsController.text.trim().isEmpty) return;
    setState(() => _symptomsError = false);
  }

  @override
  void dispose() {
    _symptomsController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait<Object>([
        widget.gateway.loadSelfCheckLists(widget.pet.id),
        widget.gateway.loadAiDiagnosisConfig(),
      ]);
      await _restoreDraft();
      if (!mounted) return;
      setState(() {
        _selfCheckLists = result[0] as List<SelfCheckList>;
        _config = result[1] as AiDiagnosisConfig;
      });
    } on Object {
      if (mounted) setState(() => _error = '健康评估配置加载失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDEE9FF), healthBackground],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          foregroundColor: const Color(0xFF1F2937),
          title: const Text(
            'AI问诊',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: _loading ? const _AssessmentLoadingState() : _buildBody(),
        bottomNavigationBar: _loading
            ? null
            : _AssessmentBottomBar(
                saving: _saving,
                submitting: _submitting,
                onSave: _saveDraft,
                onSubmit: _startDiagnosis,
              ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _selfCheckLists.isEmpty) {
      return Center(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  color: healthPrimary,
                  size: 40,
                ),
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: healthPrimary),
                  onPressed: _initialize,
                  child: const Text('重新加载'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _AssessmentPetPanel(pet: widget.pet),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 12, 8, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        color: healthPrimary,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '症状描述',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      _AssessmentChecklistCard(
                        selectedCount: _selectionCount,
                        selectedDescriptions: _selectedDescriptions,
                        enabled: _selfCheckLists.isNotEmpty,
                        onPressed: _openChecklist,
                      ),
                      const SizedBox(height: 10),
                      _AssessmentDescriptionInput(
                        controller: _symptomsController,
                        errorText: _symptomsError ? '请填写详细症状描述' : null,
                      ),
                      const SizedBox(height: 10),
                      _AssessmentBasicInfo(
                        bodyTemperature: _bodyTemperature,
                        heartRate: _heartRate,
                        breathe: _breathe,
                        config: _config,
                        onBodyTemperatureChanged: (value) =>
                            setState(() => _bodyTemperature = value),
                        onHeartRateChanged: (value) =>
                            setState(() => _heartRate = value),
                        onBreatheChanged: (value) =>
                            setState(() => _breathe = value),
                      ),
                      const SizedBox(height: 10),
                      _AssessmentImages(
                        images: _images,
                        onAdd: _pickImages,
                        onRemove: (index) => setState(() {
                          _images = [
                            for (var i = 0; i < _images.length; i++)
                              if (i != index) _images[i],
                          ];
                        }),
                      ),
                      const SizedBox(height: 10),
                      const _AssessmentTipCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  int get _selectionCount {
    final selected = _selectedOptions.values.fold<int>(
      0,
      (count, values) => count + values.length,
    );
    return selected +
        _textAnswers.values.where((value) => value.trim().isNotEmpty).length;
  }

  List<String> get _selectedDescriptions {
    final descriptions = <String>[];
    for (final list in _selfCheckLists) {
      for (final question in list.questions) {
        final answer = _textAnswers[question.id]?.trim() ?? '';
        if (answer.isNotEmpty) {
          descriptions.add('${list.name}：$answer');
        }

        final selected = _selectedOptions[question.id] ?? const <int>{};
        if (question.options.isEmpty && selected.contains(question.id)) {
          descriptions.add('${list.name}：${question.text}');
          continue;
        }
        for (final option in question.options) {
          if (selected.contains(option.id)) {
            descriptions.add('${list.name}：${option.text}');
          }
        }
      }
    }
    return descriptions;
  }

  int _selectionCountForList(SelfCheckList list) {
    var count = 0;
    for (final question in list.questions) {
      count += (_selectedOptions[question.id] ?? const <int>{}).length;
      if ((_textAnswers[question.id]?.trim() ?? '').isNotEmpty) count++;
    }
    return count;
  }

  Future<void> _openChecklist() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.55,
          maxChildSize: 0.96,
          builder: (context, scrollController) => Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _ChecklistPetAvatar(pet: widget.pet),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      '症状自查表',
                                      style: TextStyle(
                                        color: Color(0xFF1F2937),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '($_selectionCount)',
                                      style: const TextStyle(
                                        color: Color(0xFF6278E8),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  '注意事项：无异常不用勾选',
                                  style: TextStyle(
                                    color: Color(0xFFE67E22),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.pop(context),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF7B94FA),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: const Text('完成'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _selectionCount == 0
                                  ? null
                                  : () {
                                      _selectedOptions.clear();
                                      _textAnswers.clear();
                                      Navigator.pop(context);
                                    },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6278E8),
                                minimumSize: const Size.fromHeight(42),
                                side: const BorderSide(
                                  color: Color(0xFF7B94FA),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: const Text('清空'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      for (final list in _selfCheckLists)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ChecklistSectionHeader(
                                list: list,
                                selectedCount: _selectionCountForList(list),
                              ),
                              for (final question in list.questions)
                                _ChecklistQuestion(
                                  question: question,
                                  selected:
                                      _selectedOptions[question.id] ?? const {},
                                  textAnswer: _textAnswers[question.id] ?? '',
                                  onOptionChanged: (optionId, selected) {
                                    setSheetState(() {
                                      final values = _selectedOptions
                                          .putIfAbsent(
                                            question.id,
                                            () => <int>{},
                                          );
                                      if (question.type ==
                                          SelfCheckQuestionType.single) {
                                        values.clear();
                                      }
                                      if (selected) {
                                        values.add(optionId);
                                      } else {
                                        values.remove(optionId);
                                      }
                                    });
                                  },
                                  onTextChanged: (value) {
                                    setSheetState(() {
                                      _textAnswers[question.id] = value;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _pickImages() async {
    if (_images.length >= 9) return;
    final source = await showModalBottomSheet<_HealthImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, _HealthImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, _HealthImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final remaining = 9 - _images.length;
      final List<XFile> selected;
      if (source == _HealthImageSource.camera) {
        final captured = await _cameraMediaPicker.capture(
          context: context,
          allowPhoto: true,
          allowVideo: false,
          enableAudio: false,
          permissionDescription: '拍照需要使用相机，用于上传宠物症状图片并辅助健康评估。',
          imageQuality: 85,
        );
        selected = [captured?.file].nonNulls.toList();
      } else {
        selected = await _galleryMediaPicker.pick(
          context: context,
          mediaType: GalleryMediaType.image,
          allowMultiple: true,
          maxCount: remaining,
          imageQuality: 85,
        );
      }
      if (!mounted || selected.isEmpty) return;
      setState(() {
        _images = [..._images, ...selected.take(remaining)];
      });
    } on Object {
      if (mounted) _showMessage('图片选择失败，请稍后重试');
    }
  }

  String? _validate() {
    // 按页面从上到下的顺序校验，先报最靠上的必填项。
    if (_symptomsController.text.trim().isEmpty) return '请填写详细症状描述';
    if ((_bodyTemperature ?? '').isEmpty) return '请选择宠物体温';
    if ((_heartRate ?? '').isEmpty) return '请选择宠物心率';
    if ((_breathe ?? '').isEmpty) return '请选择宠物呼吸情况';
    return null;
  }

  Future<void> _startDiagnosis() async {
    final validation = _validate();
    if (validation != null) {
      setState(() => _symptomsError = _symptomsController.text.trim().isEmpty);
      _showMessage(validation);
      return;
    }
    setState(() => _symptomsError = false);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AssessmentDisclaimerSheet(config: _config),
    );
    if (confirmed != true || !mounted) return;
    await _submit();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final imageUrls = <String>[];
      for (final image in _images) {
        imageUrls.add(await widget.gateway.uploadDiagnosisImage(image.path));
      }
      await widget.gateway.createAiDiagnosisReport(
        AiDiagnosisDraft(
          petId: widget.pet.id,
          symptoms: _symptomsController.text,
          selfCheckSnapshot: buildSelfCheckSnapshot(
            lists: _selfCheckLists,
            selectedOptions: _selectedOptions,
            textAnswers: _textAnswers,
          ),
          diagnosisImages: imageUrls,
          bodyTemperature: _bodyTemperature!,
          heartRate: _heartRate!,
          breathe: _breathe!,
        ),
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_draftKey);
      if (!mounted) return;
      _showMessage('提交成功，请稍后查看报告');
      Navigator.pop(context, true);
    } on Object {
      if (mounted) _showMessage('AI 问诊提交失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _draftKey,
        jsonEncode({
          'bodyTemperature': _bodyTemperature,
          'heartRate': _heartRate,
          'breathe': _breathe,
          'symptoms': _symptomsController.text,
          'selectedOptions': {
            for (final entry in _selectedOptions.entries)
              '${entry.key}': entry.value.toList(),
          },
          'textAnswers': {
            for (final entry in _textAnswers.entries)
              '${entry.key}': entry.value,
          },
          'images': _images.map((image) => image.path).toList(),
        }),
      );
      if (mounted) _showMessage('草稿已保存');
    } on Object {
      if (mounted) _showMessage('草稿保存失败');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_draftKey);
      if (raw == null || raw.isEmpty) return;
      final json = Map<String, Object?>.from(jsonDecode(raw) as Map);
      _bodyTemperature = healthString(json['bodyTemperature']);
      _heartRate = healthString(json['heartRate']);
      _breathe = healthString(json['breathe']);
      _symptomsController.text = healthString(json['symptoms']);
      final rawSelected = healthJsonMapOrEmpty(json['selectedOptions']);
      for (final entry in rawSelected.entries) {
        final id = int.tryParse(entry.key);
        if (id == null) continue;
        _selectedOptions[id] = healthJsonList(
          entry.value,
        ).map(healthNullableInt).whereType<int>().toSet();
      }
      final rawAnswers = healthJsonMapOrEmpty(json['textAnswers']);
      for (final entry in rawAnswers.entries) {
        final id = int.tryParse(entry.key);
        if (id != null) _textAnswers[id] = healthString(entry.value);
      }
      _images = healthStringList(json['images'])
          .where((path) => File(path).existsSync())
          .map(XFile.new)
          .take(9)
          .toList(growable: false);
    } on Object {
      // 损坏或过期的本地草稿不阻断健康评估。
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AssessmentDisclaimerSheet extends StatelessWidget {
  const _AssessmentDisclaimerSheet({required this.config});

  final AiDiagnosisConfig config;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFEEF2FF),
                  child: Text(
                    '!',
                    style: TextStyle(
                      color: Color(0xFF6278E8),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    config.disclaimerTitle,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.4,
              ),
              child: SingleChildScrollView(
                child: Text(
                  config.disclaimerContent,
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: healthPrimary,
                        side: const BorderSide(color: healthPrimary),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(config.disclaimerCancelText),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: healthPrimary,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        config.disclaimerConfirmText,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssessmentLoadingState extends StatelessWidget {
  const _AssessmentLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: const SizedBox(
          width: 240,
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: healthPrimary),
                SizedBox(height: 10),
                Text(
                  '加载中...',
                  style: TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '正在准备健康评估',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssessmentBottomBar extends StatelessWidget {
  const _AssessmentBottomBar({
    required this.saving,
    required this.submitting,
    required this.onSave,
    required this.onSubmit,
  });

  final bool saving;
  final bool submitting;
  final VoidCallback onSave;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final disabled = saving || submitting;
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 45,
                  child: OutlinedButton(
                    onPressed: disabled ? null : onSave,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: healthPrimary,
                      side: const BorderSide(color: healthPrimary),
                      shape: const StadiumBorder(),
                    ),
                    child: saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: healthPrimary,
                            ),
                          )
                        : const Text(
                            '保存草稿',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 45,
                  child: FilledButton(
                    key: const ValueKey('health-assessment-submit'),
                    onPressed: disabled ? null : onSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: healthPrimary,
                      disabledBackgroundColor: const Color(0xFFBDBDBD),
                      shape: const StadiumBorder(),
                    ),
                    child: submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '开始诊断',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssessmentChecklistCard extends StatelessWidget {
  const _AssessmentChecklistCard({
    required this.selectedCount,
    required this.selectedDescriptions,
    required this.enabled,
    required this.onPressed,
  });

  final int selectedCount;
  final List<String> selectedDescriptions;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final selected = selectedCount > 0;
    return Material(
      color: selected ? const Color(0xFFF0F8FF) : const Color(0xFFEFF6FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: selected
            ? const BorderSide(color: healthPrimary, width: 0.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: selected
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: healthPrimary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '已选择 $selectedCount 项',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          '重新选择',
                          style: TextStyle(
                            color: Color(0xFF1232B1),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '已选择的症状：',
                      style: TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    for (final description in selectedDescriptions.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.only(top: 6, right: 7),
                              decoration: const BoxDecoration(
                                color: Color(0xFF6278E8),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                description,
                                style: const TextStyle(
                                  color: Color(0xFF4B5563),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (selectedDescriptions.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 1),
                        child: Text(
                          '... 还有 ${selectedDescriptions.length - 3} 项',
                          style: const TextStyle(
                            color: Color(0xFF6278E8),
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                )
              : Column(
                  children: [
                    const Text(
                      'AI诊断自查表勾选',
                      style: TextStyle(
                        color: Color(0xFF1232B1),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '提示：请仔细鉴别勾选表格提示内容，以便于提高诊断准确率。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF4E73DB),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '注意事项：无异常不用勾选',
                      style: TextStyle(color: Color(0xFFE67E22), fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: enabled
                            ? const Color(0xFF7B94FA)
                            : const Color(0xFFBDBDBD),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '开始填表',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AssessmentDescriptionInput extends StatelessWidget {
  const _AssessmentDescriptionInput({
    required this.controller,
    this.errorText,
  });

  final TextEditingController controller;

  /// 必填校验未通过时就地展示的错误文案。
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.edit_note_rounded,
              color: healthRequired,
              size: 18,
            ),
            const SizedBox(width: 6),
            const Text(
              '详细描述（必填）',
              style: TextStyle(
                color: healthRequired,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            const Text(
              '*',
              style: TextStyle(
                color: healthRequired,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => Text(
                '${value.text.length} / 500字',
                style: const TextStyle(color: Color(0xFF999999), fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('health-assessment-symptoms'),
          controller: controller,
          minLines: 5,
          maxLines: 5,
          maxLength: 500,
          decoration: InputDecoration(
            counterText: '',
            hintText:
                '请详细描述宠物的症状、持续时间、严重程度等信息...\n例如：小白从昨天开始食欲不振，今天早上还出现了呕吐...',
            hintStyle: const TextStyle(color: Color(0xFF999999), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            contentPadding: const EdgeInsets.all(10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: hasError
                  ? const BorderSide(color: healthRequired)
                  : BorderSide.none,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: healthRequired,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                errorText!,
                style: const TextStyle(color: healthRequired, fontSize: 12),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AssessmentBasicInfo extends StatelessWidget {
  const _AssessmentBasicInfo({
    required this.bodyTemperature,
    required this.heartRate,
    required this.breathe,
    required this.config,
    required this.onBodyTemperatureChanged,
    required this.onHeartRateChanged,
    required this.onBreatheChanged,
  });

  final String? bodyTemperature;
  final String? heartRate;
  final String? breathe;
  final AiDiagnosisConfig config;
  final ValueChanged<String?> onBodyTemperatureChanged;
  final ValueChanged<String?> onHeartRateChanged;
  final ValueChanged<String?> onBreatheChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: healthPrimary, size: 16),
            SizedBox(width: 5),
            Text(
              '基础信息',
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _OptionField(
          label: '体温:',
          value: bodyTemperature,
          options: config.bodyTemperatureOptions,
          onChanged: onBodyTemperatureChanged,
        ),
        const SizedBox(height: 10),
        _OptionField(
          label: '心率:',
          value: heartRate,
          options: config.heartRateOptions,
          onChanged: onHeartRateChanged,
        ),
        const SizedBox(height: 10),
        _OptionField(
          label: '呼吸:',
          value: breathe,
          options: config.breatheOptions,
          onChanged: onBreatheChanged,
        ),
      ],
    );
  }
}

class _AssessmentImages extends StatelessWidget {
  const _AssessmentImages({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  final List<XFile> images;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '上传图片（选填）',
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 66,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length + (images.length < 9 ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              if (index == images.length) {
                return InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 66,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_rounded,
                          color: Color(0xFFBDBDBD),
                          size: 24,
                        ),
                        SizedBox(height: 3),
                        Text(
                          '添加图片',
                          style: TextStyle(
                            color: Color(0xFFBDBDBD),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SizedBox(
                width: 66,
                child: _ImagePreview(
                  file: File(images[index].path),
                  onRemove: () => onRemove(index),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '最多上传9张图片，建议上传清晰的患处照片',
          style: TextStyle(color: Color(0xFF999999), fontSize: 11),
        ),
      ],
    );
  }
}

class _AssessmentTipCard extends StatelessWidget {
  const _AssessmentTipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: healthPrimary,
              size: 13,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI诊断提示',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '为了获得更准确的诊断结果，建议您：\n1. 详细描述症状发生的时间和具体表现\n2. 上传清晰的患处照片\n3. 准确填写体温等基础信息',
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentPetPanel extends StatelessWidget {
  const _AssessmentPetPanel({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final url = pet.resolvedAvatarUrl();
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox.square(
                dimension: 40,
                child: url.isEmpty
                    ? Image.asset(
                        'assets/images/health/pet_avatar.png',
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Image.asset(
                          'assets/images/health/pet_avatar.png',
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${pet.breedLabel} · ${pet.genderLabel} · ${formatPetAge(pet.birthDate)}',
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.monitor_weight_outlined,
                        color: healthPrimary,
                        size: 13,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${pet.weight}kg',
                        style: const TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionField extends StatelessWidget {
  const _OptionField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final placeholder = '请选择${label.replaceAll(':', '')}';
    return Material(
      key: ValueKey('assessment-option-$label'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: options.isEmpty ? null : () => _showPicker(context),
        child: InputDecorator(
          isEmpty: value == null || value!.isEmpty,
          decoration: InputDecoration(
            prefixIcon: Icon(
              label.startsWith('体温')
                  ? Icons.thermostat_rounded
                  : label.startsWith('心率')
                  ? Icons.favorite_outline_rounded
                  : Icons.air_rounded,
              color: healthPrimary,
              size: 18,
            ),
            labelText: label,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            labelStyle: const TextStyle(color: Color(0xFF757575), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF7F8FA),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value?.isNotEmpty == true ? value! : placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: value?.isNotEmpty == true
                        ? Colors.black
                        : const Color(0xFF999999),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9E9E9E)),
            ],
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    final title = '选择${label.replaceAll(':', '')}';
    final style = DefaultPickerStyle(haveRadius: true, title: title)
      ..pickerHeight = 240
      ..pickerTitleHeight = 48
      ..pickerItemHeight = 44
      ..textSize = 14
      ..textColor = const Color(0xFF22252B);

    Pickers.showSinglePicker(
      context,
      data: options,
      selectData: value,
      pickerStyle: style,
      onConfirm: (_, index) => onChanged(options[index]),
    );
  }
}

class _ChecklistPetAvatar extends StatelessWidget {
  const _ChecklistPetAvatar({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final url = pet.resolvedAvatarUrl();
    return ClipOval(
      child: SizedBox.square(
        dimension: 40,
        child: url.isEmpty
            ? Image.asset(
                'assets/images/health/pet_avatar.png',
                fit: BoxFit.cover,
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Image.asset(
                  'assets/images/health/pet_avatar.png',
                  fit: BoxFit.cover,
                ),
              ),
      ),
    );
  }
}

class _ChecklistSectionHeader extends StatelessWidget {
  const _ChecklistSectionHeader({
    required this.list,
    required this.selectedCount,
  });

  final SelfCheckList list;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE0E8FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 20,
            margin: const EdgeInsets.only(top: 1, right: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF6278E8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  list.name,
                  style: const TextStyle(
                    color: Color(0xFF1232B1),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (list.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    list.description,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (selectedCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE8EEFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '已选 $selectedCount',
                style: const TextStyle(
                  color: Color(0xFF4E64D2),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChecklistQuestion extends StatelessWidget {
  const _ChecklistQuestion({
    required this.question,
    required this.selected,
    required this.textAnswer,
    required this.onOptionChanged,
    required this.onTextChanged,
  });

  final SelfCheckQuestion question;
  final Set<int> selected;
  final String textAnswer;
  final void Function(int optionId, bool selected) onOptionChanged;
  final ValueChanged<String> onTextChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${question.text}${question.required ? ' *' : ''}',
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (question.type == SelfCheckQuestionType.text)
                TextFormField(
                  initialValue: textAnswer,
                  maxLines: 3,
                  onChanged: onTextChanged,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '请输入',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF7B94FA)),
                    ),
                  ),
                )
              else if (question.options.isEmpty)
                _ChecklistOptionRow(
                  questionId: question.id,
                  optionId: question.id,
                  label: '符合',
                  selected: selected.contains(question.id),
                  onSelected: (value) => onOptionChanged(question.id, value),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final option in question.options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: option.imageUrl.trim().isEmpty
                            ? _ChecklistOptionRow(
                                questionId: question.id,
                                optionId: option.id,
                                label: option.text,
                                selected: selected.contains(option.id),
                                onSelected: (value) =>
                                    onOptionChanged(option.id, value),
                              )
                            : _ChecklistImageOption(
                                questionId: question.id,
                                option: option,
                                selected: selected.contains(option.id),
                                onSelected: (value) =>
                                    onOptionChanged(option.id, value),
                              ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistOptionRow extends StatelessWidget {
  const _ChecklistOptionRow({
    required this.questionId,
    required this.optionId,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final int questionId;
  final int optionId;
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFF9FAFB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: selected ? const Color(0xFF7B94FA) : const Color(0xFFE5E7EB),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('assessment-check-option-$questionId-$optionId'),
        onTap: () => onSelected(!selected),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              _ChecklistSelectionBox(selected: selected),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF425CC7)
                        : const Color(0xFF4B5563),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistSelectionBox extends StatelessWidget {
  const _ChecklistSelectionBox({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF6278E8) : Colors.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: selected ? const Color(0xFF6278E8) : const Color(0xFFB8BEC9),
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}

class _ChecklistImageOption extends StatelessWidget {
  const _ChecklistImageOption({
    required this.questionId,
    required this.option,
    required this.selected,
    required this.onSelected,
  });

  final int questionId;
  final SelfCheckOption option;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveAssetUrl(option.imageUrl);
    return Material(
      color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFF9FAFB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: selected ? const Color(0xFF7B94FA) : const Color(0xFFE5E7EB),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('assessment-check-option-$questionId-${option.id}'),
        onTap: () => onSelected(!selected),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              _ChecklistSelectionBox(selected: selected),
              const SizedBox(width: 9),
              GestureDetector(
                onTap: imageUrl.isEmpty
                    ? null
                    : () => showFullscreenNetworkImagePreview(
                        context,
                        imageUrl: imageUrl,
                      ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox.square(
                    dimension: 64,
                    child: imageUrl.isEmpty
                        ? const _ChecklistImagePlaceholder()
                        : Image.network(
                            key: ValueKey(
                              'assessment-check-image-$questionId-${option.id}',
                            ),
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const _ChecklistImagePlaceholder(
                                  label: '图片加载失败',
                                ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  option.text,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF425CC7)
                        : const Color(0xFF4B5563),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistImagePlaceholder extends StatelessWidget {
  const _ChecklistImagePlaceholder({this.label = '暂无图片'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F3F6),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_outlined, size: 24, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.file, required this.onRemove});

  final File file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Color(0xFFF1F3F2),
              child: Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
        Positioned(
          top: 3,
          right: 3,
          child: IconButton.filled(
            tooltip: '移除图片',
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ],
    );
  }
}
