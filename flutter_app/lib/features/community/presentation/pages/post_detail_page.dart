import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/media/android_video_surface_exit.dart';
import '../../../../core/media/auto_hiding_video_controls.dart';
import '../../../../core/media/video_player_view_type.dart';
import '../../../../core/network/asset_url_resolver.dart';
import '../../../friends/friends_feature_session.dart';
import '../../../friends/presentation/pages/friend_video_player_page.dart';
import '../../domain/community_models.dart';
import '../community_controller.dart';
import '../community_design.dart';
import 'community_profile_page.dart';
import 'publish_post_page.dart';

class CommunityPostDetailPage extends StatefulWidget {
  const CommunityPostDetailPage({
    super.key,
    required this.gateway,
    required this.postId,
    required this.authenticated,
    required this.currentUserId,
    required this.requestLogin,
    this.friendsSession,
  });

  final CommunityGateway gateway;
  final int postId;
  final bool authenticated;
  final int? currentUserId;
  final CommunityLoginRequest requestLogin;
  final FriendsFeatureSession? friendsSession;

  @override
  State<CommunityPostDetailPage> createState() =>
      _CommunityPostDetailPageState();
}

class _CommunityPostDetailPageState extends State<CommunityPostDetailPage> {
  static const double _composerClearance = 84;
  static const double _replyBarHeight = 38;

  late final CommunityPostDetailController _controller;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  CommunityComment? _replyTarget;
  bool _changed = false;
  bool _allowPop = false;
  bool _isLeaving = false;
  final _videoKey = GlobalKey<_CommunityPostVideoState>();

