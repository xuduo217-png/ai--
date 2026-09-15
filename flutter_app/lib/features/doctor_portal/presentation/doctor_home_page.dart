import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/messaging/in_app_message_event.dart';
import '../../../core/network/asset_url_resolver.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/consultation_realtime_socket_client.dart';
import '../../chat/domain/chat_models.dart';
import '../../chat/presentation/chat_controller.dart';
import '../../chat/presentation/chat_page.dart';
import '../domain/doctor_portal_models.dart';
import '../navigation/doctor_portal_navigation_runtime.dart';
import 'doctor_portal_controller.dart';
import 'doctor_patient_record_page.dart';

const _doctorPrimary = Color(0xFF2196F3);
const _doctorTextPrimary = Color(0xFF333333);
const _doctorTextSecondary = Color(0xFF666666);
const _doctorTextHint = Color(0xFF999999);
const _doctorDivider = Color(0xFFEEEEEE);
const _doctorButtonBackground = Color(0xFFF3F4F6);
const _doctorSuccess = Color(0xFF4CAF50);
const _doctorWarning = Color(0xFFFFC107);

typedef DoctorRealtimeGatewayFactory = ConsultationRealtimeGateway Function();
typedef DoctorInAppMessageCallback =
    void Function(InAppMessageEvent event, int ownerDoctorId);

double _doctorPx(BuildContext context, num designPixels) {
  final size = MediaQuery.sizeOf(context);
  return (designPixels * size.shortestSide / 750).roundToDouble();
}

double _doctorFont(num fontSize) => fontSize.toDouble();

class DoctorHomePage extends StatefulWidget {
  const DoctorHomePage({
    super.key,
    required this.authController,
    required this.session,
    required this.gateway,
    required this.chatGateway,
    this.connectChatRealtime = true,
    this.realtimeGatewayFactory,
    this.onIncomingMessage,
    this.messageNavigationRuntime,
  });

  final AuthController authController;
  final AuthSession session;
  final DoctorPortalGateway gateway;
  final ChatGateway chatGateway;
  final bool connectChatRealtime;
  final DoctorRealtimeGatewayFactory? realtimeGatewayFactory;
  final DoctorInAppMessageCallback? onIncomingMessage;
  final DoctorPortalNavigationRuntime? messageNavigationRuntime;

  @override
  State<DoctorHomePage> createState() => _DoctorHomePageState();
}

