import 'package:flutter/material.dart';

import '../../../core/media/route_aware_video_surface.dart';
import '../../../core/network/asset_url_resolver.dart';
import '../../emergency/presentation/widgets/aid_guide_rich_content.dart';
import '../../health/domain/health_models.dart';
import '../../health/presentation/pages/ai_diagnosis_pages.dart';
import '../../pets/presentation/pages/pet_page_chrome.dart';
import '../domain/doctor_portal_models.dart';
import 'doctor_consultation_history_page.dart';

const _recordPrimary = petPrimaryColor;
const _recordText = petTextPrimaryColor;
const _recordMuted = petTextSecondaryColor;
const _recordBorder = petBorderColor;
const _recordPrimarySoft = Color(0x197E97FA);
const _recordPrimaryBorder = Color(0x667E97FA);
const _recordCardShadow = [
  BoxShadow(color: Color(0x14000000), offset: Offset(0, 1), blurRadius: 2),
];

class DoctorPatientRecordPage extends StatefulWidget {
  const DoctorPatientRecordPage({
    super.key,
    required this.gateway,
    required this.consultation,
    this.currentDoctorAvatarUrl = '',
  });

  final DoctorPortalGateway gateway;
  final DoctorConsultation consultation;
  final String currentDoctorAvatarUrl;

  @override
  State<DoctorPatientRecordPage> createState() =>
      _DoctorPatientRecordPageState();
}

