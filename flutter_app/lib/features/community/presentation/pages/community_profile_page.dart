import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

import '../../../friends/domain/friend_messaging_models.dart';
import '../../../friends/domain/friend_relation_models.dart';
import '../../../friends/friends_feature_session.dart';
import '../../../friends/presentation/friend_chat_page.dart';
import '../../../friends/presentation/friend_request_list_page.dart';
import '../../domain/community_models.dart';
import '../community_controller.dart';
import '../community_design.dart';
import 'community_blacklist_page.dart';
import 'community_connections_page.dart';
import 'edit_community_profile_page.dart';
import 'post_detail_page.dart';
import 'publish_post_page.dart';

const _communityProfileSystemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarBrightness: Brightness.dark,
  statusBarIconBrightness: Brightness.light,
  systemStatusBarContrastEnforced: false,
);
const _communityProfileActionShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(8)),
);
const _communityProfileActionTextStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
);

class CommunityProfilePage extends StatefulWidget {
  const CommunityProfilePage({
    super.key,
    required this.gateway,
    required this.userId,
    required this.authenticated,
    required this.currentUserId,
    required this.requestLogin,
    this.friendsSession,
    this.initiallyBlocked = false,
  });

  final CommunityGateway gateway;
  final int userId;
  final bool authenticated;
  final int? currentUserId;
  final CommunityLoginRequest requestLogin;
  final FriendsFeatureSession? friendsSession;
  final bool initiallyBlocked;

  @override
  State<CommunityProfilePage> createState() => _CommunityProfilePageState();
}

class _CommunityProfilePageState extends State<CommunityProfilePage> {
  late final CommunityProfileController _controller;
  FriendRelationshipSummary? _friendRelationship;
  bool _friendLoading = false;
  late bool _blockedByMe;
  bool _unblocking = false;

  bool get _isSelf => widget.currentUserId == widget.userId;

  @override
  void initState() {
    super.initState();
    _blockedByMe = widget.initiallyBlocked;
    _controller = CommunityProfileController(
      gateway: widget.gateway,
      userId: widget.userId,
      authenticated: widget.authenticated,
    );
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait<void>([
      _controller.load(),
      if (!_blockedByMe) _loadFriendRelationship(),
    ]);
  }

