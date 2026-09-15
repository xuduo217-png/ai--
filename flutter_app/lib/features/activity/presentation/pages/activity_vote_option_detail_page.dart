import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

import '../../../../core/media/route_aware_video_surface.dart';
import '../../../../core/media/rich_text_video_player.dart';
import '../../../friends/presentation/pages/friend_video_player_page.dart';
import '../../domain/activity_models.dart';
import '../activity_controller.dart';
import '../activity_design.dart';
import '../activity_interactions.dart';
import 'activity_vote_option_editor_page.dart';

const _optionDetailPrimary = Color(0xFF2196F3);
const _optionDetailButton = Color(0xFF5B75E5);

class ActivityVoteOptionDetailPage extends StatefulWidget {
  const ActivityVoteOptionDetailPage({
    super.key,
    required this.gateway,
    required this.activityId,
    required this.optionId,
    required this.authenticated,
    required this.requestLogin,
    this.currentUserId,
  });

  final ActivityGateway gateway;
  final int activityId;
  final int optionId;
  final bool authenticated;
  final Future<bool> Function(String message) requestLogin;
  final int? currentUserId;

  @override
  State<ActivityVoteOptionDetailPage> createState() =>
      _ActivityVoteOptionDetailPageState();
}

class _ActivityVoteOptionDetailPageState
    extends State<ActivityVoteOptionDetailPage> {
  late final ActivityDetailController _controller;
  late final ActivityCommentsController _commentsController;
  late final Listenable _pageListenable;
  final _commentTextController = TextEditingController();
  final _commentFocusNode = FocusNode();
  ActivityComment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _controller = ActivityDetailController(
      gateway: widget.gateway,
      activityId: widget.activityId,
      authenticated: widget.authenticated,
    )..load();
    _commentsController = ActivityCommentsController(
      gateway: widget.gateway,
      activityId: widget.activityId,
      voteOptionId: widget.optionId,
      authenticated: widget.authenticated,
    )..load();
    _pageListenable = Listenable.merge([_controller, _commentsController]);
  }

  @override
  void dispose() {
    _controller.dispose();
    _commentsController.dispose();
    _commentTextController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  ActivityVoteOption? _option(ActivityItem? activity) {
    if (activity == null) return null;
    for (final option in activity.voteOptions) {
      if (option.id == widget.optionId) return option;
    }
    return null;
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _vote(ActivityItem activity, ActivityVoteOption option) async {
    if (!widget.authenticated) {
      await widget.requestLogin('登录后即可参与投票');
      return;
    }
    if (activity.isExpired) {
      _message('活动已结束');
      return;
    }
    if (activity.isRegistered) {
      _message('您今天已经投过票了');
      return;
    }
    try {
      final result = await _controller.vote(option.id);
      _message(result.message.isEmpty ? '投票成功' : result.message);
    } on Object catch (error) {
      _message(activityErrorMessage(error, '投票失败，请稍后重试'));
    }
  }

  Future<void> _edit(ActivityItem activity, ActivityVoteOption option) async {
    if (!canManageActivityVoteOption(
      activity: activity,
      option: option,
      authenticated: widget.authenticated,
      currentUserId: widget.currentUserId,
    )) {
      _message(activity.isExpired ? '活动已结束，无法编辑' : '无权编辑该参赛信息');
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ActivityVoteOptionEditorPage(
          controller: _controller,
          initialOption: option,
        ),
      ),
    );
    if (changed == true && mounted) _message('参赛信息已更新');
  }

  Future<void> _delete(ActivityItem activity, ActivityVoteOption option) async {
    if (!canManageActivityVoteOption(
      activity: activity,
      option: option,
      authenticated: widget.authenticated,
      currentUserId: widget.currentUserId,
    )) {
      _message(activity.isExpired ? '活动已结束，无法删除' : '无权删除该参赛信息');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: const AppDialogIcon.danger(icon: Icons.delete_outline_rounded),
        title: const Text('删除选手'),
        content: Text('确认删除“${option.title}”吗？相关票数和评论也会一并删除，且无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await _controller.deleteVoteOption(option.id);
      if (!result.success) {
        _message(result.message.isEmpty ? '删除失败，请稍后重试' : result.message);
        return;
      }
      if (mounted) await Navigator.of(context).maybePop(true);
    } on Object catch (error) {
      _message(activityErrorMessage(error, '删除失败，请稍后重试'));
    }
  }

  Future<void> _report(ActivityVoteOption option) async {
    if (!widget.authenticated) {
      await widget.requestLogin('登录后即可举报内容');
      return;
    }
    if (!mounted) return;
    await showActivityReportSheet(
      context,
      gateway: widget.gateway,
      targetType: 'ACTIVITY_VOTE_OPTION',
      targetId: option.id,
    );
  }

  Future<void> _submitComment() async {
    final content = _commentTextController.text.trim();
    if (content.isEmpty) return;
    if (!widget.authenticated) {
      await widget.requestLogin('登录后即可发表评论');
      return;
    }
    try {
      await _commentsController.submit(content, parentId: _replyingTo?.id);
      _commentTextController.clear();
      _commentFocusNode.unfocus();
      if (mounted) setState(() => _replyingTo = null);
      _message('评论成功');
    } on Object catch (error) {
      _message(activityErrorMessage(error, '评论失败，请稍后重试'));
    }
  }

  void _replyComment(ActivityComment comment) {
    if (!widget.authenticated) {
      unawaited(widget.requestLogin('登录后即可回复评论'));
      return;
    }
    setState(() => _replyingTo = comment);
    _commentFocusNode.requestFocus();
  }

  Future<void> _reportComment(ActivityComment comment) async {
    if (!widget.authenticated) {
      await widget.requestLogin('登录后即可举报评论');
      return;
    }
    if (!mounted) return;
    await showActivityReportSheet(
      context,
      gateway: widget.gateway,
      targetType: 'ACTIVITY_COMMENT',
      targetId: comment.id,
    );
  }

  Future<void> _blockComment(ActivityComment comment) async {
    if (!widget.authenticated) {
      await widget.requestLogin('登录后即可屏蔽用户');
      return;
    }
    if (comment.userId <= 0 || comment.userId == widget.currentUserId) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: const AppDialogIcon.danger(icon: Icons.block_rounded),
        title: const Text('屏蔽用户'),
        content: Text('屏蔽 ${comment.user?.nickname ?? '该用户'} 后将不再看到其内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认屏蔽'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.gateway.blockActivityUser(comment.userId, reason: '选手评论');
      _message('已屏蔽该用户');
      await _commentsController.refresh();
    } on Object catch (error) {
      _message(activityErrorMessage(error, '屏蔽失败，请稍后重试'));
    }
  }

  void _openMedia(ActivityVoteOption option) {
    if (option.hasVideo) {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => FriendVideoPlayerPage(videoUrl: option.videoUrl),
        ),
      );
      return;
    }
    if (!option.hasImage) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            _ActivityImagePage(imageUrl: option.imageUrl, title: option.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return VideoRoutePopScope<void>(
      child: AnimatedBuilder(
        animation: _pageListenable,
        builder: (context, _) {
          final activity = _controller.activity;
          final option = _option(activity);
          final canManage = canManageActivityVoteOption(
            activity: activity,
            option: option,
            authenticated: widget.authenticated,
            currentUserId: widget.currentUserId,
          );
          return Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: false,
            body: ActivityGradientBackground(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    ActivityAppBar(
                      title: '选手详情',
                      onBack: () => Navigator.of(context).maybePop(),
                      action: option == null
                          ? null
                          : PopupMenuButton<String>(
                              tooltip: '更多操作',
                              enabled: !_controller.actionLoading,
                              icon: const Icon(
                                Icons.more_horiz_rounded,
                                color: activityInk,
                              ),
                              itemBuilder: (_) => [
                                if (canManage)
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('编辑'),
                                  ),
                                if (canManage)
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      '删除',
                                      style: TextStyle(
                                        color: Color(0xFFEF4444),
                                      ),
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'report',
                                  child: Text('举报'),
                                ),
                              ],
                              onSelected: (value) => switch (value) {
                                'edit' when activity != null => unawaited(
                                  _edit(activity, option),
                                ),
                                'delete' when activity != null => unawaited(
                                  _delete(activity, option),
                                ),
                                _ => unawaited(_report(option)),
                              },
                            ),
                    ),
                    Expanded(child: _buildBody(activity, option)),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: activity == null || option == null
                ? null
                : AnimatedPadding(
                    key: const ValueKey(
                      'activity-option-comment-keyboard-inset',
                    ),
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.only(bottom: keyboardInset),
                    child: _OptionCommentComposer(
                      controller: _commentTextController,
                      focusNode: _commentFocusNode,
                      replyingTo: _replyingTo,
                      submitting: _commentsController.submitting,
                      onChanged: (_) => setState(() {}),
                      onCancelReply: () => setState(() => _replyingTo = null),
                      onSubmit: _submitComment,
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildBody(ActivityItem? activity, ActivityVoteOption? option) {
    double px(num value) => activityDesignPx(context, value);
    if (_controller.loading && activity == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _optionDetailButton),
            SizedBox(height: px(10)),
            Text(
              '加载中...',
              style: TextStyle(
                color: activityInk,
                fontSize: px(28),
                height: 34 / 28,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      );
    }
    if (_controller.error != null && activity == null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: px(16)),
        child: _OptionStatusCard(
          title: '加载失败',
          subtitle: _controller.error!,
          action: TextButton.icon(
            onPressed: _controller.load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新加载'),
          ),
        ),
      );
    }
    if (activity == null || option == null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: px(16)),
        child: const _OptionStatusCard(
          title: '选手不存在',
          subtitle: '可能已被删除，或当前活动暂时无法访问。',
        ),
      );
    }
    return RefreshIndicator(
      color: _optionDetailButton,
      onRefresh: () => Future.wait<void>([
        _controller.refresh(),
        _commentsController.refresh(),
      ]),
      child: ListView(
        key: const ValueKey('activity-option-detail-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(px(16), px(8), px(16), px(32)),
        children: [
          _OptionDetailCard(
            activity: activity,
            option: option,
            commentTotal: _commentsController.total,
            voteEnabled: !activity.isExpired && !activity.isRegistered,
            voting: _controller.votingOptionId == option.id,
            voteLabel: activity.isExpired
                ? '已结束'
                : activity.isRegistered
                ? '今日已投'
                : _controller.votingOptionId == option.id
                ? '投票中...'
                : '投票',
            onVote: () => _vote(activity, option),
            onOpenMedia: () => _openMedia(option),
          ),
          SizedBox(height: px(16)),
          _OptionCommentsCard(
            controller: _commentsController,
            currentUserId: widget.currentUserId,
            onReply: _replyComment,
            onReport: _reportComment,
            onBlock: _blockComment,
          ),
        ],
      ),
    );
  }
}

class _OptionStatusCard extends StatelessWidget {
  const _OptionStatusCard({
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    double px(num value) => activityDesignPx(context, value);
    return Center(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: px(28), vertical: px(48)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(px(20)),
          border: Border.all(color: activityBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: px(120),
              color: activityHint,
            ),
            SizedBox(height: px(16)),
            Text(
              title,
              style: TextStyle(
                color: activityInk,
                fontSize: px(32),
                height: 40 / 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: px(8)),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: activityMuted,
                fontSize: px(26),
                height: 36 / 26,
                letterSpacing: 0,
              ),
            ),
            if (action != null) ...[SizedBox(height: px(14)), action!],
          ],
        ),
      ),
    );
  }
}

