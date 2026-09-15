import 'dart:async';

import 'package:flutter/material.dart';

import '../../../friends/friends_feature_session.dart';
import '../../domain/community_models.dart';
import '../community_controller.dart';
import '../community_design.dart';
import 'community_profile_page.dart';
import 'community_search_page.dart';
import 'post_detail_page.dart';
import 'publish_post_page.dart';

class CommunityHomePage extends StatefulWidget {
  const CommunityHomePage({
    super.key,
    required this.gateway,
    required this.authenticated,
    required this.currentUserId,
    required this.requestLogin,
    this.friendsSession,
    this.currentUserAvatarUrl = '',
  });

  final CommunityGateway gateway;
  final bool authenticated;
  final int? currentUserId;
  final CommunityLoginRequest requestLogin;
  final FriendsFeatureSession? friendsSession;
  final String currentUserAvatarUrl;

  @override
  State<CommunityHomePage> createState() => _CommunityHomePageState();
}

class _CommunityHomePageState extends State<CommunityHomePage> {
  static const double _headerExtent = 56;

  late final CommunityFeedController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = CommunityFeedController(
      gateway: widget.gateway,
      authenticated: widget.authenticated,
    );
    _scrollController.addListener(_handleScroll);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      unawaited(_controller.loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('community-home'),
      backgroundColor: Colors.transparent,
      body: CommunityBackground(
        child: SafeArea(
          bottom: false,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Stack(
              children: [
                Positioned(
                  top: _headerExtent,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRect(
                    key: const ValueKey('community-feed-viewport'),
                    child: _buildFeed(),
                  ),
                ),
                Positioned(top: 0, left: 0, right: 0, child: _buildHeader()),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.paddingOf(context).bottom + 14,
                  child: Center(
                    child: FilledButton.icon(
                      key: const ValueKey('community-publish-button'),
                      onPressed: _openPublisher,
                      style: FilledButton.styleFrom(
                        backgroundColor: communityPrimaryButton,
                        minimumSize: const Size(146, 54),
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        shape: const StadiumBorder(),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 21),
                      label: const Text(
                        '发布',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      key: const ValueKey('community-header'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            _HeaderAction(
              tooltip: '返回',
              icon: Icons.arrow_back_ios_new_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Container(
                    key: const ValueKey('community-feed-tabs'),
                    width: double.infinity,
                    height: 44,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xD9FFFFFF),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE3E8F2)),
                    ),
                    child: Row(
                      children: [
                        for (final type in CommunityFeedType.values)
                          Expanded(
                            child: _FeedTab(
                              type: type,
                              selected: _controller.type == type,
                              onTap: () => _selectType(type),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeaderAction(
                  key: const ValueKey('community-search-button'),
                  tooltip: '搜索社区',
                  icon: Icons.search_rounded,
                  onPressed: _openSearch,
                ),
                const SizedBox(width: 6),
                _HeaderProfileAction(
                  key: const ValueKey('community-my-profile-button'),
                  avatarUrl: widget.currentUserAvatarUrl,
                  onPressed: _openMyProfile,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed() {
    return RefreshIndicator(
      key: const ValueKey('community-feed-refresh'),
      onRefresh: _controller.refresh,
      color: communityPrimary,
      child: CustomScrollView(
        key: const ValueKey('community-feed-scroll'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.paddingOf(context).bottom + 96,
            ),
            sliver: SliverToBoxAdapter(child: _buildFeedContent()),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedContent() {
    if (_controller.loading && _controller.posts.isEmpty) {
      return const SizedBox(
        height: 460,
        child: Center(
          child: CircularProgressIndicator(color: communityPrimaryButton),
        ),
      );
    }
    if (_controller.posts.isEmpty) {
      final hasError = _controller.error != null;
      final following = _controller.type == CommunityFeedType.following;
      return Padding(
        padding: const EdgeInsets.only(top: 110),
        child: CommunityEmptyState(
          title: hasError
              ? '加载失败'
              : following
              ? '关注列表暂时还没有内容'
              : '还没有可展示的社区内容',
          subtitle: hasError
              ? _controller.error!
              : following
              ? '去推荐流看看感兴趣的宠友和内容，关注后这里会更热闹。'
              : '先发一条帖子，或者稍后回来看看新的宠物动态。',
          actionLabel: hasError
              ? '重新加载'
              : following
              ? '切换到推荐'
              : '去发布',
          onAction: hasError
              ? () => unawaited(_controller.load())
              : following
              ? () => unawaited(
                  _controller.selectType(CommunityFeedType.recommend),
                )
              : _openPublisher,
        ),
      );
    }
    return Column(
      children: [
        CommunityPostGrid(
          posts: _controller.posts,
          onOpenPost: _openPost,
          onOpenUser: _openProfile,
          onLike: _toggleLike,
        ),
        if (_controller.loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('加载中...', style: TextStyle(color: communityTextSecondary)),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _selectType(CommunityFeedType type) async {
    if (type == CommunityFeedType.following && !widget.authenticated) {
      await widget.requestLogin('登录后即可查看关注动态');
      return;
    }
    await _controller.selectType(type);
  }

  Future<void> _toggleLike(int postId) async {
    if (!widget.authenticated) {
      await widget.requestLogin('登录后即可点赞帖子');
      return;
    }
    try {
      await _controller.toggleLike(postId);
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('点赞失败：$error');
    }
  }

  Future<void> _openPost(CommunityPost post) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CommunityPostDetailPage(
          gateway: widget.gateway,
          postId: post.id,
          authenticated: widget.authenticated,
          currentUserId: widget.currentUserId,
          requestLogin: widget.requestLogin,
          friendsSession: widget.friendsSession,
        ),
      ),
    );
    if (changed == true) await _controller.refresh();
  }

  void _openProfile(int userId) {
    if (userId <= 0) return;
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

  Future<void> _openMyProfile() async {
    if (!widget.authenticated) {
      await widget.requestLogin('登录后即可查看社区主页');
      return;
    }
    final userId = widget.currentUserId;
    if (userId == null || userId <= 0) {
      _showMessage('账号信息不完整，请重新登录后重试');
      return;
    }
    _openProfile(userId);
  }

  Future<void> _openPublisher() async {
    if (!widget.authenticated) {
      await widget.requestLogin('登录后即可发布社区帖子');
      return;
    }
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CommunityPublishPostPage(gateway: widget.gateway),
      ),
    );
    if (created == true) await _controller.refresh();
  }

  Future<void> _openSearch() async {
    if (!widget.authenticated) {
      await widget.requestLogin('登录后即可搜索社区内容');
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunitySearchPage(
          gateway: widget.gateway,
          authenticated: widget.authenticated,
          currentUserId: widget.currentUserId,
          requestLogin: widget.requestLogin,
          friendsSession: widget.friendsSession,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FeedTab extends StatelessWidget {
  const _FeedTab({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final CommunityFeedType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('community-tab-${type.wireValue}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE7EEFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          type.label,
          maxLines: 1,
          style: TextStyle(
            color: selected ? communityPrimaryButton : communityTextSecondary,
            fontSize: 15,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F5F9),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 19, color: communityText),
      ),
    );
  }
}

class _HeaderProfileAction extends StatelessWidget {
  const _HeaderProfileAction({
    super.key,
    required this.avatarUrl,
    required this.onPressed,
  });

  final String avatarUrl;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '我的主页',
      child: Material(
        color: const Color(0xFFF3F5F9),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: SizedBox.square(
                dimension: 32,
                child: CommunityNetworkImage(
                  source: avatarUrl,
                  placeholderIcon: Icons.person_rounded,
                  backgroundColor: const Color(0xFFE8ECF6),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
