import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/friend_relation_models.dart';
import 'friend_requests_controller.dart';
import 'widgets/conversation_tile.dart';

class FriendRequestListPage extends StatefulWidget {
  const FriendRequestListPage({super.key, required this.controller});

  final FriendRequestsController controller;

  @override
  State<FriendRequestListPage> createState() => _FriendRequestListPageState();
}

class _FriendRequestListPageState extends State<FriendRequestListPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    unawaited(widget.controller.start());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 120) {
      unawaited(widget.controller.loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('好友申请'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) => _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final controller = widget.controller;
    if (controller.loading && controller.requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('加载中...', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      );
    }

    if (controller.errorMessage != null && controller.requests.isEmpty) {
      return _RequestStateView(
        icon: Icons.cloud_off_outlined,
        title: controller.errorMessage!,
        subtitle: '请检查网络后重新加载',
        actionLabel: '重试',
        onAction: controller.refresh,
      );
    }

    return Column(
      children: [
        if (controller.errorMessage != null)
          _InlineError(
            message: controller.errorMessage!,
            onRetry: controller.refresh,
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: controller.requests.isEmpty
                ? ListView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 160),
                      _RequestStateView(
                        icon: Icons.inbox_outlined,
                        title: '暂无好友申请',
                        subtitle: '新的好友申请会显示在这里',
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount:
                        controller.requests.length +
                        (controller.loadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == controller.requests.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final request = controller.requests[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RequestTile(
                          request: request,
                          processing: controller.isProcessing(request.id),
                          onAccept: () => _accept(request),
                          onReject: () => _confirmReject(request),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _accept(FriendRequest request) async {
    await widget.controller.accept(request);
    if (!mounted) return;
    _showNotice();
  }

  Future<void> _confirmReject(FriendRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: const AppDialogIcon.danger(icon: Icons.person_remove_rounded),
        title: const Text('拒绝申请'),
        content: Text('确定要拒绝 ${request.requesterName} 的好友申请吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('拒绝'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.controller.reject(request);
    if (!mounted) return;
    _showNotice();
  }

  void _showNotice() {
    final notice = widget.controller.takeNotice();
    if (notice == null || notice.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(notice)));
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.processing,
    required this.onAccept,
    required this.onReject,
  });

  final FriendRequest request;
  final bool processing;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FriendAvatar(
              name: request.requesterName,
              imageUrl: request.requesterAvatar,
              radius: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.requesterName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (request.requesterPhone != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      maskFriendPhone(request.requesterPhone!),
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (request.message != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '申请附言：${request.message}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    formatFriendRequestTime(request.createdAt),
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 74,
              child: Column(
                children: [
                  OutlinedButton.icon(
                    key: ValueKey('friend-request-reject-${request.id}'),
                    onPressed: processing ? null : onReject,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('拒绝'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(74, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      foregroundColor: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: ValueKey('friend-request-accept-${request.id}'),
                    onPressed: processing ? null : onAccept,
                    icon: processing
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 16),
                    label: const Text('接受'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(74, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF7ED),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.error_outline, color: Color(0xFFEA580C)),
        title: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: TextButton(onPressed: onRetry, child: const Text('重试')),
      ),
    );
  }
}

class _RequestStateView extends StatelessWidget {
  const _RequestStateView({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: const Color(0xFFD1D5DB)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9CA3AF)),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String maskFriendPhone(String rawPhone) {
  final phone = rawPhone.trim();
  if (phone.length != 11) return phone;
  return '${phone.substring(0, 3)}****${phone.substring(7)}';
}

String formatFriendRequestTime(DateTime rawTime) {
  final time = rawTime.toLocal();
  final minutes = time.minute.toString().padLeft(2, '0');
  return '${time.month}月${time.day}日 ${time.hour}:$minutes';
}
