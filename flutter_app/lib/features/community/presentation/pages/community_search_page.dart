import 'dart:async';

import 'package:flutter/material.dart';

import '../../../friends/friends_feature_session.dart';
import '../../domain/community_models.dart';
import '../community_controller.dart';
import '../community_design.dart';
import 'community_profile_page.dart';
import 'post_detail_page.dart';

class CommunitySearchPage extends StatefulWidget {
  const CommunitySearchPage({
    super.key,
    required this.gateway,
    required this.authenticated,
    required this.currentUserId,
    required this.requestLogin,
    this.friendsSession,
  });

  final CommunityGateway gateway;
  final bool authenticated;
  final int? currentUserId;
  final CommunityLoginRequest requestLogin;
  final FriendsFeatureSession? friendsSession;

  @override
  State<CommunitySearchPage> createState() => _CommunitySearchPageState();
}

class _CommunitySearchPageState extends State<CommunitySearchPage> {
  late final CommunitySearchController _controller;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _controller = CommunitySearchController(
      gateway: widget.gateway,
      authenticated: widget.authenticated,
    );
    _scrollController.addListener(_handleScroll);
    unawaited(_controller.loadHotTags());
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      unawaited(_controller.loadMore());
    }
  }

  void _handleChanged(String value) {
    setState(() {});
    _searchTimer?.cancel();
    _searchTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_controller.searchTags(value)),
    );
  }

  Future<void> _submit(String value) async {
    _searchTimer?.cancel();
    FocusScope.of(context).unfocus();
    await _controller.searchAndSelectFirst(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('community-search-page'),
      backgroundColor: Colors.transparent,
      body: CommunityBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildTopArea(),
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => RefreshIndicator(
                    onRefresh: _controller.refresh,
                    color: communityPrimary,
                    child: ListView(
                      key: const ValueKey('community-search-results'),
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        18,
                        16,
                        MediaQuery.paddingOf(context).bottom + 28,
                      ),
                      children: _buildContent(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopArea() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFAFFFFFF),
        border: Border(bottom: BorderSide(color: communityBorder)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 14),
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _HeaderIconButton(
                      tooltip: '返回',
                      icon: Icons.arrow_back_ios_new_rounded,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const Text(
                    '搜索社区',
                    style: TextStyle(
                      color: communityText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            TextField(
              key: const ValueKey('community-search-field'),
              controller: _textController,
              autofocus: true,
              onChanged: _handleChanged,
              onSubmitted: _submit,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索社区话题',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: communityTextSecondary,
                ),
                suffixIcon: _textController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空',
                        onPressed: () {
                          _textController.clear();
                          _handleChanged('');
                        },
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                filled: true,
                fillColor: const Color(0xFFF3F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: communityPrimary,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    final selectedTag = _controller.selectedTag;
    return [
      Row(
        children: [
          Icon(
            _controller.keyword.isEmpty
                ? Icons.local_fire_department_rounded
                : Icons.tag_rounded,
            size: 20,
            color: _controller.keyword.isEmpty
                ? const Color(0xFFE86A4A)
                : communityPrimary,
          ),
          const SizedBox(width: 7),
          Text(
            _controller.keyword.isEmpty ? '热议话题' : '相关话题',
            style: const TextStyle(
              color: communityText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_controller.loadingTags) ...[
            const Spacer(),
            const SizedBox.square(
              dimension: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
      const SizedBox(height: 13),
      if (!_controller.loadingTags && _controller.tags.isEmpty)
        CommunityEmptyState(
          icon: _controller.error == null
              ? Icons.tag_outlined
              : Icons.cloud_off_outlined,
          title: _controller.error == null ? '没有匹配的话题' : '话题加载失败',
          subtitle: _controller.error == null ? '换个关键词再试试' : _controller.error!,
          actionLabel: _controller.error == null ? null : '重新加载',
          onAction: _controller.error == null
              ? null
              : () => unawaited(_controller.refresh()),
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 9,
          children: [
            for (final tag in _controller.tags)
              _TopicChip(
                tag: tag,
                selected: selectedTag?.id == tag.id,
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  unawaited(_controller.selectTag(tag));
                },
              ),
          ],
        ),
      if (selectedTag != null) ...[
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: Text(
                '${selectedTag.name} 内容',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: communityText,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_controller.posts.isNotEmpty)
              Text(
                '${_controller.posts.length} 条',
                style: const TextStyle(
                  color: communityTextSecondary,
                  fontSize: 13,
                ),
              ),
          ],
        ),
        const SizedBox(height: 13),
        if (_controller.loadingPosts)
          const SizedBox(
            height: 280,
            child: Center(
              child: CircularProgressIndicator(color: communityPrimaryButton),
            ),
          )
        else if (_controller.posts.isEmpty)
          CommunityEmptyState(
            icon: _controller.error == null
                ? Icons.inbox_outlined
                : Icons.cloud_off_outlined,
            title: _controller.error == null ? '这个话题还没有内容' : '内容加载失败',
            subtitle: _controller.error == null
                ? '稍后再来看看新的分享'
                : _controller.error!,
            actionLabel: _controller.error == null ? null : '重新加载',
            onAction: _controller.error == null
                ? null
                : () => unawaited(_controller.selectTag(selectedTag)),
          )
        else ...[
          CommunityPostGrid(
            posts: _controller.posts,
            onOpenPost: _openPost,
            onOpenUser: _openProfile,
            onLike: _toggleLike,
          ),
          if (_controller.loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ],
    ];
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
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
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 19, color: communityText),
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.tag,
    required this.selected,
    required this.onPressed,
  });

  final CommunityTag tag;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = tag.name.startsWith('#') ? tag.name : '#${tag.name}';
    return ChoiceChip(
      key: ValueKey('community-search-tag-${tag.id}'),
      selected: selected,
      onSelected: (_) => onPressed(),
      label: Text(
        tag.usageCount > 0 ? '$label  ${compactCount(tag.usageCount)}' : label,
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : communityText,
        fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? communityPrimaryButton : communityBorder,
      ),
      backgroundColor: Colors.white,
      selectedColor: communityPrimaryButton,
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    );
  }
}
