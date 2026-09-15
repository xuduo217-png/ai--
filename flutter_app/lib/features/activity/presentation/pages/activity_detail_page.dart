import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../../core/media/route_aware_video_surface.dart';
import '../../../../core/media/rich_text_video_player.dart';
import '../../../../core/network/asset_url_resolver.dart';
import '../../../../core/widgets/app_permission_dialog.dart';
import '../../domain/activity_models.dart';
import '../activity_controller.dart';
import '../activity_design.dart';
import '../activity_interactions.dart';
import '../activity_widgets.dart';
import 'activity_vote_option_detail_page.dart';
import 'activity_vote_option_editor_page.dart';

class ActivityDetailPage extends StatefulWidget {
  const ActivityDetailPage({
    super.key,
    required this.gateway,
    required this.activityId,
    required this.authenticated,
    required this.requestLogin,
    this.currentUserId,
    this.initialPhone = '',
  });

  final ActivityGateway gateway;
  final int activityId;
  final bool authenticated;
  final Future<bool> Function(String message) requestLogin;
  final int? currentUserId;
  final String initialPhone;

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  late final ActivityDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ActivityDetailController(
      gateway: widget.gateway,
      activityId: widget.activityId,
      authenticated: widget.authenticated,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _register(ActivityItem activity) async {
    if (!widget.authenticated) {
      await widget.requestLogin(
        activity.isOnline ? '登录后即可报名参加活动' : '登录后即可报名活动',
      );
      return;
    }
    if (activity.isExpired) {
      _message('活动已结束');
      return;
    }
    if (activity.isRegistered && !activity.isOnline) {
      _message('您已经报名该活动');
      return;
    }
    if (activity.isOnline) {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ActivityVoteOptionEditorPage(controller: _controller),
        ),
      );
      if (changed == true && mounted) _message('报名成功');
      return;
    }
    final phone = await _showPhoneDialog();
    if (phone == null || !mounted) return;
    try {
      final result = await _controller.register(phone);
      _message(result.message.isEmpty ? '报名成功' : result.message);
    } on Object catch (error) {
      _message(activityErrorMessage(error, '报名失败，请稍后重试'));
    }
  }

  Future<String?> _showPhoneDialog() async {
    return showDialog<String>(
      context: context,
      builder: (_) =>
          _ActivityRegistrationDialog(initialPhone: widget.initialPhone),
    );
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

  Future<void> _editOption(
    ActivityItem activity,
    ActivityVoteOption option,
  ) async {
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

  Future<void> _reportOption(ActivityVoteOption option) async {
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

  Future<void> _openOption(ActivityVoteOption option) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ActivityVoteOptionDetailPage(
          gateway: widget.gateway,
          activityId: widget.activityId,
          optionId: option.id,
          authenticated: widget.authenticated,
          requestLogin: widget.requestLogin,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
    if (!mounted) return;
    await _controller.refresh();
    if (deleted == true && mounted) _message('参赛信息已删除');
  }

  Future<void> _showParticipants(ActivityItem activity) async {
    if (activity.isOnline || activity.registrationCount <= 0) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _ParticipantSheet(
        gateway: widget.gateway,
        activityId: activity.id,
        authenticated: widget.authenticated,
      ),
    );
  }

  Future<void> _showShare(ActivityItem activity) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActivityShareSheet(activity: activity),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VideoRoutePopScope<void>(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final activity = _controller.activity;
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: ActivityGradientBackground(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    ActivityAppBar(
                      title: '活动详情',
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(child: _buildBody(activity)),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: activity == null
                ? null
                : _ActivityActionBar(
                    activity: activity,
                    loading: _controller.actionLoading,
                    onPressed: () => _register(activity),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildBody(ActivityItem? activity) {
    if (_controller.loading && activity == null) {
      return const Center(
        child: CircularProgressIndicator(color: activityPrimary),
      );
    }
    if (_controller.error != null && activity == null) {
      return Center(
        child: TextButton.icon(
          onPressed: _controller.load,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_controller.error!),
        ),
      );
    }
    if (activity == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 80, color: activityHint),
            SizedBox(height: 10),
            Text('活动不存在', style: TextStyle(color: activityMuted)),
          ],
        ),
      );
    }
    double px(num value) => activityDesignPx(context, value);
    return RefreshIndicator(
      color: activityPrimary,
      onRefresh: _controller.refresh,
      child: ListView(
        key: const ValueKey('activity-detail-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(px(16), px(12), px(16), px(16)),
        children: [
          _ActivityMainCard(
            activity: activity,
            onParticipants: () => _showParticipants(activity),
            onShare: () => _showShare(activity),
          ),
          if (activity.summary.isNotEmpty) ...[
            SizedBox(height: px(12)),
            _ActivitySection(
              title: '活动简介',
              child: Text(
                activity.summary,
                style: TextStyle(
                  color: const Color(0xFF4B5563),
                  fontSize: px(32),
                  height: 55 / 32,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
          if (activity.isOnline) ...[
            SizedBox(height: px(12)),
            _buildVoteOptions(activity),
          ],
          if (activity.description.trim().isNotEmpty) ...[
            SizedBox(height: px(12)),
            _ActivitySection(
              title: '活动详情',
              removeHorizontalPadding: true,
              child: _ActivityRichContent(content: activity.description),
            ),
          ],
          if (activity.isOnline) ...[
            SizedBox(height: px(12)),
            ActivityCommentsPanel(
              gateway: widget.gateway,
              activityId: activity.id,
              authenticated: widget.authenticated,
              requestLogin: widget.requestLogin,
              currentUserId: widget.currentUserId,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoteOptions(ActivityItem activity) {
    final options = activity.voteOptions;
    double px(num value) => activityDesignPx(context, value);
    return Column(
      key: const ValueKey('activity-vote-options'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '选手列表',
                style: TextStyle(
                  color: activityInk,
                  fontSize: px(36),
                  height: 44 / 36,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (activity.isRegistered)
              Text(
                '今日已投票',
                style: TextStyle(
                  color: activityPrimary,
                  fontSize: px(24),
                  height: 30 / 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
          ],
        ),
        SizedBox(height: px(10)),
        if (options.isEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: px(16), vertical: px(20)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(px(12)),
            ),
            child: Text(
              '暂无选手',
              style: TextStyle(color: activityMuted, fontSize: px(28)),
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    for (var index = 0; index < options.length; index += 2)
                      Padding(
                        padding: EdgeInsets.only(bottom: px(16)),
                        child: _optionCard(activity, options[index]),
                      ),
                  ],
                ),
              ),
              SizedBox(width: px(8)),
              Expanded(
                child: Column(
                  children: [
                    for (var index = 1; index < options.length; index += 2)
                      Padding(
                        padding: EdgeInsets.only(bottom: px(16)),
                        child: _optionCard(activity, options[index]),
                      ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _optionCard(ActivityItem activity, ActivityVoteOption option) {
    final canManage = canManageActivityVoteOption(
      activity: activity,
      option: option,
      authenticated: widget.authenticated,
      currentUserId: widget.currentUserId,
    );
    return ActivityVoteOptionCard(
      option: option,
      voteEnabled: !activity.isExpired && !activity.isRegistered,
      voting: _controller.votingOptionId == option.id,
      buttonLabel: activity.isExpired
          ? '已结束'
          : activity.isRegistered
          ? '今日已投'
          : '投票',
      onOpen: () => _openOption(option),
      onVote: () => _vote(activity, option),
      onReport: () => _reportOption(option),
      onEdit: canManage ? () => _editOption(activity, option) : null,
    );
  }
}

class _ActivityRegistrationDialog extends StatefulWidget {
  const _ActivityRegistrationDialog({required this.initialPhone});

  final String initialPhone;

  @override
  State<_ActivityRegistrationDialog> createState() =>
      _ActivityRegistrationDialogState();
}

class _ActivityRegistrationDialogState
    extends State<_ActivityRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double px(num value) => activityDesignPx(context, value);
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: px(32)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(px(16)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: EdgeInsets.all(px(28)),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '确认报名',
                  style: TextStyle(
                    color: activityInk,
                    fontSize: px(36),
                    height: 44 / 36,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: px(10)),
                Text(
                  '请输入您的联系电话',
                  style: TextStyle(
                    color: activityMuted,
                    fontSize: px(28),
                    height: 36 / 28,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: px(24)),
                TextFormField(
                  key: const ValueKey('activity-register-phone'),
                  controller: _controller,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  autofocus: true,
                  style: TextStyle(
                    color: activityInk,
                    fontSize: px(28),
                    height: 36 / 28,
                    letterSpacing: 0,
                  ),
                  decoration: InputDecoration(
                    hintText: '请输入手机号',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                    counterText: '',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: px(24),
                      vertical: px(20),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(px(12)),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(px(12)),
                      borderSide: const BorderSide(color: activityPrimary),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(px(12)),
                      borderSide: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(px(12)),
                      borderSide: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                  ),
                  validator: (value) {
                    final phone = value?.trim() ?? '';
                    return RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)
                        ? null
                        : '请输入有效的手机号码';
                  },
                ),
                SizedBox(height: px(24)),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: px(88),
                        child: TextButton(
                          key: const ValueKey('activity-register-cancel'),
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF374151),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(px(8)),
                            ),
                          ),
                          child: Text(
                            '取消',
                            style: TextStyle(
                              fontSize: px(28),
                              height: 36 / 28,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: px(12)),
                    Expanded(
                      child: SizedBox(
                        height: px(88),
                        child: FilledButton(
                          key: const ValueKey('activity-register-confirm'),
                          onPressed: () {
                            if (_formKey.currentState?.validate() == true) {
                              Navigator.of(
                                context,
                              ).pop(_controller.text.trim());
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: activityPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(px(8)),
                            ),
                          ),
                          child: Text(
                            '确认',
                            style: TextStyle(
                              fontSize: px(28),
                              height: 36 / 28,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
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
      ),
    );
  }
}

class _ActivityMainCard extends StatelessWidget {
  const _ActivityMainCard({
    required this.activity,
    required this.onParticipants,
    required this.onShare,
  });

  final ActivityItem activity;
  final VoidCallback onParticipants;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    double px(num value) => activityDesignPx(context, value);
    return Material(
      key: const ValueKey('activity-main-card'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(px(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: px(16), vertical: px(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (activity.coverImageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(px(12)),
                child: ActivityCoverImage(
                  url: activity.coverImageUrl,
                  semanticLabel: '${activity.title}活动封面',
                ),
              ),
              SizedBox(height: px(14)),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    activity.title,
                    style: TextStyle(
                      color: activityInk,
                      fontSize: px(36),
                      height: 44 / 36,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                SizedBox(width: px(12)),
                Material(
                  color: activityPrimary,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    key: const ValueKey('activity-share'),
                    onTap: onShare,
                    borderRadius: BorderRadius.circular(999),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: px(56)),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: px(18),
                          vertical: px(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.share_rounded,
                              size: px(36),
                              color: Colors.white,
                            ),
                            SizedBox(width: px(8)),
                            Text(
                              '分享',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: px(28),
                                height: 32 / 28,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: px(14)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: px(14),
                    vertical: px(7),
                  ),
                  decoration: BoxDecoration(
                    color: activityStatusColor(activity.status),
                    borderRadius: BorderRadius.circular(px(6)),
                  ),
                  child: Text(
                    activity.status.label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: px(24),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (!activity.isOnline)
                  InkWell(
                    onTap: activity.registrationCount > 0
                        ? onParticipants
                        : null,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: px(12),
                        vertical: px(8),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_rounded,
                            size: px(28),
                            color: activityPrimary,
                          ),
                          SizedBox(width: px(6)),
                          Text(
                            '${activity.registrationCount} 人已报名',
                            style: TextStyle(
                              color: activityIndigo,
                              fontSize: px(24),
                              height: 28 / 24,
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
            SizedBox(height: px(16)),
            _DetailInfoRow(
              icon: Icons.schedule_rounded,
              label: '时间：',
              value: activityDateRange(activity.startTime, activity.endTime),
            ),
            if (!activity.isOnline) ...[
              SizedBox(height: px(16)),
              _DetailInfoRow(
                icon: Icons.location_on_rounded,
                label: '地点：',
                value: activity.location.isEmpty ? '-' : activity.location,
              ),
            ],
            SizedBox(height: px(16)),
            _DetailInfoRow(
              icon: Icons.business_rounded,
              label: '医院：',
              value: activity.hospitalName.isEmpty
                  ? '-'
                  : activity.hospitalName,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  const _DetailInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    double px(num value) => activityDesignPx(context, value);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: px(48), color: activityPrimary),
        SizedBox(width: px(10)),
        Text(
          label,
          style: TextStyle(color: activityMuted, fontSize: px(28)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Color(0xFF374151),
              fontSize: px(28),
              height: 36 / 28,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityRichContent extends StatelessWidget {
  const _ActivityRichContent({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final document = HtmlParser.parseHTML(content);
    var imageIndex = 0;
    for (final image in document.querySelectorAll('img')) {
      final rawSource = image.attributes['src']?.trim() ?? '';
      final source = rawSource.startsWith('//')
          ? 'https:$rawSource'
          : resolveAssetUrl(rawSource);
      if (source.isEmpty) {
        image.remove();
        continue;
      }
      image.attributes['src'] = source;
      image.attributes['data-activity-image-id'] = '${imageIndex++}';
      image.attributes.remove('width');
      image.attributes.remove('height');
      image.attributes.remove('style');
    }

    var videoIndex = 0;
    for (final wrapper in document.querySelectorAll(
      'div[data-w-e-type="video"]',
    )) {
      wrapper.attributes['data-activity-video-id'] = '${videoIndex++}';
    }
    for (final video in document.querySelectorAll('video')) {
      var ancestor = video.parent;
      var wrappedByWangEditor = false;
      while (ancestor != null) {
        if (ancestor.localName == 'div' &&
            ancestor.attributes['data-w-e-type'] == 'video') {
          wrappedByWangEditor = true;
          break;
        }
        ancestor = ancestor.parent;
      }
      if (wrappedByWangEditor) continue;
      video.attributes['data-activity-video-id'] = '${videoIndex++}';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return Html.fromElement(
          key: const ValueKey('activity-rich-content'),
          documentElement: document,
          shrinkWrap: true,
          extensions: [
            ImageExtension(
              handleAssetImages: false,
              builder: (context) => _ActivityRichImage(
                imageId:
                    context.attributes['data-activity-image-id'] ??
                    'raw-${context.node.hashCode}',
                source: context.attributes['src'] ?? '',
                width: contentWidth,
              ),
            ),
            MatcherExtension(
              matcher: _matchesActivityRichVideo,
              builder: (context) {
                final videoId =
                    context.attributes['data-activity-video-id'] ??
                    'raw-${context.node.hashCode}';
                final source = _extractActivityVideoSource(context);
                if (source == null) {
                  return UnavailableRichTextVideo(
                    key: ValueKey('activity-rich-video-unavailable-$videoId'),
                    foregroundColor: activityMuted,
                  );
                }
                return RichTextVideoPlayer(
                  key: ValueKey('activity-rich-video-state-$videoId'),
                  source: source,
                  width: contentWidth,
                  semanticsKey: ValueKey('activity-rich-video-$videoId'),
                  semanticLabel: '活动详情视频播放器',
                  controlKeyPrefix: 'activity-rich-video',
                  accentColor: activityPrimary,
                  autoPlayWhenVisible: true,
                );
              },
            ),
          ],
          doNotRenderTheseTags: const {
            'script',
            'style',
            'iframe',
            'object',
            'embed',
          },
          style: {
            'html': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
            'body': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              color: const Color(0xFF4B5563),
              fontSize: FontSize(14),
              lineHeight: const LineHeight(1.6),
              letterSpacing: 0,
            ),
            'img': Style(
              display: Display.block,
              width: Width(contentWidth),
              height: Height.auto(),
              margin: Margins.only(bottom: 10),
            ),
            'video': Style(
              display: Display.block,
              width: Width(contentWidth),
              height: Height.auto(),
              margin: Margins.only(bottom: 10),
            ),
          },
        );
      },
    );
  }
}

bool _activityVideoHasWangEditorAncestor(ExtensionContext context) {
  var ancestor = context.element?.parent;
  while (ancestor != null) {
    if (ancestor.localName == 'div' &&
        ancestor.attributes['data-w-e-type'] == 'video') {
      return true;
    }
    ancestor = ancestor.parent;
  }
  return false;
}

bool _matchesActivityRichVideo(ExtensionContext context) {
  if (context.elementName == 'div' &&
      context.attributes['data-w-e-type'] == 'video') {
    return true;
  }
  return context.elementName == 'video' &&
      !_activityVideoHasWangEditorAncestor(context);
}

RichTextVideoSource? _extractActivityVideoSource(ExtensionContext context) {
  final element = context.element;
  if (element == null) return null;
  final video = context.elementName == 'video'
      ? element
      : element.querySelector('video');
  if (video == null) return null;

  final directSource = video.attributes['src']?.trim();
  final rawSource = directSource?.isNotEmpty == true
      ? directSource
      : video.querySelector('source')?.attributes['src'];
  final uri = _resolveActivityVideoUri(rawSource);
  if (uri == null) return null;

  return RichTextVideoSource(
    uri: uri,
    posterUri: _resolveActivityVideoUri(video.attributes['poster']),
  );
}

Uri? _resolveActivityVideoUri(String? value) {
  final source = value?.trim() ?? '';
  if (source.isEmpty) return null;
  final resolved = source.startsWith('//')
      ? 'https:$source'
      : resolveAssetUrl(source);
  final uri = Uri.tryParse(resolved);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return uri;
}

class _ActivityRichImage extends StatelessWidget {
  const _ActivityRichImage({
    required this.imageId,
    required this.source,
    required this.width,
  });

  final String imageId;
  final String source;
  final double width;

  @override
  Widget build(BuildContext context) {
    final image = source.startsWith('data:')
        ? _memoryImage()
        : Image.network(
            source,
            width: width,
            fit: BoxFit.fitWidth,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => _placeholder(),
          );
    return SizedBox(
      key: ValueKey('activity-rich-image-$imageId'),
      width: width,
      child: image,
    );
  }

  Widget _memoryImage() {
    try {
      return Image.memory(
        UriData.parse(source).contentAsBytes(),
        width: width,
        fit: BoxFit.fitWidth,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    } on FormatException {
      return _placeholder();
    }
  }

  Widget _placeholder() {
    return const AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Color(0xFFF3F4F6),
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: activityHint),
        ),
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    required this.title,
    required this.child,
    this.removeHorizontalPadding = false,
  });

  final String title;
  final Widget child;
  final bool removeHorizontalPadding;

  @override
  Widget build(BuildContext context) {
    double px(num value) => activityDesignPx(context, value);
    return Container(
      padding: EdgeInsets.fromLTRB(
        removeHorizontalPadding ? 0 : px(16),
        px(20),
        removeHorizontalPadding ? 0 : px(16),
        px(20),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(px(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: removeHorizontalPadding ? px(16) : 0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: activityInk,
                      fontSize: px(36),
                      height: 44 / 36,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: px(16)),
          child,
        ],
      ),
    );
  }
}

class _ActivityActionBar extends StatelessWidget {
  const _ActivityActionBar({
    required this.activity,
    required this.loading,
    required this.onPressed,
  });

  final ActivityItem activity;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    double px(num value) => activityDesignPx(context, value);
    final disabled =
        activity.isExpired ||
        (!activity.isOnline &&
            (activity.isRegistered || !activity.canRegister));
    final label = switch ((activity.activityType, activity.status)) {
      (_, ActivityStatus.expired) => '活动已结束',
      (ActivityType.offline, _) when activity.isRegistered => '已报名',
      (ActivityType.offline, _) => '立即报名',
      (ActivityType.online, _) => '报名参加',
    };
    return Material(
      color: Colors.white,
      elevation: 12,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(px(16), px(16), px(16), px(12)),
        child: SizedBox(
          height: px(88),
          child: FilledButton(
            key: const ValueKey('activity-primary-action'),
            onPressed: loading || disabled ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: activity.isOnline
                  ? activityIndigo
                  : activityPrimary,
              disabledBackgroundColor: const Color(0xFFE5E7EB),
              disabledForegroundColor: activityHint,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: loading
                ? SizedBox.square(
                    dimension: px(32),
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: px(28),
                      height: 36 / 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ParticipantSheet extends StatefulWidget {
  const _ParticipantSheet({
    required this.gateway,
    required this.activityId,
    required this.authenticated,
  });

  final ActivityGateway gateway;
  final int activityId;
  final bool authenticated;

  @override
  State<_ParticipantSheet> createState() => _ParticipantSheetState();
}

class _ParticipantSheetState extends State<_ParticipantSheet> {
  late final Future<ActivityParticipantPage> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.gateway.loadActivityParticipants(
      widget.activityId,
      authenticated: widget.authenticated,
      pageSize: 50,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.65,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              '已报名用户',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: activityInk,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<ActivityParticipantPage>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: activityPrimary),
                  );
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('报名列表加载失败'));
                }
                final items = snapshot.data?.items ?? const [];
                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      '暂无报名用户',
                      style: TextStyle(color: activityHint),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final participant = items[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 3),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEEF2FF),
                        backgroundImage: participant.userAvatarUrl.isNotEmpty
                            ? NetworkImage(participant.userAvatarUrl)
                            : null,
                        child: participant.userAvatarUrl.isEmpty
                            ? const Icon(
                                Icons.person_rounded,
                                color: activityPrimary,
                              )
                            : null,
                      ),
                      title: Text(participant.userName),
                      subtitle: Text(
                        '报名于 ${activityRelativeTime(participant.registeredAt)}',
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityShareSheet extends StatefulWidget {
  const _ActivityShareSheet({required this.activity});

  final ActivityItem activity;

  @override
  State<_ActivityShareSheet> createState() => _ActivityShareSheetState();
}

class _ActivityShareSheetState extends State<_ActivityShareSheet> {
  static const _posterChannel = MethodChannel(
    'com.good.pet.hospital/activity_share_poster',
  );

  final _posterKey = GlobalKey();
  bool _saving = false;

  Future<Uint8List> _capturePoster() async {
    final boundary = _posterKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError('活动海报尚未渲染完成');
    }
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('活动海报生成失败');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _previewPoster() async {
    try {
      final bytes = await _capturePoster();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black,
        builder: (dialogContext) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Center(child: Image.memory(bytes)),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    key: const ValueKey('activity-share-preview-close'),
                    tooltip: '关闭预览',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0x88000000),
                    ),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _confirmSavePoster() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      await _savePoster();
      return;
    }
    final confirmed = await showAppPermissionDialog(
      context: context,
      icon: Icons.photo_library_rounded,
      title: '保存海报到相册',
      description: '需要相册写入权限，用于保存当前活动海报，方便分享给朋友。',
      assurances: const ['只保存您长按选择的活动海报', '不会读取或上传您的相册内容'],
      cancelText: '暂不需要',
      confirmText: '允许保存海报',
      accentColor: activityPrimary,
      cancelButtonKey: const ValueKey('activity-share-save-cancel'),
      confirmButtonKey: const ValueKey('activity-share-save-confirm'),
    );
    if (confirmed) await _savePoster();
  }

  Future<void> _savePoster() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await _capturePoster();
      final saved = await _posterChannel.invokeMethod<bool>('savePng', {
        'bytes': bytes,
      });
      if (saved != true) throw StateError('保存失败，请检查相册权限后重试');
      _showMessage('海报已保存到相册');
    } on PlatformException catch (error) {
      _showMessage(error.message ?? '保存失败，请检查相册权限后重试');
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final qrPayload = jsonEncode({
      'type': 'activities',
      'value': '${activity.id}',
    });
    final qrUrl = Uri.https('api.qrserver.com', '/v1/create-qr-code/', {
      'size': '420x420',
      'data': qrPayload,
    }).toString();
    final posterImage = activity.sharePosterImageUrl;
    final hasSharePoster = posterImage.isNotEmpty;
    final title = activity.sharePosterTitle;
    final description = activity.sharePosterDescription;
    final posterWidth = math.max(
      240.0,
      math
          .min(
            MediaQuery.sizeOf(context).width * 0.72,
            activityDesignPx(context, 420),
          )
          .roundToDouble(),
    );
    final posterHeight = (posterWidth * 16 / 9).roundToDouble();
    final posterPadding = (posterWidth * 0.05).roundToDouble();
    final qrSize = math.max(88.0, (posterWidth * 0.29).roundToDouble());
    final qrLeft = posterPadding;
    final qrTop = posterHeight - posterPadding - qrSize;
    final textLeft = qrLeft + qrSize + (posterWidth * 0.033).roundToDouble();
    final textWidth = math.max(0.0, posterWidth - textLeft - posterPadding);
    double px(num value) => activityDesignPx(context, value);

    return Container(
      margin: const EdgeInsets.only(top: 54),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(px(28))),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(px(24), px(20), px(24), px(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: px(56),
                height: px(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              SizedBox(height: px(16)),
              Text(
                '分享活动',
                style: TextStyle(
                  color: activityInk,
                  fontSize: px(44),
                  height: 52 / 44,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: px(10)),
              Text(
                hasSharePoster ? '长按保存海报，分享给朋友扫码进入活动' : '让朋友扫一扫二维码，直接进入这个活动详情页',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: activityMuted,
                  fontSize: px(30),
                  height: 40 / 30,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: px(24)),
              if (hasSharePoster)
                GestureDetector(
                  key: const ValueKey('activity-share-poster-save-area'),
                  onTap: _previewPoster,
                  onLongPress: _saving ? null : _confirmSavePoster,
                  child: Column(
                    children: [
                      RepaintBoundary(
                        key: _posterKey,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(px(18)),
                          child: SizedBox(
                            width: posterWidth,
                            height: posterHeight,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.network(
                                    posterImage,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const ColoredBox(
                                      color: Color(0xFFF3F4F6),
                                      child: Icon(
                                        Icons.event_rounded,
                                        color: activityPrimary,
                                        size: 54,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: qrLeft,
                                  top: qrTop,
                                  width: qrSize,
                                  height: qrSize,
                                  child: ColoredBox(
                                    color: Colors.white,
                                    child: Padding(
                                      padding: EdgeInsets.all(px(6)),
                                      child: Image.network(
                                        qrUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.qr_code_2_rounded,
                                          color: activityInk,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (title.isNotEmpty || description.isNotEmpty)
                                  Positioned(
                                    left: textLeft,
                                    top: qrTop,
                                    width: textWidth,
                                    child: Container(
                                      constraints: BoxConstraints(
                                        minHeight: px(64),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: px(10),
                                        vertical: px(8),
                                      ),
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (title.isNotEmpty)
                                            Text(
                                              title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: const Color(0xFF111827),
                                                fontSize: px(24),
                                                height: 30 / 24,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0,
                                              ),
                                            ),
                                          if (description.isNotEmpty) ...[
                                            SizedBox(height: px(4)),
                                            Text(
                                              description,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: const Color(0xFF374151),
                                                fontSize: px(18),
                                                height: 24 / 18,
                                                letterSpacing: 0,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: px(12)),
                      Text(
                        _saving ? '正在保存...' : '点击预览，长按保存到相册',
                        style: TextStyle(
                          color: activityMuted,
                          fontSize: px(22),
                          height: 30 / 22,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.all(px(20)),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(px(24)),
                  ),
                  child: Image.network(
                    qrUrl,
                    width: MediaQuery.sizeOf(context).width * 0.6,
                    height: MediaQuery.sizeOf(context).width * 0.6,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.qr_code_2_rounded,
                      color: activityInk,
                      size: MediaQuery.sizeOf(context).width * 0.5,
                    ),
                  ),
                ),
              SizedBox(height: px(20)),
              FilledButton(
                key: const ValueKey('activity-share-close'),
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  minimumSize: Size(px(180), px(72)),
                  padding: EdgeInsets.symmetric(
                    horizontal: px(32),
                    vertical: px(14),
                  ),
                  backgroundColor: activityPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(px(50)),
                  ),
                  textStyle: TextStyle(
                    fontSize: px(24),
                    height: 32 / 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
