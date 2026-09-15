import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/asset_url_resolver.dart';
import '../../../../core/widgets/fullscreen_network_image_preview.dart';
import '../../../pets/domain/pet_models.dart';
import '../../domain/health_models.dart';
import '../health_controller.dart';
import '../widgets/diagnosis_assessment_panel.dart';
import 'health_assessment_page.dart';
import 'health_page.dart';

class AiDiagnosisListPage extends StatefulWidget {
  const AiDiagnosisListPage({
    super.key,
    required this.gateway,
    this.onOpenPets,
  });

  final HealthGateway gateway;
  final Future<void> Function()? onOpenPets;

  @override
  State<AiDiagnosisListPage> createState() => _AiDiagnosisListPageState();
}

class _AiDiagnosisListPageState extends State<AiDiagnosisListPage> {
  late final AiDiagnosisListController _controller;
  AiDiagnosisConfig _config = AiDiagnosisConfig.fallback;
  bool _disclaimerExpanded = true;

  @override
  void initState() {
    super.initState();
    _controller = AiDiagnosisListController(gateway: widget.gateway);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await Future.wait<void>([_controller.initialize(), _loadConfig()]);
  }

  Future<void> _loadConfig() async {
    try {
      final config = await widget.gateway.loadAiDiagnosisConfig();
      if (mounted) setState(() => _config = config);
    } on Object {
      // 配置失败时沿用本地兜底文案，不阻断问诊记录加载。
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AiGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _aiAppBar('AI 问诊记录'),
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (_controller.loading && _controller.pets.isEmpty) {
              return const _AiLoadingState(description: '正在获取您的宠物信息');
            }
            if (_controller.error != null && _controller.pets.isEmpty) {
              return _AiState(
                icon: Icons.cloud_off_outlined,
                title: '加载失败',
                description: _controller.error!,
                actionLabel: '重新加载',
                onAction: _initialize,
              );
            }
            if (_controller.pets.isEmpty) {
              return _AiState(
                icon: Icons.pets_rounded,
                title: '暂无宠物',
                description: '添加您的第一只宠物，开始 AI 问诊之旅',
                actionLabel: widget.onOpenPets == null ? null : '添加宠物',
                onAction: widget.onOpenPets == null ? null : _managePets,
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: _AiDisclaimerCard(
                    title: _config.disclaimerTitle,
                    content: _config.disclaimerContent,
                    expanded: _disclaimerExpanded,
                    onToggle: () => setState(
                      () => _disclaimerExpanded = !_disclaimerExpanded,
                    ),
                  ),
                ),
                _PetSelectorStrip(
                  pets: _controller.pets,
                  selectedPetId: _controller.selectedPetId,
                  onSelected: _controller.selectPet,
                ),
                Expanded(child: _buildReports()),
              ],
            );
          },
        ),
        bottomNavigationBar: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _controller.pets.isEmpty
              ? const SizedBox.shrink()
              : _AiBottomBar(
                  buttonKey: const ValueKey('ai-diagnosis-new'),
                  label: '开始 AI 问诊',
                  onPressed: _openAssessment,
                ),
        ),
      ),
    );
  }

  Widget _buildReports() {
    if (_controller.loading) {
      return const Center(
        child: CircularProgressIndicator(color: healthPrimary),
      );
    }
    if (_controller.error != null) {
      return _AiState(
        icon: Icons.cloud_off_outlined,
        title: _controller.error!,
        actionLabel: '重试',
        onAction: () => _controller.selectPet(_controller.selectedPetId),
      );
    }
    if (_controller.reports.isEmpty) {
      return const _AiReportsEmptyState();
    }
    return RefreshIndicator(
      onRefresh: () => _controller.selectPet(_controller.selectedPetId),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
        itemCount: _controller.reports.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final report = _controller.reports[index];
          final pet = _controller.petFor(report.petId);
          return _ReportTile(
            report: report,
            pet: pet,
            onTap: () => _openReport(report),
          );
        },
      ),
    );
  }

  Future<void> _openAssessment() async {
    if (_controller.pets.isEmpty) {
      if (widget.onOpenPets != null) await _managePets();
      return;
    }
    final pet =
        _controller.petFor(_controller.selectedPetId ?? -1) ??
        _controller.pets.first;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => HealthAssessmentPage(gateway: widget.gateway, pet: pet),
      ),
    );
    if (created == true && mounted) await _controller.selectPet(pet.id);
  }

  void _openReport(AiDiagnosisReport report) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AiDiagnosisReportPage(
          gateway: widget.gateway,
          reportId: report.id,
          initialReport: report,
        ),
      ),
    );
  }

  Future<void> _managePets() async {
    await widget.onOpenPets?.call();
    if (mounted) await _controller.initialize();
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.report,
    required this.pet,
    required this.onTap,
  });

  final AiDiagnosisReport report;
  final Pet? pet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (report.status) {
      AiDiagnosisStatus.pending => const Color(0xFFF59E0B),
      AiDiagnosisStatus.processing => healthPrimary,
      AiDiagnosisStatus.completed => const Color(0xFF10B981),
      AiDiagnosisStatus.failed => const Color(0xFFEF4444),
      AiDiagnosisStatus.timeout => const Color(0xFF6B7280),
    };
    final statusText = switch (report.status) {
      AiDiagnosisStatus.pending => '待生成',
      AiDiagnosisStatus.processing => '生成中',
      AiDiagnosisStatus.completed => '已完成',
      AiDiagnosisStatus.failed => '生成失败',
      AiDiagnosisStatus.timeout => '已超时',
    };
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 2, child: ColoredBox(color: color)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.09),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _relativeDateLabel(report.createdAt),
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              '症状描述',
                              style: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              report.symptoms.isEmpty
                                  ? '暂无症状描述'
                                  : report.symptoms,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF1F2937),
                                fontSize: 13,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF9CA3AF),
                        size: 22,
                      ),
                    ],
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