  Future<void> _loadFriendRelationship() async {
    final session = widget.friendsSession;
    if (!widget.authenticated || _isSelf || session == null) return;
    setState(() => _friendLoading = true);
    try {
      final result = await session.repository.loadRelationshipSummary(
        targetUserId: widget.userId,
      );
      if (mounted) setState(() => _friendRelationship = result);
    } on Object {
      // 社区资料仍可独立展示，好友关系失败不阻断页面。
    } finally {
      if (mounted) setState(() => _friendLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      key: const ValueKey('community-profile-system-ui'),
      value: _communityProfileSystemUiOverlayStyle,
      child: Scaffold(
        key: const ValueKey('community-profile-page'),
        backgroundColor: Colors.transparent,
        body: CommunityBackground(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.loading && _controller.profile == null) {
      return SafeArea(
        bottom: false,
        child: Stack(
          children: [
            const Center(
              child: CircularProgressIndicator(color: communityPrimaryButton),
            ),
            _backButton(),
          ],
        ),
      );
    }
    final profile = _controller.profile;
    if (profile == null) {
      return SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 130, 24, 24),
              children: [
                CommunityEmptyState(
                  icon: Icons.person_off_outlined,
                  title: '个人主页加载失败',
                  subtitle: _controller.error ?? '请检查网络后重试',
                  actionLabel: '重新加载',
                  onAction: _load,
                ),
              ],
            ),
            _backButton(),
          ],
        ),
      );
    }
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    return RefreshIndicator(
      color: communityPrimaryButton,
      edgeOffset: statusBarHeight,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 28,
        ),
        children: [
          _ProfileHero(
            profile: profile,
            isSelf: _isSelf || profile.relationship.isSelf,
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Transform.translate(
                  offset: const Offset(0, -18),
                  child: _buildProfileSummary(profile),
                ),
                Transform.translate(
                  offset: const Offset(0, -8),
                  child: _buildStats(profile),
                ),
                _buildActions(profile),
                const SizedBox(height: 22),
                _buildPostsHeader(profile),
                const SizedBox(height: 10),
                _buildPosts(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _backButton() {
    return Positioned(
      top: 10,
      left: 10,
      child: IconButton.filledTonal(
        tooltip: '返回',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
      ),
    );
  }

  Widget _buildProfileSummary(CommunityProfile profile) {
    final user = profile.user;
    final relation = profile.relationship;
    return Container(
      key: const ValueKey('community-profile-summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: communityCardDecoration(),
      child: Column(
        children: [
          Container(
            key: const ValueKey('community-profile-avatar'),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: communitySurface,
              shape: BoxShape.circle,
              border: Border.all(color: communityBorder),
            ),
            child: CommunityAvatar(user: user, radius: 43),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  user.nickname,
                  key: const ValueKey('community-profile-nickname'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: communityText,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (user.verified) ...[
                const SizedBox(width: 5),
                const Icon(
                  Icons.verified_rounded,
                  size: 20,
                  color: communityPrimary,
                ),
              ],
            ],
          ),
          if (user.username.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              '@${user.username}',
              style: const TextStyle(
                color: communityTextSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            user.bio.isEmpty ? '这个宠友还没有填写个人简介' : user.bio,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: user.bio.isEmpty ? communityHint : communityTextSecondary,
              height: 1.5,
              fontSize: 14,
            ),
          ),
          if (!relation.isSelf &&
              (relation.isFollowedBy || relation.isMutualFollow)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: relation.isMutualFollow
                    ? const Color(0xFFEAF8F0)
                    : const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                relation.isMutualFollow ? '互相关注' : 'TA 关注了你',
                style: TextStyle(
                  color: relation.isMutualFollow
                      ? const Color(0xFF168A52)
                      : communityPrimaryButton,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStats(CommunityProfile profile) {
    return Container(
      decoration: communityCardDecoration(),
      height: 78,
      child: Row(
        children: [
          Expanded(
            child: _StatButton(label: '帖子', value: profile.stats.postCount),
          ),
          const VerticalDivider(indent: 18, endIndent: 18),
          Expanded(
            child: _StatButton(
              label: '关注',
              value: profile.stats.followingCount,
              onTap: () => _openConnections(CommunityConnectionType.following),
            ),
          ),
          const VerticalDivider(indent: 18, endIndent: 18),
          Expanded(
            child: _StatButton(
              label: '粉丝',
              value: profile.stats.followerCount,
              onTap: () => _openConnections(CommunityConnectionType.followers),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(CommunityProfile profile) {
    if (_isSelf || profile.relationship.isSelf) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('community-edit-profile'),
                  onPressed: _openEditor,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('编辑资料'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: communityPrimaryButton,
                    minimumSize: const Size.fromHeight(46),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: _communityProfileActionShape,
                    side: const BorderSide(color: communityPrimaryButton),
                    textStyle: _communityProfileActionTextStyle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('community-profile-publish'),
                  onPressed: _openPublisher,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('发布帖子'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: _communityProfileActionShape,
                    backgroundColor: communityPrimaryButton,
                    textStyle: _communityProfileActionTextStyle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('community-blacklist-entry'),
              onPressed: _openBlacklist,
              icon: const Icon(Icons.person_off_outlined, size: 18),
              label: const Text('黑名单'),
              style: OutlinedButton.styleFrom(
                foregroundColor: communityTextSecondary,
                minimumSize: const Size.fromHeight(44),
                shape: _communityProfileActionShape,
                side: const BorderSide(color: communityBorder),
                textStyle: _communityProfileActionTextStyle,
              ),
            ),
          ),
        ],
      );
    }
    if (_blockedByMe) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const ValueKey('community-remove-from-blacklist'),
          onPressed: _unblocking ? null : _confirmRemoveFromBlacklist,
          icon: _unblocking
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_remove_outlined, size: 19),
          label: const Text('移出黑名单'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            foregroundColor: const Color(0xFFC2413B),
            side: const BorderSide(color: Color(0xFFE7AAA6)),
            shape: _communityProfileActionShape,
            textStyle: _communityProfileActionTextStyle,
          ),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('community-follow-button'),
            onPressed: _controller.working ? null : _toggleFollow,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              backgroundColor: profile.relationship.isFollowing
                  ? const Color(0xFFE8ECF6)
                  : communityPrimaryButton,
              foregroundColor: profile.relationship.isFollowing
                  ? communityText
                  : Colors.white,
            ),
            icon: Icon(
              profile.relationship.isFollowing
                  ? Icons.check_rounded
                  : Icons.add_rounded,
              size: 20,
            ),
            label: Text(profile.relationship.isFollowing ? '已关注' : '关注'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _buildFriendButton(profile.user)),
      ],
    );
  }

  Widget _buildFriendButton(CommunityUser user) {
    final relation = _friendRelationship;
    final (icon, label) = switch (relation) {
      FriendRelationshipSummary(isFriend: true) => (
        Icons.chat_bubble_outline_rounded,
        '发消息',
      ),
      FriendRelationshipSummary(incomingPending: true) => (
        Icons.mark_email_unread_outlined,
        '处理申请',
      ),
      FriendRelationshipSummary(outgoingPending: true) => (
        Icons.schedule_rounded,
        '等待验证',
      ),
      _ => (Icons.person_add_alt_1_rounded, '加好友'),
    };
    return OutlinedButton.icon(
      key: const ValueKey('community-friend-action'),
      onPressed: _friendLoading ? null : () => _handleFriendAction(user),
      icon: _friendLoading
          ? const SizedBox.square(
              dimension: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
    );
  }

  Widget _buildPostsHeader(CommunityProfile profile) {
    return Row(
      children: [
        Text(
          _isSelf ? '我的帖子' : 'TA 的帖子',
          style: const TextStyle(
            color: communityText,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${profile.stats.postCount}',
          style: const TextStyle(color: communityTextSecondary),
        ),
      ],
    );
  }

  Widget _buildPosts() {
    if (_controller.posts.isEmpty) {
      return const CommunityEmptyState(
        icon: Icons.photo_library_outlined,
        title: '还没有发布帖子',
        subtitle: '发布的宠物日常会出现在这里。',
      );
    }
    return CommunityPostGrid(
      posts: _controller.posts,
      onOpenPost: _openPost,
      onOpenUser: (_) {},
      onLike: _togglePostLike,
      onManagePost: _isSelf ? _showPostActions : null,
    );
  }

  Future<void> _showPostActions(CommunityPost post) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('community-edit-post-action'),
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑帖子'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              key: const ValueKey('community-delete-post-action'),
              leading: const Icon(Icons.delete_outline_rounded),
              iconColor: communityError,
              textColor: communityError,
              title: const Text('删除帖子'),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _editPost(post);
    } else if (action == 'delete') {
      await _deletePost(post);
    }
  }

  Future<void> _editPost(CommunityPost post) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CommunityPublishPostPage(
          gateway: widget.gateway,
          initialPost: post,
        ),
      ),
    );
    if (updated == true) await _controller.load();
  }

  Future<void> _deletePost(CommunityPost post) async {
    if (!await confirmCommunityPostDeletion(context) || !mounted) return;
    try {
      await _controller.deletePost(post.id);
      if (mounted) _showMessage('帖子已删除');
    } on Object catch (error) {
      if (mounted) _showMessage('删除失败：$error');
    }
  }

  Future<void> _toggleFollow() async {
    if (!widget.authenticated) {
      await widget.requestLogin('登录后即可关注宠友');
      return;
    }
    try {
      await _controller.toggleFollow();
    } on Object catch (error) {
      if (mounted) _showMessage('操作失败：$error');
    }
  }

  Future<void> _confirmRemoveFromBlacklist() async {
    final nickname = _controller.profile?.user.nickname ?? '该用户';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: const AppDialogIcon(icon: Icons.person_remove_outlined),
        title: const Text('移出黑名单'),
        content: Text('确定要将 $nickname 移出黑名单吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('community-remove-from-blacklist-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('移出'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _unblocking = true);
    try {
      await widget.gateway.unblockCommunityUser(widget.userId);
      if (!mounted) return;
      setState(() => _blockedByMe = false);
      await _loadFriendRelationship();
      if (mounted) _showMessage('已将 $nickname 移出黑名单');
    } on Object catch (error) {
      if (mounted) _showMessage('移出黑名单失败：$error');
    } finally {
      if (mounted) setState(() => _unblocking = false);
    }
  }

  Future<void> _togglePostLike(int postId) async {
    if (!widget.authenticated) {
      await widget.requestLogin('登录后即可点赞帖子');
      return;
    }
    try {
      await _controller.togglePostLike(postId);
    } on Object catch (error) {
      if (mounted) _showMessage('点赞失败：$error');
    }
  }

  Future<void> _handleFriendAction(CommunityUser user) async {
    if (!widget.authenticated) {
      await widget.requestLogin('登录后即可添加好友或聊天');
      return;
    }
    final session = widget.friendsSession;
    if (session == null) {
      _showMessage('好友功能暂不可用');
      return;
    }
    final relation = _friendRelationship;
    if (relation?.isFriend == true) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => FriendChatPage(
            controller: session.createFriendChatController(
              FriendshipSummary(
                friendId: user.id,
                friendName: user.nickname,
                friendAvatar: user.avatarUrl,
                friendSignature: user.bio,
              ),
            ),
          ),
        ),
      );
      return;
    }
    if (relation?.incomingPending == true) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => FriendRequestListPage(
            controller: session.createFriendRequestsController(),
          ),
        ),
      );
      await _loadFriendRelationship();
      return;
    }
    if (relation?.outgoingPending == true) {
      _showMessage('好友申请已发送，请等待对方验证');
      return;
    }
    final message = await _friendRequestMessage(user.nickname);
    if (message == null) return;
    setState(() => _friendLoading = true);
    try {
      final result = await session.repository.sendFriendRequest(
        receiverId: user.id,
        message: message,
      );
      if (!mounted) return;
      _showMessage(result.message);
      await _loadFriendRelationship();
    } on Object catch (error) {
      if (mounted) _showMessage('好友申请发送失败：$error');
    } finally {
      if (mounted) setState(() => _friendLoading = false);
    }
  }

  Future<String?> _friendRequestMessage(String nickname) async {
    var message = '你好，我在宠物社区看到了你的分享。';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AppDialog(
        icon: const AppDialogIcon(icon: Icons.person_add_alt_1_rounded),
        title: Text('添加 $nickname 为好友'),
        content: TextFormField(
          key: const ValueKey('community-friend-request-message-field'),
          initialValue: message,
          maxLength: 100,
          maxLines: 3,
          onChanged: (value) => message = value,
          decoration: const InputDecoration(labelText: '验证消息'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, message.trim()),
            child: const Text('发送'),
          ),
        ],
      ),
    );
    return result;
  }

  void _openConnections(CommunityConnectionType type) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityConnectionsPage(
          gateway: widget.gateway,
          userId: widget.userId,
          type: type,
          authenticated: widget.authenticated,
          currentUserId: widget.currentUserId,
          requestLogin: widget.requestLogin,
          friendsSession: widget.friendsSession,
        ),
      ),
    );
  }

  void _openBlacklist() {
    final currentUserId = widget.currentUserId;
    if (currentUserId == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityBlacklistPage(
          gateway: widget.gateway,
          currentUserId: currentUserId,
          requestLogin: widget.requestLogin,
          friendsSession: widget.friendsSession,
        ),
      ),
    );
  }

  Future<void> _openEditor() async {
    final profile = _controller.profile;
    if (profile == null) return;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            EditCommunityProfilePage(gateway: widget.gateway, profile: profile),
      ),
    );
    if (updated == true) await _controller.load();
  }

  Future<void> _openPublisher() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CommunityPublishPostPage(gateway: widget.gateway),
      ),
    );
    if (created == true) await _controller.load();
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
    if (changed == true) await _controller.load();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.isSelf,
    required this.onBack,
  });

  final CommunityProfile profile;
  final bool isSelf;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final user = profile.user;
    final hasCoverImage = user.coverImageUrl.trim().isNotEmpty;
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    return SizedBox(
      key: const ValueKey('community-profile-hero'),
      height: 242 + statusBarHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!hasCoverImage)
            const ColoredBox(
              key: ValueKey('community-profile-cover-fallback'),
              color: Color(0xFF7186D8),
            )
          else
            CommunityNetworkImage(
              key: const ValueKey('community-profile-cover-image'),
              source: user.coverImageUrl,
              placeholderIcon: Icons.image_outlined,
              backgroundColor: const Color(0xFF7186D8),
            ),
          if (hasCoverImage)
            const DecoratedBox(
              key: ValueKey('community-profile-cover-overlay'),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x44000000), Color(0x77000000)],
                ),
              ),
            ),
          Positioned(
            top: statusBarHeight + 10,
            left: 10,
            child: IconButton.filled(
              tooltip: '返回',
              onPressed: onBack,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0x66000000),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
            ),
          ),
          Positioned(
            top: statusBarHeight + 18,
            left: 72,
            right: 72,
            child: Text(
              isSelf ? '我的主页' : '他的主页',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(color: Color(0x66000000), blurRadius: 8)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatButton extends StatelessWidget {
  const _StatButton({required this.label, required this.value, this.onTap});

  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            compactCount(value),
            style: const TextStyle(
              color: communityText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: communityTextSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