class _DoctorHomePageState extends State<DoctorHomePage>
    with WidgetsBindingObserver {
  late final DoctorConsultationsController _consultationsController;
  late final DoctorIncomeController _incomeController;
  late final DoctorProfileController _profileController;
  StreamSubscription<InAppMessageEvent>? _incomingMessageSubscription;
  int _selectedIndex = 0;

  int get _doctorId => switch (widget.session.profile['id']) {
    final int value => value,
    final num value => value.toInt(),
    final Object value => int.tryParse('$value') ?? 0,
    null => 0,
  };

  String get _currentUserAvatarUrl {
    final value =
        widget.session.profile['avatar'] ?? widget.session.profile['avatarUrl'];
    return value is String ? value.trim() : '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _consultationsController = DoctorConsultationsController(
      gateway: widget.gateway,
      doctorId: _doctorId,
      realtime: widget.connectChatRealtime
          ? widget.realtimeGatewayFactory?.call()
          : null,
      onSessionRevoked: widget.authController.invalidateLocalSession,
    );
    _incomeController = DoctorIncomeController(gateway: widget.gateway);
    _profileController = DoctorProfileController(gateway: widget.gateway);
    widget.messageNavigationRuntime?.bindConsultationHandler(
      _openConsultationByConversationId,
    );
    _incomingMessageSubscription = _consultationsController
        .incomingMessageEvents
        .listen((event) => widget.onIncomingMessage?.call(event, _doctorId));
    unawaited(_consultationsController.start());
  }

  @override
  void didUpdateWidget(covariant DoctorHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageNavigationRuntime == widget.messageNavigationRuntime) {
      return;
    }
    oldWidget.messageNavigationRuntime?.unbindConsultationHandler();
    widget.messageNavigationRuntime?.bindConsultationHandler(
      _openConsultationByConversationId,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_consultationsController.resume());
      switch (_selectedIndex) {
        case 0:
          break;
        case 1:
          unawaited(_incomeController.load(refresh: true));
        case 2:
          unawaited(_profileController.load());
      }
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_consultationsController.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.messageNavigationRuntime?.unbindConsultationHandler();
    unawaited(_incomingMessageSubscription?.cancel());
    _consultationsController.dispose();
    _incomeController.dispose();
    _profileController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    if (index == 1 && !_incomeController.hasLoaded) {
      _incomeController.load();
    }
    if (index == 2 && !_profileController.hasLoaded) {
      _profileController.load();
    }
  }

  Future<void> _openConsultation(DoctorConsultation consultation) async {
    final active = consultation.isActive;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (chatContext) => ChatPage(
          controller: ChatController(
            gateway: widget.chatGateway,
            target: ChatTarget(
              doctorId: _doctorId,
              name: consultation.userName,
              avatarUrl: resolveAssetUrl(consultation.userAvatarUrl),
            ),
            currentUserId: _doctorId,
            currentUserType: 'doctor',
            currentUserAvatar: _currentUserAvatarUrl,
            receiverId: consultation.userId,
            accessToken: widget.session.accessToken,
            viewOnly: !active,
            connectRealtime: widget.connectChatRealtime,
            extendSessionRequest:
                widget.gateway is DoctorConsultationExtensionGateway
                ? ({
                    required String conversationId,
                    required int minutes,
                    required String idempotencyKey,
                  }) => (widget.gateway as DoctorConsultationExtensionGateway)
                      .extendConsultation(
                        conversationId: conversationId,
                        minutes: minutes,
                        idempotencyKey: idempotencyKey,
                      )
                : null,
            headerStatusText: active ? '正在咨询' : '咨询已结束',
            headerStatusActive: active,
            consultationSession: _consultationsController,
            bootstrapLoader: ({required refresh}) =>
                widget.gateway.loadDoctorChat(
                  consultation: consultation,
                  doctorId: _doctorId,
                ),
          ),
          onHeaderTap: () {
            Navigator.of(chatContext).push<void>(
              MaterialPageRoute(
                builder: (_) => DoctorPatientRecordPage(
                  gateway: widget.gateway,
                  consultation: consultation,
                  currentDoctorAvatarUrl: _currentUserAvatarUrl,
                ),
              ),
            );
          },
        ),
      ),
    );
    if (mounted) await _consultationsController.load(refresh: true);
  }

  Future<bool> _openConsultationByConversationId(String conversationId) async {
    final consultation = await _consultationsController.resolveConsultation(
      conversationId,
    );
    if (!mounted || consultation == null) return false;
    unawaited(_openConsultation(consultation));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFF),
      body: DecoratedBox(
        key: const ValueKey('doctor-portal-background'),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
          ),
        ),
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            DoctorConsultationsView(
              controller: _consultationsController,
              onOpenConsultation: _openConsultation,
            ),
            DoctorIncomeView(controller: _incomeController),
            DoctorProfileView(
              controller: _profileController,
              authController: widget.authController,
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _consultationsController,
        builder: (context, _) => _DoctorTabBar(
          selectedIndex: _selectedIndex,
          consultationUnreadCount: _consultationsController.totalUnreadCount,
          onSelected: _selectTab,
        ),
      ),
    );
  }
}

class DoctorConsultationsView extends StatelessWidget {
  const DoctorConsultationsView({
    super.key,
    required this.controller,
    required this.onOpenConsultation,
  });