class _DoctorPatientRecordPageState extends State<DoctorPatientRecordPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Map<int, _PagedRecord<AiDiagnosisReport>> _reports = {};
  final Map<int, _ValueRecord<PetCarePlanState>> _carePlans = {};
  final Map<int, _PagedRecord<HealthAppointment>> _appointments = {};
  DoctorPatientRecord? _record;
  int? _selectedPetId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(_handleTabChanged);
    _loadRecord();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    _ensureCurrentTabLoaded();
  }

  Future<void> _loadRecord() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final record = await widget.gateway.loadPatientRecord(
        widget.consultation.conversationId,
      );
      if (!mounted) return;
      setState(() {
        _record = record;
        _selectedPetId = record.pets.isEmpty ? null : record.pets.first.pet.id;
        _loading = false;
      });
      _ensureCurrentTabLoaded();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  void _selectPet(int petId) {
    if (_selectedPetId == petId) return;
    setState(() => _selectedPetId = petId);
    _ensureCurrentTabLoaded();
  }

  void _ensureCurrentTabLoaded() {
    final petId = _selectedPetId;
    if (petId == null) return;
    switch (_tabController.index) {
      case 0:
        if (!_reports.containsKey(petId)) _loadReports(petId);
      case 2:
        if (!_carePlans.containsKey(petId)) _loadCarePlan(petId);
      case 3:
        if (!_appointments.containsKey(petId)) _loadAppointments(petId);
    }
  }

  Future<void> _loadReports(int petId, {bool loadMore = false}) async {
    final state = _reports.putIfAbsent(petId, _PagedRecord.new);
    if (state.loading) return;
    setState(() {
      state.loading = true;
      state.error = null;
    });
    try {
      final page = await widget.gateway.loadPatientAiReports(
        conversationId: widget.consultation.conversationId,
        petId: petId,
        page: loadMore ? state.page + 1 : 1,
      );
      if (!mounted) return;
      setState(() {
        state.items = loadMore ? [...state.items, ...page.items] : page.items;
        state.page = page.page;
        state.totalPages = page.totalPages;
        state.loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        state.loading = false;
        state.error = '$error';
      });
    }
  }

  Future<void> _loadAppointments(int petId, {bool loadMore = false}) async {
    final state = _appointments.putIfAbsent(petId, _PagedRecord.new);
    if (state.loading) return;
    setState(() {
      state.loading = true;
      state.error = null;
    });
    try {
      final page = await widget.gateway.loadPatientAppointments(
        conversationId: widget.consultation.conversationId,
        petId: petId,
        page: loadMore ? state.page + 1 : 1,
      );
      if (!mounted) return;
      setState(() {
        state.items = loadMore ? [...state.items, ...page.items] : page.items;
        state.page = page.page;
        state.totalPages = page.totalPages;
        state.loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        state.loading = false;
        state.error = '$error';
      });
    }
  }

  Future<void> _loadCarePlan(int petId) async {
    final state = _carePlans.putIfAbsent(petId, _ValueRecord.new);
    if (state.loading) return;
    setState(() {
      state.loading = true;
      state.error = null;
    });
    try {
      final value = await widget.gateway.loadPatientCarePlan(
        conversationId: widget.consultation.conversationId,
        petId: petId,
      );
      if (!mounted) return;
      setState(() {
        state.value = value;
        state.loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        state.loading = false;
        state.error = '$error';
      });
    }
  }

  DoctorPatientPet? get _selectedPet {
    final petId = _selectedPetId;
    if (petId == null) return null;
    for (final pet in _record?.pets ?? const <DoctorPatientPet>[]) {
      if (pet.pet.id == petId) return pet;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PetGradientBackground(
      key: const ValueKey('patient-record-background'),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              PetPageHeader(
                title: '用户健康档案',
                onBack: () => Navigator.of(context).maybePop(),
                trailing: IconButton(
                  key: const ValueKey('patient-record-refresh'),
                  tooltip: '刷新',
                  onPressed: _loading ? null : _loadRecord,
                  color: _recordText,
                  disabledColor: petTextTertiaryColor,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _recordPrimary),
      );
    }
    final record = _record;
    if (record == null) {
      return _RecordMessage(
        icon: Icons.error_outline,
        message: _error ?? '健康档案加载失败',
        actionLabel: '重试',
        onAction: _loadRecord,
      );
    }
    if (record.pets.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 6),
          _PatientHeader(record: record),
          const SizedBox(height: 10),
          _HistoryEntry(
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => DoctorConsultationHistoryPage(
                  gateway: widget.gateway,
                  consultation: widget.consultation,
                  currentDoctorAvatarUrl: widget.currentDoctorAvatarUrl,
                ),
              ),
            ),
          ),
          const Expanded(
            child: _RecordMessage(
              icon: Icons.pets_outlined,
              message: '该用户还没有宠物档案',
            ),
          ),
        ],
      );
    }

    final selectedPet = _selectedPet!;
    return NestedScrollView(
      key: const ValueKey('patient-record-scroll'),
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 6),
              _PatientHeader(record: record),
              const SizedBox(height: 10),
              _HistoryEntry(
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => DoctorConsultationHistoryPage(
                      gateway: widget.gateway,
                      consultation: widget.consultation,
                      currentDoctorAvatarUrl: widget.currentDoctorAvatarUrl,
                    ),
                  ),
                ),
              ),
              _PetSelector(
                pets: record.pets,
                selectedPetId: _selectedPetId!,
                onSelected: _selectPet,
              ),
              _PetOverview(pet: selectedPet),
            ],
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _PatientRecordTabBarDelegate(controller: _tabController),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportTab(_selectedPetId!),
          _HealthOverviewTab(stats: selectedPet.healthStats),
          _buildCarePlanTab(_selectedPetId!),
          _buildAppointmentTab(_selectedPetId!),
        ],
      ),
    );
  }

  Widget _buildReportTab(int petId) {
    final state = _reports[petId];
    if (state == null || (state.loading && state.items.isEmpty)) {
      return const Center(
        child: CircularProgressIndicator(color: _recordPrimary),
      );
    }
    if (state.items.isEmpty) {
      return _RecordMessage(
        icon: Icons.description_outlined,
        message: state.error ?? '暂无 AI 问诊报告',
        actionLabel: state.error == null ? null : '重试',
        onAction: state.error == null ? null : () => _loadReports(petId),
      );
    }
    return RefreshIndicator(
      color: _recordPrimary,
      onRefresh: () => _loadReports(petId),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return _LoadMoreButton(
              loading: state.loading,
              onPressed: () => _loadReports(petId, loadMore: true),
            );
          }
          final report = state.items[index];
          return _AiReportTile(
            report: report,
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => DoctorAiReportDetailPage(
                  gateway: widget.gateway,
                  conversationId: widget.consultation.conversationId,
                  reportId: report.id,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppointmentTab(int petId) {
    final state = _appointments[petId];
    if (state == null || (state.loading && state.items.isEmpty)) {
      return const Center(
        child: CircularProgressIndicator(color: _recordPrimary),
      );
    }
    if (state.items.isEmpty) {
      return _RecordMessage(
        icon: Icons.event_note_outlined,
        message: state.error ?? '暂无健康档案',
        actionLabel: state.error == null ? null : '重试',
        onAction: state.error == null ? null : () => _loadAppointments(petId),
      );
    }
    return RefreshIndicator(
      color: _recordPrimary,
      onRefresh: () => _loadAppointments(petId),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return _LoadMoreButton(
              loading: state.loading,
              onPressed: () => _loadAppointments(petId, loadMore: true),
            );
          }
          final appointment = state.items[index];
          return _AppointmentTile(
            appointment: appointment,
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => DoctorHealthRecordDetailPage(
                  gateway: widget.gateway,
                  conversationId: widget.consultation.conversationId,
                  appointmentId: appointment.id,
                  initialRecord: appointment,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCarePlanTab(int petId) {
    final state = _carePlans[petId];
    if (state == null || (state.loading && state.value == null)) {
      return const Center(
        child: CircularProgressIndicator(color: _recordPrimary),
      );
    }
    final value = state.value;
    if (value == null) {
      return _RecordMessage(
        icon: Icons.health_and_safety_outlined,
        message: state.error ?? '护理建议加载失败',
        actionLabel: '重试',
        onAction: () => _loadCarePlan(petId),
      );
    }
    return RefreshIndicator(
      color: _recordPrimary,
      onRefresh: () => _loadCarePlan(petId),
      child: _CareAdviceTab(state: value),
    );
  }
}

class _PagedRecord<T> {
  List<T> items = [];
  int page = 0;
  int totalPages = 0;
  bool loading = false;
  String? error;

  bool get hasMore => page < totalPages;
}

class _ValueRecord<T> {
  T? value;
  bool loading = false;
  String? error;
}

class _PatientRecordTabBarDelegate extends SliverPersistentHeaderDelegate {
  _PatientRecordTabBarDelegate({required this.controller});

  final TabController controller;

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Colors.white,
      elevation: overlapsContent ? 2 : 0,
      shadowColor: const Color(0x18000000),
      child: TabBar(
        key: const ValueKey('patient-record-tabs'),
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: _recordPrimary,
        unselectedLabelColor: _recordMuted,
        indicatorColor: _recordPrimary,
        indicatorWeight: 2.5,
        dividerColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(_recordPrimarySoft),
        tabs: const [
          Tab(text: 'AI问诊'),
          Tab(text: '健康概览'),
          Tab(text: '护理建议'),
          Tab(text: '健康档案'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PatientRecordTabBarDelegate oldDelegate) {
    return oldDelegate.controller != controller;
  }
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({required this.record});

  final DoctorPatientRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: _recordCardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Row(
        children: [
          _RecordAvatar(
            imageUrl: record.userAvatarUrl,
            fallbackIcon: Icons.person,
            size: 52,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _recordText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '共 ${record.petCount} 只宠物',
                  style: const TextStyle(color: _recordMuted, fontSize: 14),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified_user_outlined, color: _recordPrimary),
        ],
      ),
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: _recordCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: const ValueKey('patient-history-entry'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 14, 12),
            child: Row(
              children: [
                _RecordIcon(
                  icon: Icons.history_rounded,
                  size: 38,
                  iconSize: 21,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '历史咨询',
                        style: TextStyle(
                          color: _recordText,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '查看该用户与您的过往聊天',
                        style: TextStyle(color: _recordMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: _recordMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PetSelector extends StatelessWidget {
  const _PetSelector({
    required this.pets,
    required this.selectedPetId,
    required this.onSelected,
  });

  final List<DoctorPatientPet> pets;
  final int selectedPetId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = pets[index];
          final selected = item.pet.id == selectedPetId;
          return InkWell(
            key: ValueKey('patient-pet-${item.pet.id}'),
            onTap: () => onSelected(item.pet.id),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 94,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? _recordPrimarySoft
                    : Colors.white.withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? _recordPrimaryBorder : Colors.white,
                ),
                boxShadow: selected ? _recordCardShadow : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RecordAvatar(
                    imageUrl: item.pet.avatarUrl,
                    fallbackIcon: Icons.pets,
                    size: 38,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.pet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? _recordPrimary : _recordText,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PetOverview extends StatelessWidget {
  const _PetOverview({required this.pet});

  final DoctorPatientPet pet;

  @override
  Widget build(BuildContext context) {
    final value = pet.pet;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 2, 15, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _InfoPill(icon: Icons.category_outlined, label: value.breedLabel),
          _InfoPill(icon: Icons.wc, label: value.genderLabel),
          _InfoPill(
            icon: Icons.monitor_weight_outlined,
            label: '${value.weight.toStringAsFixed(1)} kg',
          ),
          _InfoPill(icon: Icons.cake_outlined, label: _petAge(value.birthDate)),
          _InfoPill(
            icon: Icons.medical_services_outlined,
            label: value.isNeutered ? '已绝育' : '未绝育',
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _recordMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: _recordMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RecordIcon extends StatelessWidget {
  const _RecordIcon({
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _recordPrimarySoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: _recordPrimary, size: iconSize),
    );
  }
}

class _HealthOverviewTab extends StatelessWidget {
  const _HealthOverviewTab({required this.stats});

  final PetHealthStats stats;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('patient-health-overview-list'),
      padding: const EdgeInsets.all(16),
      children: [
        for (
          var index = 0;
          index < HealthAppointmentType.values.length;
          index++
        ) ...[
          _HealthMetricCard(
            type: HealthAppointmentType.values[index],
            metric: stats.metricFor(HealthAppointmentType.values[index]),
          ),
          if (index < HealthAppointmentType.values.length - 1)
            const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _HealthMetricCard extends StatelessWidget {
  const _HealthMetricCard({required this.type, required this.metric});

  final HealthAppointmentType type;
  final HealthMetric metric;

  @override
  Widget build(BuildContext context) {
    final nextAt = metric.nextAt;
    final overdue = nextAt != null && nextAt.isBefore(DateTime.now());
    final typeColor = _healthTypeColor(type);
    final statusColor = metric.count == 0
        ? _recordMuted
        : overdue
        ? const Color(0xFFDC2626)
        : typeColor;
    return Container(
      key: ValueKey('patient-health-metric-${type.wireValue}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: _recordCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_healthTypeIcon(type), color: typeColor, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _healthMetricStatus(type, metric, overdue: overdue),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${metric.count} ${type == HealthAppointmentType.vaccine ? '针' : '次'}',
                style: const TextStyle(
                  color: _recordText,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Divider(height: 28, color: _recordBorder),
          _RecordField(
            label: _healthDateLabel(type, next: false),
            value: _formatDate(metric.lastAt),
          ),
          const SizedBox(height: 12),
          _RecordField(
            label: _healthDateLabel(type, next: true),
            value: _formatDate(metric.nextAt),
          ),
        ],
      ),
    );
  }
}

class _CareAdviceTab extends StatelessWidget {
  const _CareAdviceTab({required this.state});

  final PetCarePlanState state;

  @override
  Widget build(BuildContext context) {
    final advice = state.plan?.care;
    final categories = advice == null
        ? const <_CareAdviceData>[]
        : [
            _CareAdviceData(
              title: '美容护理',
              icon: Icons.content_cut_rounded,
              color: const Color(0xFFFF8C78),
              items: advice.grooming,
            ),
            _CareAdviceData(
              title: '医疗护理',
              icon: Icons.medical_services_rounded,
              color: const Color(0xFFEF4444),
              items: advice.medical,
            ),
            _CareAdviceData(
              title: '运动建议',
              icon: Icons.directions_run_rounded,
              color: const Color(0xFF21A675),
              items: advice.exercise,
            ),
            _CareAdviceData(
              title: '疫苗接种',
              icon: Icons.vaccines_rounded,
              color: _recordPrimary,
              items: advice.vaccination,
            ),
            _CareAdviceData(
              title: '环境管理',
              icon: Icons.home_rounded,
              color: const Color(0xFFF59E0B),
              items: advice.environment,
            ),
          ].where((item) => item.items.isNotEmpty).toList(growable: false);
    if (categories.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 72),
          _RecordMessage(
            icon: Icons.health_and_safety_outlined,
            message: _carePlanEmptyMessage(state),
          ),
        ],
      );
    }
    return ListView(
      key: const ValueKey('patient-care-advice-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (state.generatedAt != null) ...[
          Text(
            '生成于 ${_formatDateTime(state.generatedAt!)}',
            style: const TextStyle(color: _recordMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
        ],
        for (var index = 0; index < categories.length; index++) ...[
          _CareAdviceCard(data: categories[index]),
          if (index < categories.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CareAdviceData {
  const _CareAdviceData({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
}

class _CareAdviceCard extends StatelessWidget {
  const _CareAdviceCard({required this.data});

  final _CareAdviceData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: _recordCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, color: data.color, size: 22),
              const SizedBox(width: 9),
              Text(
                data.title,
                style: const TextStyle(
                  color: _recordText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < data.items.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: data.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    data.items[index],
                    style: const TextStyle(color: _recordMuted, height: 1.5),
                  ),
                ),
              ],
            ),
            if (index < data.items.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _AiReportTile extends StatelessWidget {
  const _AiReportTile({required this.report, required this.onTap});

  final AiDiagnosisReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = report.status == AiDiagnosisStatus.completed;
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: const Color(0x14000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        key: ValueKey('patient-ai-report-${report.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _recordPrimarySoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: _recordPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            report.symptoms.isEmpty
                                ? 'AI 问诊报告'
                                : report.symptoms,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _recordText,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          report.status.label,
                          style: TextStyle(
                            color: completed
                                ? const Color(0xFF059669)
                                : const Color(0xFFD97706),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _formatDateTime(report.createdAt),
                      style: const TextStyle(color: _recordMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _recordMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.appointment, required this.onTap});

  final HealthAppointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (appointment.type) {
      HealthAppointmentType.vaccine => Icons.vaccines_outlined,
      HealthAppointmentType.deworming => Icons.bug_report_outlined,
      HealthAppointmentType.checkup => Icons.monitor_heart_outlined,
    };
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: const Color(0x14000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        key: ValueKey('patient-appointment-${appointment.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _recordPrimary, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            appointment.type.label,
                            style: const TextStyle(
                              color: _recordText,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          appointment.status.label,
                          style: const TextStyle(
                            color: _recordPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${appointment.appointmentDate}  ${appointment.timeSlot}',
                      style: const TextStyle(color: _recordText, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appointment.hospital?.name ?? '医院信息未记录',
                      style: const TextStyle(color: _recordMuted, fontSize: 13),
                    ),
                    if (appointment.doctorName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '接诊医生：${appointment.doctorName}',
                        style: const TextStyle(
                          color: _recordMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (appointment.notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        appointment.notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _recordMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: _recordMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class DoctorHealthRecordDetailPage extends StatefulWidget {
  const DoctorHealthRecordDetailPage({
    super.key,
    required this.gateway,
    required this.conversationId,
    required this.appointmentId,
    this.initialRecord,
  });

  final DoctorPortalGateway gateway;
  final String conversationId;
  final int appointmentId;
  final HealthAppointment? initialRecord;

  @override
  State<DoctorHealthRecordDetailPage> createState() =>
      _DoctorHealthRecordDetailPageState();
}

class _DoctorHealthRecordDetailPageState
    extends State<DoctorHealthRecordDetailPage> {
  late Future<HealthAppointment> _record;

  @override
  void initState() {
    super.initState();
    _record = _load();
  }

  Future<HealthAppointment> _load() => widget.gateway.loadPatientAppointment(
    conversationId: widget.conversationId,
    appointmentId: widget.appointmentId,
  );

  @override
  Widget build(BuildContext context) {
    return VideoRoutePopScope<void>(
      child: PetGradientBackground(
        key: const ValueKey('patient-health-record-detail-background'),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                PetPageHeader(
                  title: '健康档案详情',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: FutureBuilder<HealthAppointment>(
                    future: _record,
                    initialData: widget.initialRecord,
                    builder: (context, snapshot) {
                      final record = snapshot.data;
                      if (record == null &&
                          snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: _recordPrimary,
                          ),
                        );
                      }
                      if (record == null) {
                        return _RecordMessage(
                          icon: Icons.error_outline,
                          message: '${snapshot.error ?? '健康档案加载失败'}',
                          actionLabel: '重试',
                          onAction: () => setState(() => _record = _load()),
                        );
                      }
                      return _HealthRecordDetail(record: record);
                    },
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

class _HealthRecordDetail extends StatelessWidget {
  const _HealthRecordDetail({required this.record});

  final HealthAppointment record;

  @override
  Widget build(BuildContext context) {
    final hospital = record.hospital;
    return ListView(
      key: const ValueKey('patient-health-record-detail-scroll'),
      padding: const EdgeInsets.all(16),
      children: [
        _DetailSection(
          title: '档案信息',
          children: [
            _RecordField(label: '项目', value: record.type.label),
            _RecordField(label: '状态', value: record.status.label),
            _RecordField(label: '日期', value: record.appointmentDate),
            _RecordField(label: '时段', value: record.timeSlot),
            _RecordField(label: '医院', value: hospital?.name ?? '未记录'),
            if (hospital?.address.isNotEmpty == true)
              _RecordField(label: '地址', value: hospital!.address),
            if (record.doctorName.isNotEmpty)
              _RecordField(label: '医生', value: record.doctorName),
            _RecordField(
              label: '操作内容',
              value: record.operationContent.isEmpty
                  ? '未填写操作内容'
                  : record.operationContent,
            ),
          ],
        ),
        if (record.detailContent.isNotEmpty)
          _DetailSection(
            title: '详细内容',
            children: [AidGuideRichContent(content: record.detailContent)],
          ),
        if (record.notes.isNotEmpty)
          _DetailSection(
            title: '备注',
            children: [
              SelectableText(
                record.notes,
                style: const TextStyle(color: _recordText, height: 1.5),
              ),
            ],
          ),
      ],
    );
  }
}

class DoctorAiReportDetailPage extends StatefulWidget {
  const DoctorAiReportDetailPage({
    super.key,
    required this.gateway,
    required this.conversationId,
    required this.reportId,
  });

  final DoctorPortalGateway gateway;
  final String conversationId;
  final int reportId;

  @override
  State<DoctorAiReportDetailPage> createState() =>
      _DoctorAiReportDetailPageState();
}

class _DoctorAiReportDetailPageState extends State<DoctorAiReportDetailPage> {
  late Future<AiDiagnosisReport> _report;

  @override
  void initState() {
    super.initState();
    _report = _load();
  }

  Future<AiDiagnosisReport> _load() => widget.gateway.loadPatientAiReport(
    conversationId: widget.conversationId,
    reportId: widget.reportId,
  );

  @override
  Widget build(BuildContext context) {
    return PetGradientBackground(
      key: const ValueKey('patient-ai-report-background'),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              PetPageHeader(
                title: 'AI 问诊报告',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: FutureBuilder<AiDiagnosisReport>(
                  future: _report,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(color: _recordPrimary),
                      );
                    }
                    final report = snapshot.data;
                    if (report == null) {
                      return _RecordMessage(
                        icon: Icons.error_outline,
                        message: '${snapshot.error ?? '报告加载失败'}',
                        actionLabel: '重试',
                        onAction: () => setState(() => _report = _load()),
                      );
                    }
                    if (report.status == AiDiagnosisStatus.pending ||
                        report.status == AiDiagnosisStatus.processing) {
                      return _RecordMessage(
                        icon: Icons.auto_awesome_rounded,
                        message: 'AI 正在分析中...\n预计需要 30-60 秒',
                        actionLabel: '刷新状态',
                        onAction: () => setState(() => _report = _load()),
                      );
                    }
                    if (report.status == AiDiagnosisStatus.failed ||
                        report.status == AiDiagnosisStatus.timeout) {
                      return _RecordMessage(
                        icon: Icons.error_outline_rounded,
                        message: report.errorMessage.isEmpty
                            ? 'AI 服务暂时不可用，请稍后重试'
                            : report.errorMessage,
                        actionLabel: '刷新状态',
                        onAction: () => setState(() => _report = _load()),
                      );
                    }
                    return AiDiagnosisReportContent(
                      report: report,
                      config: AiDiagnosisConfig.fallback,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: _recordCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RecordIcon(
                icon: _detailSectionIcon(title),
                size: 34,
                iconSize: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _recordText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: _recordBorder),
          ...children.expand((child) => [child, const SizedBox(height: 10)]),
        ],
      ),
    );
  }
}

class _RecordField extends StatelessWidget {
  const _RecordField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(label, style: const TextStyle(color: _recordMuted)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: _recordText, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _RecordMessage extends StatelessWidget {
  const _RecordMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: _recordMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _recordMuted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _recordPrimary,
              ),
            )
          : const Icon(Icons.expand_more),
      label: const Text('加载更多'),
    );
  }
}

class _RecordAvatar extends StatelessWidget {
  const _RecordAvatar({
    required this.imageUrl,
    required this.fallbackIcon,
    required this.size,
  });

  final String imageUrl;
  final IconData fallbackIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveAssetUrl(imageUrl);
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: _recordPrimarySoft,
        child: resolved.isEmpty
            ? Icon(fallbackIcon, color: _recordPrimary, size: size * 0.52)
            : Image.network(
                resolved,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  fallbackIcon,
                  color: _recordPrimary,
                  size: size * 0.52,
                ),
              ),
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return '未记录';
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime value) {
  return '${_formatDate(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

Color _healthTypeColor(HealthAppointmentType type) => switch (type) {
  HealthAppointmentType.vaccine => _recordPrimary,
  HealthAppointmentType.deworming => const Color(0xFF21A675),
  HealthAppointmentType.checkup => const Color(0xFFFF8C78),
};

IconData _healthTypeIcon(HealthAppointmentType type) => switch (type) {
  HealthAppointmentType.vaccine => Icons.vaccines_outlined,
  HealthAppointmentType.deworming => Icons.bug_report_outlined,
  HealthAppointmentType.checkup => Icons.monitor_heart_outlined,
};

String _healthMetricStatus(
  HealthAppointmentType type,
  HealthMetric metric, {
  required bool overdue,
}) {
  if (metric.count == 0) {
    return switch (type) {
      HealthAppointmentType.vaccine => '暂无接种记录',
      HealthAppointmentType.deworming => '暂无驱虫记录',
      HealthAppointmentType.checkup => '暂无体检记录',
    };
  }
  if (overdue) {
    return switch (type) {
      HealthAppointmentType.vaccine => '接种时间已到',
      HealthAppointmentType.deworming => '驱虫时间已到',
      HealthAppointmentType.checkup => '体检时间已到',
    };
  }
  return switch (type) {
    HealthAppointmentType.vaccine => '接种计划正常',
    HealthAppointmentType.deworming => '驱虫计划正常',
    HealthAppointmentType.checkup => '体检计划正常',
  };
}

String _healthDateLabel(HealthAppointmentType type, {required bool next}) {
  return switch ((type, next)) {
    (HealthAppointmentType.vaccine, false) => '最近接种',
    (HealthAppointmentType.vaccine, true) => '下次接种',
    (HealthAppointmentType.deworming, false) => '最近驱虫',
    (HealthAppointmentType.deworming, true) => '下次驱虫',
    (HealthAppointmentType.checkup, false) => '最近体检',
    (HealthAppointmentType.checkup, true) => '下次体检',
  };
}

String _carePlanEmptyMessage(PetCarePlanState state) {
  return switch (state.status) {
    CarePlanStatus.generating => '护理建议正在生成',
    CarePlanStatus.failed when state.error.isNotEmpty =>
      '护理建议生成失败：${state.error}',
    CarePlanStatus.failed => '护理建议生成失败',
    CarePlanStatus.notGenerated || CarePlanStatus.completed => '暂无护理建议',
  };
}

String _petAge(DateTime? birthDate) {
  if (birthDate == null) return '年龄未知';
  final now = DateTime.now();
  var months = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
  if (now.day < birthDate.day) months--;
  if (months < 0) return '年龄未知';
  if (months < 12) return '$months 个月';
  final years = months ~/ 12;
  final remainder = months % 12;
  return remainder == 0 ? '$years 岁' : '$years 岁 $remainder 个月';
}

IconData _detailSectionIcon(String title) => switch (title) {
  '档案信息' => Icons.event_note_outlined,
  '详细内容' => Icons.article_outlined,
  '备注' => Icons.notes_outlined,
  '问诊概况' => Icons.assignment_outlined,
  '基础指标' => Icons.monitor_heart_outlined,
  '西医分析' => Icons.medical_information_outlined,
  '用药建议' => Icons.medication_outlined,
  '中医分析' => Icons.spa_outlined,
  '异常信息' => Icons.error_outline_rounded,
  _ => Icons.description_outlined,
};