class _PetSelectorStrip extends StatelessWidget {
  const _PetSelectorStrip({
    required this.pets,
    required this.selectedPetId,
    required this.onSelected,
  });

  final List<Pet> pets;
  final int? selectedPetId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 98,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: pets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final pet = pets[index];
          final selected = pet.id == selectedPetId;
          final avatarUrl = pet.resolvedAvatarUrl();
          return Material(
            color: Colors.white,
            elevation: selected ? 2 : 0,
            shadowColor: healthPrimary.withValues(alpha: 0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(
                color: selected ? healthPrimary : const Color(0xFFE5E7EB),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('ai-diagnosis-pet-${pet.id}'),
              onTap: () => onSelected(pet.id),
              child: SizedBox(
                width: 72,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? const Color(0xFFEEF2FF)
                              : const Color(0xFFF5F5F5),
                        ),
                        child: ClipOval(
                          child: SizedBox.square(
                            dimension: 34,
                            child: avatarUrl.isEmpty
                                ? Image.asset(
                                    'assets/images/health/pet_avatar.png',
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Image.asset(
                                      'assets/images/health/pet_avatar.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? healthPrimary
                              : const Color(0xFF1F2937),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        pet.breedLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF6278E8)
                              : const Color(0xFF6B7280),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AiReportsEmptyState extends StatelessWidget {
  const _AiReportsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
                ),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.auto_awesome,
                  color: healthPrimary,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '暂无问诊记录',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '点击下方“开始 AI 问诊”按钮\n为您的宠物创建第一份健康评估报告',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxWidth: 330),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: Color(0xFFEEF2FF),
                    child: Text(
                      'i',
                      style: TextStyle(
                        color: healthPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '温馨提示',
                          style: TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '填写症状描述后，AI 会分析宠物的健康状况并给出专业建议',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                            height: 1.4,
                          ),
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
    );
  }
}

enum _DiagnosisTab { western, tcm }

class AiDiagnosisReportPage extends StatefulWidget {
  const AiDiagnosisReportPage({
    super.key,
    required this.gateway,
    required this.reportId,
    this.initialReport,
  });

  final HealthGateway gateway;
  final int reportId;
  final AiDiagnosisReport? initialReport;

  @override
  State<AiDiagnosisReportPage> createState() => _AiDiagnosisReportPageState();
}

class _AiDiagnosisReportPageState extends State<AiDiagnosisReportPage> {
  AiDiagnosisReport? _report;
  AiDiagnosisConfig _config = AiDiagnosisConfig.fallback;
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  bool _requestInFlight = false;
  int _pollCount = 0;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _report = widget.initialReport;
    unawaited(_load());
  }

  Future<void> _load({bool automatic = false}) async {
    if (_requestInFlight) return;
    _pollTimer?.cancel();
    _requestInFlight = true;
    if (!automatic) _pollCount = 0;
    setState(() {
      _loading = _report == null;
      _error = null;
    });
    try {
      final result = await Future.wait<Object>([
        widget.gateway.loadAiDiagnosisReport(widget.reportId),
        widget.gateway.loadAiDiagnosisConfig().onError((_, _) => _config),
      ]);
      if (!mounted) return;
      setState(() {
        _report = result[0] as AiDiagnosisReport;
        _config = result[1] as AiDiagnosisConfig;
      });
    } on Object {
      if (mounted) setState(() => _error = '报告详情加载失败，请稍后重试');
    } finally {
      _requestInFlight = false;
      if (mounted) {
        setState(() => _loading = false);
        final report = _report;
        final active =
            report?.status == AiDiagnosisStatus.pending ||
            report?.status == AiDiagnosisStatus.processing;
        final assessmentPending =
            report?.status == AiDiagnosisStatus.completed &&
            (report?.westernAssessment?.isPending == true ||
                report?.tcmAssessment?.isPending == true);
        if (_error == null &&
            (active || assessmentPending) &&
            _pollCount < 60) {
          _pollCount += 1;
          _pollTimer = Timer(
            const Duration(seconds: 5),
            () => _load(automatic: true),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AiGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _aiAppBar('AI问诊报告详情'),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const _AiLoadingState(description: '正在获取报告详情');
    }
    if (_report == null) {
      return _AiState(
        icon: Icons.cloud_off_outlined,
        title: '加载失败',
        description: _error ?? '报告加载失败',
        actionLabel: '重新加载',
        onAction: _load,
      );
    }
    final report = _report!;
    return AiDiagnosisReportContent(
      report: report,
      config: _config,
      error: _error,
      onRefresh: _load,
      showEmergencyAlerts: false,
      showSelfCheckSnapshot: false,
    );
  }
}

/// AI 问诊报告的统一内容视图，用户端和医生端详情页共用。
///
/// 页面外层（导航栏、数据加载和背景）由各端负责，这里只维护报告内容
/// 的展示层级、诊断切换和风险提示展开状态。
class AiDiagnosisReportContent extends StatefulWidget {
  const AiDiagnosisReportContent({
    super.key,
    required this.report,
    this.config = AiDiagnosisConfig.fallback,
    this.error,
    this.onRefresh,
    this.showEmergencyAlerts = true,
    this.showSelfCheckSnapshot = true,
  });

  final AiDiagnosisReport report;
  final AiDiagnosisConfig config;
  final String? error;
  final Future<void> Function()? onRefresh;

  /// 是否在内容区顶部展示中西医紧急提示。
  ///
  /// 用户端报告详情页不展示；医生端需要保留急诊风险信息，默认展示。
  final bool showEmergencyAlerts;

  /// 是否展示「自查表结果」面板（本次问诊选择的自查表症状与图片）。
  ///
  /// 用户端不展示；医生端需要据此核对问诊过程中的自查表填写内容，默认展示。
  final bool showSelfCheckSnapshot;

  @override
  State<AiDiagnosisReportContent> createState() =>
      _AiDiagnosisReportContentState();
}

class _AiDiagnosisReportContentState extends State<AiDiagnosisReportContent> {
  bool _disclaimerExpanded = true;
  _DiagnosisTab _tab = _DiagnosisTab.western;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      widget.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (widget.report.status != AiDiagnosisStatus.completed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: [
                        Text(
                          widget.report.status == AiDiagnosisStatus.pending ||
                                  widget.report.status ==
                                      AiDiagnosisStatus.processing
                              ? 'AI 正在分析中...'
                              : '诊断未完成，请稍后重试',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (widget.report.errorMessage.isNotEmpty)
                          Text(widget.report.errorMessage),
                        if (widget.onRefresh != null)
                          TextButton(
                            onPressed: widget.onRefresh,
                            child: const Text('刷新状态'),
                          ),
                      ],
                    ),
                  ),
                // 两种评估独立生成；另一标签中的急诊建议也不能被隐藏。
                if (widget.showEmergencyAlerts)
                  for (final entry in [
                    ('西医', widget.report.westernAssessment),
                    ('中医', widget.report.tcmAssessment),
                  ])
                    if (entry.$2?.emergency?.text('level') == 'emergency' ||
                        entry.$2?.emergency?.text('level') == 'urgent')
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        color: const Color(0xFFFFEDEE),
                        child: Text(
                          '${entry.$1}紧急提示：${entry.$2!.emergency!.text('action').isEmpty ? '请尽快联系兽医' : entry.$2!.emergency!.text('action')}',
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                _ReportPetCard(report: widget.report),
                const SizedBox(height: 8),
                _ReportOverview(report: widget.report),
                const SizedBox(height: 8),
                _SymptomsPanel(report: widget.report),
                if (widget.showSelfCheckSnapshot &&
                    widget.report.selfCheckSnapshot.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SelfCheckSnapshotPanel(report: widget.report),
                ],
                const SizedBox(height: 8),
                _AiDisclaimerCard(
                  title: widget.config.disclaimerTitle,
                  content: widget.config.disclaimerContent,
                  expanded: _disclaimerExpanded,
                  onToggle: () => setState(
                    () => _disclaimerExpanded = !_disclaimerExpanded,
                  ),
                ),
                const SizedBox(height: 8),
                _DiagnosisTabs(
                  selected: _tab,
                  onSelected: (tab) => setState(() => _tab = tab),
                ),
                const SizedBox(height: 8),
                DiagnosisAssessmentPanel(
                  assessment: _tab == _DiagnosisTab.western
                      ? widget.report.westernAssessment
                      : widget.report.tcmAssessment,
                  disclaimer: _tab == _DiagnosisTab.western
                      ? widget.report.westernDisclaimer
                      : widget.report.tcmDisclaimer,
                ),
                if (_tab == _DiagnosisTab.western)
                  _WesternReport(report: widget.report)
                else
                  _TcmReport(report: widget.report),
                const SizedBox(height: 8),
                _UserNoticePanel(tab: _tab),
              ],
            ),
          ),
        ),
      ],
    );
    final onRefresh = widget.onRefresh;
    return onRefresh == null
        ? list
        : RefreshIndicator(onRefresh: onRefresh, child: list);
  }
}

