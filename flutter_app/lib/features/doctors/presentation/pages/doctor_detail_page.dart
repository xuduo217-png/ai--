import 'dart:async';

import 'package:flutter/material.dart';

import '../../../health/domain/health_models.dart';
import '../../domain/doctor_models.dart';
import '../doctor_directory_controller.dart';

class DoctorDetailPage extends StatefulWidget {
  const DoctorDetailPage({
    super.key,
    required this.gateway,
    required this.doctorId,
    required this.onConsult,
    this.consultationGateway,
    this.authenticated = true,
    this.onOpenConsultation,
    this.onOpenAllConsultations,
    this.onLoginRequired,
  });

  final DoctorDirectoryGateway gateway;
  final int doctorId;
  final ValueChanged<DoctorProfile> onConsult;
  final HealthGateway? consultationGateway;
  final bool authenticated;
  final ValueChanged<HealthConsultation>? onOpenConsultation;
  final VoidCallback? onOpenAllConsultations;
  final ValueChanged<String>? onLoginRequired;

  @override
  State<DoctorDetailPage> createState() => _DoctorDetailPageState();
}

class _DoctorDetailPageState extends State<DoctorDetailPage> {
  late final DoctorDetailController _controller;
  List<HealthConsultation> _consultations = const [];
  bool _consultationsLoading = false;
  String? _consultationsError;

