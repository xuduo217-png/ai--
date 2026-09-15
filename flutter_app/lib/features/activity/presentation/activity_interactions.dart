import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

import '../../../core/network/api_client.dart';
import '../domain/activity_models.dart';
import 'activity_controller.dart';
import 'activity_design.dart';

typedef ActivityLoginRequester = Future<bool> Function(String message);

String activityErrorMessage(Object error, String fallback) {
  return error is ApiException && error.message.trim().isNotEmpty
      ? error.message
      : fallback;
}

bool canManageActivityVoteOption({
  required ActivityItem? activity,
  required ActivityVoteOption? option,
  required bool authenticated,
  required int? currentUserId,
}) {
  final ownerUserId = option?.ownerUserId;
  return authenticated &&
      activity != null &&
      activity.isOnline &&
      !activity.isExpired &&
      option != null &&
      currentUserId != null &&
      ownerUserId != null &&
      ownerUserId == currentUserId;
}

class ActivityVoteOptionCard extends StatelessWidget {
  const ActivityVoteOptionCard({
    super.key,
    required this.option,
    required this.voteEnabled,
    required this.voting,
    required this.buttonLabel,
    required this.onOpen,
    required this.onVote,
    required this.onReport,
    this.onEdit,
  });

  final ActivityVoteOption option;
  final bool voteEnabled;
  final bool voting;
  final String buttonLabel;
  final VoidCallback onOpen;
  final VoidCallback onVote;
  final VoidCallback onReport;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    double px(num value) => activityDesignPx(context, value);
    const ratios = <double>[0.78, 1.04, 0.88, 1.18, 0.94, 1.12];
    final ratio = ratios[option.id.abs() % ratios.length];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: px(4)),
      child: Material(
        key: ValueKey('activity-vote-option-${option.id}'),
        color: Colors.white,
        elevation: 3,
        shadowColor: const Color(0x14000000),
        borderRadius: BorderRadius.circular(px(14)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: ratio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _OptionMedia(option: option),
                    if (option.hasVideo)
                      IgnorePointer(
                        child: ColoredBox(
                          color: const Color(0x290F172A),
                          child: Center(
                            child: Container(
                              width: px(70),
                              height: px(70),
                              decoration: BoxDecoration(
                                color: const Color(0x940F172A),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0x6BFFFFFF),
                                ),
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: px(52),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: px(10),
                      left: px(10),
                      child: Material(
                        color: const Color(0xF0FFFFFF),
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: ValueKey('activity-report-option-${option.id}'),
                          onTap: onReport,
                          customBorder: const CircleBorder(),
                          child: SizedBox.square(
                            dimension: px(48),
                            child: Icon(
                              Icons.flag_rounded,
                              color: const Color(0xFFEF4444),
                              size: px(26),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (onEdit != null)
                      Positioned(
                        top: px(10),
                        right: px(10),
                        child: Material(
                          color: const Color(0xF0FFFFFF),
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            key: ValueKey('activity-edit-option-${option.id}'),
                            onTap: onEdit,
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: px(14),
                                vertical: px(7),
                              ),
                              child: Text(
                                '编辑',
                                style: TextStyle(
                                  color: activityIndigo,
                                  fontSize: px(22),
                                  height: 28 / 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(px(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title.isEmpty ? '未命名选手' : option.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: activityInk,
                        fontSize: px(30),
                        height: 38 / 30,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    if (option.description.isNotEmpty) ...[
                      SizedBox(height: px(8)),
                      Text(
                        option.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: activityMuted,
                          fontSize: px(24),
                          height: 32 / 24,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                    SizedBox(height: px(12)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: px(10),
                          vertical: px(6),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.how_to_vote_rounded,
                              color: activityIndigo,
                              size: px(24),
                            ),
                            SizedBox(width: px(4)),
                            Text(
                              '${option.voteCount} 票',
                              style: TextStyle(
                                color: activityIndigo,
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
                    SizedBox(height: px(10)),
                    SizedBox(
                      width: double.infinity,
                      height: px(46),
                      child: FilledButton(
                        key: ValueKey('activity-vote-${option.id}'),
                        onPressed: voting || !voteEnabled ? null : onVote,
                        style: FilledButton.styleFrom(
                          backgroundColor: activityPrimary,
                          disabledBackgroundColor: const Color(0xFFE5E7EB),
                          disabledForegroundColor: activityHint,
                          padding: EdgeInsets.symmetric(horizontal: px(12)),
                          shape: const StadiumBorder(),
                        ),
                        child: voting
                            ? SizedBox.square(
                                dimension: px(24),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                buttonLabel,
                                style: TextStyle(
                                  fontSize: px(24),
                                  height: 30 / 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
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
      ),
    );
  }
}

class _OptionMedia extends StatelessWidget {
  const _OptionMedia({required this.option});

  final ActivityVoteOption option;

  @override
  Widget build(BuildContext context) {
    final url = option.hasImage ? option.imageUrl : option.videoCoverUrl;
    if (url.isEmpty) {
      double px(num value) => activityDesignPx(context, value);
      return ColoredBox(
        color: const Color(0xFFF3F4F6),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                color: activityHint,
                size: px(48),
              ),
              SizedBox(height: px(8)),
              Text(
                '暂无媒体',
                style: TextStyle(
                  color: activityHint,
                  fontSize: px(22),
                  height: 28 / 22,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFFF3F4F6),
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: activityHint),
        ),
      ),
    );
  }
}

class ActivityCommentsPanel extends StatefulWidget {
  const ActivityCommentsPanel({
    super.key,
    required this.gateway,
    required this.activityId,
    required this.authenticated,
    required this.requestLogin,
    this.voteOptionId,
    this.currentUserId,
    this.compactComposer = false,
  });

  final ActivityGateway gateway;
  final int activityId;
  final int? voteOptionId;
  final bool authenticated;
  final ActivityLoginRequester requestLogin;
  final int? currentUserId;
  final bool compactComposer;

  @override
  State<ActivityCommentsPanel> createState() => _ActivityCommentsPanelState();
}

class _ActivityCommentsPanelState extends State<ActivityCommentsPanel> {
  late final ActivityCommentsController _controller;
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  ActivityComment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _controller = ActivityCommentsController(
      gateway: widget.gateway,
      activityId: widget.activityId,
      voteOptionId: widget.voteOptionId,
      authenticated: widget.authenticated,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final content = _textController.text.trim();
    if (content.isEmpty) return;
    if (!widget.authenticated) {
      await widget.requestLogin('登录后即可发表评论');
      return;
    }
    try {
      await _controller.submit(content, parentId: _replyingTo?.id);
      _textController.clear();
      _focusNode.unfocus();
      if (mounted) setState(() => _replyingTo = null);
      _message('评论成功');
    } on Object catch (error) {
      _message(activityErrorMessage(error, '评论失败，请稍后重试'));
    }
  }

  void _reply(ActivityComment comment) {
    if (!widget.authenticated) {
      unawaited(widget.requestLogin('登录后即可回复评论'));
      return;
    }
    setState(() => _replyingTo = comment);
    _focusNode.requestFocus();
  }

  Future<void> _report(ActivityComment comment) async {
    if (!widget.authenticated) {
      await widget.requestLogin('登录后即可举报内容');
      return;
    }
    await showActivityReportSheet(
      context,
      gateway: widget.gateway,
      targetType: 'ACTIVITY_COMMENT',
      targetId: comment.id,
    );
  }

  Future<void> _block(ActivityComment comment) async {
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
      await widget.gateway.blockActivityUser(comment.userId, reason: '活动评论');
      _message('已屏蔽该用户');
      await _controller.refresh();
    } on Object catch (error) {
      _message(activityErrorMessage(error, '屏蔽失败，请稍后重试'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        double px(num value) => activityDesignPx(context, value);
        final comments = _controller.comments;
        return Container(
          key: const ValueKey('activity-comments-section'),
          padding: EdgeInsets.symmetric(horizontal: px(16), vertical: px(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(px(12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '评论 ${_controller.total}',
                      style: TextStyle(
                        color: activityInk,
                        fontSize: px(36),
                        height: 44 / 36,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: px(12),
                      vertical: px(7),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: activityIndigo,
                          size: px(28),
                        ),
                        SizedBox(width: px(4)),
                        Text(
                          '友善交流',
                          style: TextStyle(
                            color: activityIndigo,
                            fontSize: px(22),
                            height: 28 / 22,
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
              if (_controller.loading && comments.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: px(28)),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: activityPrimary),
                      SizedBox(height: px(10)),
                      Text(
                        '正在加载评论',
                        style: TextStyle(
                          color: const Color(0xFF64748B),
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
                        color: const Color(0xFFCBD5E1),
                        size: px(72),
                      ),
                      SizedBox(height: px(10)),
                      Text(
                        _controller.error == null ? '还没有评论' : '加载失败',
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
                        _controller.error ?? '来写下第一条评论，给喜欢的选手加油吧。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF64748B),
                          fontSize: px(22),
                          height: 30 / 22,
                          letterSpacing: 0,
                        ),
                      ),
                      if (_controller.error != null) ...[
                        SizedBox(height: px(14)),
                        TextButton(
                          onPressed: _controller.load,
                          style: TextButton.styleFrom(
                            foregroundColor: activityIndigo,
                            backgroundColor: const Color(0xFFEEF2FF),
                            shape: const StadiumBorder(),
                            padding: EdgeInsets.symmetric(
                              horizontal: px(18),
                              vertical: px(8),
                            ),
                          ),
                          child: const Text('重新加载'),
                        ),
                      ],
                    ],
                  ),
                )
              else
                ...comments.map(
                  (comment) => _ActivityCommentTile(
                    comment: comment,
                    currentUserId: widget.currentUserId,
                    onReply: () => _reply(comment),
                    onReport: () => _report(comment),
                    onBlock: () => _block(comment),
                  ),
                ),
              if (_controller.hasMore) ...[
                SizedBox(height: px(12)),
                SizedBox(
                  height: px(46),
                  child: TextButton(
                    onPressed: _controller.loadingMore
                        ? null
                        : () => unawaited(_controller.loadMore()),
                    style: TextButton.styleFrom(
                      foregroundColor: activityIndigo,
                      backgroundColor: const Color(0xFFEEF2FF),
                      disabledForegroundColor: activityHint,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(_controller.loadingMore ? '加载中...' : '查看更多评论'),
                  ),
                ),
              ],
              SizedBox(height: px(8)),
              _buildComposer(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComposer(BuildContext context) {
    double px(num value) => activityDesignPx(context, value);
    final canSubmit = _textController.text.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.all(px(12)),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(px(16)),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_replyingTo != null) ...[
            Padding(
              padding: EdgeInsets.only(bottom: px(10)),
              child: Row(
                children: [
                  Icon(
                    Icons.reply_rounded,
                    color: activityIndigo,
                    size: px(28),
                  ),
                  SizedBox(width: px(6)),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          color: const Color(0xFF64748B),
                          fontSize: px(22),
                          height: 28 / 22,
                        ),
                        children: [
                          const TextSpan(text: '回复 '),
                          TextSpan(
                            text: _replyingTo!.user?.nickname ?? '用户',
                            style: const TextStyle(
                              color: activityIndigo,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => setState(() => _replyingTo = null),
                      customBorder: const CircleBorder(),
                      child: SizedBox.square(
                        dimension: px(42),
                        child: Icon(
                          Icons.close_rounded,
                          color: const Color(0xFF64748B),
                          size: px(30),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: const Color(0xFFE5E7EB)),
            SizedBox(height: px(10)),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: px(68),
                    maxHeight: px(150),
                  ),
                  child: TextField(
                    key: ValueKey(
                      'activity-comment-input-${widget.voteOptionId ?? 'activity'}',
                    ),
                    controller: _textController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: widget.compactComposer ? 3 : 5,
                    maxLength: 1000,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: _replyingTo == null
                          ? '写下你的评论...'
                          : '回复 ${_replyingTo!.user?.nickname ?? '用户'}...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      counterText: '',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: px(14),
                        vertical: px(12),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(px(14)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(
                      color: activityInk,
                      fontSize: px(26),
                      height: 34 / 26,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
              SizedBox(width: px(10)),
              SizedBox(
                height: px(68),
                child: FilledButton(
                  key: ValueKey(
                    'activity-comment-send-${widget.voteOptionId ?? 'activity'}',
                  ),
                  onPressed: _controller.submitting || !canSubmit
                      ? null
                      : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: activityPrimary,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    padding: EdgeInsets.symmetric(horizontal: px(16)),
                    minimumSize: Size(px(88), px(68)),
                    shape: const StadiumBorder(),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: _controller.submitting
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
                            fontSize: px(24),
                            height: 30 / 24,
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
    );
  }
}

class _ActivityCommentTile extends StatelessWidget {
  const _ActivityCommentTile({
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
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
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
                            color: activityPrimary,
                          ),
                        )
                      : Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFFE5E7EB),
                            child: Icon(
                              Icons.person_rounded,
                              color: activityPrimary,
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
                        color: const Color(0xFF64748B),
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
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: px(12),
                vertical: px(10),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(px(14)),
                border: Border.all(color: const Color(0xFFE5E7EB)),
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
              _CommentActionButton(
                icon: Icons.reply_rounded,
                label: '回复',
                onTap: onReply,
              ),
              _CommentActionButton(
                icon: Icons.flag_rounded,
                label: '举报',
                onTap: onReport,
              ),
              if (comment.userId > 0 && comment.userId != currentUserId)
                _CommentActionButton(
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

class _CommentActionButton extends StatelessWidget {
  const _CommentActionButton({
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
            border: Border.all(color: const Color(0xFFE5E7EB)),
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

Future<bool> showActivityReportSheet(
  BuildContext context, {
  required ActivityGateway gateway,
  required String targetType,
  required int targetId,
}) async {
  const reasons = <(String, String)>[
    ('HARASSMENT', '骚扰或人身攻击'),
    ('PORNOGRAPHY', '色情低俗'),
    ('VIOLENCE', '暴力血腥'),
    ('FRAUD', '欺诈或冒充'),
    ('SPAM', '垃圾广告'),
    ('ILLEGAL', '违法违规'),
    ('MISINFORMATION', '虚假信息'),
    ('OTHER', '其他'),
  ];
  final reason = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '选择举报原因',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: activityInk,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                key: const ValueKey('activity-report-reason-list'),
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: reasons.length,
                itemBuilder: (_, index) {
                  final item = reasons[index];
                  return ListTile(
                    dense: true,
                    title: Text(item.$2),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(sheetContext).pop(item.$1),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (reason == null || !context.mounted) return false;
  try {
    await gateway.reportActivityContent(
      targetType: targetType,
      targetId: targetId,
      reason: reason,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('举报已提交，我们会尽快处理')));
    }
    return true;
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(activityErrorMessage(error, '举报失败，请稍后重试'))),
      );
    }
    return false;
  }
}
