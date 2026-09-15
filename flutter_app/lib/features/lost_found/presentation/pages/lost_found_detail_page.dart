import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

import '../../../../core/network/asset_url_resolver.dart';
import '../../../../core/platform/external_uri_launcher.dart';
import '../../../friends/presentation/pages/friend_video_player_page.dart';
import '../../domain/lost_found_models.dart';
import '../lost_found_controller.dart';
import '../lost_found_design.dart';
import 'lost_found_editor_page.dart';
import 'lost_found_list_page.dart';

class LostFoundDetailPage extends StatefulWidget {
  const LostFoundDetailPage({
    super.key,
    required this.gateway,
    required this.initialRecord,
    required this.authenticated,
    this.currentUserId,
    this.requestLogin,
    this.uriLauncher = const MethodChannelExternalUriLauncher(),
  });

  final LostFoundGateway gateway;
  final LostFoundRecord initialRecord;
  final bool authenticated;
  final int? currentUserId;
  final LostFoundLoginRequest? requestLogin;
  final ExternalUriLauncher uriLauncher;

  @override
  State<LostFoundDetailPage> createState() => _LostFoundDetailPageState();
}

class _LostFoundDetailPageState extends State<LostFoundDetailPage> {
  static const double _composerClearance = 84;
  static const double _replyBarHeight = 38;