class _ReportOverview extends StatelessWidget {
  const _ReportOverview({required this.report});

  final AiDiagnosisReport report;

  @override
  Widget build(BuildContext context) {
    return _ReportPanel(
      title: '报告信息',
      icon: Icons.description_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoLine(label: '报告日期:', value: _dateTimeLabel(report.createdAt)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Text(
                  '报告ID:',
                  style: TextStyle(color: Color(0xFF4B5563), fontSize: 14),
                ),
                const Spacer(),
                Text(
                  '${report.id}',
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 0.5,
                  height: 16,
                  color: const Color(0xFFE6E6E6),
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: '${report.id}'),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(const SnackBar(content: Text('报告ID已复制')));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: healthPrimary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '复制',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
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

class _ReportPetCard extends StatelessWidget {
  const _ReportPetCard({required this.report});

  final AiDiagnosisReport report;

  @override
  Widget build(BuildContext context) {
    final snapshot = report.petSnapshot;
    final name = healthString(snapshot['name'], fallback: '未知宠物');
    final breed = healthString(
      snapshot['subCategoryName'] ?? snapshot['breed'],
      fallback: '未知',
    );
    final birthDate = healthDateTime(snapshot['birthDate']);
    final genderValue = healthNullableInt(snapshot['gender']);
    final gender = genderValue == 1
        ? '弟弟'
        : genderValue == 2
        ? '妹妹'
        : '未知';
    final age = birthDate == null ? '未知' : formatPetAge(birthDate);
    final weight = healthString(snapshot['weight'], fallback: '未知');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/health/pet_avatar.png',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$breed · $age · $gender',
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
                        size: 13,
                        color: healthPrimary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        weight == '未知' ? weight : '${weight}kg',
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

class _SymptomsPanel extends StatelessWidget {
  const _SymptomsPanel({required this.report});

  final AiDiagnosisReport report;

  @override
  Widget build(BuildContext context) {
    return _ReportPanel(
      title: '报告描述',
      icon: Icons.chat_bubble_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '症状描述:',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            report.symptoms.isEmpty ? '暂无症状描述' : report.symptoms,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (report.basicInfo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                children: [
                  _BasicInfoItem(
                    label: '体温',
                    value: healthString(
                      report.basicInfo['bodyTemperature'],
                      fallback: '-',
                    ),
                  ),
                  _BasicInfoItem(
                    label: '心率',
                    value: healthString(
                      report.basicInfo['heartRate'],
                      fallback: '-',
                    ),
                  ),
                  _BasicInfoItem(
                    label: '呼吸',
                    value: healthString(
                      report.basicInfo['breathe'],
                      fallback: '-',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelfCheckSnapshotPanel extends StatelessWidget {
  const _SelfCheckSnapshotPanel({required this.report});

  final AiDiagnosisReport report;

  @override
  Widget build(BuildContext context) {
    return _ReportPanel(
      title: '自查表结果',
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '本次问诊中选择的症状和图片',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < report.selfCheckSnapshot.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == report.selfCheckSnapshot.length - 1 ? 0 : 10,
              ),
              child: _SelfCheckSectionResultCard(
                section: report.selfCheckSnapshot[index],
                sectionIndex: index,
              ),
            ),
        ],
      ),
    );
  }
}

class _SelfCheckSectionResultCard extends StatelessWidget {
  const _SelfCheckSectionResultCard({
    required this.section,
    required this.sectionIndex,
  });

  final AiSelfCheckSectionResult section;
  final int sectionIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8EBF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.folder_open_outlined,
                size: 17,
                color: Color(0xFF6278E8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  section.name,
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < section.questions.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == section.questions.length - 1 ? 0 : 8,
              ),
              child: _SelfCheckQuestionResultCard(
                question: section.questions[index],
                sectionIndex: sectionIndex,
                questionIndex: index,
              ),
            ),
        ],
      ),
    );
  }
}

class _SelfCheckQuestionResultCard extends StatelessWidget {
  const _SelfCheckQuestionResultCard({
    required this.question,
    required this.sectionIndex,
    required this.questionIndex,
  });

  final AiSelfCheckQuestionResult question;
  final int sectionIndex;
  final int questionIndex;

  @override
  Widget build(BuildContext context) {
    final selectedOptions = question.options.where((item) => item.selected);
    final options = selectedOptions.isEmpty
        ? question.options
        : selectedOptions;
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question.text.isEmpty ? '未命名问题' : question.text,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (options.isEmpty) ...[
            const SizedBox(height: 5),
            const Text(
              '未记录选项',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
          ] else ...[
            const SizedBox(height: 7),
            for (var index = 0; index < options.length; index++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == options.length - 1 ? 0 : 7,
                ),
                child: _SelfCheckOptionResultTile(
                  option: options.elementAt(index),
                  sectionIndex: sectionIndex,
                  questionIndex: questionIndex,
                  optionIndex: index,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SelfCheckOptionResultTile extends StatelessWidget {
  const _SelfCheckOptionResultTile({
    required this.option,
    required this.sectionIndex,
    required this.questionIndex,
    required this.optionIndex,
  });

  final AiSelfCheckOptionResult option;
  final int sectionIndex;
  final int questionIndex;
  final int optionIndex;

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveAssetUrl(option.imageUrl);
    final image = imageUrl.isEmpty
        ? null
        : ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              key: ValueKey(
                'ai-self-check-image-$sectionIndex-$questionIndex-$optionIndex',
              ),
              imageUrl,
              width: 84,
              height: 84,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const _SelfCheckImagePlaceholder(
                icon: Icons.image_not_supported_outlined,
                label: '图片加载失败',
              ),
            ),
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (image != null) ...[
          GestureDetector(
            onTap: () =>
                showFullscreenNetworkImagePreview(context, imageUrl: imageUrl),
            child: image,
          ),
          const SizedBox(width: 9),
        ],
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5FA),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              option.text.isEmpty ? '未填写答案' : option.text,
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelfCheckImagePlaceholder extends StatelessWidget {
  const _SelfCheckImagePlaceholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      color: const Color(0xFFEFF1F5),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: const Color(0xFF9CA3AF)),
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

class _BasicInfoItem extends StatelessWidget {
  const _BasicInfoItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF1F2937), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DiagnosisTabs extends StatelessWidget {
  const _DiagnosisTabs({required this.selected, required this.onSelected});

  final _DiagnosisTab selected;
  final ValueChanged<_DiagnosisTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: const ValueKey('ai-diagnosis-report-tabs'),
        width: 160,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            _DiagnosisTabButton(
              label: '西医诊断',
              selected: selected == _DiagnosisTab.western,
              onTap: () => onSelected(_DiagnosisTab.western),
            ),
            _DiagnosisTabButton(
              label: '中医诊断',
              selected: selected == _DiagnosisTab.tcm,
              onTap: () => onSelected(_DiagnosisTab.tcm),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosisTabButton extends StatelessWidget {
  const _DiagnosisTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? const Color(0xFF8EA3FF) : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF606060),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserNoticePanel extends StatelessWidget {
  const _UserNoticePanel({required this.tab});

  final _DiagnosisTab tab;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tab == _DiagnosisTab.western
            ? const Color(0xFF8EA3FF)
            : const Color(0xFF996A4B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        children: [
          Text(
            '用户悉知',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'AI 问诊报告基于您提交的宠物症状、自查表、图片和基础指标生成，仅供宠物健康管理参考，不能替代线下执业兽医的面诊、检查、诊断、处方或治疗建议。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
          ),
          SizedBox(height: 5),
          Text(
            '如宠物出现呼吸困难、抽搐、高热、持续呕吐腹泻等紧急症状，请立即前往线下宠物医院就诊；不要仅凭本报告自行用药。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WesternReport extends StatelessWidget {
  const _WesternReport({required this.report});

  final AiDiagnosisReport report;

  @override
  Widget build(BuildContext context) {
    if (report.westernDiagnosis.isEmpty && report.medications.isEmpty) {
      return const _DiagnosisEmptyState(
        icon: Icons.medical_services_outlined,
        message: '暂无西医分析结果',
      );
    }

    final assignments = List.generate(
      report.westernDiagnosis.length,
      (_) => <MedicationAdvice>[],
    );
    final unmatchedMedications = <MedicationAdvice>[];
    // 后端用药通过 symptom 关联诊断；缺少 symptom 时按位置兜底，其余药物单独保留。
    for (var index = 0; index < report.medications.length; index += 1) {
      final medication = report.medications[index];
      final symptom = _normalizedDiagnosisName(medication.symptom);
      final diagnosisIndex = symptom.isEmpty
          ? (index < assignments.length ? index : -1)
          : report.westernDiagnosis.indexWhere(
              (item) => _normalizedDiagnosisName(item.symptom) == symptom,
            );
      if (diagnosisIndex < 0) {
        unmatchedMedications.add(medication);
      } else {
        assignments[diagnosisIndex].add(medication);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < report.westernDiagnosis.length; index += 1)
          Padding(
            padding: EdgeInsets.only(
              bottom:
                  index == report.westernDiagnosis.length - 1 &&
                      unmatchedMedications.isEmpty
                  ? 0
                  : 10,
            ),
            child: _WesternDiagnosisCard(
              key: ValueKey('western-diagnosis-card-$index'),
              number: index + 1,
              diagnosis: report.westernDiagnosis[index],
              medications: assignments[index],
            ),
          ),
        if (report.westernDiagnosis.isEmpty && unmatchedMedications.isNotEmpty)
          _UnmatchedMedicationCard(medications: unmatchedMedications)
        else if (unmatchedMedications.isNotEmpty)
          _UnmatchedMedicationCard(
            key: const ValueKey('western-unmatched-medications'),
            medications: unmatchedMedications,
          ),
      ],
    );
  }
}

class _TcmReport extends StatelessWidget {
  const _TcmReport({required this.report});

  final AiDiagnosisReport report;

  @override
  Widget build(BuildContext context) {
    if (report.tcmDiagnosis.isEmpty) {
      return const _DiagnosisEmptyState(
        icon: Icons.spa_outlined,
        message: '暂无中医分析结果',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < report.tcmDiagnosis.length; index += 1)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == report.tcmDiagnosis.length - 1 ? 0 : 10,
            ),
            child: _TcmDiagnosisCard(
              key: ValueKey('tcm-diagnosis-card-$index'),
              number: index + 1,
              diagnosis: report.tcmDiagnosis[index],
            ),
          ),
      ],
    );
  }
}

class _ReportPanel extends StatelessWidget {
  const _ReportPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: healthPrimary, size: 24),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _WesternDiagnosisCard extends StatelessWidget {
  const _WesternDiagnosisCard({
    super.key,
    required this.number,
    required this.diagnosis,
    required this.medications,
  });

  final int number;
  final WesternDiagnosisItem diagnosis;
  final List<MedicationAdvice> medications;

  @override
  Widget build(BuildContext context) {
    return _DiagnosisPlanCard(
      title: diagnosis.symptom.isEmpty ? '未命名诊断' : diagnosis.symptom,
      probability: diagnosis.probability,
      titleColor: const Color(0xFF1F2937),
      probabilityKey: ValueKey('western-probability-$number'),
      children: [
        if (diagnosis.reason.isNotEmpty)
          _DiagnosisTextBlock(
            label: '诊断依据',
            value: diagnosis.reason,
            backgroundColor: const Color(0xFFF0F9FF),
            labelColor: const Color(0xFF7E97FA),
          ),
        if (medications.isNotEmpty)
          _MedicationSection(
            medications: medications,
            itemKeyPrefix: 'western-medication-$number',
            showSymptom: false,
          ),
      ],
    );
  }
}

class _MedicationSection extends StatelessWidget {
  const _MedicationSection({
    required this.medications,
    required this.itemKeyPrefix,
    required this.showSymptom,
    this.title = '用药建议',
    this.topMargin = 14,
  });

  final List<MedicationAdvice> medications;
  final String itemKeyPrefix;
  final bool showSymptom;
  final String title;
  final double topMargin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: topMargin),
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFFE1F0FF), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF7E97FA),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < medications.length; index += 1)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == medications.length - 1 ? 0 : 8,
              ),
              child: _MedicationRow(
                key: ValueKey('$itemKeyPrefix-$index'),
                medication: medications[index],
                showSymptom: showSymptom,
              ),
            ),
        ],
      ),
    );
  }
}

