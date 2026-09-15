import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/network/asset_url_resolver.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../domain/lost_found_models.dart';
import '../lost_found_controller.dart';
import '../lost_found_design.dart';
import 'lost_found_detail_page.dart';
import 'lost_found_editor_page.dart';

typedef LostFoundLoginRequest = Future<bool> Function(String message);

class LostFoundListPage extends StatefulWidget {
  const LostFoundListPage({
    super.key,
    required this.gateway,
    required this.authenticated,
    this.currentUserId,
    this.requestLogin,
    this.publisherId,
    this.title = '走失领养',
  });

  final LostFoundGateway gateway;
  final bool authenticated;
  final int? currentUserId;
  final LostFoundLoginRequest? requestLogin;
  final int? publisherId;
  final String title;

  @override
  State<LostFoundListPage> createState() => _LostFoundListPageState();
}

class _LostFoundListPageState extends State<LostFoundListPage> {
  static const double _headerExtent = 56;

  late final LostFoundListController _controller;

  bool get _managingOwnRecords =>
      widget.authenticated &&
      widget.currentUserId != null &&
      widget.publisherId == widget.currentUserId;

  @override
  void initState() {
    super.initState();
    _controller = LostFoundListController(
      gateway: widget.gateway,
      authenticated: widget.authenticated,
      publisherId: widget.publisherId,
    );
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
      backgroundColor: Colors.transparent,
      body: LostFoundGradientBackground(
        child: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Stack(
              children: [
                Positioned.fill(child: _buildBody()),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _Header(
                    title: widget.title,
                    recordType: _controller.recordType,
                    onBack: () => Navigator.of(context).pop(),
                    onTypeChanged: _controller.selectType,
                    onPublish: _openEditor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final recordsEmpty = _controller.records.isEmpty;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 360) {
          unawaited(_controller.loadMore());
        }
        return false;
      },
      child: RefreshIndicator(
        key: const ValueKey('lost-found-refresh'),
        color: lostFoundBlue,
        edgeOffset: _headerExtent,
        onRefresh: _controller.refresh,
        child: CustomScrollView(
          key: const ValueKey('lost-found-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: SizedBox(
                key: ValueKey('lost-found-scroll-header-spacer'),
                height: _headerExtent,
              ),
            ),
            if (_controller.loading && recordsEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: lostFoundBlue),
                ),
              )
            else if (_controller.error != null && recordsEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _LostFoundState(
                  icon: Icons.cloud_off_rounded,
                  title: '加载失败',
                  message: _controller.error!,
                  actionLabel: '重新加载',
                  onAction: _controller.refresh,
                ),
              )
            else if (recordsEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _LostFoundState(
                  icon: _controller.recordType == LostFoundRecordType.lost
                      ? Icons.search_rounded
                      : Icons.home_outlined,
                  title: _controller.recordType == LostFoundRecordType.lost
                      ? '暂时没有走失信息'
                      : '暂时没有领养信息',
                  message: '下拉刷新看看，或发布一条新信息。',
                  actionLabel: '立即发布',
                  onAction: _openEditor,
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  lostFoundPx(context, 16),
                  8,
                  lostFoundPx(context, 16),
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _MasonryGrid(
                    records: _controller.records,
                    onOpen: _openDetail,
                    onEdit: _managingOwnRecords ? _openRecordEditor : null,
                    onDelete: _managingOwnRecords ? _confirmDelete : null,
                  ),
                ),
              ),
            if (_controller.loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (!recordsEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  key: const ValueKey('lost-found-scroll-bottom-spacer'),
                  height: MediaQuery.paddingOf(context).bottom + 28,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor() async {
    if (!widget.authenticated) {
      await widget.requestLogin?.call('登录后即可发布走失或领养信息');
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => LostFoundEditorPage(
          gateway: widget.gateway,
          initialType: _controller.recordType,
        ),
      ),
    );
    if (changed == true) await _controller.refresh();
  }

  Future<void> _openDetail(LostFoundRecord record) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => LostFoundDetailPage(
          gateway: widget.gateway,
          initialRecord: record,
          authenticated: widget.authenticated,
          currentUserId: widget.currentUserId,
          requestLogin: widget.requestLogin,
        ),
      ),
    );
    if (changed == true) await _controller.refresh();
  }