class _OptionDetailCard extends StatelessWidget {
  const _OptionDetailCard({
    required this.activity,
    required this.option,
    required this.commentTotal,
    required this.voteEnabled,
    required this.voting,
    required this.voteLabel,
    required this.onVote,
    required this.onOpenMedia,
  });

  final ActivityItem activity;
  final ActivityVoteOption option;
  final int commentTotal;
  final bool voteEnabled;
  final bool voting;
  final String voteLabel;
  final VoidCallback onVote;
  final VoidCallback onOpenMedia;

  @override
  Widget build(BuildContext context) {
    double px(num value) => activityDesignPx(context, value);
    final active = activity.isRegistered;
    return Container(
      key: const ValueKey('activity-option-detail-card'),
      padding: EdgeInsets.all(px(18)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(px(22)),
        border: Border.all(color: activityBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const ValueKey('activity-option-header-panel'),
            padding: EdgeInsets.all(px(12)),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F7FF),
              borderRadius: BorderRadius.circular(px(18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: activityInk,
                          fontSize: px(30),
                          height: 36 / 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      SizedBox(height: px(4)),
                      Text(
                        activity.hospitalName.isEmpty
                            ? '活动选手'
                            : activity.hospitalName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: activityMuted,
                          fontSize: px(24),
                          height: 30 / 24,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: px(8)),
                Container(
                  constraints: BoxConstraints(minHeight: px(52)),
                  padding: EdgeInsets.symmetric(
                    horizontal: px(12),
                    vertical: px(10),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.how_to_vote_rounded,
                        color: _optionDetailPrimary,
                        size: px(28),
                      ),
                      SizedBox(width: px(4)),
                      Text(
                        '选手详情',
                        style: TextStyle(
                          color: _optionDetailPrimary,
                          fontSize: px(24),
                          height: 30 / 24,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: px(18)),
          Text(
            option.title.isEmpty ? '未命名选手' : option.title,
            style: TextStyle(
              color: activityInk,
              fontSize: px(36),
              height: 44 / 36,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          if (option.description.isNotEmpty) ...[
            SizedBox(height: px(10)),
            Text(
              option.description,
              style: TextStyle(
                color: activityInk,
                fontSize: px(30),
                height: 46 / 30,
                letterSpacing: 0,
              ),
            ),
          ],
          if (option.hasVideo) ...[
            SizedBox(height: px(18)),
            _EmbeddedOptionVideo(
              key: const ValueKey('activity-option-detail-video'),
              videoUrl: option.videoUrl,
              posterUrl: option.videoCoverUrl.isNotEmpty
                  ? option.videoCoverUrl
                  : option.imageUrl,
              onFullscreen: onOpenMedia,
            ),
          ] else if (option.hasImage) ...[
            SizedBox(height: px(18)),
            Material(
              key: const ValueKey('activity-option-detail-image'),
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(px(18)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onOpenMedia,
                child: SizedBox(
                  height: px(360),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        option.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Color(0xFFF3F4F6),
                          child: Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: activityHint,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: px(14),
                        bottom: px(14),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: px(12),
                            vertical: px(7),
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x940F172A),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.zoom_out_map_rounded,
                                size: px(28),
                                color: Colors.white,
                              ),
                              SizedBox(width: px(4)),
                              Text(
                                '点击全屏查看',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: px(22),
                                  height: 26 / 22,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          SizedBox(height: px(18)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _OptionMetricCard(
                  key: const ValueKey('activity-option-detail-vote'),
                  icon: Icons.how_to_vote_rounded,
                  label: voteLabel,
                  value: '${option.voteCount}',
                  action: true,
                  active: active,
                  enabled: voteEnabled && !voting,
                  onTap: onVote,
                ),
              ),
              SizedBox(width: px(6)),
              Expanded(
                child: _OptionMetricCard(
                  key: const ValueKey('activity-option-detail-comments'),
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '评论',
                  value: '$commentTotal',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OptionMetricCard extends StatelessWidget {
  const _OptionMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.action = false,
    this.active = false,
    this.enabled = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool action;
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    double px(num value) => activityDesignPx(context, value);
    final foreground = active ? activityIndigo : const Color(0xFF64748B);
    final background = active
        ? const Color(0xFFEEF2FF)
        : action
        ? const Color(0xFFEEF6FF)
        : const Color(0xFFF7F8FA);
    final border = active
        ? const Color(0xFFC7D2FE)
        : action
        ? const Color(0xFFBFDBFE)
        : activityBorder;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(px(16)),
      child: InkWell(
        onTap: action && enabled ? onTap : null,
        borderRadius: BorderRadius.circular(px(16)),
        child: Container(
          constraints: BoxConstraints(minHeight: px(200)),
          padding: EdgeInsets.symmetric(horizontal: px(8), vertical: px(14)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(px(16)),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: px(60),
                height: px(60),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFE0E7FF) : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: foreground, size: px(34)),
              ),
              SizedBox(height: px(6)),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: px(24),
                  height: 30 / 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: px(6)),
              Text(
                value,
                style: TextStyle(
                  color: active ? activityIndigo : activityInk,
                  fontSize: px(30),
                  height: 36 / 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCommentsCard extends StatelessWidget {
  const _OptionCommentsCard({
    required this.controller,
    required this.currentUserId,
    required this.onReply,
    required this.onReport,
    required this.onBlock,
  });

  final ActivityCommentsController controller;
  final int? currentUserId;
  final ValueChanged<ActivityComment> onReply;
  final ValueChanged<ActivityComment> onReport;
  final ValueChanged<ActivityComment> onBlock;

  @override
  Widget build(BuildContext context) {
    double px(num value) => activityDesignPx(context, value);
    final comments = controller.comments;
    return Container(
      key: const ValueKey('activity-option-comments-card'),
      padding: EdgeInsets.all(px(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(px(22)),
        border: Border.all(color: activityBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '评论 ${controller.total}',
                  style: TextStyle(
                    color: activityInk,
                    fontSize: px(34),
                    height: 42 / 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: px(10),
                  vertical: px(7),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: px(28),
                      color: _optionDetailPrimary,
                    ),
                    SizedBox(width: px(4)),
                    Text(
                      '友善交流',
                      style: TextStyle(
                        color: _optionDetailPrimary,
                        fontSize: px(24),
                        height: 30 / 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: px(16)),
          if (controller.loading && comments.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: px(28)),
              child: Column(
                children: [
                  const CircularProgressIndicator(color: _optionDetailButton),
                  SizedBox(height: px(10)),
                  Text(
                    '正在加载评论',
                    style: TextStyle(
                      color: activityMuted,
                      fontSize: px(24),
                      height: 30 / 24,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            )
          else if (comments.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: px(12),
                vertical: px(28),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: px(88),
                    color: const Color(0xFFCBD5E1),
                  ),
                  SizedBox(height: px(10)),
                  Text(
                    controller.error == null ? '还没有评论' : '加载失败',
                    style: TextStyle(
                      color: activityInk,
                      fontSize: px(28),
                      height: 36 / 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(height: px(6)),
                  Text(
                    controller.error ?? '来写下第一条评论，给喜欢的选手加油吧。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: activityMuted,
                      fontSize: px(22),
                      height: 30 / 22,
                      letterSpacing: 0,
                    ),
                  ),
                  if (controller.error != null) ...[
                    SizedBox(height: px(14)),
                    TextButton(
                      onPressed: controller.load,
                      style: TextButton.styleFrom(
                        foregroundColor: activityIndigo,
                        backgroundColor: const Color(0xFFEEF2FF),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('重新加载'),
                    ),
                  ],
                ],
              ),
            )
          else
            ...comments.map(
              (comment) => _OptionCommentTile(
                comment: comment,
                currentUserId: currentUserId,
                onReply: () => onReply(comment),
                onReport: () => onReport(comment),
                onBlock: () => onBlock(comment),
              ),
            ),
          if (controller.hasMore) ...[
            SizedBox(height: px(12)),
            SizedBox(
              height: px(46),
              child: TextButton(
                onPressed: controller.loadingMore
                    ? null
                    : () => unawaited(controller.loadMore()),
                style: TextButton.styleFrom(
                  foregroundColor: activityIndigo,
                  backgroundColor: const Color(0xFFEEF2FF),
                  disabledForegroundColor: activityHint,
                  shape: const StadiumBorder(),
                ),
                child: Text(controller.loadingMore ? '加载中...' : '查看更多评论'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionCommentTile extends StatelessWidget {
  const _OptionCommentTile({
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    required this.onReport,
    required this.onBlock,
  });

  final ActivityComment comment;
  final int? currentUserId;
  final VoidCallback onReply;
  final VoidCallback onReport;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    double px(num value) => activityDesignPx(context, value);
    final avatarUrl = comment.user?.avatarUrl ?? '';
    return Container(
      padding: EdgeInsets.symmetric(vertical: px(18)),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: activityBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(px(20)),
                child: SizedBox.square(
                  dimension: px(58),
                  child: avatarUrl.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFFE5E7EB),
                          child: Icon(
                            Icons.person_rounded,
                            color: _optionDetailPrimary,
                          ),
                        )
                      : Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFFE5E7EB),
                            child: Icon(
                              Icons.person_rounded,
                              color: _optionDetailPrimary,
                            ),
                          ),
                        ),
                ),
              ),
              SizedBox(width: px(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.user?.nickname ?? '匿名用户',
                      style: TextStyle(
                        color: activityInk,
                        fontSize: px(26),
                        height: 32 / 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: px(4)),
                    Text(
                      activityRelativeTime(comment.createdAt),
                      style: TextStyle(
                        color: activityMuted,
                        fontSize: px(22),
                        height: 28 / 22,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: px(12)),
          Text(
            comment.content,
            style: TextStyle(
              color: activityInk,
              fontSize: px(28),
              height: 40 / 28,
              letterSpacing: 0,
            ),
          ),
          if (comment.replies.isNotEmpty) ...[
            SizedBox(height: px(12)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: px(12),
                vertical: px(10),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(px(14)),
                border: Border.all(color: activityBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: comment.replies
                    .map(
                      (reply) => Padding(
                        padding: EdgeInsets.only(bottom: px(6)),
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                              color: activityInk,
                              fontSize: px(24),
                              height: 34 / 24,
                            ),
                            children: [
                              TextSpan(
                                text: reply.user?.nickname ?? '匿名用户',
                                style: const TextStyle(
                                  color: activityIndigo,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(text: '：${reply.content}'),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
          SizedBox(height: px(12)),
          Wrap(
            spacing: px(10),
            runSpacing: px(8),
            children: [
              _OptionCommentAction(
                icon: Icons.reply_rounded,
                label: '回复',
                onTap: onReply,
              ),
              _OptionCommentAction(
                icon: Icons.flag_rounded,
                label: '举报',
                onTap: onReport,
              ),
              if (comment.userId > 0 && comment.userId != currentUserId)
                _OptionCommentAction(
                  icon: Icons.block_rounded,
                  label: '屏蔽',
                  onTap: onBlock,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OptionCommentAction extends StatelessWidget {
  const _OptionCommentAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    double px(num value) => activityDesignPx(context, value);
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: BoxConstraints(minHeight: px(38)),
          padding: EdgeInsets.symmetric(horizontal: px(12)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: activityBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF64748B), size: px(28)),
              SizedBox(width: px(4)),
              Text(
                label,
                style: TextStyle(
                  color: const Color(0xFF64748B),
                  fontSize: px(22),
                  height: 28 / 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCommentComposer extends StatelessWidget {
  const _OptionCommentComposer({
    required this.controller,
    required this.focusNode,
    required this.replyingTo,
    required this.submitting,
    required this.onChanged,
    required this.onCancelReply,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ActivityComment? replyingTo;
  final bool submitting;
  final ValueChanged<String> onChanged;
  final VoidCallback onCancelReply;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    double px(num value) => activityDesignPx(context, value);
    final canSubmit = controller.text.trim().isNotEmpty && !submitting;
    return Material(
      key: const ValueKey('activity-option-comment-surface'),
      color: Colors.white,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(px(16), px(8), px(16), px(12)),
        child: Container(
          key: const ValueKey('activity-option-comment-sticky'),
          padding: EdgeInsets.all(px(12)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(px(20)),
            border: Border.all(color: activityBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (replyingTo != null) ...[
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: px(10),
                    vertical: px(8),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(px(14)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.reply_rounded,
                        size: px(32),
                        color: _optionDetailPrimary,
                      ),
                      SizedBox(width: px(6)),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                              color: activityMuted,
                              fontSize: px(24),
                              height: 30 / 24,
                            ),
                            children: [
                              const TextSpan(text: '回复 '),
                              TextSpan(
                                text: replyingTo!.user?.nickname ?? '匿名用户',
                                style: const TextStyle(
                                  color: _optionDetailPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Material(
                        color: const Color(0xB8FFFFFF),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: onCancelReply,
                          customBorder: const CircleBorder(),
                          child: SizedBox.square(
                            dimension: px(30),
                            child: Icon(
                              Icons.close_rounded,
                              size: px(24),
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: px(8)),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: px(40),
                        maxHeight: px(110),
                      ),
                      child: TextField(
                        key: const ValueKey('activity-option-comment-input'),
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 1000,
                        onChanged: onChanged,
                        decoration: InputDecoration(
                          hintText: replyingTo == null
                              ? '写下你的评论...'
                              : '回复 ${replyingTo!.user?.nickname ?? '匿名用户'}...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          counterText: '',
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF3F4F6),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: px(14),
                            vertical: px(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(px(10)),
                            borderSide: const BorderSide(color: activityBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(px(10)),
                            borderSide: const BorderSide(
                              color: Color(0xFFBFDBFE),
                            ),
                          ),
                        ),
                        style: TextStyle(
                          color: activityInk,
                          fontSize: px(28),
                          height: 38 / 28,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: px(8)),
                  SizedBox(
                    height: px(52),
                    child: FilledButton(
                      key: const ValueKey('activity-option-comment-send'),
                      onPressed: canSubmit ? () => unawaited(onSubmit()) : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _optionDetailButton,
                        disabledBackgroundColor: const Color(0xFFCBD5E1),
                        padding: EdgeInsets.symmetric(horizontal: px(14)),
                        minimumSize: Size(px(80), px(40)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(px(10)),
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: submitting
                          ? SizedBox.square(
                              dimension: px(24),
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              '发送',
                              style: TextStyle(
                                fontSize: px(26),
                                height: 32 / 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
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

class _EmbeddedOptionVideo extends StatelessWidget {
  const _EmbeddedOptionVideo({
    super.key,
    required this.videoUrl,
    required this.posterUrl,
    required this.onFullscreen,
  });

  final String videoUrl;
  final String posterUrl;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    double px(num value) => activityDesignPx(context, value);
    final videoUri = _networkUri(videoUrl);
    final posterUri = _networkUri(posterUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(px(18)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          if (videoUri == null) {
            return const AspectRatio(
              aspectRatio: 16 / 9,
              child: UnavailableRichTextVideo(),
            );
          }
          return RichTextVideoPlayer(
            key: const ValueKey('activity-option-detail-video-state'),
            source: RichTextVideoSource(uri: videoUri, posterUri: posterUri),
            width: width,
            semanticsKey: const ValueKey('activity-option-detail-video-player'),
            semanticLabel: '活动选手视频播放器',
            controlKeyPrefix: 'activity-option-detail-video',
            accentColor: _optionDetailButton,
            autoPlayWhenVisible: true,
            onFullscreen: onFullscreen,
          );
        },
      ),
    );
  }

  Uri? _networkUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri;
  }
}

class _ActivityImagePage extends StatelessWidget {
  const _ActivityImagePage({required this.imageUrl, required this.title});

  final String imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        top: false,
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Center(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Text('图片加载失败', style: TextStyle(color: Colors.white70)),
            ),
          ),
        ),
      ),
    );
  }
}