  final DoctorConsultationsController controller;
  final ValueChanged<DoctorConsultation> onOpenConsultation;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Column(
            children: [
              const _DoctorHeader(title: '咨询管理'),
              _ConsultationStatusFilter(controller: controller),
              Expanded(
                child: RefreshIndicator(
                  color: _doctorPrimary,
                  onRefresh: () => controller.load(refresh: true),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: _consultationSlivers(context),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _consultationSlivers(BuildContext context) {
    if (controller.loading && controller.consultations.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _LoadingState(label: '加载中...'),
        ),
      ];
    }
    if (controller.consultations.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ConsultationEmptyState(
            message: controller.error ?? '暂无咨询记录',
            onRetry: controller.error == null ? null : controller.load,
          ),
        ),
      ];
    }
    final bottom =
        MediaQuery.paddingOf(context).bottom + _doctorPx(context, 20);
    return [
      SliverList.builder(
        itemCount: controller.consultations.length,
        itemBuilder: (context, index) {
          final consultation = controller.consultations[index];
          return Padding(
            padding: EdgeInsets.fromLTRB(
              _doctorPx(context, 16),
              _doctorPx(context, 12),
              _doctorPx(context, 16),
              index == controller.consultations.length - 1 ? bottom : 0,
            ),
            child: _ConsultationCard(
              key: ValueKey('doctor-consultation-${consultation.id}'),
              consultation: consultation,
              onTap: () => onOpenConsultation(consultation),
            ),
          );
        },
      ),
    ];
  }
}

class _ConsultationStatusFilter extends StatelessWidget {
  const _ConsultationStatusFilter({required this.controller});

  final DoctorConsultationsController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: _doctorPx(context, 16),
        vertical: _doctorPx(context, 12),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: _doctorDivider,
            width: _doctorPx(context, 1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ConsultationStatusButton(
              key: const ValueKey('doctor-status-paid'),
              label: '进行中',
              selectedColor: const Color(0xFF3B82F6),
              selected: controller.status == DoctorConsultationStatus.paid,
              onTap: () =>
                  controller.selectStatus(DoctorConsultationStatus.paid),
            ),
          ),
          SizedBox(width: _doctorPx(context, 8)),
          Expanded(
            child: _ConsultationStatusButton(
              key: const ValueKey('doctor-status-expired'),
              label: '已过期',
              selectedColor: const Color(0xFF9CA3AF),
              selected: controller.status == DoctorConsultationStatus.expired,
              onTap: () =>
                  controller.selectStatus(DoctorConsultationStatus.expired),
            ),
          ),
          SizedBox(width: _doctorPx(context, 8)),
        ],
      ),
    );
  }
}