  Future<void> _openRecordEditor(LostFoundRecord record) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            LostFoundEditorPage(gateway: widget.gateway, initialRecord: record),
      ),
    );
    if (changed == true) await _controller.refresh();
  }

  Future<void> _confirmDelete(LostFoundRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: const AppDialogIcon.danger(icon: Icons.delete_outline_rounded),
        title: const Text('删除信息'),
        content: Text('确认删除“${record.title}”吗？删除后无法恢复。'),
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
      await widget.gateway.deleteLostFoundRecord(record.id);
      await _controller.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('删除成功')));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('删除失败：$error')));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.recordType,
    required this.onBack,
    required this.onTypeChanged,
    required this.onPublish,
  });

  final String title;
  final LostFoundRecordType recordType;
  final VoidCallback onBack;
  final ValueChanged<LostFoundRecordType> onTypeChanged;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('lost-found-header'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            SizedBox(
              width: 76,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _RoundIconButton(
                  tooltip: '返回',
                  icon: Icons.arrow_back_ios_new_rounded,
                  onPressed: onBack,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Semantics(
                    label: title,
                    child: Container(
                      key: const ValueKey('lost-found-tabs'),
                      width: double.infinity,
                      height: 44,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xD9FFFFFF),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE3E8F2)),
                      ),
                      child: Row(
                        children: LostFoundRecordType.values
                            .map((type) {
                              final active = type == recordType;
                              return Expanded(
                                child: InkWell(
                                  key: ValueKey(
                                    'lost-found-tab-${type.wireValue}',
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => onTypeChanged(type),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? const Color(0xFFE7EEFF)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      type.label,
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: active
                                            ? const Color(0xFF5B75E5)
                                            : lostFoundTextSecondary,
                                        fontSize: 15,
                                        fontWeight: active
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 76,
              child: Align(
                alignment: Alignment.centerRight,
                child: Tooltip(
                  message: '发布信息',
                  child: FilledButton(
                    key: const ValueKey('lost-found-publish-button'),
                    onPressed: onPublish,
                    style: FilledButton.styleFrom(
                      backgroundColor: lostFoundBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(72, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: const StadiumBorder(),
                      elevation: 2,
                      shadowColor: const Color(0x332563EB),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '发布',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
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
      color: const Color(0xE6FFFFFF),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 19, color: lostFoundText),
      ),
    );
  }
}

class _MasonryGrid extends StatelessWidget {
  const _MasonryGrid({
    required this.records,
    required this.onOpen,
    this.onEdit,
    this.onDelete,
  });

  final List<LostFoundRecord> records;
  final ValueChanged<LostFoundRecord> onOpen;
  final ValueChanged<LostFoundRecord>? onEdit;
  final ValueChanged<LostFoundRecord>? onDelete;

  @override
  Widget build(BuildContext context) {
    final columns = <List<LostFoundRecord>>[[], []];
    final heights = <double>[0, 0];
    for (final record in records) {
      final column = heights[0] <= heights[1] ? 0 : 1;
      columns[column].add(record);
      heights[column] += _estimatedHeight(record);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < 2; index++) ...[
          Expanded(
            child: Column(
              children: columns[index]
                  .map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LostFoundRecordCard(
                        record: record,
                        onPressed: () => onOpen(record),
                        onEdit: onEdit == null ? null : () => onEdit!(record),
                        onDelete: onDelete == null
                            ? null
                            : () => onDelete!(record),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          if (index == 0) const SizedBox(width: 8),
        ],
      ],
    );
  }

  double _estimatedHeight(LostFoundRecord record) {
    final ratios = [0.78, 1.02, 0.84, 1.16, 0.9, 1.08];
    final ratio = ratios[record.id.abs() % ratios.length];
    return 180 / ratio + math.min(record.description.length, 60) * 0.6;
  }
}

class LostFoundRecordCard extends StatefulWidget {
  const LostFoundRecordCard({
    super.key,
    required this.record,
    required this.onPressed,
    this.onEdit,
    this.onDelete,
  });

  final LostFoundRecord record;
  final VoidCallback onPressed;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<LostFoundRecordCard> createState() => _LostFoundRecordCardState();
}

class _LostFoundRecordCardState extends State<LostFoundRecordCard> {
  static const _fallbackRatios = [0.78, 1.02, 0.84, 1.16, 0.9, 1.08];
  ImageStream? _stream;
  ImageStreamListener? _listener;
  late double _coverRatio;

  @override
  void initState() {
    super.initState();
    _coverRatio = _fallbackRatio;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveRatio();
  }

  @override
  void didUpdateWidget(covariant LostFoundRecordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.coverUrl != widget.record.coverUrl) {
      _coverRatio = _fallbackRatio;
      _resolveRatio();
    }
  }

  double get _fallbackRatio {
    return _fallbackRatios[widget.record.id.abs() % _fallbackRatios.length];
  }

  void _resolveRatio() {
    final url = resolveAssetUrl(widget.record.coverUrl);
    _removeListener();
    if (url.isEmpty) return;
    final stream = NetworkImage(
      url,
    ).resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((image, _) {
      final ratio = (image.image.width / math.max(image.image.height, 1))
          .clamp(0.72, 1.26)
          .toDouble();
      if (mounted && ratio != _coverRatio) setState(() => _coverRatio = ratio);
    });
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void _removeListener() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _listener = null;
    _stream = null;
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final coverUrl = resolveAssetUrl(record.coverUrl);
    final statusColor = record.recordType == LostFoundRecordType.adoption
        ? const Color(0xFF2563EB)
        : record.isFound
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: lostFoundCardDecoration(radius: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: _coverRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (coverUrl.isEmpty)
                        _CardCoverPlaceholder(
                          label:
                              record.recordType == LostFoundRecordType.adoption
                              ? '等待新家出现'
                              : '等待更多线索',
                        )
                      else
                        LostFoundNetworkImage(url: coverUrl),
                      Positioned(
                        top: 7,
                        left: 7,
                        right: 7,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (record.isPinned)
                              _CardBadge(
                                icon: Icons.push_pin_rounded,
                                label: '置顶',
                                color: const Color(0xFFF59E0B),
                              ),
                            const Spacer(),
                            _CardBadge(
                              label: record.statusLabel,
                              color: statusColor,
                            ),
                          ],
                        ),
                      ),
                      if (record.videoUrl.isNotEmpty ||
                          record.images.isNotEmpty)
                        Positioned(
                          left: 7,
                          bottom: 7,
                          child: _CardBadge(
                            icon: record.videoUrl.isNotEmpty
                                ? Icons.videocam_rounded
                                : Icons.photo_library_rounded,
                            label: record.videoUrl.isNotEmpty
                                ? '视频'
                                : record.images.length > 1
                                ? '${record.images.length}张图'
                                : '图片',
                            color: const Color(0xA6000000),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: lostFoundText,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (record.breedLabel.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          record.breedLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: lostFoundBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        record.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: lostFoundTextSecondary,
                          height: 1.45,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_rounded,
                            size: 14,
                            color: lostFoundTextSecondary,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              record.contactName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: lostFoundTextSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Text(
                            formatLostFoundTime(record.createdAt),
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      if (widget.onEdit != null || widget.onDelete != null) ...[
                        const Divider(height: 18, color: lostFoundBorder),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                key: ValueKey('lost-found-edit-${record.id}'),
                                onPressed: widget.onEdit,
                                style: TextButton.styleFrom(
                                  foregroundColor: lostFoundBlue,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 6,
                                  ),
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('编辑'),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: TextButton.icon(
                                key: ValueKey('lost-found-delete-${record.id}'),
                                onPressed: widget.onDelete,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 6,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                ),
                                label: const Text('删除'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBadge extends StatelessWidget {
  const _CardBadge({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardCoverPlaceholder extends StatelessWidget {
  const _CardCoverPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF7E97FA),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pets_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LostFoundState extends StatelessWidget {
  const _LostFoundState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: lostFoundBlue),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: lostFoundText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: lostFoundTextSecondary),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
