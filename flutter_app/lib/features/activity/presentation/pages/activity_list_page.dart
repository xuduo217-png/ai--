import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/activity_models.dart';
import '../activity_controller.dart';
import '../activity_design.dart';
import '../activity_widgets.dart';
import 'activity_detail_page.dart';

typedef ActivityLoginRequester = Future<bool> Function(String message);

class ActivityListPage extends StatefulWidget {
  const ActivityListPage({
    super.key,
    required this.gateway,
    required this.authenticated,
    required this.requestLogin,
    this.currentUserId,
    this.initialPhone = '',
  });

  final ActivityGateway gateway;
  final bool authenticated;
  final ActivityLoginRequester requestLogin;
  final int? currentUserId;
  final String initialPhone;

  @override
  State<ActivityListPage> createState() => _ActivityListPageState();
}

class _ActivityListPageState extends State<ActivityListPage> {
  late final ActivityListController _controller;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = ActivityListController(
      gateway: widget.gateway,
      authenticated: widget.authenticated,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searchVisible = !_searchVisible);
    if (_searchVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
      return;
    }
    _searchController.clear();
    _searchFocus.unfocus();
    unawaited(_controller.search(''));
  }

  Future<void> _openActivity(ActivityItem activity) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ActivityDetailPage(
          gateway: widget.gateway,
          activityId: activity.id,
          authenticated: widget.authenticated,
          requestLogin: widget.requestLogin,
          currentUserId: widget.currentUserId,
          initialPhone: widget.initialPhone,
        ),
      ),
    );
    if (mounted) await _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ActivityGradientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _searchVisible
                    ? _ActivitySearchBar(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        onSubmitted: _controller.search,
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        key: const ValueKey('activity-list-header'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              _ActivityHeaderAction(
                key: const ValueKey('activity-back'),
                tooltip: '返回',
                icon: Icons.arrow_back_ios_new_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: _ActivityStatusTabs(
                      selected: _controller.selectedStatus,
                      onSelected: (status) =>
                          unawaited(_controller.selectStatus(status)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _ActivityHeaderAction(
                key: const ValueKey('activity-search-toggle'),
                tooltip: _searchVisible ? '关闭搜索' : '搜索活动',
                icon: _searchVisible
                    ? Icons.close_rounded
                    : Icons.search_rounded,
                onPressed: _toggleSearch,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.loading && _controller.activities.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: activityPrimary),
      );
    }
    if (_controller.error != null && _controller.activities.isEmpty) {
      return _ActivityListNotice(
        icon: Icons.cloud_off_rounded,
        message: _controller.error!,
        actionLabel: '重新加载',
        onAction: _controller.retry,
      );
    }
    if (_controller.activities.isEmpty) {
      return _ActivityListNotice(
        icon: Icons.event_busy_rounded,
        message: _controller.searchKeyword.isEmpty ? '暂无活动' : '没有找到相关活动',
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 360) {
          unawaited(_controller.loadMore());
        }
        return false;
      },
      child: RefreshIndicator(
        color: activityPrimary,
        onRefresh: _controller.refresh,
        child: ListView.builder(
          key: const ValueKey('activity-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            activityDesignPx(context, 24),
            activityDesignPx(context, 12),
            activityDesignPx(context, 24),
            activityDesignPx(context, 28) +
                MediaQuery.paddingOf(context).bottom,
          ),
          itemCount:
              _controller.activities.length + (_controller.loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _controller.activities.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: activityPrimary,
                    ),
                  ),
                ),
              );
            }
            final activity = _controller.activities[index];
            return ActivityCard(
              activity: activity,
              onPressed: () => _openActivity(activity),
            );
          },
        ),
      ),
    );
  }
}

class _ActivitySearchBar extends StatelessWidget {
  const _ActivitySearchBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('activity-search-bar'),
      padding: EdgeInsets.fromLTRB(
        activityDesignPx(context, 24),
        0,
        activityDesignPx(context, 24),
        activityDesignPx(context, 10),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: '搜索活动名称',
          hintStyle: const TextStyle(color: activityHint, letterSpacing: 0),
          prefixIcon: const Icon(Icons.search_rounded, color: activityHint),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '清空',
                  onPressed: () {
                    controller.clear();
                    onSubmitted('');
                  },
                  icon: const Icon(Icons.cancel_rounded, color: activityHint),
                ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ActivityStatusTabs extends StatelessWidget {
  const _ActivityStatusTabs({required this.selected, required this.onSelected});

  final ActivityStatus selected;
  final ValueChanged<ActivityStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    const statuses = [
      ActivityStatus.upcoming,
      ActivityStatus.ongoing,
      ActivityStatus.expired,
    ];
    return Container(
      key: const ValueKey('activity-status-tabs'),
      width: double.infinity,
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xD9FFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E8F2)),
      ),
      child: Row(
        children: statuses
            .map((status) {
              final active = selected == status;
              return Expanded(
                child: InkWell(
                  key: ValueKey('activity-status-${status.wireValue}'),
                  onTap: () => onSelected(status),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFE7EEFF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          status.label,
                          maxLines: 1,
                          style: TextStyle(
                            color: active
                                ? const Color(0xFF5B75E5)
                                : activityMuted,
                            fontSize: 15,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _ActivityHeaderAction extends StatelessWidget {
  const _ActivityHeaderAction({
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
        icon: Icon(icon, size: 19, color: activityInk),
      ),
    );
  }
}

class _ActivityListNotice extends StatelessWidget {
  const _ActivityListNotice({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: const Color(0xFFBCC8E5)),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: activityMuted, letterSpacing: 0),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => unawaited(onAction!()),
                style: FilledButton.styleFrom(backgroundColor: activityPrimary),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