class _ConsultationStatusButton extends StatelessWidget {
  const _ConsultationStatusButton({
    super.key,
    required this.label,
    required this.selectedColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color selectedColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_doctorPx(context, 8));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? selectedColor : _doctorButtonBackground,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0x0D000000),
            offset: Offset(0, _doctorPx(context, 1)),
            blurRadius: _doctorPx(context, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _doctorPx(context, 12),
              vertical: _doctorPx(context, 8),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : _doctorTextSecondary,
                fontSize: _doctorFont(14),
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DoctorIncomeView extends StatelessWidget {
  const DoctorIncomeView({super.key, required this.controller});

  final DoctorIncomeController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.loading && !controller.hasLoaded) {
            return const Column(
              children: [
                _DoctorHeader(title: '收入统计'),
                Expanded(child: _LoadingState(label: '加载中...')),
              ],
            );
          }
          return Column(
            children: [
              const _DoctorHeader(title: '收入统计'),
              if (controller.stats case final stats?)
                _IncomeOverviewCard(stats: stats),
              const _IncomeSectionTitle(),
              Expanded(child: _buildIncomeList(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIncomeList(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < _doctorPx(context, 120)) {
          controller.loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        color: _doctorPrimary,
        onRefresh: () => controller.load(refresh: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                _doctorPx(context, 16),
                _doctorPx(context, 8),
                _doctorPx(context, 16),
                0,
              ),
              sliver: controller.records.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: _IncomeEmptyState(
                        message: controller.error ?? '暂无收入记录',
                      ),
                    )
                  : SliverList.builder(
                      itemCount: controller.records.length,
                      itemBuilder: (context, index) => Padding(
                        padding: EdgeInsets.only(
                          bottom: _doctorPx(context, 12),
                        ),
                        child: _IncomeRecordCard(
                          record: controller.records[index],
                        ),
                      ),
                    ),
            ),
            if (controller.loadingMore)
              SliverToBoxAdapter(
                child: _IncomeFooterState(loading: true, message: '加载更多中...'),
              )
            else if (!controller.hasMore && controller.records.isNotEmpty)
              const SliverToBoxAdapter(
                child: _IncomeFooterState(loading: false, message: '没有更多收入记录了'),
              ),
            SliverToBoxAdapter(
              child: SizedBox(
                height:
                    MediaQuery.paddingOf(context).bottom +
                    _doctorPx(context, 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeSectionTitle extends StatelessWidget {
  const _IncomeSectionTitle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF6F8FC),
      padding: EdgeInsets.fromLTRB(
        _doctorPx(context, 16),
        _doctorPx(context, 8),
        _doctorPx(context, 16),
        _doctorPx(context, 8),
      ),
      child: Text(
        '收入明细',
        style: TextStyle(
          color: _doctorTextPrimary,
          fontSize: _doctorFont(16),
          fontWeight: FontWeight.bold,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class DoctorProfileView extends StatefulWidget {
  const DoctorProfileView({
    super.key,
    required this.controller,
    required this.authController,
  });

  final DoctorProfileController controller;
  final AuthController authController;

  @override
  State<DoctorProfileView> createState() => _DoctorProfileViewState();
}

class _DoctorProfileViewState extends State<DoctorProfileView> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_showNotice);
  }

  @override
  void didUpdateWidget(covariant DoctorProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_showNotice);
    widget.controller.addListener(_showNotice);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_showNotice);
    super.dispose();
  }

  void _showNotice() {
    final notice = widget.controller.takeNotice();
    if (notice == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(notice)));
    });
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: const AppDialogIcon(icon: Icons.logout_rounded),
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('doctor-logout-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.authController.logout();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final profile = widget.controller.profile;
          return Column(
            children: [
              const _DoctorHeader(title: '个人中心', centered: true),
              Expanded(
                child: profile == null
                    ? widget.controller.loading
                          ? const _LoadingState(label: '加载中...')
                          : _ProfileErrorState(
                              message: widget.controller.error ?? '无法获取医生信息',
                              onRetry: widget.controller.load,
                            )
                    : RefreshIndicator(
                        color: _doctorPrimary,
                        onRefresh: widget.controller.load,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: _DoctorInfoCard(
                                profile: profile,
                                updatingStatus:
                                    widget.controller.updatingOnlineStatus,
                                onToggleOnlineStatus: () => widget.controller
                                    .updateOnlineStatus(!profile.isOnline),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: _LogoutButton(onPressed: _confirmLogout),
                            ),
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height:
                                    MediaQuery.paddingOf(context).bottom +
                                    _doctorPx(context, 20),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DoctorHeader extends StatelessWidget {
  const _DoctorHeader({required this.title, this.centered = false});

  final String title;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: _doctorPx(context, centered ? 16 : 20),
        vertical: _doctorPx(context, centered ? 18 : 16),
      ),
      alignment: centered ? Alignment.center : Alignment.centerLeft,
      child: Text(
        title,
        textAlign: centered ? TextAlign.center : TextAlign.left,
        style: TextStyle(
          color: centered ? const Color(0xFF1F2937) : _doctorTextPrimary,
          fontSize: _doctorFont(20),
          fontWeight: centered ? FontWeight.w600 : FontWeight.bold,
          letterSpacing: centered ? 0 : 0.5,
        ),
      ),
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  const _ConsultationCard({
    super.key,
    required this.consultation,
    required this.onTap,
  });

  final DoctorConsultation consultation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = consultation.status == DoctorConsultationStatus.paid;
    final radius = BorderRadius.circular(_doctorPx(context, 12));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0x1A000000),
            offset: Offset(0, _doctorPx(context, 2)),
            blurRadius: _doctorPx(context, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.all(_doctorPx(context, 16)),
            child: Row(
              children: [
                _DoctorAvatar(
                  imageUrl: consultation.petAvatarUrl ?? '',
                  size: _doctorPx(context, 50),
                  circular: true,
                  fallbackIcon: Icons.pets_rounded,
                ),
                SizedBox(width: _doctorPx(context, 12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              consultation.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _doctorTextPrimary,
                                fontSize: _doctorFont(16),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          SizedBox(width: _doctorPx(context, 8)),
                          _ConsultationStatusBadge(active: active),
                        ],
                      ),
                      SizedBox(height: _doctorPx(context, 8)),
                      Text(
                        consultation.lastMessage ?? '暂无消息',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _doctorTextSecondary,
                          fontSize: _doctorFont(14),
                          height: _doctorFont(20) / _doctorFont(14),
                          letterSpacing: 0,
                        ),
                      ),
                      SizedBox(height: _doctorPx(context, 8)),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              consultation.serviceItemName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _doctorTextHint,
                                fontSize: _doctorFont(12),
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          SizedBox(width: _doctorPx(context, 8)),
                          Text(
                            _consultationTimeLabel(consultation),
                            style: TextStyle(
                              color: _doctorTextHint,
                              fontSize: _doctorFont(12),
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: _doctorPx(context, 8)),
                if (consultation.unreadCount > 0) ...[
                  _DoctorUnreadBadge(
                    key: ValueKey(
                      'doctor-consultation-unread-${consultation.id}',
                    ),
                    count: consultation.unreadCount,
                  ),
                  SizedBox(width: _doctorPx(context, 8)),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  size: _doctorPx(context, 40),
                  color: _doctorTextHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsultationStatusBadge extends StatelessWidget {
  const _ConsultationStatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF3B82F6) : const Color(0xFF9CA3AF);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _doctorPx(context, 8),
        vertical: _doctorPx(context, 2),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(_doctorPx(context, 4)),
      ),
      child: Text(
        active ? '进行中' : '已过期',
        style: TextStyle(
          color: color,
          fontSize: _doctorFont(12),
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _IncomeOverviewCard extends StatelessWidget {
  const _IncomeOverviewCard({required this.stats});

  final DoctorIncomeStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('doctor-income-overview'),
      constraints: BoxConstraints(minHeight: _doctorPx(context, 180)),
      margin: EdgeInsets.fromLTRB(
        _doctorPx(context, 16),
        0,
        _doctorPx(context, 16),
        _doctorPx(context, 8),
      ),
      padding: EdgeInsets.all(_doctorPx(context, 20)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_doctorPx(context, 16)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7E97FA), Color(0xFF6480F9), Color(0xFF6481F9)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            children: [
              Text(
                '总收入',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: _doctorFont(13),
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: _doctorPx(context, 8)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _money(stats.total),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _doctorFont(28),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0,
                  ),
                ),
              ),
              SizedBox(height: _doctorPx(context, 4)),
              Text(
                '已完成 ${stats.consultationCount} 次咨询',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: _doctorFont(11),
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          SizedBox(height: _doctorPx(context, 16)),
          Row(
            children: [
              Expanded(
                child: _IncomePeriod(label: '今日', value: stats.today),
              ),
              const _IncomePeriodDivider(),
              Expanded(
                child: _IncomePeriod(label: '本周', value: stats.thisWeek),
              ),
              const _IncomePeriodDivider(),
              Expanded(
                child: _IncomePeriod(label: '本月', value: stats.thisMonth),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncomePeriod extends StatelessWidget {
  const _IncomePeriod({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: _doctorFont(11),
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: _doctorPx(context, 4)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _money(value),
            style: TextStyle(
              color: Colors.white,
              fontSize: _doctorFont(14),
              fontWeight: FontWeight.bold,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _IncomePeriodDivider extends StatelessWidget {
  const _IncomePeriodDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _doctorPx(context, 1),
      height: _doctorPx(context, 30),
      color: Colors.white.withValues(alpha: 0.3),
    );
  }
}

class _IncomeRecordCard extends StatelessWidget {
  const _IncomeRecordCard({required this.record});

  final DoctorIncomeRecord record;

  @override
  Widget build(BuildContext context) {
    final settled = record.status.toLowerCase() == 'settled';
    final statusColor = settled ? _doctorSuccess : _doctorWarning;
    return Container(
      padding: EdgeInsets.all(_doctorPx(context, 14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_doctorPx(context, 12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x14000000),
            offset: Offset(0, _doctorPx(context, 2)),
            blurRadius: _doctorPx(context, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: _doctorPx(context, 40),
                  height: _doctorPx(context, 40),
                  decoration: const BoxDecoration(
                    color: Color(0x152196F3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.payments_rounded,
                    size: _doctorPx(context, 40),
                    color: _doctorPrimary,
                  ),
                ),
                SizedBox(width: _doctorPx(context, 12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${record.userName} - ${record.serviceName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _doctorTextPrimary,
                          fontSize: _doctorFont(14),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      SizedBox(height: _doctorPx(context, 4)),
                      Text(
                        _formatDateTime(record.createdAt),
                        style: TextStyle(
                          color: _doctorTextHint,
                          fontSize: _doctorFont(12),
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: _doctorPx(context, 8)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${_money(record.amount)}',
                style: TextStyle(
                  color: _doctorSuccess,
                  fontSize: _doctorFont(16),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: _doctorPx(context, 4)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _doctorPx(context, 8),
                  vertical: _doctorPx(context, 3),
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.125),
                  borderRadius: BorderRadius.circular(_doctorPx(context, 10)),
                ),
                child: Text(
                  settled ? '已结算' : '待结算',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: _doctorFont(11),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoctorInfoCard extends StatelessWidget {
  const _DoctorInfoCard({
    required this.profile,
    required this.updatingStatus,
    required this.onToggleOnlineStatus,
  });

  final DoctorPortalProfile profile;
  final bool updatingStatus;
  final VoidCallback onToggleOnlineStatus;

  @override
  Widget build(BuildContext context) {
    final useStackedStats = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    return Container(
      key: const ValueKey('doctor-profile-card'),
      margin: EdgeInsets.fromLTRB(
        _doctorPx(context, 16),
        _doctorPx(context, 12),
        _doctorPx(context, 16),
        0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_doctorPx(context, 12)),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF9FAFB)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A000000),
            offset: Offset(0, _doctorPx(context, 2)),
            blurRadius: _doctorPx(context, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(_doctorPx(context, 16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DoctorAvatar(
              imageUrl: profile.avatarUrl,
              size: _doctorPx(context, 70),
              circular: true,
              borderWidth: _doctorPx(context, 3),
              fallbackIcon: Icons.medical_services_rounded,
            ),
            SizedBox(width: _doctorPx(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF1F2937),
                            fontSize: _doctorFont(18),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      if (profile.isGoldDoctor) ...[
                        SizedBox(width: _doctorPx(context, 8)),
                        Tooltip(
                          message: '金牌医生',
                          child: Icon(
                            Icons.verified_rounded,
                            size: _doctorPx(context, 40),
                            color: const Color(0xFFFFD700),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: _doctorPx(context, 8)),
                  if (profile.hospitalName.isNotEmpty ||
                      profile.departmentName.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.business_rounded,
                          size: _doctorPx(context, 28),
                          color: const Color(0xFF6B7280),
                        ),
                        SizedBox(width: _doctorPx(context, 4)),
                        Expanded(
                          child: Text(
                            profile.workplace,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF6B7280),
                              fontSize: _doctorFont(14),
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  SizedBox(height: _doctorPx(context, 8)),
                  Text(
                    '专长：${profile.specialty}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF6B7280),
                      fontSize: _doctorFont(14),
                      height: _doctorFont(20) / _doctorFont(14),
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(height: _doctorPx(context, 12)),
                  if (useStackedStats)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProfileInfo(
                          label: '从业',
                          value: '${profile.experienceYears}年',
                        ),
                        SizedBox(height: _doctorPx(context, 6)),
                        _ProfileInfo(
                          label: '咨询',
                          value: '${profile.consultationCount}人',
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        _ProfileInfo(
                          label: '从业',
                          value: '${profile.experienceYears}年',
                        ),
                        Container(
                          width: _doctorPx(context, 1),
                          height: _doctorPx(context, 12),
                          margin: EdgeInsets.symmetric(
                            horizontal: _doctorPx(context, 12),
                          ),
                          color: const Color(0xFFE5E7EB),
                        ),
                        _ProfileInfo(
                          label: '咨询',
                          value: '${profile.consultationCount}人',
                        ),
                      ],
                    ),
                  SizedBox(height: _doctorPx(context, 12)),
                  _PracticeStatusBadge(active: profile.isActive),
                  SizedBox(height: _doctorPx(context, 12)),
                  _OnlineStatusButton(
                    online: profile.isOnline,
                    updating: updatingStatus,
                    onPressed: onToggleOnlineStatus,
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

class _ProfileInfo extends StatelessWidget {
  const _ProfileInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF9CA3AF),
            fontSize: _doctorFont(13),
            letterSpacing: 0,
          ),
        ),
        SizedBox(width: _doctorPx(context, 4)),
        Text(
          value,
          style: TextStyle(
            color: const Color(0xFF1F2937),
            fontSize: _doctorFont(14),
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _PracticeStatusBadge extends StatelessWidget {
  const _PracticeStatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _doctorPx(context, 12),
        vertical: _doctorPx(context, 4),
      ),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(_doctorPx(context, 12)),
      ),
      child: Text(
        active ? '执业中' : '已停诊',
        style: TextStyle(
          color: active ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
          fontSize: _doctorFont(13),
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _OnlineStatusButton extends StatelessWidget {
  const _OnlineStatusButton({
    required this.online,
    required this.updating,
    required this.onPressed,
  });

  final bool online;
  final bool updating;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_doctorPx(context, 20));
    return Opacity(
      opacity: updating ? 0.6 : 1,
      child: Material(
        color: online ? _doctorSuccess : const Color(0xFF9E9E9E),
        borderRadius: radius,
        child: InkWell(
          key: const ValueKey('doctor-online-switch'),
          onTap: updating ? null : onPressed,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _doctorPx(context, 16),
              vertical: _doctorPx(context, 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  online ? Icons.circle : Icons.radio_button_unchecked,
                  size: _doctorPx(context, 32),
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  updating
                      ? '更新中...'
                      : online
                      ? '在线'
                      : '离线',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _doctorFont(14),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
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

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_doctorPx(context, 12));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _doctorPx(context, 16),
        _doctorPx(context, 24),
        _doctorPx(context, 16),
        0,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        child: InkWell(
          key: const ValueKey('doctor-logout-button'),
          onTap: onPressed,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: _doctorPx(context, 16)),
            child: Center(
              child: Text(
                '退出登录',
                style: TextStyle(
                  color: const Color(0xFFEF4444),
                  fontSize: _doctorFont(16),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoctorTabBar extends StatelessWidget {
  const _DoctorTabBar({
    required this.selectedIndex,
    required this.consultationUnreadCount,
    required this.onSelected,
  });

  final int selectedIndex;
  final int consultationUnreadCount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('doctor-bottom-tab-bar'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(_doctorPx(context, 20)),
          topRight: Radius.circular(_doctorPx(context, 20)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, -5),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: _doctorPx(context, 8)),
          child: Row(
            children: [
              Expanded(
                child: _DoctorTabItem(
                  tabId: 'consultations',
                  label: '咨询',
                  icon: Icons.chat_bubble_outline,
                  selected: selectedIndex == 0,
                  unreadCount: consultationUnreadCount,
                  onTap: () => onSelected(0),
                ),
              ),
              Expanded(
                child: _DoctorTabItem(
                  tabId: 'income',
                  label: '收入',
                  icon: Icons.account_balance_wallet_outlined,
                  selected: selectedIndex == 1,
                  onTap: () => onSelected(1),
                ),
              ),
              Expanded(
                child: _DoctorTabItem(
                  tabId: 'profile',
                  label: '我的',
                  icon: Icons.person,
                  selected: selectedIndex == 2,
                  onTap: () => onSelected(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorTabItem extends StatelessWidget {
  const _DoctorTabItem({
    required this.tabId,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.unreadCount = 0,
  });

  final String tabId;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF3B82F6) : const Color(0xFF6B7280);
    return InkWell(
      key: ValueKey('doctor-tab-$tabId'),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: _doctorPx(context, 4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              key: ValueKey('doctor-tab-$tabId-icon-slot'),
              dimension: _doctorPx(context, 56),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(
                      icon,
                      size: _doctorPx(context, 56),
                      color: color,
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: -2,
                      right: -4,
                      child: _DoctorUnreadBadge(
                        key: ValueKey('doctor-tab-$tabId-unread-badge'),
                        count: unreadCount,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: _doctorPx(context, 2)),
            Text(
              label,
              key: ValueKey('doctor-tab-$tabId-label'),
              style: TextStyle(
                color: color,
                fontSize: _doctorPx(context, 22),
                height: 1.15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorUnreadBadge extends StatelessWidget {
  const _DoctorUnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        maxLines: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _DoctorAvatar extends StatelessWidget {
  const _DoctorAvatar({
    required this.imageUrl,
    required this.size,
    required this.circular,
    required this.fallbackIcon,
    this.borderWidth = 0,
  });

  final String imageUrl;
  final double size;
  final bool circular;
  final IconData fallbackIcon;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final url = resolveAssetUrl(imageUrl);
    final borderRadius = circular
        ? BorderRadius.circular(size / 2)
        : BorderRadius.circular(_doctorPx(context, 8));
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: ColoredBox(
          color: const Color(0xFFE8EDFF),
          child: url.isEmpty
              ? Icon(fallbackIcon, color: _doctorPrimary, size: size * 0.5)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    fallbackIcon,
                    color: _doctorPrimary,
                    size: size * 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _doctorPrimary),
          SizedBox(height: _doctorPx(context, 12)),
          Text(
            label,
            style: TextStyle(
              color: _doctorTextHint,
              fontSize: _doctorFont(14),
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsultationEmptyState extends StatelessWidget {
  const _ConsultationEmptyState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: _doctorPx(context, 128),
            color: _doctorTextHint,
          ),
          SizedBox(height: _doctorPx(context, 16)),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _doctorTextHint,
              fontSize: _doctorFont(14),
              letterSpacing: 0,
            ),
          ),
          if (onRetry != null) ...[
            SizedBox(height: _doctorPx(context, 16)),
            TextButton(onPressed: onRetry, child: const Text('重新加载')),
          ],
        ],
      ),
    );
  }
}

class _IncomeEmptyState extends StatelessWidget {
  const _IncomeEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_rounded,
            size: _doctorPx(context, 96),
            color: _doctorTextHint,
          ),
          SizedBox(height: _doctorPx(context, 12)),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _doctorTextHint,
              fontSize: _doctorFont(14),
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeFooterState extends StatelessWidget {
  const _IncomeFooterState({required this.loading, required this.message});

  final bool loading;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _doctorPx(context, 20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: _doctorPrimary,
                strokeWidth: 2,
              ),
            ),
          if (loading) SizedBox(height: _doctorPx(context, 8)),
          Text(
            message,
            style: TextStyle(
              color: _doctorTextSecondary,
              fontSize: _doctorFont(14),
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: _doctorPx(context, 80),
            color: _doctorTextHint,
          ),
          SizedBox(height: _doctorPx(context, 12)),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _doctorTextSecondary,
              fontSize: _doctorFont(14),
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: _doctorPx(context, 12)),
          TextButton(onPressed: onRetry, child: const Text('重新加载')),
        ],
      ),
    );
  }
}

String _consultationTimeLabel(DoctorConsultation consultation) {
  final endAt = consultation.serviceEndAt;
  if (consultation.status == DoctorConsultationStatus.expired ||
      endAt == null) {
    return consultation.status == DoctorConsultationStatus.expired
        ? '已过期'
        : '正在咨询';
  }
  final remaining = endAt.difference(DateTime.now());
  if (remaining <= Duration.zero) return '已过期';
  final minutes = remaining.inMinutes;
  final hours = minutes ~/ 60;
  final days = hours ~/ 24;
  if (days >= 1) return '剩余 $days 天';
  if (hours >= 1) return '剩余 $hours 小时 ${minutes % 60} 分钟';
  return '剩余 $minutes 分钟';
}

String _money(double value) => '¥${value.toStringAsFixed(2)}';

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  String two(int number) => number.toString().padLeft(2, '0');
  final date = '${two(local.month)}-${two(local.day)}';
  final time = '${two(local.hour)}:${two(local.minute)}';
  return local.year == now.year ? '$date $time' : '${local.year}-$date $time';
}
