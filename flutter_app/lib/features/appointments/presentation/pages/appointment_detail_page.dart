import 'package:flutter/material.dart';

import '../../domain/appointment_models.dart';

class AppointmentDetailPage extends StatefulWidget {
  const AppointmentDetailPage({
    super.key,
    required this.gateway,
    required this.appointmentId,
  });

  final AppointmentGateway gateway;
  final int appointmentId;

  @override
  State<AppointmentDetailPage> createState() => _AppointmentDetailPageState();
}

class _AppointmentDetailPageState extends State<AppointmentDetailPage> {
  late Future<AppointmentDetail> _appointment;

  @override
  void initState() {
    super.initState();
    _appointment = widget.gateway.loadAppointment(widget.appointmentId);
  }

  void _retry() {
    setState(() {
      _appointment = widget.gateway.loadAppointment(widget.appointmentId);
    });
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
          centerTitle: true,
          title: const Text(
            '预约详情',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: FutureBuilder<AppointmentDetail>(
          future: _appointment,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final appointment = snapshot.data;
            if (appointment == null) {
              return _AppointmentError(onRetry: _retry);
            }
            return _AppointmentContent(appointment: appointment);
          },
        ),
      ),
    );
  }
}

class _AppointmentContent extends StatelessWidget {
  const _AppointmentContent({required this.appointment});

  final AppointmentDetail appointment;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(appointment.status);
    return ListView(
      key: const ValueKey('appointment-detail-scroll'),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: const ValueKey('appointment-status'),
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _statusIcon(appointment.status),
                        size: 44,
                        color: statusColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        appointment.status.label,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DetailSection(
                  title: '预约信息',
                  children: [
                    _DetailLine(label: '服务类型', value: appointment.type.label),
                    _DetailLine(
                      label: '预约时间',
                      value: _formatDateTime(appointment.appointmentTime),
                    ),
                    if (appointment.petName.isNotEmpty)
                      _DetailLine(label: '宠物', value: appointment.petName),
                    if (appointment.hospitalName.isNotEmpty)
                      _DetailLine(label: '医院', value: appointment.hospitalName),
                    if (appointment.doctorName.isNotEmpty)
                      _DetailLine(
                        label: '医生',
                        value: appointment.doctorSpecialty.isEmpty
                            ? appointment.doctorName
                            : '${appointment.doctorName} · ${appointment.doctorSpecialty}',
                      ),
                    if (appointment.nextAppointmentTime case final nextTime?)
                      _DetailLine(
                        label: '下次预约',
                        value: _formatDateTime(nextTime),
                      ),
                  ],
                ),
                if (appointment.hospitalAddress.isNotEmpty ||
                    appointment.hospitalPhone.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailSection(
                    title: '医院信息',
                    children: [
                      if (appointment.hospitalAddress.isNotEmpty)
                        _DetailLine(
                          label: '地址',
                          value: appointment.hospitalAddress,
                        ),
                      if (appointment.hospitalPhone.isNotEmpty)
                        _DetailLine(
                          label: '电话',
                          value: appointment.hospitalPhone,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                _DetailSection(
                  title: '诊疗记录',
                  children: [
                    _DetailLine(
                      label: '症状描述',
                      value: _fallback(appointment.symptoms),
                    ),
                    _DetailLine(
                      label: '诊断结果',
                      value: _fallback(appointment.diagnosis),
                    ),
                    _DetailLine(
                      label: '治疗方案',
                      value: _fallback(appointment.treatment),
                    ),
                    _DetailLine(
                      label: '备注',
                      value: _fallback(appointment.notes),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1F2937),
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

class _AppointmentError extends StatelessWidget {
  const _AppointmentError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_busy_outlined,
            size: 48,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 12),
          const Text('预约信息加载失败'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

String _fallback(String value) => value.isEmpty ? '暂无' : value;

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

Color _statusColor(AppointmentStatus status) => switch (status) {
  AppointmentStatus.pending => const Color(0xFFC87516),
  AppointmentStatus.confirmed => const Color(0xFF2563EB),
  AppointmentStatus.inProgress => const Color(0xFF0F766E),
  AppointmentStatus.completed => const Color(0xFF15803D),
  AppointmentStatus.cancelled ||
  AppointmentStatus.noShow => const Color(0xFF6B7280),
};

IconData _statusIcon(AppointmentStatus status) => switch (status) {
  AppointmentStatus.pending => Icons.schedule_rounded,
  AppointmentStatus.confirmed => Icons.event_available_rounded,
  AppointmentStatus.inProgress => Icons.medical_services_outlined,
  AppointmentStatus.completed => Icons.check_circle_outline_rounded,
  AppointmentStatus.cancelled => Icons.event_busy_outlined,
  AppointmentStatus.noShow => Icons.person_off_outlined,
};