class _TcmDiagnosisCard extends StatelessWidget {
  const _TcmDiagnosisCard({
    super.key,
    required this.number,
    required this.diagnosis,
  });

  final int number;
  final TcmDiagnosisItem diagnosis;

  @override
  Widget build(BuildContext context) {
    return _DiagnosisPlanCard(
      title: diagnosis.name.isEmpty ? '未命名证候' : diagnosis.name,
      probability: diagnosis.probability,
      titleColor: const Color(0xFF996A4B),
      probabilityKey: ValueKey('tcm-probability-$number'),
      elevated: true,
      children: [
        if (diagnosis.description.isNotEmpty)
          _DiagnosisTextBlock(
            label: '证候描述',
            value: diagnosis.description,
            backgroundColor: const Color(0xFFFFF5EE),
            labelColor: const Color(0xFF996A4B),
          ),
        if (diagnosis.therapy.isNotEmpty)
          _DiagnosisTextBlock(
            label: '治疗原则',
            value: diagnosis.therapy,
            backgroundColor: const Color(0xFFFFF5EE),
            labelColor: const Color(0xFF996A4B),
          ),
        if (diagnosis.base.isNotEmpty)
          _DiagnosisTextBlock(
            label: '基础建议',
            value: diagnosis.base,
            backgroundColor: const Color(0xFFFFF5EE),
            labelColor: const Color(0xFF996A4B),
          ),
        if (diagnosis.prescription.isNotEmpty || diagnosis.usage.isNotEmpty)
          _TcmPrescriptionSection(
            prescription: diagnosis.prescription,
            usage: diagnosis.usage,
          ),
      ],
    );
  }
}

