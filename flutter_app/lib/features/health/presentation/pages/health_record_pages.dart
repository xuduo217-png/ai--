import 'package:flutter/material.dart';

import '../../../../core/media/route_aware_video_surface.dart';
import '../../../emergency/presentation/widgets/aid_guide_rich_content.dart';
import '../../../pets/domain/pet_models.dart';
import '../../domain/health_models.dart';
import 'health_page.dart';

class HealthRecordListPage extends StatefulWidget {
  const HealthRecordListPage({
    super.key,
    required this.gateway,
    required this.pet,
  });

  final HealthGateway gateway;
  final Pet pet;

  @override
  State<HealthRecordListPage> createState() => _HealthRecordListPageState();
}

class _HealthRecordListPageState extends State<HealthRecordListPage> {
  late Future<AppointmentPage> _records;
  HealthAppointmentType? _filterType;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _records = widget.gateway.loadAppointments(
      petId: widget.pet.id,
      pageSize: 100,
      type: _filterType,
      status: HealthAppointmentStatus.completed,
    );
  }

  void _changeFilter(HealthAppointmentType? type) {
    if (_filterType == type) return;
    setState(() {
      _filterType = type;
      _reload();
    });
  }

  Future<void> _refresh() async {
    setState(_reload);
    try {
      await _records;
    } on Object {
      // FutureBuilder renders the retry state.
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
          centerTitle: true,
          title: Text(
            '${widget.pet.name}的健康档案',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Column(
          children: [
            _RecordFilterBar(selected: _filterType, onSelected: _changeFilter),
            Expanded(
              child: FutureBuilder<AppointmentPage>(
                future: _records,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00C853),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return _RecordError(onRetry: () => setState(_reload));
                  }
                  final records = snapshot.data?.items ?? const [];
                  if (records.isEmpty) {
                    return _HealthRecordEmpty(onRefresh: _refresh);
                  }
                  return RefreshIndicator(
                    color: healthPrimary,
                    onRefresh: _refresh,
                    child: ListView.builder(
                      key: const ValueKey('health-record-list-scroll'),
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      itemCount: records.length,
                      itemBuilder: (context, index) => _HealthRecordListItem(
                        record: records[index],
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => HealthRecordDetailPage(
                              gateway: widget.gateway,
                              appointmentId: records[index].id,
                              initialRecord: records[index],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordFilterBar extends StatelessWidget {
  const _RecordFilterBar({required this.selected, required this.onSelected});

  final HealthAppointmentType? selected;
  final ValueChanged<HealthAppointmentType?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('health-record-filters'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            for (var index = 0; index < _recordFilters.length; index++) ...[
              if (index > 0) const SizedBox(width: 3),
              Expanded(
                child: _RecordFilterTab(
                  filter: _recordFilters[index],
                  selected: selected == _recordFilters[index].type,
                  onTap: () => onSelected(_recordFilters[index].type),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordFilterTab extends StatelessWidget {
  const _RecordFilterTab({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final _RecordFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        key: ValueKey('health-record-filter-${filter.key}'),
        color: selected ? healthPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              filter.label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF6B7280),
                fontSize: 14,
                height: 18 / 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HealthRecordListItem extends StatelessWidget {
  const _HealthRecordListItem({required this.record, required this.onTap});

  final HealthAppointment record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('health-record-list-item-${record.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Row(
              children: [
                _RecordTypeIcon(type: record.type),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.operationContent.trim().isEmpty
                            ? '未填写操作内容'
                            : record.operationContent,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _recordMeta(record),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                          height: 15 / 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  '›',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 36,
                    height: 1,
                    fontWeight: FontWeight.w300,
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

class _RecordTypeIcon extends StatelessWidget {
  const _RecordTypeIcon({required this.type});

  final HealthAppointmentType type;

  @override
  Widget build(BuildContext context) {
    final (backgroundColor, foregroundColor, icon) = switch (type) {
      HealthAppointmentType.vaccine => (
        const Color(0xFFEAF2FF),
        const Color(0xFF5B9DF8),
        Icons.vaccines_rounded,
      ),
      HealthAppointmentType.deworming => (
        const Color(0xFFFFF3E9),
        const Color(0xFFFF8A3D),
        Icons.medication_rounded,
      ),
      HealthAppointmentType.checkup => (
        const Color(0xFFF6EBFF),
        const Color(0xFFB36CF4),
        Icons.assignment_turned_in_rounded,
      ),
    };
    return Container(
      key: ValueKey('health-record-type-icon-${type.wireValue}'),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(7),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: foregroundColor, size: 18),
    );
  }
}

class _HealthRecordEmpty extends StatelessWidget {
  const _HealthRecordEmpty({required this.onRefresh});

  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: healthPrimary,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          key: const ValueKey('health-record-list-empty'),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: constraints.maxHeight,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.medical_services,
                    size: 64,
                    color: Color(0xFF9CA3AF),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '暂无健康档案记录',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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

class _RecordFilter {
  const _RecordFilter(this.key, this.label, this.type);

  final String key;
  final String label;
  final HealthAppointmentType? type;
}

const _recordFilters = [
  _RecordFilter('all', '全部', null),
  _RecordFilter('vaccine', '疫苗', HealthAppointmentType.vaccine),
  _RecordFilter('deworming', '驱虫', HealthAppointmentType.deworming),
  _RecordFilter('checkup', '体检', HealthAppointmentType.checkup),
];

String _recordMeta(HealthAppointment record) {
  final values = <String>[
    record.appointmentDate,
    switch (record.type) {
      HealthAppointmentType.vaccine => '疫苗',
      HealthAppointmentType.deworming => '驱虫',
      HealthAppointmentType.checkup => '体检',
    },
    if (record.doctorName.trim().isNotEmpty) record.doctorName,
  ];
  return values.join(' · ');
}

class HealthRecordDetailPage extends StatefulWidget {
  const HealthRecordDetailPage({
    super.key,
    required this.gateway,
    required this.appointmentId,
    this.initialRecord,
  });

  final HealthGateway gateway;
  final int appointmentId;
  final HealthAppointment? initialRecord;

  @override
  State<HealthRecordDetailPage> createState() => _HealthRecordDetailPageState();
}

class _HealthRecordDetailPageState extends State<HealthRecordDetailPage> {
  late Future<HealthAppointment> _record;

  @override
  void initState() {
    super.initState();
    _record = _loadRecord();
  }

  Future<HealthAppointment> _loadRecord() async {
    try {
      return await widget.gateway.loadAppointment(widget.appointmentId);
    } on Object {
      final initialRecord = widget.initialRecord;
      if (initialRecord != null) return initialRecord;
      rethrow;
    }
  }

  void _retry() {
    setState(() => _record = _loadRecord());
  }

  @override
  Widget build(BuildContext context) {
    return VideoRoutePopScope<void>(
      child: DecoratedBox(
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
            centerTitle: true,
            title: const Text(
              '健康档案详情',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: FutureBuilder<HealthAppointment>(
            future: _record,
            initialData: widget.initialRecord,
            builder: (context, snapshot) {
              final record = snapshot.data;
              if (record == null &&
                  snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: healthPrimary),
                );
              }
              if (record == null) return _RecordError(onRetry: _retry);
              return _HealthRecordDetail(record: record);
            },
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
    return ListView(
      key: const ValueKey('health-record-detail-scroll'),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RecordDetailCard(
                  key: const ValueKey('health-record-type-card'),
                  child: Row(
                    children: [
                      _RecordTypeIcon(type: record.type),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          record.type.label,
                          style: const TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _RecordDetailCard(
                  key: const ValueKey('health-record-info-card'),
                  child: Column(
                    children: [
                      _RecordLine(label: '预约日期', value: record.appointmentDate),
                      _RecordLine(label: '预约时间', value: record.timeSlot),
                      if (record.hospital != null)
                        _RecordLine(label: '医院', value: record.hospital!.name),
                      if (record.doctorName.trim().isNotEmpty)
                        _RecordLine(label: '医生', value: record.doctorName),
                      _RecordLine(
                        label: '操作内容',
                        value: record.operationContent.trim().isEmpty
                            ? '未填写操作内容'
                            : record.operationContent,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                if (record.detailContent.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _RecordDetailCard(
                    key: const ValueKey('health-record-detail-card'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _RecordSectionTitle('详细内容'),
                        const SizedBox(height: 10),
                        AidGuideRichContent(content: record.detailContent),
                      ],
                    ),
                  ),
                ],
                if (record.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _RecordDetailCard(
                    key: const ValueKey('health-record-notes-card'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _RecordSectionTitle('备注'),
                        const SizedBox(height: 10),
                        SelectableText(
                          record.notes,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecordDetailCard extends StatelessWidget {
  const _RecordDetailCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _RecordSectionTitle extends StatelessWidget {
  const _RecordSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF1F2937),
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _RecordLine extends StatelessWidget {
  const _RecordLine({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordError extends StatelessWidget {
  const _RecordError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('健康档案加载失败'),
          const SizedBox(height: 10),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