  late final LostFoundDetailController _controller;
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  LostFoundComment? _replyingTo;
  bool _changed = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _controller = LostFoundDetailController(
      gateway: widget.gateway,
      recordId: widget.initialRecord.id,
      authenticated: widget.authenticated,
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  LostFoundRecord get _record => _controller.record ?? widget.initialRecord;
  bool get _isOwner =>
      widget.currentUserId != null &&
      widget.currentUserId == _record.publisherId;

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _allowPop) return;
        final routeResult = result ?? _changed;
        setState(() => _allowPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop(routeResult);
        });
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        body: LostFoundGradientBackground(
          child: SafeArea(
            bottom: false,
            child: ListenableBuilder(
              listenable: _controller,
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
                    child: _buildCommentComposer(),
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
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).pop(_changed),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          Expanded(
            child: Text(
              _record.recordType == LostFoundRecordType.lost ? '走失详情' : '领养详情',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: lostFoundText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          PopupMenuButton<_DetailAction>(
            tooltip: '更多操作',
            enabled: !_controller.working,
            onSelected: _handleAction,
            itemBuilder: (_) => _isOwner
                ? [
                    const PopupMenuItem(
                      value: _DetailAction.edit,
                      child: _MenuItem(
                        icon: Icons.edit_outlined,
                        label: '编辑信息',
                      ),
                    ),
                    if (_record.recordType == LostFoundRecordType.lost &&
                        !_record.isFound)
                      const PopupMenuItem(
                        value: _DetailAction.markFound,
                        child: _MenuItem(
                          icon: Icons.task_alt_rounded,
                          label: '标记已找回',
                        ),
                      ),
                    const PopupMenuItem(
                      value: _DetailAction.delete,
                      child: _MenuItem(
                        icon: Icons.delete_outline_rounded,
                        label: '删除信息',
                        destructive: true,
                      ),
                    ),
                  ]
                : const [
                    PopupMenuItem(
                      value: _DetailAction.report,
                      child: _MenuItem(
                        icon: Icons.flag_outlined,
                        label: '举报信息',
                        destructive: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: _DetailAction.block,
                      child: _MenuItem(
                        icon: Icons.block_rounded,
                        label: '屏蔽发布者',
                        destructive: true,
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.loading && _controller.record == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.error != null && _controller.record == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 52,
                color: lostFoundBlue,
              ),
              const SizedBox(height: 12),
              Text(
                _controller.error!,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _controller.load,
                child: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _controller.load,
      child: ListView(
        key: const ValueKey('lost-found-detail-scroll'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          MediaQuery.paddingOf(context).bottom +
              _composerClearance +
              (_replyingTo == null ? 0 : _replyBarHeight),
        ),
        children: [
          _buildHero(),
          const SizedBox(height: 12),
          _buildDescription(),
          const SizedBox(height: 12),
          _buildMedia(),
          const SizedBox(height: 12),
          _buildContact(),
          const SizedBox(height: 12),
          _buildComments(),
        ],
      ),
    );
  }

  Widget _buildHero() {
    final record = _record;
    final adoption = record.recordType == LostFoundRecordType.adoption;
    final avatar = resolveAssetUrl(record.pet?.avatarUrl);
    final statusColor = adoption
        ? const Color(0xFFE0F2FE)
        : record.isFound
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFEE2E2);
    final statusForeground = adoption
        ? const Color(0xFF0369A1)
        : record.isFound
        ? const Color(0xFF15803D)
        : const Color(0xFFB91C1C);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: lostFoundCardDecoration(
        radius: 13,
      ).copyWith(color: const Color(0xFFF8FBFF)),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: LostFoundNetworkImage(url: avatar),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        _HeroBadge(
                          icon: adoption
                              ? Icons.favorite_border_rounded
                              : Icons.search_rounded,
                          label: record.recordType.label,
                          background: lostFoundBlueSoft,
                          foreground: lostFoundBlue,
                        ),
                        _HeroBadge(
                          label: record.statusLabel,
                          background: statusColor,
                          foreground: statusForeground,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      record.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: lostFoundText,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      record.breedLabel.isEmpty ? '- / -' : record.breedLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: lostFoundTextSecondary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '发布人 · ${record.publisher?.displayName ?? '发布人'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryItem(
                      label: '发布时间',
                      value: _formatDateTime(record.createdAt),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryItem(
                      label: '联系人',
                      value: record.contactName,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryItem(
                      label: '信息类型',
                      value: '${record.recordType.label}信息',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryItem(
                      label: '最近更新',
                      value: _formatDateTime(record.updatedAt),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  record.isFound
                      ? Icons.check_circle_rounded
                      : Icons.tips_and_updates_outlined,
                  size: 18,
                  color: record.isFound
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFD97706),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    adoption
                        ? '建议联系前先阅读完整领养说明，并确认交接与照顾条件。'
                        : record.isFound
                        ? '宠物已经找回，感谢大家提供的帮助。'
                        : '如果你掌握相关线索，请尽快通过电话联系发布人。',
                    style: const TextStyle(
                      color: lostFoundText,
                      height: 1.45,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    final adoption = _record.recordType == LostFoundRecordType.adoption;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LostFoundSectionTitle(
            icon: Icons.description_outlined,
            title: adoption ? '领养说明' : '走失说明',
          ),
          const SizedBox(height: 13),
          Text(
            _record.description,
            style: const TextStyle(
              color: lostFoundText,
              fontSize: 15,
              height: 1.62,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia() {
    final record = _record;
    final adoption = record.recordType == LostFoundRecordType.adoption;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LostFoundSectionTitle(
            icon: Icons.perm_media_outlined,
            title: adoption ? '宠物影像' : '线索影像',
          ),
          const SizedBox(height: 8),
          Text(
            adoption ? '通过图片和视频补充宠物近况，帮助领养人更快了解状态。' : '现场图片和视频可以帮助核对宠物特征与线索信息。',
            style: const TextStyle(color: lostFoundTextSecondary, height: 1.45),
          ),
          const SizedBox(height: 13),
          if (record.images.isEmpty)
            Container(
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: lostFoundBorder),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    color: Color(0xFF94A3B8),
                  ),
                  SizedBox(height: 7),
                  Text('暂未上传图片资料', style: TextStyle(color: Color(0xFF94A3B8))),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.04,
              ),
              itemCount: record.images.length,
              itemBuilder: (context, index) => InkWell(
                key: ValueKey('lost-found-image-$index'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => LostFoundImageViewerPage(
                      images: record.images,
                      initialIndex: index,
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LostFoundNetworkImage(
                    url: resolveAssetUrl(record.images[index]),
                  ),
                ),
              ),
            ),
          if (record.videoUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              key: const ValueKey('lost-found-video'),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      FriendVideoPlayerPage(videoUrl: record.videoUrl),
                ),
              ),
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      LostFoundNetworkImage(
                        url: resolveAssetUrl(record.videoCoverUrl),
                        placeholderIcon: Icons.videocam_rounded,
                      ),
                      const ColoredBox(color: Color(0x240F172A)),
                      const Center(
                        child: CircleAvatar(
                          radius: 27,
                          backgroundColor: Color(0x990F172A),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: _HeroBadge(
                          icon: Icons.videocam_rounded,
                          label: adoption ? '宠物视频' : '现场视频',
                          background: const Color(0xA60F172A),
                          foreground: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContact() {
    final adoption = _record.recordType == LostFoundRecordType.adoption;
    return _SectionCard(
      color: const Color(0xFFF9FBFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LostFoundSectionTitle(icon: Icons.call_outlined, title: '联系方式'),
          const SizedBox(height: 8),
          Text(
            adoption
                ? '如需了解领养条件、交接方式或宠物近况，可直接与发布人联系。'
                : _record.isFound
                ? '宠物已经找回，仍可联系发布人确认后续情况。'
                : '如有线索或发现相似宠物，请第一时间联系发布人。',
            style: const TextStyle(color: lostFoundTextSecondary, height: 1.45),
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: lostFoundBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '联系人',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _record.contactName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Divider(height: 24),
                const Text(
                  '联系电话',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _record.contactPhone,
                  style: const TextStyle(
                    color: lostFoundBlue,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('lost-found-call'),
              onPressed: _callContact,
              icon: const Icon(Icons.phone_rounded),
              label: const Text('立即联系'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComments() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LostFoundSectionTitle(
            icon: Icons.chat_bubble_outline_rounded,
            title: '评论 ${_controller.commentTotal}',
            trailing: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: lostFoundBlue,
                  size: 16,
                ),
                SizedBox(width: 4),
                Text(
                  '友善交流',
                  style: TextStyle(color: lostFoundBlue, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_controller.comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Color(0xFF94A3B8),
                      size: 34,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '还没有评论',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '留下第一条留言，帮助线索沟通更顺畅。',
                      style: TextStyle(
                        color: lostFoundTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._controller.comments.map(
              (comment) => _CommentItem(
                comment: comment,
                currentUserId: widget.currentUserId,
                onReply: () => unawaited(_startReply(comment)),
                onReport: () => _reportComment(comment),
                onBlock: comment.userId > 0
                    ? () => _blockUser(comment.userId, '屏蔽评论用户')
                    : null,
              ),
            ),
          if (_controller.hasMoreComments)
            Center(
              child: TextButton.icon(
                onPressed: _controller.working
                    ? null
                    : _controller.loadMoreComments,
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text('查看更多评论'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentComposer() {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        key: const ValueKey('lost-found-comment-composer'),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(8)),
          border: Border.fromBorderSide(BorderSide(color: lostFoundBorder)),
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
            if (_replyingTo case final target?)
              Container(
                height: _replyBarHeight,
                padding: const EdgeInsets.only(left: 16, right: 6),
                color: lostFoundBlueSoft,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '回复 ${target.user?.displayName ?? '用户'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: lostFoundTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '取消回复',
                      onPressed: () => setState(() => _replyingTo = null),
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
                      key: const ValueKey('lost-found-comment-field'),
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      enabled: !_controller.working,
                      minLines: 1,
                      maxLines: 2,
                      maxLength: 1000,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: widget.authenticated
                            ? _replyingTo == null
                                  ? '友善评论，分享你的线索'
                                  : '回复 ${_replyingTo!.user?.displayName ?? '用户'}'
                            : '登录后参与留言交流',
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
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
                      onTap: widget.authenticated ? null : _requestCommentLogin,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 40,
                    child: FilledButton(
                      key: const ValueKey('lost-found-comment-send'),
                      onPressed: _controller.working ? null : _sendComment,
                      style: FilledButton.styleFrom(
                        backgroundColor: lostFoundBlue,
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

  Future<void> _handleAction(_DetailAction action) async {
    switch (action) {
      case _DetailAction.edit:
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => LostFoundEditorPage(
              gateway: widget.gateway,
              initialRecord: _record,
            ),
          ),
        );
        if (changed == true) {
          _changed = true;
          await _controller.load();
        }
      case _DetailAction.markFound:
        await _confirmMarkFound();
      case _DetailAction.delete:
        await _confirmDelete();
      case _DetailAction.report:
        await _reportRecord();
      case _DetailAction.block:
        await _blockUser(_record.publisherId, '屏蔽发布者');
    }
  }

  Future<void> _confirmMarkFound() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: const AppDialogIcon(icon: Icons.task_alt_rounded),
        title: const Text('确认已找回'),
        content: const Text('标记后，列表会显示“已找回”状态。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _controller.markFound();
      _changed = true;
      if (mounted) _showMessage('已标记为找回');
    } on Object catch (error) {
      if (mounted) _showMessage('操作失败：$error');
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: const AppDialogIcon.danger(icon: Icons.delete_outline_rounded),
        title: const Text('删除信息'),
        content: const Text('删除后无法恢复，确认继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _controller.delete();
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) _showMessage('删除失败：$error');
    }
  }

  Future<void> _callContact() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: const AppDialogIcon(icon: Icons.phone_rounded),
        title: const Text('拨打电话'),
        content: Text('是否拨打 ${_record.contactPhone}？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.phone_rounded),
            label: const Text('拨打'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final uri = Uri(scheme: 'tel', path: _record.contactPhone.trim());
    final launched = await widget.uriLauncher.launch(uri);
    if (!launched && mounted) _showMessage('当前设备无法拨打电话');
  }

  Future<void> _requestCommentLogin() async {
    FocusScope.of(context).unfocus();
    await widget.requestLogin?.call('登录后即可参与留言交流');
  }

  Future<void> _startReply(LostFoundComment comment) async {
    if (!await _ensureAuthenticated('登录后即可回复评论')) return;
    if (!mounted) return;
    setState(() => _replyingTo = comment);
    _commentFocusNode.requestFocus();
  }

  Future<void> _sendComment() async {
    if (!widget.authenticated) {
      await _requestCommentLogin();
      return;
    }
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      _showMessage('请输入评论内容');
      return;
    }
    try {
      await _controller.createComment(content, parentId: _replyingTo?.id);
      if (!mounted) return;
      _commentController.clear();
      _commentFocusNode.unfocus();
      setState(() => _replyingTo = null);
      _showMessage('评论已发布');
    } on Object catch (error) {
      if (mounted) _showMessage('评论失败：$error');
    }
  }

  Future<void> _reportRecord() async {
    if (!await _ensureAuthenticated('登录后即可举报信息')) return;
    await _showReportSheet(
      targetType: 'LOST_FOUND_RECORD',
      targetId: _record.id,
      targetUserId: _record.publisherId,
      title: '${_record.recordType.label}信息 · ${_record.title}',
    );
  }

  Future<void> _reportComment(LostFoundComment comment) async {
    if (!await _ensureAuthenticated('登录后即可举报评论')) return;
    await _showReportSheet(
      targetType: 'LOST_FOUND_COMMENT',
      targetId: comment.id,
      targetUserId: comment.userId,
      title: '走失/领养评论 · ${comment.user?.displayName ?? '匿名用户'}',
    );
  }

  Future<void> _showReportSheet({
    required String targetType,
    required int targetId,
    required int targetUserId,
    required String title,
  }) async {
    final result = await showModalBottomSheet<_ReportResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReportSheet(title: title),
    );
    if (result == null) return;
    try {
      await widget.gateway.reportLostFoundContent(
        targetType: targetType,
        targetId: targetId,
        reason: result.reason,
        description: result.description,
      );
      if (!mounted) return;
      final block = targetUserId > 0
          ? await showDialog<bool>(
              context: context,
              builder: (context) => AppDialog(
                icon: const AppDialogIcon.danger(icon: Icons.report_rounded),
                title: const Text('举报已提交'),
                content: const Text('你也可以屏蔽该用户，减少后续互动。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('完成'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('同时屏蔽'),
                  ),
                ],
              ),
            )
          : false;
      if (block == true) {
        await _blockUser(targetUserId, '举报后屏蔽', confirm: false);
      }
    } on Object catch (error) {
      if (mounted) _showMessage('举报失败：$error');
    }
  }

  Future<void> _blockUser(
    int userId,
    String reason, {
    bool confirm = true,
  }) async {
    if (userId <= 0) return;
    if (!await _ensureAuthenticated('登录后即可管理屏蔽名单')) return;
    if (!mounted) return;
    if (confirm) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AppDialog(
          icon: const AppDialogIcon.danger(icon: Icons.block_rounded),
          title: Text(reason),
          content: const Text('屏蔽后，该用户发布的信息和评论将从你的列表中隐藏。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认屏蔽'),
            ),
          ],
        ),
      );
      if (approved != true) return;
    }
    try {
      await widget.gateway.blockLostFoundUser(userId, reason: reason);
      if (!mounted) return;
      _showMessage('已屏蔽该用户');
      _changed = true;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) _showMessage('屏蔽失败：$error');
    }
  }

  Future<bool> _ensureAuthenticated(String message) async {
    if (widget.authenticated) return true;
    await widget.requestLogin?.call(message);
    return false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _DetailAction { edit, markFound, delete, report, block }

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.redAccent : lostFoundText;
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: lostFoundCardDecoration(radius: 12).copyWith(color: color),
      child: child,
    );
  }
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    required this.onReport,
    this.onBlock,
    this.reply = false,
  });

  final LostFoundComment comment;
  final int? currentUserId;
  final VoidCallback onReply;
  final VoidCallback onReport;
  final VoidCallback? onBlock;
  final bool reply;

  @override
  Widget build(BuildContext context) {
    final ownComment = currentUserId != null && currentUserId == comment.userId;
    final avatar = resolveAssetUrl(comment.user?.avatarUrl);
    return Container(
      margin: EdgeInsets.only(left: reply ? 38 : 0, bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: reply ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEF2F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: LostFoundNetworkImage(url: avatar),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.user?.displayName ?? '匿名用户',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      formatLostFoundTime(comment.createdAt),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const _HeroBadge(
                label: '留言',
                background: lostFoundBlueSoft,
                foreground: lostFoundBlue,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            comment.content,
            style: const TextStyle(height: 1.5, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 2,
            children: [
              TextButton.icon(
                onPressed: onReply,
                icon: const Icon(Icons.reply_rounded, size: 15),
                label: const Text('回复'),
              ),
              if (!ownComment)
                TextButton.icon(
                  onPressed: onReport,
                  icon: const Icon(Icons.flag_outlined, size: 15),
                  label: const Text('举报'),
                ),
              if (!ownComment && onBlock != null)
                TextButton.icon(
                  onPressed: onBlock,
                  icon: const Icon(Icons.block_rounded, size: 15),
                  label: const Text('屏蔽'),
                ),
            ],
          ),
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 2),
            ...comment.replies.map(
              (child) => _CommentItem(
                comment: child,
                currentUserId: currentUserId,
                onReply: onReply,
                onReport: onReport,
                onBlock: onBlock,
                reply: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class LostFoundImageViewerPage extends StatefulWidget {
  const LostFoundImageViewerPage({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  final List<String> images;
  final int initialIndex;

  @override
  State<LostFoundImageViewerPage> createState() =>
      _LostFoundImageViewerPageState();
}

class _LostFoundImageViewerPageState extends State<LostFoundImageViewerPage> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
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
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1}/${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Center(
            child: Image.network(
              resolveAssetUrl(widget.images[index]),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 44,
                  ),
                  SizedBox(height: 8),
                  Text('图片无法加载', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportResult {
  const _ReportResult({required this.reason, required this.description});

  final LostFoundReportReason reason;
  final String description;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.title});

  final String title;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _descriptionController = TextEditingController();
  LostFoundReportReason _reason = LostFoundReportReason.harassment;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '举报内容',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: lostFoundTextSecondary),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: LostFoundReportReason.values
                  .map((reason) {
                    return ChoiceChip(
                      label: Text(reason.label),
                      selected: reason == _reason,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _reason = reason),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: '补充说明（选填）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      key: const ValueKey('lost-found-report-cancel'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: lostFoundTextSecondary,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      key: const ValueKey('lost-found-report-submit'),
                      style: FilledButton.styleFrom(
                        backgroundColor: lostFoundBlue,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(
                        context,
                        _ReportResult(
                          reason: _reason,
                          description: _descriptionController.text.trim(),
                        ),
                      ),
                      icon: const Icon(Icons.flag_rounded),
                      label: const Text('提交举报'),
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

String _formatDateTime(DateTime? value) {
  if (value == null) return '-';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}
