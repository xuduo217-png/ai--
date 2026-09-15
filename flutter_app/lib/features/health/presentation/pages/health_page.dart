import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pickers/pickers.dart';
import 'package:flutter_pickers/style/default_style.dart';
import 'package:flutter_pickers/time_picker/model/date_mode.dart';
import 'package:flutter_pickers/time_picker/model/pduration.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

import '../../../pets/domain/pet_models.dart';
import '../../domain/health_models.dart';
import '../health_controller.dart';
import 'care_plan_page.dart';
import 'health_knowledge_pages.dart';
import 'health_record_pages.dart';

const healthGreen = Color(0xFF21A675);
const healthPrimary = Color(0xFF7E97FA);
const healthBackground = Color(0xFFFAFBFF);

/// 必填标记与校验错误统一使用的高亮红，与地址编辑等表单保持一致。
const healthRequired = Color(0xFFEF4444);

class HealthPage extends StatefulWidget {
  const HealthPage({super.key, required this.gateway, this.onOpenPets});

  final HealthGateway gateway;
  final Future<void> Function()? onOpenPets;

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  late final HealthController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HealthController(gateway: widget.gateway);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          title: const Text(
            '宠智灵营养师',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              tooltip: '刷新健康数据',
              onPressed: _controller.refresh,
              color: const Color(0xFF1F2937),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (_controller.loading) {
              return const Center(
                child: CircularProgressIndicator(color: healthPrimary),
              );
            }
            if (_controller.pets.isEmpty) return _buildEmptyPets();
            return RefreshIndicator(
              color: healthPrimary,
              onRefresh: _controller.refresh,
              child: ListView(
                key: const ValueKey('health-home-scroll'),
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                            child: _PetSelector(
                              pets: _controller.pets,
                              selected: _controller.selectedPet!,
                              stats: _controller.stats,
                              loading: _controller.refreshingPet,
                              onSelected: _controller.selectPet,
                              onManagePets: _managePets,
                            ),
                          ),
                          if (_controller.error != null) ...[
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              child: _InlineError(
                                message: _controller.error!,
                                onRetry: _controller.refresh,
                              ),
                            ),
                          ],
                          const SizedBox(height: 13),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: _ReminderPanel(
                              controller: _controller,
                              onAppointment: _openAppointment,
                              onView: _openAppointmentDetail,
                            ),
                          ),
                          const SizedBox(height: 13),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: _FeatureGradientCard(
                              key: const ValueKey('health-care-plan-card'),
                              colors: const [
                                Color(0xFF7E97FA),
                                Color(0xFF6480F9),
                              ],
                              icon: Icons.lightbulb_outline_rounded,
                              heading: '护理建议',
                              description: '根据宠物的健康状况，我们为您定制了专属的护理计划建议',
                              actionLabel: '查看详情',
                              onTap: _openCarePlan,
                            ),
                          ),
                          const SizedBox(height: 13),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: _RecordPreview(
                              records: _controller.completedRecords,
                              onOpenAll: _openHealthRecords,
                              onOpenRecord: _openRecord,
                            ),
                          ),
                          const SizedBox(height: 13),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: _FeatureGradientCard(
                              key: const ValueKey('health-knowledge-card'),
                              colors: const [
                                Color(0xFFF472B6),
                                Color(0xFFC084FC),
                              ],
                              icon: Icons.access_time_rounded,
                              heading: '健康知识',
                              title: '春季宠物护理指南',
                              description: '春天到了，了解如何帮助宠物适应活动季节的变化，预防常见疾病。',
                              actionLabel: '立即阅读',
                              onTap: _openKnowledge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyPets() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets_rounded, size: 54, color: Color(0xFF96A29D)),
            const SizedBox(height: 14),
            const Text(
              '请先添加宠物档案',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('营养师会根据宠物档案提供健康管理建议'),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: widget.onOpenPets == null ? null : _managePets,
              style: FilledButton.styleFrom(backgroundColor: healthPrimary),
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加宠物'),
            ),
            if (_controller.error != null) ...[
              const SizedBox(height: 16),
              Text(_controller.error!, textAlign: TextAlign.center),
              TextButton(
                onPressed: _controller.initialize,
                child: const Text('重新加载'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _managePets() async {
    await widget.onOpenPets?.call();
    if (mounted) await _controller.initialize();
  }

  Future<void> _openAppointment(HealthAppointmentType type) async {
    final request = await showModalBottomSheet<_AppointmentRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AppointmentSheet(
        type: type,
        hospitalsLoader: _controller.loadHospitals,
      ),
    );
    if (request == null || !mounted) return;
    try {
      await _controller.createAppointment(
        type: type,
        hospital: request.hospital,
        date: request.date,
        timeSlot: request.timeSlot,
        notes: request.notes,
      );
      if (mounted) _showMessage('${type.label}预约已提交');
    } on Object {
      if (mounted) _showMessage('预约提交失败，请稍后重试');
    }
  }

  Future<void> _openAppointmentDetail(HealthAppointment appointment) async {
    final shouldCancel = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (_) => _AppointmentDetailSheet(appointment: appointment),
    );
    if (shouldCancel != true || !mounted) return;
    try {
      await _controller.cancelAppointment(appointment.id);
      if (mounted) _showMessage('预约已取消');
    } on Object {
      if (mounted) _showMessage('取消失败，请稍后重试');
    }
  }

  void _openCarePlan() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CarePlanPage(
          gateway: widget.gateway,
          petId: _controller.selectedPet!.id,
        ),
      ),
    );
  }

  void _openHealthRecords() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HealthRecordListPage(
          gateway: widget.gateway,
          pet: _controller.selectedPet!,
        ),
      ),
    );
  }

  void _openRecord(HealthAppointment record) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HealthRecordDetailPage(
          gateway: widget.gateway,
          appointmentId: record.id,
          initialRecord: record,
        ),
      ),
    );
  }

  void _openKnowledge() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HealthKnowledgeListPage(gateway: widget.gateway),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PetSelector extends StatelessWidget {
  const _PetSelector({
    required this.pets,
    required this.selected,
    required this.stats,
    required this.loading,
    required this.onSelected,
    required this.onManagePets,
  });

  final List<Pet> pets;
  final Pet selected;
  final PetHealthStats stats;
  final bool loading;
  final ValueChanged<Pet> onSelected;
  final VoidCallback onManagePets;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('health-pet-card'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showPetSelector(context),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PetAvatar(pet: selected, size: 32),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                selected.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF1F2937),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (loading) ...[
                              const SizedBox(width: 6),
                              const SizedBox.square(
                                dimension: 12,
                                child: CircularProgressIndicator(
                                  color: healthPrimary,
                                  strokeWidth: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${selected.breedLabel} · ${formatPetAge(selected.birthDate)} · ${selected.genderLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const SizedBox.square(
                              dimension: 4,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '体重: ${_formatWeight(selected.weight)}kg',
                              style: const TextStyle(
                                color: Color(0xFF374151),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: healthPrimary),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '切换',
                      style: TextStyle(
                        color: healthPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatItem(
                    icon: Icons.vaccines_outlined,
                    label: '疫苗接种',
                    value: '${stats.vaccine.count}针',
                    color: const Color(0xFF3B82F6),
                  ),
                  _StatItem(
                    icon: Icons.cleaning_services_outlined,
                    label: '驱虫次数',
                    value: '${stats.deworming.count}次',
                    color: const Color(0xFFF97316),
                  ),
                  _StatItem(
                    icon: Icons.fact_check_outlined,
                    label: '体检次数',
                    value: '${stats.checkup.count}次',
                    color: const Color(0xFF22C55E),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPetSelector(BuildContext context) async {
    final selectedId = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '选择宠物',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: pets.length,
                itemBuilder: (context, index) {
                  final pet = pets[index];
                  final active = pet.id == selected.id;
                  return ListTile(
                    leading: _PetAvatar(pet: pet, size: 44),
                    title: Text(
                      pet.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${pet.breedLabel} · ${formatPetAge(pet.birthDate)} · ${pet.genderLabel}',
                    ),
                    trailing: active
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF22C55E),
                          )
                        : null,
                    tileColor: active
                        ? healthPrimary.withValues(alpha: 0.08)
                        : null,
                    onTap: () => Navigator.pop(context, pet.id),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('管理宠物档案'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pop(context, -1),
            ),
          ],
        ),
      ),
    );
    if (selectedId == null) return;
    if (selectedId == -1) {
      onManagePets();
      return;
    }
    onSelected(pets.firstWhere((pet) => pet.id == selectedId));
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 29),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 1),
          Text(value, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}

class _ReminderPanel extends StatelessWidget {
  const _ReminderPanel({
    required this.controller,
    required this.onAppointment,
    required this.onView,
  });

  final HealthController controller;
  final ValueChanged<HealthAppointmentType> onAppointment;
  final ValueChanged<HealthAppointment> onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('health-reminder-card'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.notifications_none_rounded,
                color: healthPrimary,
                size: 24,
              ),
              SizedBox(width: 4),
              Text(
                '健康提醒',
                style: TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          for (
            var index = 0;
            index < HealthAppointmentType.values.length;
            index++
          ) ...[
            _ReminderRow(
              type: HealthAppointmentType.values[index],
              metric: controller.stats.metricFor(
                HealthAppointmentType.values[index],
              ),
              appointment: controller.activeAppointmentFor(
                HealthAppointmentType.values[index],
              ),
              onAppointment: () =>
                  onAppointment(HealthAppointmentType.values[index]),
              onView: onView,
            ),
            if (index < HealthAppointmentType.values.length - 1)
              const Divider(height: 1, color: Color(0xFFEEF2F7)),
          ],
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.type,
    required this.metric,
    required this.appointment,
    required this.onAppointment,
    required this.onView,
  });

  final HealthAppointmentType type;
  final HealthMetric metric;
  final HealthAppointment? appointment;
  final VoidCallback onAppointment;
  final ValueChanged<HealthAppointment> onView;

  @override
  Widget build(BuildContext context) {
    final buttonLabel = _reminderButtonLabel(appointment);
    final buttonColor = _reminderButtonColor(appointment);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2, right: 8),
            decoration: BoxDecoration(
              color: _typeColor(type).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_typeIcon(type), color: _typeColor(type), size: 22),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _reminderTitle(type),
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _reminderDescription(type, metric),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _reminderSubDescription(type, metric),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: appointment == null
                        ? onAppointment
                        : () => onView(appointment!),
                    style: FilledButton.styleFrom(
                      backgroundColor: buttonColor,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      buttonLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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

class _RecordPreview extends StatelessWidget {
  const _RecordPreview({
    required this.records,
    required this.onOpenAll,
    required this.onOpenRecord,
  });

  final List<HealthAppointment> records;
  final VoidCallback onOpenAll;
  final ValueChanged<HealthAppointment> onOpenRecord;

  @override
  Widget build(BuildContext context) {
    final preview = records.take(3).toList(growable: false);
    return Container(
      key: const ValueKey('health-record-card'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '健康档案',
                  style: TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onOpenAll,
                style: TextButton.styleFrom(
                  foregroundColor: healthPrimary,
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('查看全部 ›'),
              ),
            ],
          ),
          if (preview.isEmpty)
            const SizedBox(
              height: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.medical_services_outlined,
                    color: Color(0xFF9CA3AF),
                    size: 24,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '暂无健康档案',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (final record in preview)
                  _RecordItem(record: record, onTap: onOpenRecord),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecordItem extends StatelessWidget {
  const _RecordItem({required this.record, required this.onTap});

  final HealthAppointment record;
  final ValueChanged<HealthAppointment> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => onTap(record),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Row(
              children: [
                Icon(
                  _typeIcon(record.type),
                  color: _typeColor(record.type),
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.operationContent.isEmpty
                            ? record.type.label
                            : record.operationContent,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${record.appointmentDate} · ${record.type.label}',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureGradientCard extends StatelessWidget {
  const _FeatureGradientCard({
    super.key,
    required this.colors,
    required this.icon,
    required this.heading,
    this.title = '',
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  final List<Color> colors;
  final IconData icon;
  final String heading;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: title.isEmpty ? 120 : 146),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 24),
                    const SizedBox(width: 4),
                    Text(
                      heading,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF2F0),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFC83D35)),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
            TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

class _AppointmentRequest {
  const _AppointmentRequest({
    required this.hospital,
    required this.date,
    required this.timeSlot,
    required this.notes,
  });

  final HealthHospital hospital;
  final DateTime date;
  final String timeSlot;
  final String notes;
}

class _AppointmentSheet extends StatefulWidget {
  const _AppointmentSheet({required this.type, required this.hospitalsLoader});

  final HealthAppointmentType type;
  final Future<List<HealthHospital>> Function() hospitalsLoader;

  @override
  State<_AppointmentSheet> createState() => _AppointmentSheetState();
}

class _AppointmentSheetState extends State<_AppointmentSheet> {
  static const _timeSlots = [
    '09:00-10:00',
    '10:00-11:00',
    '11:00-12:00',
    '13:00-14:00',
    '14:00-15:00',
    '15:00-16:00',
    '16:00-17:00',
    '17:00-18:00',
  ];

  late final Future<List<HealthHospital>> _hospitals;
  final TextEditingController _notesController = TextEditingController();
  HealthHospital? _hospital;
  DateTime? _date;
  String? _timeSlot;

  @override
  void initState() {
    super.initState();
    _hospitals = widget.hospitalsLoader();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '预约${widget.type.label}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(_date == null ? '选择预约日期' : formatPetDate(_date!)),
            ),
            const SizedBox(height: 14),
            const Text('时间段', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in _timeSlots)
                  ChoiceChip(
                    label: Text(slot),
                    selected: _timeSlot == slot,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _timeSlot = slot),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<HealthHospital>>(
              future: _hospitals,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return const Text('医院列表加载失败，请关闭后重试');
                }
                final hospitals = snapshot.data ?? const [];
                return InkWell(
                  key: const ValueKey('health-hospital-picker'),
                  onTap: hospitals.isEmpty
                      ? null
                      : () => _openHospitalPicker(hospitals),
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.fromLTRB(16, 14, 8, 14),
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.chevron_right_rounded, size: 22),
                      suffixIconConstraints: BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                    child: Text(
                      _hospital?.name ??
                          (hospitals.isEmpty ? '暂无可预约医院' : '预约医院'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _hospital == null
                            ? const Color(0xFF9298A5)
                            : const Color(0xFF22252B),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesController,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: '备注（选填）',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: _submit, child: const Text('提交预约')),
          ],
        ),
      ),
    );
  }

  void _pickDate() {
    final now = DateTime.now();
    final initialDate = _date ?? now.add(const Duration(days: 1));
    final maxDate = now.add(const Duration(days: 180));
    final style = DefaultPickerStyle(haveRadius: true, title: '选择预约日期')
      ..pickerHeight = 240
      ..pickerTitleHeight = 48
      ..pickerItemHeight = 44
      ..textSize = 14
      ..textColor = const Color(0xFF22252B);

    Pickers.showDatePicker(
      context,
      mode: DateMode.YMD,
      selectDate: PDuration.parse(initialDate),
      minDate: PDuration(year: now.year, month: now.month, day: now.day),
      maxDate: PDuration(
        year: maxDate.year,
        month: maxDate.month,
        day: maxDate.day,
      ),
      pickerStyle: style,
      onConfirm: (value) {
        if (!mounted) return;
        setState(() => _date = DateTime(value.year!, value.month!, value.day!));
      },
    );
  }

  void _openHospitalPicker(List<HealthHospital> hospitals) {
    final options = [
      for (final hospital in hospitals) _HospitalPickerOption(hospital),
    ];
    final selectedOption = _hospital == null
        ? null
        : options.firstWhere((option) => option.hospital.id == _hospital!.id);
    final style = DefaultPickerStyle(haveRadius: true, title: '选择预约医院')
      ..pickerHeight = 240
      ..pickerTitleHeight = 48
      ..pickerItemHeight = 44
      ..textSize = 14
      ..textColor = const Color(0xFF22252B);

    Pickers.showSinglePicker(
      context,
      data: options,
      selectData: selectedOption,
      pickerStyle: style,
      onConfirm: (_, index) {
        if (mounted) setState(() => _hospital = options[index].hospital);
      },
    );
  }

  void _submit() {
    final missingFields = <String>[
      if (_date == null) '预约日期',
      if (_timeSlot == null) '预约时间段',
      if (_hospital == null) '预约医院',
    ];
    if (missingFields.isNotEmpty) {
      FocusScope.of(context).unfocus();
      unawaited(_showIncompletePrompt(missingFields));
      return;
    }
    Navigator.pop(
      context,
      _AppointmentRequest(
        hospital: _hospital!,
        date: _date!,
        timeSlot: _timeSlot!,
        notes: _notesController.text,
      ),
    );
  }

  Future<void> _showIncompletePrompt(List<String> missingFields) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        key: const ValueKey('appointment-incomplete-dialog'),
        icon: const AppDialogIcon(icon: Icons.info_outline_rounded),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: healthPrimary, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '预约信息未填写完整',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Text(
          '请先选择${missingFields.join('、')}，再提交预约。',
          key: const ValueKey('appointment-incomplete-message'),
          style: const TextStyle(
            color: Color(0xFF4B5563),
            fontSize: 15,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _HospitalPickerOption {
  const _HospitalPickerOption(this.hospital);

  final HealthHospital hospital;

  @override
  String toString() => hospital.name;
}

class _AppointmentDetailSheet extends StatelessWidget {
  const _AppointmentDetailSheet({required this.appointment});

  final HealthAppointment appointment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${appointment.type.label}预约',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          _DetailLine(label: '状态', value: appointment.status.label),
          _DetailLine(label: '日期', value: appointment.appointmentDate),
          _DetailLine(label: '时间', value: appointment.timeSlot),
          _DetailLine(label: '医院', value: appointment.hospital?.name ?? '宠物医院'),
          if (appointment.hospital?.address.isNotEmpty == true)
            _DetailLine(label: '地址', value: appointment.hospital!.address),
          if (appointment.notes.isNotEmpty)
            _DetailLine(label: '备注', value: appointment.notes),
          const SizedBox(height: 14),
          if (appointment.isActive)
            OutlinedButton(
              onPressed: () => Navigator.pop(context, true),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('取消预约'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF75807B)),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _PetAvatar extends StatelessWidget {
  const _PetAvatar({required this.pet, required this.size});

  final Pet pet;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = pet.resolvedAvatarUrl();
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
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

IconData _typeIcon(HealthAppointmentType type) => switch (type) {
  HealthAppointmentType.vaccine => Icons.vaccines_outlined,
  HealthAppointmentType.deworming => Icons.shield_outlined,
  HealthAppointmentType.checkup => Icons.health_and_safety_outlined,
};

Color _typeColor(HealthAppointmentType type) => switch (type) {
  HealthAppointmentType.vaccine => const Color(0xFF3B82F6),
  HealthAppointmentType.deworming => const Color(0xFFF97316),
  HealthAppointmentType.checkup => const Color(0xFF22C55E),
};

String _reminderTitle(HealthAppointmentType type) => switch (type) {
  HealthAppointmentType.vaccine => '疫苗提醒',
  HealthAppointmentType.deworming => '驱虫提醒',
  HealthAppointmentType.checkup => '体检提醒',
};

String _reminderDescription(HealthAppointmentType type, HealthMetric metric) {
  if (metric.daysUntilNext != null) {
    return switch (type) {
      HealthAppointmentType.vaccine => '距离下次疫苗接种还有 ${metric.daysUntilNext} 天',
      HealthAppointmentType.deworming => '距离下次驱虫还有 ${metric.daysUntilNext} 天',
      HealthAppointmentType.checkup => '距离下次体检还有 ${metric.daysUntilNext} 天',
    };
  }
  if (type == HealthAppointmentType.vaccine && metric.count > 0) {
    return '已录入 ${metric.count} 针，待设置下次接种时间';
  }
  return switch (type) {
    HealthAppointmentType.vaccine => '未设置下次疫苗接种时间',
    HealthAppointmentType.deworming => '未设置下次驱虫时间',
    HealthAppointmentType.checkup => '未设置下次体检时间',
  };
}

String _reminderSubDescription(
  HealthAppointmentType type,
  HealthMetric metric,
) {
  if (metric.lastAt != null) {
    return switch (type) {
      HealthAppointmentType.vaccine => '上次接种: ${formatPetDate(metric.lastAt!)}',
      HealthAppointmentType.deworming =>
        '上次驱虫: ${formatPetDate(metric.lastAt!)}',
      HealthAppointmentType.checkup => '上次体检: ${formatPetDate(metric.lastAt!)}',
    };
  }
  if (type == HealthAppointmentType.vaccine && metric.count > 0) {
    return '已录入第 ${metric.count} 针，未记录接种时间';
  }
  return switch (type) {
    HealthAppointmentType.vaccine => '暂无接种记录',
    HealthAppointmentType.deworming => '暂无驱虫记录',
    HealthAppointmentType.checkup => '暂无体检记录',
  };
}

String _reminderButtonLabel(HealthAppointment? appointment) =>
    switch (appointment?.status) {
      HealthAppointmentStatus.pending => '待确认',
      HealthAppointmentStatus.confirmed => '查看预约',
      _ => '预约',
    };

Color _reminderButtonColor(HealthAppointment? appointment) =>
    switch (appointment?.status) {
      HealthAppointmentStatus.pending => const Color(0xFFF59E0B),
      HealthAppointmentStatus.confirmed => const Color(0xFF10B981),
      _ => const Color(0xFF3B82F6),
    };

String _formatWeight(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}
