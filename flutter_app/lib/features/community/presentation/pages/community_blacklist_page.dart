import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

import '../../../friends/friends_feature_session.dart';
import '../../domain/community_models.dart';
import '../community_controller.dart';
import '../community_design.dart';
import 'community_profile_page.dart';

class CommunityBlacklistPage extends StatefulWidget {
  const CommunityBlacklistPage({
    super.key,
    required this.gateway,
    required this.currentUserId,
    required this.requestLogin,
    this.friendsSession,
  });

  final CommunityGateway gateway;
  final int currentUserId;
  final CommunityLoginRequest requestLogin;
  final FriendsFeatureSession? friendsSession;

  @override
  State<CommunityBlacklistPage> createState() => _CommunityBlacklistPageState();
}

class _CommunityBlacklistPageState extends State<CommunityBlacklistPage> {
  late final CommunityBlacklistController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CommunityBlacklistController(gateway: widget.gateway);
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
      key: const ValueKey('community-blacklist-page'),
      backgroundColor: Colors.transparent,
      body: CommunityBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          const Expanded(
            child: Text(
              '黑名单',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: communityText,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_controller.loading && _controller.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: communityPrimaryButton),
      );
    }
    if (_controller.items.isEmpty) {
      final hasError = _controller.error != null;
      return RefreshIndicator(
        color: communityPrimaryButton,
        onRefresh: _controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
          children: [
            CommunityEmptyState(
              icon: hasError
                  ? Icons.cloud_off_outlined
                  : Icons.person_off_outlined,
              title: hasError ? '加载失败' : '黑名单为空',
              subtitle: hasError ? _controller.error! : '暂无被拉黑的用户。',
              actionLabel: hasError ? '重新加载' : null,
              onAction: hasError ? _controller.load : null,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: communityPrimaryButton,
      onRefresh: _controller.refresh,
      child: ListView.separated(
        key: const ValueKey('community-blacklist'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _controller.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _controller.items[index];
          return _CommunityBlockTile(
            item: item,
            pending: _controller.pendingUserId == item.blockedUserId,
            onOpen: () => unawaited(_openProfile(item)),
            onUnblock: () => unawaited(_confirmUnblock(item)),
          );
        },
      ),
    );
  }

  Future<void> _confirmUnblock(CommunityBlockItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: const AppDialogIcon(icon: Icons.person_add_alt_rounded),
        title: const Text('解除拉黑'),
        content: Text('确定要解除对 ${item.blockedUser.nickname} 的拉黑吗？'),
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
    try {
      await _controller.unblock(item);
      if (!mounted) return;
      _showMessage('已解除对 ${item.blockedUser.nickname} 的拉黑');
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('解除拉黑失败：$error');
    }
  }

  Future<void> _openProfile(CommunityBlockItem item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityProfilePage(
          gateway: widget.gateway,
          userId: item.blockedUserId,
          authenticated: true,
          currentUserId: widget.currentUserId,
          requestLogin: widget.requestLogin,
          friendsSession: widget.friendsSession,
          initiallyBlocked: true,
        ),
      ),
    );
    if (mounted) await _controller.refresh();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CommunityBlockTile extends StatelessWidget {
  const _CommunityBlockTile({
    required this.item,
    required this.pending,
    required this.onOpen,
    required this.onUnblock,
  });

  final CommunityBlockItem item;
  final bool pending;
  final VoidCallback onOpen;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final user = item.blockedUser;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('community-block-${item.blockedUserId}'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: communityCardDecoration(),
          child: Row(
            children: [
              CommunityAvatar(user: user, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: communityText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '拉黑于 ${communityDate(item.blockedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: communityTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (item.reason.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: communityHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 96,
                height: 38,
                child: pending
                    ? const Center(
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : OutlinedButton(
                        key: ValueKey(
                          'community-unblock-${item.blockedUserId}',
                        ),
                        onPressed: onUnblock,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: const Text('解除拉黑'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
