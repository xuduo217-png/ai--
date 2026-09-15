import 'dart:async';

import 'package:flutter/material.dart';

import '../../../friends/friends_feature_session.dart';
import '../../domain/community_models.dart';
import '../community_controller.dart';
import '../community_design.dart';
import 'community_profile_page.dart';

class CommunityConnectionsPage extends StatefulWidget {
  const CommunityConnectionsPage({
    super.key,
    required this.gateway,
    required this.userId,
    required this.type,
    required this.authenticated,
    required this.currentUserId,
    required this.requestLogin,
    this.friendsSession,
  });

  final CommunityGateway gateway;
  final int userId;
  final CommunityConnectionType type;
  final bool authenticated;
  final int? currentUserId;
  final CommunityLoginRequest requestLogin;
  final FriendsFeatureSession? friendsSession;

  @override
  State<CommunityConnectionsPage> createState() =>
      _CommunityConnectionsPageState();
}

class _CommunityConnectionsPageState extends State<CommunityConnectionsPage> {
  late final CommunityConnectionsController _controller;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _controller = CommunityConnectionsController(
      gateway: widget.gateway,
      userId: widget.userId,
      type: widget.type,
      authenticated: widget.authenticated,
      currentUserId: widget.currentUserId,
    );
    _scrollController.addListener(_handleScroll);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 160) {
      unawaited(_controller.loadMore());
    }
  }

  void _handleSearch(String value) {
    setState(() {});
    _searchTimer?.cancel();
    _searchTimer = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_controller.search(value)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('community-connections-page'),
      backgroundColor: Colors.transparent,
      body: CommunityBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearch(),
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
          Expanded(
            child: Text(
              widget.type.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
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

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: TextField(
        key: const ValueKey('community-connection-search'),
        controller: _searchController,
        onChanged: _handleSearch,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: widget.type == CommunityConnectionType.followers
              ? '搜索粉丝'
              : '搜索关注的宠友',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '清空',
                  onPressed: () {
                    _searchController.clear();
                    _handleSearch('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: communityBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: communityBorder),
          ),
        ),
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
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
        children: [
          CommunityEmptyState(
            icon: hasError
                ? Icons.cloud_off_outlined
                : Icons.people_outline_rounded,
            title: hasError
                ? '加载失败'
                : _controller.keyword.isEmpty
                ? '这里还没有用户'
                : '没有找到相关用户',
            subtitle: hasError
                ? _controller.error!
                : _controller.keyword.isEmpty
                ? '新的社区关系会显示在这里。'
                : '换个关键词再试试。',
            actionLabel: hasError ? '重新加载' : null,
            onAction: hasError ? _controller.load : null,
          ),
        ],
      );
    }
    return RefreshIndicator(
      color: communityPrimaryButton,
      onRefresh: _controller.refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
        itemCount: _controller.items.length + (_controller.loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _controller.items.length) {
            return const Padding(
              padding: EdgeInsets.all(18),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final item = _controller.items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ConnectionTile(
              item: item,
              pending: _controller.pendingUserId == item.user.id,
              onOpen: () => _openProfile(item.user.id),
              onToggleFollow: () => _toggleFollow(item),
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleFollow(CommunityRelationUser item) async {
    if (!widget.authenticated) {
      await widget.requestLogin('登录后即可关注宠友');
      return;
    }
    try {
      await _controller.toggleFollow(item);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('操作失败：$error')));
    }
  }

  void _openProfile(int userId) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityProfilePage(
          gateway: widget.gateway,
          userId: userId,
          authenticated: widget.authenticated,
          currentUserId: widget.currentUserId,
          requestLogin: widget.requestLogin,
          friendsSession: widget.friendsSession,
        ),
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({
    required this.item,
    required this.pending,
    required this.onOpen,
    required this.onToggleFollow,
  });

  final CommunityRelationUser item;
  final bool pending;
  final VoidCallback onOpen;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final user = item.user;
    final relationship = item.relationship;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('community-connection-${user.id}'),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: communityText,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (user.verified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: communityPrimary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.bio.isEmpty ? '暂未填写个人简介' : user.bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: communityTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!relationship.isSelf) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 88,
                  height: 38,
                  child: relationship.isFollowing
                      ? OutlinedButton(
                          onPressed: pending ? null : onToggleFollow,
                          child: pending
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('已关注'),
                        )
                      : FilledButton(
                          onPressed: pending ? null : onToggleFollow,
                          style: FilledButton.styleFrom(
                            backgroundColor: communityPrimaryButton,
                          ),
                          child: pending
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('关注'),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
