import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/doctor_models.dart';
import '../../../health/domain/health_models.dart';
import '../doctor_directory_controller.dart';
import 'doctor_detail_page.dart';

class DoctorListPage extends StatefulWidget {
  const DoctorListPage({
    super.key,
    required this.gateway,
    required this.goldOnly,
    required this.onConsult,
    this.consultationGateway,
    this.authenticated = true,
    this.onOpenConsultation,
    this.onOpenAllConsultations,
    this.onLoginRequired,
  });

  final DoctorDirectoryGateway gateway;
  final bool goldOnly;
  final ValueChanged<DoctorProfile> onConsult;
  final HealthGateway? consultationGateway;
  final bool authenticated;
  final ValueChanged<HealthConsultation>? onOpenConsultation;
  final ValueChanged<int>? onOpenAllConsultations;
  final ValueChanged<String>? onLoginRequired;

  @override
  State<DoctorListPage> createState() => _DoctorListPageState();
}

class _DoctorListPageState extends State<DoctorListPage> {
  late final DoctorDirectoryController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = DoctorDirectoryController(
      gateway: widget.gateway,
      goldOnly: widget.goldOnly,
    );
    _scrollController.addListener(_loadMoreNearEnd);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreNearEnd)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _loadMoreNearEnd() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 180) {
      unawaited(_controller.loadMore());
    }
  }

  Future<void> _openDoctor(DoctorProfile doctor) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DoctorDetailPage(
          gateway: widget.gateway,
          doctorId: doctor.id,
          onConsult: widget.onConsult,
          consultationGateway: widget.consultationGateway,
          authenticated: widget.authenticated,
          onOpenConsultation: widget.onOpenConsultation,
          onOpenAllConsultations: widget.onOpenAllConsultations == null
              ? null
              : () => widget.onOpenAllConsultations!(doctor.id),
          onLoginRequired: widget.onLoginRequired,
        ),
      ),
    );
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
        key: ValueKey(
          widget.goldOnly ? 'gold-doctor-list-page' : 'doctor-list-page',
        ),
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(widget.goldOnly ? '金牌医生' : '全部医生'),
          centerTitle: true,
          toolbarHeight: 52,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.chevron_left_rounded, size: 32),
          ),
          titleTextStyle: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isInitialLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6B84F7)),
      );
    }
    if (_controller.doctors.isEmpty && _controller.errorMessage != null) {
      return _DoctorStateView(
        icon: Icons.cloud_off_outlined,
        title: _controller.errorMessage!,
        action: TextButton.icon(
          key: const ValueKey('doctor-list-retry'),
          onPressed: _controller.retry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重新加载'),
        ),
      );
    }
    if (_controller.doctors.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF6B84F7),
        onRefresh: _controller.refresh,
        child: const _DoctorStateView(
          icon: Icons.medical_services_outlined,
          title: '暂无医生数据',
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF6B84F7),
      onRefresh: _controller.refresh,
      child: ListView.builder(
        key: const ValueKey('doctor-list-scroll-view'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(9, 12, 9, 20),
        itemCount: _controller.doctors.length + 1,
        itemBuilder: (context, index) {
          if (index == _controller.doctors.length) {
            return _ListFooter(controller: _controller);
          }
          final doctor = _controller.doctors[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: DoctorDirectoryCard(
              doctor: doctor,
              onTap: () => _openDoctor(doctor),
              onConsult: () => widget.onConsult(doctor),
            ),
          );
        },
      ),
    );
  }
}

class DoctorDirectoryCard extends StatelessWidget {
  const DoctorDirectoryCard({
    super.key,
    required this.doctor,
    required this.onTap,
    required this.onConsult,
  });

  final DoctorProfile doctor;
  final VoidCallback onTap;
  final VoidCallback onConsult;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('doctor-card-${doctor.id}'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(7),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DoctorAvatar(doctor: doctor, size: 44),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            doctor.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _ExperienceBadge(experience: doctor.experience),
                        if (doctor.isGold) ...[
                          const SizedBox(width: 4),
                          Image.asset(
                            'assets/images/main/main_glod.png',
                            width: 14,
                            height: 14,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doctor.specialty.isEmpty ? '专业宠物医生' : doctor.specialty,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                key: ValueKey('doctor-action-${doctor.id}'),
                width: 68,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: doctor.price,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(
                              text: '/次',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    _ConsultButton(doctorId: doctor.id, onPressed: onConsult),
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

class _DoctorAvatar extends StatelessWidget {
  const _DoctorAvatar({required this.doctor, required this.size});

  final DoctorProfile doctor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      color: const Color(0xFFEFF3FA),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        color: const Color(0xFF9AA5B5),
        size: size * 0.58,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: doctor.avatarUrl.isEmpty
          ? fallback
          : Image.network(
              doctor.avatarUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

class _ExperienceBadge extends StatelessWidget {
  const _ExperienceBadge({required this.experience});

  final int experience;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = experience >= 10
        ? (const Color(0xFFF3E8FF), const Color(0xFF7C3AED))
        : experience >= 5
        ? (const Color(0xFFFEF3C7), const Color(0xFFD97706))
        : (const Color(0xFFDBEAFE), const Color(0xFF2563EB));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: Text(
          '$experience年经验',
          style: TextStyle(
            color: foreground,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ConsultButton extends StatelessWidget {
  const _ConsultButton({required this.doctorId, required this.onPressed});

  final int doctorId;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        width: 68,
        height: 26,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7E97FA), Color(0xFF6480F9), Color(0xFF6481F9)],
          ),
        ),
        child: InkWell(
          key: ValueKey('doctor-consult-$doctorId'),
          onTap: onPressed,
          child: const Center(
            child: Text(
              '去咨询',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});

  final DoctorDirectoryController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (controller.loadMoreError != null) {
      return Center(
        child: TextButton.icon(
          key: const ValueKey('doctor-list-load-more-retry'),
          onPressed: controller.loadMore,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('加载更多失败，重试'),
        ),
      );
    }
    if (!controller.hasMore) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Center(
          child: Text(
            '没有更多数据了',
            style: TextStyle(color: Color(0xFF8A939E), fontSize: 12),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}

class _DoctorStateView extends StatelessWidget {
  const _DoctorStateView({
    required this.icon,
    required this.title,
    this.action,
  });

  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 54, color: const Color(0xFF98A0AA)),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 15,
                    ),
                  ),
                  if (action case final action?) ...[
                    const SizedBox(height: 10),
                    action,
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
