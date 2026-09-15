import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/asset_url_resolver.dart';
import '../../domain/health_models.dart';
import '../health_controller.dart';
import 'health_page.dart';

class ConsultationListPage extends StatefulWidget {
  const ConsultationListPage({
    super.key,
    required this.gateway,
    required this.onOpenConsultation,
    this.doctorId,
  });

  final HealthGateway gateway;
  final ValueChanged<HealthConsultation> onOpenConsultation;
  final int? doctorId;

  @override
  State<ConsultationListPage> createState() => _ConsultationListPageState();
}

class _ConsultationListPageState extends State<ConsultationListPage> {
  late final ConsultationListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConsultationListController(
      gateway: widget.gateway,
      doctorId: widget.doctorId,
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: healthBackground,
      appBar: AppBar(title: const Text('历史咨询')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.error != null) {
            return _ConsultationState(
              icon: Icons.cloud_off_outlined,
              title: _controller.error!,
              onRetry: _controller.load,
            );
          }
          if (_controller.consultations.isEmpty) {
            return const _ConsultationState(
              icon: Icons.chat_bubble_outline_rounded,
              title: '暂无历史咨询',
            );
          }
          return RefreshIndicator(
            onRefresh: _controller.load,
            child: ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: _controller.consultations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final consultation = _controller.consultations[index];
                return _ConsultationTile(
                  consultation: consultation,
                  onTap: () => widget.onOpenConsultation(consultation),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ConsultationTile extends StatelessWidget {
  const _ConsultationTile({required this.consultation, required this.onTap});

  final HealthConsultation consultation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = resolveAssetUrl(consultation.doctorAvatarUrl);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                foregroundImage: avatarUrl.isEmpty
                    ? null
                    : NetworkImage(avatarUrl),
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.medical_services_outlined)
                    : null,
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
                            consultation.doctorName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          consultation.isActive ? '服务中' : '已结束',
                          style: TextStyle(
                            fontSize: 12,
                            color: consultation.isActive
                                ? healthGreen
                                : const Color(0xFF8B9691),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      consultation.lastMessage ?? '暂无消息',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF5F6965)),
                    ),
                    if (consultation.lastMessageAt != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        _dateTimeLabel(consultation.lastMessageAt!),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8B9691),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsultationState extends StatelessWidget {
  const _ConsultationState({
    required this.icon,
    required this.title,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: const Color(0xFF96A29D)),
          const SizedBox(height: 12),
          Text(title),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ],
      ),
    );
  }
}

String _dateTimeLabel(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
