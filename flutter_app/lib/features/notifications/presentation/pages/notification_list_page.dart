import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/notification_models.dart';
import '../notification_badge_controller.dart';
import '../notification_list_controller.dart';

typedef OpenNotificationAction =
    Future<void> Function(NotificationAction action);

const _notificationHeaderBackgroundColor = Color(0xFFDEE9FF);

class NotificationListPage extends StatefulWidget {
  const NotificationListPage({
    super.key,
    required this.gateway,
    required this.badgeController,
    required this.onAction,
  });

  final NotificationGateway gateway;
  final NotificationBadgeController badgeController;
  final OpenNotificationAction onAction;

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  late final NotificationListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = NotificationListController(
      gateway: widget.gateway,
      badgeController: widget.badgeController,
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('通知消息'),
          backgroundColor: _notificationHeaderBackgroundColor,
          surfaceTintColor: _notificationHeaderBackgroundColor,
          foregroundColor: AppColors.ink,
          actions: [
            if (_controller.notifications.any((item) => !item.isRead))
              TextButton(
                key: const ValueKey('notification-mark-all-button'),
                style: TextButton.styleFrom(foregroundColor: AppColors.ink),
                onPressed: _controller.isMarkingAll ? null : _confirmMarkAll,
                child: _controller.isMarkingAll
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.ink,
                        ),
                      )
                    : const Text('全部已读'),
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isInitialLoading && _controller.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.errorMessage != null && _controller.notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _controller.retry,
        child: _NotificationStateView(
          icon: Icons.wifi_off_rounded,
          title: '通知加载失败',
          description: '请检查网络后重试',
          action: OutlinedButton.icon(
            key: const ValueKey('notification-retry'),
            onPressed: _controller.retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ),
      );
    }
    if (_controller.notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _controller.refresh,
        child: const _NotificationStateView(
          icon: Icons.notifications_none_rounded,
          title: '暂无通知消息',
          description: '订单、互动和系统消息会显示在这里',
        ),
      );
    }

    return Column(
      children: [
        if (_controller.errorMessage != null)
          Material(
            color: const Color(0xFFFFF4E5),
            child: ListTile(
              dense: true,
              leading: const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFB66A18),
              ),
              title: const Text('刷新失败，正在显示上次内容'),
              trailing: TextButton(
                onPressed: _controller.refresh,
                child: const Text('重试'),
              ),
            ),
          ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 220) {
                unawaited(_controller.loadMore());
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: _controller.refresh,
              child: ListView.separated(
                key: const ValueKey('notification-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                itemCount: _controller.notifications.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == _controller.notifications.length) {
                    return _buildFooter();
                  }
                  return _NotificationCard(
                    notification: _controller.notifications[index],
                    onTap: _openNotification,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    if (_controller.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_controller.loadMoreError != null) {
      return Center(
        child: TextButton.icon(
          key: const ValueKey('notification-load-more-retry'),
          onPressed: _controller.loadMore,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('加载更多失败，点击重试'),
        ),
      );
    }
    return const SizedBox(height: 4);
  }

  Future<void> _openNotification(UserNotification notification) async {
    final result = await _controller.markNotificationRead(notification.id);
    if (!mounted) return;
    if (result == NotificationMutationResult.failed) {
      _showMessage(_controller.mutationError ?? '标记已读失败，请稍后重试');
      return;
    }
    if (result != NotificationMutationResult.succeeded) return;
    await widget.onAction(notification.action);
  }

  Future<void> _confirmMarkAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: const AppDialogIcon(icon: Icons.done_all_rounded),
        title: const Text('全部标为已读？'),
        content: const Text('当前列表中的未读通知将全部标记为已读。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('notification-mark-all-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await _controller.markAllRead();
    if (!mounted || result != NotificationMutationResult.failed) return;
    _showMessage(_controller.mutationError ?? '全部标记已读失败，请稍后重试');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final UserNotification notification;
  final ValueChanged<UserNotification> onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return Semantics(
      button: true,
      label:
          '${unread ? '未读' : '已读'}，${notification.title}，${notification.content}',
      excludeSemantics: true,
      child: Material(
        key: ValueKey('notification-card-${notification.id}'),
        color: unread ? const Color(0xFFEFF7FF) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(notification),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _typeTint(notification.type),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _typeIcon(notification.type),
                    size: 20,
                    color: _typeColor(notification.type),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.25,
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: const Color(0xFF242B35),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatNotificationTime(notification.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8A929D),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        notification.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Color(0xFF616A75),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: unread
                      ? Container(
                          key: ValueKey(
                            'notification-unread-dot-${notification.id}',
                          ),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1677FF),
                            shape: BoxShape.circle,
                          ),
                        )
                      : const SizedBox(width: 8, height: 8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationStateView extends StatelessWidget {
  const _NotificationStateView({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
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
                  Icon(icon, size: 52, color: const Color(0xFF98A0AA)),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF7B8491)),
                  ),
                  if (action case final action?) ...[
                    const SizedBox(height: 14),
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

IconData _typeIcon(NotificationType type) => switch (type) {
  NotificationType.system => Icons.settings_outlined,
  NotificationType.announcement => Icons.campaign_outlined,
  NotificationType.interaction => Icons.favorite_border_rounded,
  NotificationType.unknown => Icons.notifications_none_rounded,
};

Color _typeColor(NotificationType type) => switch (type) {
  NotificationType.system => const Color(0xFF376996),
  NotificationType.announcement => const Color(0xFFB15B18),
  NotificationType.interaction => const Color(0xFFC43865),
  NotificationType.unknown => const Color(0xFF68717D),
};

Color _typeTint(NotificationType type) => switch (type) {
  NotificationType.system => const Color(0xFFE5F0FA),
  NotificationType.announcement => const Color(0xFFFFEEDC),
  NotificationType.interaction => const Color(0xFFFFE6EF),
  NotificationType.unknown => const Color(0xFFEDF0F3),
};