class _TcmPrescriptionSection extends StatelessWidget {
  const _TcmPrescriptionSection({
    required this.prescription,
    required this.usage,
  });

  final String prescription;
  final String usage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '方药',
            style: TextStyle(
              color: Color(0xFF996A4B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (prescription.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5EE),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                prescription,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (prescription.isNotEmpty && usage.isNotEmpty)
            const SizedBox(height: 6),
          if (usage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5EE),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                usage,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DiagnosisPlanCard extends StatelessWidget {
  const _DiagnosisPlanCard({
    required this.title,
    required this.probability,
    required this.titleColor,
    required this.probabilityKey,
    required this.children,
    this.elevated = false,
  });

  final String title;
  final String probability;
  final Color titleColor;
  final Key probabilityKey;
  final List<Widget> children;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final probabilityInfo = _probabilityInfo(probability);
    return Material(
      color: Colors.white,
      elevation: elevated ? 2 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (probabilityInfo != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: probabilityInfo.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      probabilityInfo.label,
                      style: TextStyle(
                        color: probabilityInfo.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (probabilityInfo != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        key: probabilityKey,
                        value: probabilityInfo.value,
                        minHeight: 6,
                        color: probabilityInfo.color,
                        backgroundColor: const Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 42,
                    child: Text(
                      probabilityInfo.percent,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DiagnosisTextBlock extends StatelessWidget {
  const _DiagnosisTextBlock({
    required this.label,
    required this.value,
    required this.backgroundColor,
    required this.labelColor,
  });

  final String label;
  final String value;
  final Color backgroundColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF303849),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicationRow extends StatelessWidget {
  const _MedicationRow({
    super.key,
    required this.medication,
    required this.showSymptom,
  });

  final MedicationAdvice medication;
  final bool showSymptom;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '药物：',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              Expanded(
                child: Text(
                  medication.drugName.isEmpty ? '未命名药物' : medication.drugName,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (showSymptom && medication.symptom.isNotEmpty) ...[
            const SizedBox(height: 5),
            _MedicationFact(label: '适用', value: medication.symptom),
          ],
          if (medication.dosage.isNotEmpty || medication.frequency.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 18,
                runSpacing: 4,
                children: [
                  if (medication.dosage.isNotEmpty)
                    _MedicationFact(label: '剂量', value: medication.dosage),
                  if (medication.frequency.isNotEmpty)
                    _MedicationFact(label: '频率', value: medication.frequency),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MedicationFact extends StatelessWidget {
  const _MedicationFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label：',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w400,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
      style: const TextStyle(
        color: Color(0xFF1F2937),
        fontSize: 12,
        height: 1.4,
      ),
    );
  }
}

class _UnmatchedMedicationCard extends StatelessWidget {
  const _UnmatchedMedicationCard({super.key, required this.medications});

  final List<MedicationAdvice> medications;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _MedicationSection(
          medications: medications,
          itemKeyPrefix: 'western-unmatched-medication',
          showSymptom: true,
          title: '其他用药建议',
          topMargin: 0,
        ),
      ),
    );
  }
}

class _DiagnosisEmptyState extends StatelessWidget {
  const _DiagnosisEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF9AA3B2), size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF697386), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

String _normalizedDiagnosisName(String value) =>
    value.replaceAll(RegExp(r'\s+'), '').toLowerCase();

class _ProbabilityInfo {
  const _ProbabilityInfo({
    required this.label,
    required this.percent,
    required this.color,
    required this.value,
  });

  final String label;
  final String percent;
  final Color color;
  final double value;
}

_ProbabilityInfo? _probabilityInfo(String rawValue) {
  final normalized = rawValue.trim();
  if (normalized.isEmpty) return null;

  final isPercent = normalized.endsWith('%');
  final numericText = isPercent
      ? normalized.substring(0, normalized.length - 1).trim()
      : normalized;
  final parsed = double.tryParse(numericText);
  if (parsed == null) return null;

  final probability = isPercent ? parsed / 100 : parsed;
  if (probability < 0 || probability > 1) return null;

  final (label, color) = switch (probability) {
    >= 0.9 => ('概率极高', const Color(0xFFFF4444)),
    >= 0.8 => ('概率很高', const Color(0xFFFF6B6B)),
    >= 0.7 => ('概率高', const Color(0xFFFF8C00)),
    >= 0.6 => ('概率较高', const Color(0xFFFFA500)),
    >= 0.5 => ('概率中等', const Color(0xFFFFC107)),
    _ => ('概率较低', const Color(0xFFFFB300)),
  };

  return _ProbabilityInfo(
    label: label,
    percent: _formatProbability(normalized),
    color: color,
    value: probability,
  );
}

String _formatProbability(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.endsWith('%')) return normalized;
  final number = double.tryParse(normalized);
  if (number == null || number < 0 || number > 1) return normalized;
  final percentage = number * 100;
  final text = percentage == percentage.roundToDouble()
      ? percentage.toStringAsFixed(0)
      : percentage.toStringAsFixed(1);
  return '$text%';
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Color(0xFF111827), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiState extends StatelessWidget {
  const _AiState({
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 40, color: healthPrimary),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      description!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (actionLabel != null) ...[
                    const SizedBox(height: 14),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: healthPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiLoadingState extends StatelessWidget {
  const _AiLoadingState({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 240,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: healthPrimary),
                const SizedBox(height: 10),
                const Text(
                  '加载中...',
                  style: TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiGradientBackground extends StatelessWidget {
  const _AiGradientBackground({required this.child});

  final Widget child;

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
      child: child,
    );
  }
}

PreferredSizeWidget _aiAppBar(String title) {
  return AppBar(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    elevation: 0,
    foregroundColor: const Color(0xFF1F2937),
    title: Text(
      title,
      style: const TextStyle(
        color: Color(0xFF1F2937),
        fontSize: 19,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _AiDisclaimerCard extends StatelessWidget {
  const _AiDisclaimerCard({
    required this.title,
    required this.content,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final String content;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: healthPrimary.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: const BorderSide(color: Color(0xFFDBE4FF), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 8,
                    backgroundColor: Color(0xFFEEF2FF),
                    child: Text(
                      '!',
                      style: TextStyle(
                        color: Color(0xFF6278E8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    expanded ? '收起' : '展开',
                    style: const TextStyle(
                      color: healthPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (expanded) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 0.5, color: Color(0xFFEEF2FF)),
                ),
                Text(
                  content,
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AiBottomBar extends StatelessWidget {
  const _AiBottomBar({
    required this.label,
    required this.onPressed,
    this.buttonKey,
  });

  final String label;
  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: SizedBox(
            height: 45,
            child: FilledButton(
              key: buttonKey,
              style: FilledButton.styleFrom(
                backgroundColor: healthPrimary,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: onPressed,
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

String _relativeDateLabel(DateTime date) {
  final difference = DateTime.now().difference(date.toLocal());
  if (difference.isNegative || difference.inMinutes < 1) return '刚刚';
  if (difference.inHours < 1) return '${difference.inMinutes}分钟前';
  if (difference.inDays < 1) return '${difference.inHours}小时前';
  if (difference.inDays == 1) return '昨天';
  if (difference.inDays < 7) return '${difference.inDays}天前';
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.month)}-${two(local.day)}';
}

String _dateTimeLabel(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