  @override
  void initState() {
    super.initState();
    _controller = CommunityPostDetailController(
      gateway: widget.gateway,
      postId: widget.postId,
      authenticated: widget.authenticated,
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _allowPop) return;
        unawaited(_requestPop(result ?? _changed));
      },
      child: Scaffold(
        key: const ValueKey('community-post-detail-page'),
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        body: CommunityBackground(
          child: SafeArea(
            bottom: false,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Stack(
                children: [
                  Positioned.fill(
                    child: Column(
                      children: [
                        _buildHeader(),
                        Expanded(child: _buildBody()),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 8,
                    child: _buildComposer(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      key: const ValueKey('community-post-detail-header'),
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.transparent,
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('community-post-detail-back'),
            tooltip: '返回',
            onPressed: () => unawaited(_requestPop(_changed)),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          const Expanded(
            child: Text(
              '帖子详情',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: communityText,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          PopupMenuButton<String>(
            key: const ValueKey('community-post-menu'),
            tooltip: '更多',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: _handlePostMenu,
            itemBuilder: (_) {
              final post = _controller.post;
              final isOwner =
                  post != null && post.userId == widget.currentUserId;
              if (isOwner) {
                return const [
                  PopupMenuItem(value: 'edit', child: Text('编辑帖子')),
                  PopupMenuItem(value: 'delete', child: Text('删除帖子')),
                ];
              }
              return const [
                PopupMenuItem(value: 'report', child: Text('举报帖子')),
                PopupMenuItem(value: 'block', child: Text('拉黑作者')),
              ];
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.loading && _controller.post == null) {
      return const Center(
        child: CircularProgressIndicator(color: communityPrimaryButton),
      );
    }
    final post = _controller.post;
    if (post == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
        children: [
          CommunityEmptyState(
            icon: Icons.cloud_off_outlined,
            title: '帖子加载失败',
            subtitle: _controller.error ?? '请检查网络后重试',
            actionLabel: '重新加载',
            onAction: () => unawaited(_controller.load()),
          ),
        ],
      );
    }
    return RefreshIndicator(
      color: communityPrimaryButton,
      onRefresh: _controller.reload,
      child: ListView(
        key: const ValueKey('community-post-detail-scroll'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          MediaQuery.paddingOf(context).bottom +
              _composerClearance +
              (_replyTarget == null ? 0 : _replyBarHeight),
        ),
        children: [
          _PostBody(
            post: post,
            onOpenAuthor: () => _openProfile(post.userId),
            onOpenImage: _openImage,
            onOpenVideo: () => _openVideo(post.videoUrl),
            onLike: _togglePostLike,
            videoKey: _videoKey,
          ),
          const SizedBox(height: 12),
          _buildCommentsHeader(),
          const SizedBox(height: 8),
          if (_controller.comments.isEmpty)
            const CommunityEmptyState(
              key: ValueKey('community-comments-empty-state'),
              icon: Icons.chat_bubble_outline_rounded,
              title: '还没有评论',
              subtitle: '说说你的看法，成为第一个参与讨论的人。',
            )
          else
            for (final comment in _controller.comments)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CommentTile(
                  comment: comment,
                  onOpenUser: _openProfile,
                  onLike: _toggleCommentLike,
                  onReply: _startReply,
                  onMore: _showCommentActions,
                ),
              ),
          if (_controller.hasMoreComments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton(
                onPressed: _controller.loadingMore
                    ? null
                    : _controller.loadMoreComments,
                child: _controller.loadingMore
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('加载更多评论'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentsHeader() {
    return Row(
      children: [
        const Text(
          '全部评论',
          style: TextStyle(
            color: communityText,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          compactCount(_controller.commentTotal),
          style: const TextStyle(color: communityTextSecondary),
        ),
      ],
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        key: const ValueKey('community-comment-composer'),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(8)),
          border: Border.fromBorderSide(BorderSide(color: communityBorder)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A111827),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyTarget case final target?)
              Container(
                height: 38,
                padding: const EdgeInsets.only(left: 16, right: 6),
                color: communitySoftSurface,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '回复 ${target.author.nickname}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: communityTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '取消回复',
                      onPressed: () => setState(() => _replyTarget = null),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('community-comment-field'),
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      minLines: 1,
                      maxLines: 2,
                      maxLength: 1000,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: _replyTarget == null
                            ? '友善评论，分享你的看法'
                            : '回复 ${_replyTarget!.author.nickname}',
                        filled: true,
                        fillColor: communityMutedSurface,
                        isDense: true,
                        constraints: const BoxConstraints(minHeight: 40),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 40,
                    child: FilledButton(
                      key: const ValueKey('community-send-comment'),
                      onPressed: _controller.working ? null : _submitComment,
                      style: FilledButton.styleFrom(
                        backgroundColor: communityPrimaryButton,
                        disabledBackgroundColor: const Color(0xFFCBD5E1),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(52, 40),
                        shape: const StadiumBorder(),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: _controller.working
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '发送',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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

  Future<bool> _ensureAuthenticated(String message) async {
    if (widget.authenticated) return true;
    await widget.requestLogin(message);
    return false;
  }

  Future<void> _togglePostLike() async {
    if (!await _ensureAuthenticated('登录后即可点赞帖子')) return;
    try {
      await _controller.togglePostLike();
    } on Object catch (error) {
      if (mounted) _showMessage('点赞失败：$error');
    }
  }

  Future<void> _toggleCommentLike(int commentId) async {
    if (!await _ensureAuthenticated('登录后即可点赞评论')) return;
    try {
      await _controller.toggleCommentLike(commentId);
    } on Object catch (error) {
      if (mounted) _showMessage('点赞失败：$error');
    }
  }

  Future<void> _submitComment() async {
    if (!await _ensureAuthenticated('登录后即可参与评论')) return;
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      _showMessage('请输入评论内容');
      return;
    }
    try {
      await _controller.createComment(content, parentId: _replyTarget?.id);
      if (!mounted) return;
      _commentController.clear();
      _commentFocusNode.unfocus();
      setState(() => _replyTarget = null);
      _showMessage('评论已发布');
    } on Object catch (error) {
      if (mounted) _showMessage('评论失败：$error');
    }
  }

  Future<void> _startReply(CommunityComment comment) async {
    if (!await _ensureAuthenticated('登录后即可回复评论')) return;
    if (!mounted) return;
    setState(() => _replyTarget = comment);
    _commentFocusNode.requestFocus();
  }

  void _openImage(CommunityPost post, int index) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            _CommunityImageViewer(images: post.images, initialIndex: index),
      ),
    );
  }

  void _openVideo(String videoUrl) {
    if (videoUrl.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FriendVideoPlayerPage(videoUrl: videoUrl),
      ),
    );
  }

  Future<void> _requestPop(bool result) async {
    if (_isLeaving) return;
    _isLeaving = true;

    // PlatformView 的原生 Surface 不随 Flutter 路由动画同步，先暂停并从
    // widget tree 移除视频，等移除完成后再启动返回动画。
    await _videoKey.currentState?.prepareForNavigation();
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
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

  Future<void> _handlePostMenu(String action) async {
    final post = _controller.post;
    if (post == null) return;
    final isOwner = post.userId == widget.currentUserId;
    if (isOwner && action == 'edit') {
      final updated = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => CommunityPublishPostPage(
            gateway: widget.gateway,
            initialPost: post,
          ),
        ),
      );
      if (updated == true) {
        _changed = true;
        await _controller.load();
      }
      return;
    }
    if (isOwner && action == 'delete') {
      if (!await confirmCommunityPostDeletion(context) || !mounted) return;
      try {
        await widget.gateway.deleteCommunityPost(post.id);
        if (!mounted) return;
        await _requestPop(true);
      } on Object catch (error) {
        if (mounted) _showMessage('删除失败：$error');
      }
      return;
    }
    if (!await _ensureAuthenticated('登录后即可使用内容安全功能')) return;
    if (!mounted) return;
    if (action == 'report') {
      await _report(targetType: 'COMMUNITY_POST', targetId: post.id);
    } else if (action == 'block') {
      await _blockUser(post.author);
    }
  }

  Future<void> _showCommentActions(CommunityComment comment) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('举报评论'),
              onTap: () => Navigator.pop(context, 'report'),
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded),
              title: const Text('拉黑该用户'),
              onTap: () => Navigator.pop(context, 'block'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !await _ensureAuthenticated('登录后即可使用内容安全功能')) {
      return;
    }
    if (!mounted) return;
    if (action == 'report') {
      await _report(targetType: 'COMMUNITY_COMMENT', targetId: comment.id);
    } else {
      await _blockUser(comment.author);
    }
  }

  Future<void> _report({
    required String targetType,
    required int targetId,
  }) async {
    final reason = await showModalBottomSheet<_ReportReason>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '请选择举报原因',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            for (final reason in _ReportReason.values)
              ListTile(
                title: Text(reason.label),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, reason),
              ),
          ],
        ),
      ),
    );
    if (reason == null) return;
    try {
      await widget.gateway.reportCommunityContent(
        targetType: targetType,
        targetId: targetId,
        reason: reason.value,
      );
      if (mounted) _showMessage('举报已提交，我们会尽快处理');
    } on Object catch (error) {
      if (mounted) _showMessage('举报失败：$error');
    }
  }

  Future<void> _blockUser(CommunityUser user) async {
    if (user.id <= 0 || user.id == widget.currentUserId) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x990F172A),
      builder: (dialogContext) => _CommunityBlockUserDialog(
        userName: user.nickname,
        onCancel: () => Navigator.pop(dialogContext, false),
        onConfirm: () => Navigator.pop(dialogContext, true),
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.gateway.blockCommunityUser(user.id);
      if (!mounted) return;
      _showMessage('已拉黑 ${user.nickname}');
    } on Object catch (error) {
      if (mounted) _showMessage('拉黑失败：$error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CommunityBlockUserDialog extends StatelessWidget {
  const _CommunityBlockUserDialog({
    required this.userName,
    required this.onCancel,
    required this.onConfirm,
  });

  final String userName;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const ValueKey('community-block-user-dialog'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        key: const ValueKey('community-block-user-dialog-panel'),
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x240F172A),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.block_rounded,
                color: communityError,
                size: 25,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '拉黑用户',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: communityText,
                fontSize: 19,
                height: 1.25,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '拉黑 $userName 后，将减少看到对方内容。确定继续吗？',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: communityTextSecondary,
                fontSize: 14,
                height: 1.5,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      key: const ValueKey('community-block-user-cancel'),
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: communityText,
                        side: const BorderSide(color: communityBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: FilledButton(
                      key: const ValueKey('community-block-user-confirm'),
                      onPressed: onConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: communityError,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('确认拉黑'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PostBody extends StatelessWidget {
  const _PostBody({
    required this.post,
    required this.onOpenAuthor,
    required this.onOpenImage,
    required this.onOpenVideo,
    required this.onLike,
    required this.videoKey,
  });

  final CommunityPost post;
  final VoidCallback onOpenAuthor;
  final void Function(CommunityPost post, int index) onOpenImage;
  final VoidCallback onOpenVideo;
  final VoidCallback onLike;
  final GlobalKey<_CommunityPostVideoState> videoKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: communityCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpenAuthor,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                CommunityAvatar(user: post.author, radius: 23),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.author.nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: communityText,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (post.author.verified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              color: communityPrimary,
                              size: 17,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        communityDate(post.createdAt),
                        style: const TextStyle(
                          color: communityTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.isFeatured)
                  const _PostStatusBadge(label: '精选', featured: true),
                if (post.isPinned) ...[
                  const SizedBox(width: 6),
                  const _PostStatusBadge(label: '置顶'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            post.content,
            style: const TextStyle(
              color: communityText,
              fontSize: 17,
              height: 1.65,
            ),
          ),
          if (post.images.isNotEmpty) ...[
            const SizedBox(height: 16),
            _PostImageGrid(post: post, onOpenImage: onOpenImage),
          ],
          if (post.videoUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            KeyedSubtree(
              key: const ValueKey('community-post-video'),
              child: _CommunityPostVideo(
                key: videoKey,
                videoUrl: post.videoUrl,
                posterUrl: post.videoCoverUrl,
                onFullscreen: onOpenVideo,
              ),
            ),
          ],
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in post.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag.startsWith('#') ? tag : '#$tag',
                      style: const TextStyle(
                        color: communityPrimaryButton,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  icon: Icons.visibility_outlined,
                  value: post.viewCount,
                  label: '浏览',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  key: const ValueKey('community-detail-like'),
                  icon: post.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  value: post.likeCount,
                  label: '点赞',
                  active: post.isLiked,
                  onTap: onLike,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  icon: Icons.chat_bubble_outline_rounded,
                  value: post.commentCount,
                  label: '评论',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final _communityVideoPlaybackCoordinator = _CommunityVideoPlaybackCoordinator();

class _CommunityVideoPlaybackCoordinator {
  static const double autoPlayVisibilityThreshold = 0.6;

  final Map<_CommunityPostVideoState, double> _visibleFractions = {};
  _CommunityPostVideoState? _activeVideo;
  bool _evaluationScheduled = false;
  int _activationEpoch = 0;

  void updateVisibility(
    _CommunityPostVideoState video,
    double visibleFraction,
  ) {
    _visibleFractions[video] = visibleFraction;
    _scheduleEvaluation();
  }

  void unregister(_CommunityPostVideoState video) {
    _visibleFractions.remove(video);
    if (identical(_activeVideo, video)) {
      _activeVideo = null;
      _activationEpoch += 1;
    }
    _scheduleEvaluation();
  }

  void deactivate(_CommunityPostVideoState video) {
    if (!identical(_activeVideo, video)) return;
    _switchTo(null);
  }

  void playManually(_CommunityPostVideoState video) {
    _switchTo(video);
  }

  void pauseManually(_CommunityPostVideoState video) {
    if (identical(_activeVideo, video)) {
      _activeVideo = null;
      _activationEpoch += 1;
    }
    unawaited(video.pauseFromCoordinator());
  }

  Future<void> pauseForNavigation(_CommunityPostVideoState video) async {
    if (identical(_activeVideo, video)) {
      _activeVideo = null;
      _activationEpoch += 1;
    }
    await video.pauseFromCoordinator();
  }

  void _scheduleEvaluation() {
    if (_evaluationScheduled) return;
    _evaluationScheduled = true;
    scheduleMicrotask(() {
      _evaluationScheduled = false;
      _evaluate();
    });
  }

  void _evaluate() {
    _CommunityPostVideoState? nextVideo;
    var largestVisibleFraction = -1.0;

    final current = _activeVideo;
    final currentFraction = _visibleFractions[current];
    if (current != null &&
        current.canAutoPlay &&
        currentFraction != null &&
        currentFraction >= autoPlayVisibilityThreshold) {
      nextVideo = current;
      largestVisibleFraction = currentFraction;
    }

    for (final entry in _visibleFractions.entries) {
      if (!entry.key.canAutoPlay ||
          entry.value < autoPlayVisibilityThreshold ||
          entry.value <= largestVisibleFraction) {
        continue;
      }
      nextVideo = entry.key;
      largestVisibleFraction = entry.value;
    }

    _switchTo(nextVideo);
  }

  void _switchTo(_CommunityPostVideoState? nextVideo) {
    final previousVideo = _activeVideo;
    if (identical(previousVideo, nextVideo)) {
      if (nextVideo != null && !nextVideo.isPlaying) {
        unawaited(nextVideo.playFromCoordinator());
      }
      return;
    }

    _activeVideo = nextVideo;
    final epoch = ++_activationEpoch;
    unawaited(_completeSwitch(previousVideo, nextVideo, epoch));
  }

  Future<void> _completeSwitch(
    _CommunityPostVideoState? previousVideo,
    _CommunityPostVideoState? nextVideo,
    int epoch,
  ) async {
    await previousVideo?.pauseFromCoordinator();
    if (epoch != _activationEpoch || !identical(_activeVideo, nextVideo)) {
      return;
    }
    await nextVideo?.playFromCoordinator();
  }
}

class _CommunityPostVideo extends StatefulWidget {
  const _CommunityPostVideo({
    super.key,
    required this.videoUrl,
    required this.posterUrl,
    required this.onFullscreen,
  });

  final String videoUrl;
  final String posterUrl;
  final VoidCallback onFullscreen;

  @override
  State<_CommunityPostVideo> createState() => _CommunityPostVideoState();
}

class _CommunityPostVideoState extends State<_CommunityPostVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Future<void>? _initialization;
  ScrollableState? _scrollable;
  bool _playing = false;
  bool _appIsActive = true;
  bool _routeIsActive = true;
  bool _manualPause = false;
  bool _detached = false;
  double _detachedAspectRatio = 16 / 9;
  bool _visibilityUpdateScheduled = false;
  double _visibleFraction = 0;

  bool get isPlaying => _controller?.value.isPlaying ?? false;

  bool get canAutoPlay {
    final controller = _controller;
    return mounted &&
        _appIsActive &&
        _routeIsActive &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        !_manualPause &&
        !_detached &&
        controller != null &&
        controller.value.isInitialized;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appIsActive = switch (WidgetsBinding.instance.lifecycleState) {
      null || AppLifecycleState.resumed => true,
      _ => false,
    };
    _initialization = _initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextScrollable = Scrollable.maybeOf(context);
    if (!identical(_scrollable, nextScrollable)) {
      _scrollable?.position.removeListener(_scheduleVisibilityUpdate);
      _scrollable = nextScrollable;
      _scrollable?.position.addListener(_scheduleVisibilityUpdate);
    }
    _routeIsActive = TickerMode.of(context);
    _scheduleVisibilityUpdate();
  }

  Future<void> _initialize() async {
    final uri = Uri.tryParse(resolveAssetUrl(widget.videoUrl));
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw StateError('视频地址无效');
    }
    final controller = VideoPlayerController.networkUrl(
      uri,
      viewType: platformAdaptiveVideoViewType,
    );
    _controller = controller;
    await controller.initialize();
    if (!mounted || !identical(_controller, controller)) {
      await controller.dispose();
      return;
    }
    await controller.setLooping(false);
    _playing = controller.value.isPlaying;
    controller.addListener(_handlePlaybackChanged);
    if (mounted) {
      setState(() {});
      _scheduleVisibilityUpdate();
    }
  }

  void _handlePlaybackChanged() {
    final controller = _controller;
    if (!mounted || controller == null) return;
    final playing = controller.value.isPlaying;
    if (playing == _playing) return;
    _playing = playing;
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant _CommunityPostVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl == widget.videoUrl) return;
    _communityVideoPlaybackCoordinator.unregister(this);
    unawaited(_disposeController());
    _playing = false;
    _manualPause = false;
    _initialization = _initialize();
    _scheduleVisibilityUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsActive = state == AppLifecycleState.resumed;
    if (_appIsActive) {
      _scheduleVisibilityUpdate();
    } else {
      _communityVideoPlaybackCoordinator.deactivate(this);
    }
  }

  void _scheduleVisibilityUpdate() {
    if (!mounted || _visibilityUpdateScheduled) return;
    _visibilityUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityUpdateScheduled = false;
      if (mounted) _updateVisibility();
    });
  }

  void _updateVisibility() {
    final videoBox = context.findRenderObject();
    final viewportBox = _scrollable?.context.findRenderObject();
    var visibleFraction = 0.0;

    if (videoBox is RenderBox &&
        videoBox.hasSize &&
        viewportBox is RenderBox &&
        viewportBox.hasSize &&
        videoBox.size.height > 0) {
      final videoRect = videoBox.localToGlobal(Offset.zero) & videoBox.size;
      final viewportRect =
          viewportBox.localToGlobal(Offset.zero) & viewportBox.size;
      final intersection = videoRect.intersect(viewportRect);
      if (!intersection.isEmpty) {
        visibleFraction = (intersection.height / videoRect.height)
            .clamp(0.0, 1.0)
            .toDouble();
      }
    }

    final wasAutoPlayVisible =
        _visibleFraction >=
        _CommunityVideoPlaybackCoordinator.autoPlayVisibilityThreshold;
    _visibleFraction = visibleFraction;
    final isAutoPlayVisible =
        visibleFraction >=
        _CommunityVideoPlaybackCoordinator.autoPlayVisibilityThreshold;
    if (wasAutoPlayVisible && !isAutoPlayVisible) {
      _manualPause = false;
    }
    _communityVideoPlaybackCoordinator.updateVisibility(this, visibleFraction);
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_handlePlaybackChanged);
    if (controller == null) return;
    try {
      await controller.dispose();
    } on Object {
      // 页面退出不能被原生播放器释放异常阻断。
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollable?.position.removeListener(_scheduleVisibilityUpdate);
    _communityVideoPlaybackCoordinator.unregister(this);
    unawaited(_disposeController());
    super.dispose();
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      _manualPause = true;
      _communityVideoPlaybackCoordinator.pauseManually(this);
    } else {
      _manualPause = false;
      _communityVideoPlaybackCoordinator.playManually(this);
    }
  }

  Future<void> playFromCoordinator() async {
    final controller = _controller;
    if (!mounted ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isPlaying) {
      return;
    }
    try {
      await controller.play();
    } on Object {
      if (identical(_controller, controller)) {
        try {
          await controller.pause();
        } on Object {
          // 播放器自身错误会继续由现有错误状态展示。
        }
      }
    }
  }

  Future<void> pauseFromCoordinator() async {
    final controller = _controller;
    if (controller == null || !controller.value.isPlaying) return;
    try {
      await controller.pause();
    } on Object {
      // 页面切换和可见性变化不能被原生播放器暂停异常阻断。
    }
  }

  Future<void> prepareForNavigation() async {
    _manualPause = true;
    _communityVideoPlaybackCoordinator.unregister(this);
    await pauseFromCoordinator();
    if (AndroidVideoSurfaceExit.isSupported) {
      await AndroidVideoSurfaceExit.prepareForRouteExit();
    }
    if (!mounted) return;

    final aspectRatio = _controller?.value.aspectRatio ?? 0;
    if (aspectRatio > 0) {
      _detachedAspectRatio = aspectRatio.clamp(9 / 16, 16 / 9).toDouble();
    }
    // 原生 Surface 已隐藏并确认销毁；父页面在占位图绘制后再启动返回动画。
    setState(() => _detached = true);
    unawaited(_disposeController());
  }

  Future<void> _openFullscreen() async {
    await _communityVideoPlaybackCoordinator.pauseForNavigation(this);
    if (mounted) widget.onFullscreen();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          if (_detached) {
            return AspectRatio(
              key: const ValueKey('community-post-video-detached'),
              aspectRatio: _detachedAspectRatio,
              child: ColoredBox(
                color: const Color(0xFF18233F),
                child: widget.posterUrl.isEmpty
                    ? null
                    : CommunityNetworkImage(source: widget.posterUrl),
              ),
            );
          }
          final controller = _controller;
          final initialized =
              snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasError &&
              controller != null &&
              controller.value.isInitialized;
          final aspectRatio = initialized
              ? controller.value.aspectRatio.clamp(9 / 16, 16 / 9).toDouble()
              : 16 / 9;
          return AspectRatio(
            aspectRatio: aspectRatio,
            child: ColoredBox(
              color: const Color(0xFF18233F),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (initialized)
                    AutoHidingVideoControls(
                      isPlaying: _playing,
                      surfaceKey: const ValueKey(
                        'community-post-video-surface',
                      ),
                      controls: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: IconButton(
                              key: const ValueKey(
                                'community-post-video-toggle',
                              ),
                              tooltip: _playing ? '暂停' : '播放',
                              onPressed: _togglePlayback,
                              iconSize: 54,
                              color: Colors.white,
                              icon: Icon(
                                _playing
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_fill_rounded,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton.filledTonal(
                              key: const ValueKey(
                                'community-post-video-fullscreen',
                              ),
                              tooltip: '全屏播放',
                              onPressed: _openFullscreen,
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0x990F172A),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(
                                Icons.fullscreen_rounded,
                                size: 26,
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: VideoProgressIndicator(
                              controller,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: communityPrimaryButton,
                                bufferedColor: Colors.white38,
                                backgroundColor: Colors.white24,
                              ),
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                            ),
                          ),
                        ],
                      ),
                      child: VideoPlayer(controller),
                    )
                  else if (widget.posterUrl.isNotEmpty)
                    CommunityNetworkImage(source: widget.posterUrl),
                  if (!initialized)
                    ColoredBox(
                      color: const Color(0x33000000),
                      child: Center(
                        child: snapshot.hasError
                            ? const Text(
                                '视频无法播放',
                                style: TextStyle(color: Colors.white70),
                              )
                            : const CircularProgressIndicator(
                                color: Colors.white,
                              ),
                      ),
                    ),
                  if (!initialized)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filledTonal(
                        key: const ValueKey('community-post-video-fullscreen'),
                        tooltip: '全屏播放',
                        onPressed: _openFullscreen,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0x990F172A),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.fullscreen_rounded, size: 26),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PostImageGrid extends StatelessWidget {
  const _PostImageGrid({required this.post, required this.onOpenImage});

  final CommunityPost post;
  final void Function(CommunityPost post, int index) onOpenImage;

  @override
  Widget build(BuildContext context) {
    if (post.images.length == 1) {
      return GestureDetector(
        key: const ValueKey('community-post-image-0'),
        onTap: () => onOpenImage(post, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                child: CommunityNetworkImage(
                  source: post.images.first,
                  fit: BoxFit.fitWidth,
                ),
              ),
              const Positioned(
                right: 10,
                bottom: 10,
                child: _ImageBadge(
                  icon: Icons.zoom_out_map_rounded,
                  label: '点击全屏查看',
                ),
              ),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: post.images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
      ),
      itemBuilder: (context, index) => GestureDetector(
        key: ValueKey('community-post-image-$index'),
        onTap: () => onOpenImage(post, index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CommunityNetworkImage(source: post.images[index]),
              Positioned(
                left: 7,
                bottom: 7,
                child: _ImageBadge(
                  icon: Icons.image_outlined,
                  label: '${index + 1}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageBadge extends StatelessWidget {
  const _ImageBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x99111827),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostStatusBadge extends StatelessWidget {
  const _PostStatusBadge({required this.label, this.featured = false});

  final String label;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: featured ? const Color(0xFFFFF4DD) : const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: featured ? const Color(0xFFB66A00) : communityPrimaryButton,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final int value;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          height: 62,
          decoration: communityCardDecoration(
            color: active ? const Color(0xFFFFF0F2) : communitySoftSurface,
            borderColor: active ? const Color(0xFFFFCDD3) : communityBorder,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: active ? communityError : communityTextSecondary,
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    compactCount(value),
                    style: TextStyle(
                      color: active ? communityError : communityText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: communityTextSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.onOpenUser,
    required this.onLike,
    required this.onReply,
    required this.onMore,
    this.nested = false,
  });

  final CommunityComment comment;
  final ValueChanged<int> onOpenUser;
  final ValueChanged<int> onLike;
  final ValueChanged<CommunityComment> onReply;
  final ValueChanged<CommunityComment> onMore;
  final bool nested;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: EdgeInsets.all(nested ? 11 : 14),
      decoration: communityCardDecoration(
        color: nested ? communitySoftSurface : communitySurface,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => onOpenUser(comment.userId),
            child: CommunityAvatar(
              user: comment.author,
              radius: nested ? 15 : 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.author.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: communityText,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      communityDate(comment.createdAt),
                      style: const TextStyle(
                        color: communityHint,
                        fontSize: 10,
                      ),
                    ),
                    InkResponse(
                      onTap: () => onMore(comment),
                      radius: 19,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.more_horiz_rounded, size: 17),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  comment.content,
                  style: const TextStyle(
                    color: communityText,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => onLike(comment.id),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      icon: Icon(
                        comment.isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 16,
                        color: comment.isLiked
                            ? communityError
                            : communityTextSecondary,
                      ),
                      label: Text(
                        compactCount(comment.likeCount),
                        style: TextStyle(
                          color: comment.isLiked
                              ? communityError
                              : communityTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => onReply(comment),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('回复'),
                    ),
                  ],
                ),
                if (comment.replies.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  for (final reply in comment.replies)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _CommentTile(
                        comment: reply,
                        onOpenUser: onOpenUser,
                        onLike: onLike,
                        onReply: onReply,
                        onMore: onMore,
                        nested: true,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return nested ? content : content;
  }
}

class _CommunityImageViewer extends StatefulWidget {
  const _CommunityImageViewer({
    required this.images,
    required this.initialIndex,
  });

  final List<String> images;
  final int initialIndex;

  @override
  State<_CommunityImageViewer> createState() => _CommunityImageViewerState();
}

class _CommunityImageViewerState extends State<_CommunityImageViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        title: Text('${_index + 1}/${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: CommunityNetworkImage(
              source: widget.images[index],
              fit: BoxFit.contain,
              backgroundColor: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

enum _ReportReason {
  spam('SPAM', '垃圾广告'),
  illegal('ILLEGAL', '违法违规'),
  pornography('PORNOGRAPHY', '色情低俗'),
  fraud('FRAUD', '欺诈信息'),
  harassment('HARASSMENT', '骚扰攻击'),
  other('OTHER', '其他问题');

  const _ReportReason(this.value, this.label);

  final String value;
  final String label;
}
