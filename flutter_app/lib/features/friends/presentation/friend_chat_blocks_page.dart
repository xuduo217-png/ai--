import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/friend_relation_models.dart';
import 'friend_chat_blocks_controller.dart';
import 'widgets/conversation_tile.dart';

const _friendChatBlocksHeaderBackgroundColor = Color(0xFFDEE9FF);

class FriendChatBlocksPage extends StatefulWidget {
  const FriendChatBlocksPage({super.key, required this.controller});

  final FriendChatBlocksController controller;

  @override
  State<FriendChatBlocksPage> createState() => _FriendChatBlocksPageState();
}

class _FriendChatBlocksPageState extends State<FriendChatBlocksPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.initialize());
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: _friendChatBlocksHeaderBackgroundColor,
        surfaceTintColor: _friendChatBlocksHeaderBackgroundColor,
        foregroundColor: AppColors.ink,
        title: const Text('黑名单'),
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) => _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final controller = widget.controller;
    if (controller.loading && controller.blocks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.errorMessage != null && controller.blocks.isEmpty) {
      return _BlockListState(
        icon: Icons.cloud_off_outlined,
        message: controller.errorMessage!,
        actionLabel: '重试',
        onAction: controller.refresh,
      );
    }
    if (controller.blocks.isEmpty) {
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Icon(Icons.person_off_outlined, size: 48, color: AppColors.muted),
            SizedBox(height: 12),
            Text(
              '黑名单为空',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 15),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        key: const ValueKey('friend-chat-block-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: controller.blocks.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
        itemBuilder: (context, index) {
          final block = controller.blocks[index];
          return Material(
            color: Colors.white,
            child: ListTile(
              key: ValueKey('friend-chat-block-${block.blockedUserId}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: FriendAvatar(
                name: block.blockedUserName,
                imageUrl: block.blockedUserAvatar,
                radius: 24,
              ),
              title: Text(
                block.blockedUserName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('拉黑于 ${_formatDate(block.blockedAt)}'),
              trailing: SizedBox(
                width: 88,
                height: 40,
                child: controller.isUnblocking(block.blockedUserId)
                    ? const Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TextButton(
                        key: ValueKey(
                          'friend-chat-unblock-${block.blockedUserId}',
                        ),
                        onPressed: () => unawaited(_confirmUnblock(block)),
                        child: const Text('解除拉黑'),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmUnblock(FriendChatBlock block) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: const AppDialogIcon(icon: Icons.person_add_alt_rounded),
        title: const Text('解除拉黑'),
        content: Text('确定要解除对 ${block.blockedUserName} 的拉黑吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('解除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await widget.controller.unblock(block);
    if (!mounted) return;
    final message = success
        ? '已解除拉黑'
        : widget.controller.errorMessage ?? '解除拉黑失败';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BlockListState extends StatelessWidget {
  const _BlockListState({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => unawaited(onAction()),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)}';
}