  @override
  void initState() {
    super.initState();
    _controller = DoctorDetailController(
      gateway: widget.gateway,
      doctorId: widget.doctorId,
    );
    unawaited(_controller.load());
    if (widget.authenticated && widget.consultationGateway != null) {
      unawaited(_loadConsultations());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final doctor = _controller.doctor;
        return Scaffold(
          key: const ValueKey('doctor-detail-page'),
          backgroundColor: const Color(0xFFF6F8FC),
          appBar: doctor == null
              ? AppBar(
                  backgroundColor: const Color(0xFFF6F8FC),
                  surfaceTintColor: Colors.transparent,
                )
              : null,
          body: _controller.loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6B84F7)),
                )
              : doctor == null
              ? _buildError()
              : _buildContent(doctor),
          bottomNavigationBar: doctor == null
              ? null
              : SafeArea(
                  top: false,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        key: const ValueKey('doctor-detail-consult'),
                        onPressed: () => widget.onConsult(doctor),
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: const Text('开始咨询'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6B84F7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF6464),
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              _controller.errorMessage ?? '医生不存在',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              key: const ValueKey('doctor-detail-retry'),
              onPressed: _controller.load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(DoctorProfile doctor) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 268,
          pinned: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            background: _DoctorHeroImage(doctor: doctor),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        doctor.name,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (doctor.online)
                      const _DetailBadge(
                        text: '在线',
                        background: Color(0xFFE7F8F1),
                        foreground: Color(0xFF16866B),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _DetailBadge(
                      text: '${doctor.experience}年经验',
                      background: const Color(0xFFFFF3DC),
                      foreground: const Color(0xFFB76800),
                    ),
                    if (doctor.isGold)
                      const _DetailBadge(
                        text: '金牌医生',
                        background: Color(0xFFFFF4CC),
                        foreground: Color(0xFFA76300),
                        icon: Icons.workspace_premium_rounded,
                      ),
                    _DetailBadge(
                      text: '接单 ${doctor.consultationCount} 次',
                      background: const Color(0xFFEAF0FF),
                      foreground: const Color(0xFF526DDE),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _DoctorStats(doctor: doctor),
                if (doctor.hospitalName != null ||
                    doctor.departmentName != null) ...[
                  const SizedBox(height: 24),
                  const Text(
                    '执业信息',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (doctor.hospitalName case final hospital?)
                    _InfoLine(
                      icon: Icons.local_hospital_outlined,
                      text: hospital,
                    ),
                  if (doctor.departmentName case final department?)
                    _InfoLine(
                      icon: Icons.medical_services_outlined,
                      text: department,
                    ),
                ],
                const SizedBox(height: 24),
                const Text(
                  '医生简介',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  doctor.description,
                  style: const TextStyle(
                    color: Color(0xFF5D6673),
                    fontSize: 15,
                    height: 1.65,
                  ),
                ),
                if (widget.consultationGateway != null) ...[
                  const SizedBox(height: 26),
                  _buildConsultationHistory(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadConsultations() async {
    final gateway = widget.consultationGateway;
    if (gateway == null || !widget.authenticated) return;
    if (mounted) {
      setState(() {
        _consultationsLoading = true;
        _consultationsError = null;
      });
    }
    try {
      final result = await gateway.loadHealthConsultations(
        doctorId: widget.doctorId,
        page: 1,
        pageSize: 3,
      );
      if (!mounted) return;
      setState(() {
        _consultations = result.items;
        _consultationsLoading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _consultationsLoading = false;
        _consultationsError = '历史咨询加载失败，请稍后重试';
      });
    }
  }

  Widget _buildConsultationHistory() {
    final more = widget.onOpenAllConsultations;
    return Column(
      key: const ValueKey('doctor-consultation-history-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '历史咨询',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            if (more != null)
              TextButton(
                key: const ValueKey('doctor-consultation-history-more'),
                onPressed: widget.authenticated
                    ? more
                    : () => widget.onLoginRequired?.call('登录后即可查看历史咨询'),
                child: const Text('查看全部'),
              ),
          ],
        ),
        if (!widget.authenticated)
          _ConsultationHistoryState(
            icon: Icons.lock_outline_rounded,
            title: '登录后查看与该医生的历史咨询',
            onRetry: widget.onLoginRequired == null
                ? null
                : () => widget.onLoginRequired!.call('登录后即可查看历史咨询'),
          )
        else if (_consultationsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF6B84F7),
              ),
            ),
          )
        else if (_consultationsError != null)
          _ConsultationHistoryState(
            icon: Icons.cloud_off_outlined,
            title: _consultationsError!,
            onRetry: _loadConsultations,
          )
        else if (_consultations.isEmpty)
          const _ConsultationHistoryState(
            icon: Icons.chat_bubble_outline_rounded,
            title: '暂无历史咨询',
          )
        else
          Column(
            children: [
              for (final consultation in _consultations)
                _DoctorConsultationCard(
                  consultation: consultation,
                  onTap: widget.onOpenConsultation == null
                      ? null
                      : () => widget.onOpenConsultation!(consultation),
                ),
            ],
          ),
      ],
    );
  }
}

class _ConsultationHistoryState extends StatelessWidget {
  const _ConsultationHistoryState({
    required this.icon,
    required this.title,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF98A2B3)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Color(0xFF667085)),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _DoctorConsultationCard extends StatelessWidget {
  const _DoctorConsultationCard({
    required this.consultation,
    required this.onTap,
  });

  final HealthConsultation consultation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = consultation.isActive;
    final statusColor = active
        ? const Color(0xFF16866B)
        : const Color(0xFF98A2B3);
    final time = consultation.lastMessageAt ?? consultation.paidAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey('doctor-consultation-${consultation.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 21,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        consultation.lastMessage?.trim().isNotEmpty == true
                            ? consultation.lastMessage!
                            : '暂无消息记录',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF344054),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        time == null ? '暂无时间' : _consultationDateLabel(time),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF98A2B3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  active ? '服务中' : '已结束',
                  style: TextStyle(fontSize: 12, color: statusColor),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFF98A2B3),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _consultationDateLabel(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

class _DoctorHeroImage extends StatelessWidget {
  const _DoctorHeroImage({required this.doctor});

  final DoctorProfile doctor;

  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: Color(0xFFEAF0F8),
      child: Center(
        child: Icon(Icons.person_rounded, size: 112, color: Color(0xFF9AA5B5)),
      ),
    );
    if (doctor.avatarUrl.isEmpty) return fallback;
    return Image.network(
      doctor.avatarUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _DetailBadge extends StatelessWidget {
  const _DetailBadge({
    required this.text,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String text;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon case final icon?) ...[
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorStats extends StatelessWidget {
  const _DoctorStats({required this.doctor});

  final DoctorProfile doctor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatItem(
            value: doctor.rating.toStringAsFixed(1),
            label: '综合评分',
          ),
        ),
        const SizedBox(height: 42, child: VerticalDivider()),
        Expanded(
          child: _StatItem(value: '${doctor.consultationCount}', label: '咨询次数'),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFF526DDE),
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(color: Color(0xFF7B8491), fontSize: 12),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B84F7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF5D6673), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
