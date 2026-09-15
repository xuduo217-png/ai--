import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/friend_messaging_models.dart';
import '../friends_feature_session.dart';
import 'friend_chat_blocks_page.dart';
import 'friend_chat_page.dart';
import 'friend_request_list_page.dart';
import 'friends_directory_controller.dart';
import 'search_user_page.dart';
import 'widgets/conversation_tile.dart';

class FriendsListView extends StatefulWidget {
  const FriendsListView({super.key, required this.session});

  final FriendsFeatureSession session;

  @override
  State<FriendsListView> createState() => _FriendsListViewState();
}

class _FriendsListViewState extends State<FriendsListView> {
  static const double _sectionHeight = 32;
  static const double _friendHeight = 72;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  FriendsDirectoryController get _controller =>
      widget.session.directoryController;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('friends-directory-background'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Column(
            children: [
              _DirectoryHeader(
                requestCount: _controller.pendingRequestCount,
                onBlacklist: _openBlacklist,
                onRequests: _openRequests,
                onAdd: _openSearch,
              ),
              _DirectorySearch(
                controller: _searchController,
                onChanged: _controller.updateSearch,
                onClear: _clearSearch,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '共 ${_controller.filteredFriends.length} 位好友',
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              if (_controller.errorMessage != null &&
                  _controller.friends.isNotEmpty)
                _DirectoryError(
                  message: _controller.errorMessage!,
                  onRetry: _controller.refresh,
                ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.loading && _controller.friends.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('加载中...', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      );
    }
    if (_controller.errorMessage != null && _controller.friends.isEmpty) {
      return _DirectoryEmpty(
        icon: Icons.cloud_off_outlined,
        title: _controller.errorMessage!,
        subtitle: '请检查网络后重新加载',
        actionLabel: '重试',
        onAction: _controller.refresh,
      );
    }
    final sections = _controller.sections;
    if (sections.isEmpty) {
      return RefreshIndicator(
        onRefresh: _controller.refresh,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            _DirectoryEmpty(
              icon: _controller.search.trim().isEmpty
                  ? Icons.people_outline
                  : Icons.search_off,
              title: _controller.search.trim().isEmpty ? '暂无好友' : '未找到相关好友',
              subtitle: _controller.search.trim().isEmpty
                  ? '点击右上角添加好友'
                  : '尝试其他搜索关键词',
            ),
          ],
        ),
      );
    }
    final rows = _rowsFor(sections);
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _controller.refresh,
          child: ListView.builder(
            key: const ValueKey('friends-directory-list'),
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: rows.length,
            itemExtentBuilder: (index, _) =>
                rows[index] is _SectionRow ? _sectionHeight : _friendHeight,
            itemBuilder: (context, index) {
              return switch (rows[index]) {
                final _SectionRow row => _SectionHeader(letter: row.letter),
                final _FriendRow row => _FriendTile(
                  friend: row.friend,
                  onTap: () => _openChat(row.friend),
                  onLongPress: () => _showFriendActions(row.friend),
                ),
              };
            },
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: _AlphabetIndex(
              letters: sections.map((section) => section.letter).toList(),
              onSelected: (letter) => _jumpToLetter(letter, sections),
            ),
          ),
        ),
      ],
    );
  }

  List<_DirectoryRow> _rowsFor(List<FriendDirectorySection> sections) {
    return [
      for (final section in sections) ...[
        _SectionRow(section.letter),
        for (final friend in section.friends) _FriendRow(friend),
      ],
    ];
  }

  void _jumpToLetter(String letter, List<FriendDirectorySection> sections) {
    var offset = 0.0;
    for (final section in sections) {
      if (section.letter == letter) break;
      offset += _sectionHeight + section.friends.length * _friendHeight;
    }
    if (!_scrollController.hasClients) return;
    final bounded = offset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    unawaited(
      _scrollController.animateTo(
        bounded,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    _controller.updateSearch('');
  }

  Future<void> _openRequests() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FriendRequestListPage(
          controller: widget.session.createFriendRequestsController(),
        ),
      ),
    );
    await _controller.refreshAfterRequestChanged(accepted: true);
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SearchUserPage(
          controller: widget.session.createFriendSearchController(),
        ),
      ),
    );
    await _controller.refresh();
  }

  Future<void> _openChat(FriendshipSummary friend) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FriendChatPage(
          controller: widget.session.createFriendChatController(friend),
        ),
      ),
    );
    await _controller.refresh();
  }

  Future<void> _openBlacklist() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FriendChatBlocksPage(
          controller: widget.session.createFriendChatBlocksController(),
        ),
      ),
    );
  }

  Future<void> _showFriendActions(FriendshipSummary friend) async {
    HapticFeedback.mediumImpact();
    final action = await showModalBottomSheet<_FriendAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: FriendAvatar(
                name: friend.displayName,
                imageUrl: friend.friendAvatar,
                radius: 22,
              ),
              title: Text(
                friend.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('修改备注'),
              onTap: () => Navigator.pop(context, _FriendAction.remark),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.accent,
              ),
              title: const Text(
                '删除好友',
                style: TextStyle(color: AppColors.accent),
              ),
              onTap: () => Navigator.pop(context, _FriendAction.delete),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _FriendAction.remark) {
      await _editRemark(friend);
    } else {
      await _confirmDelete(friend);
    }
  }

  Future<void> _editRemark(FriendshipSummary friend) async {
    var value = friend.remark ?? '';
    String? validationMessage;
    final remark = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialog(
          icon: const AppDialogIcon(icon: Icons.edit_note_rounded),
          title: const Text('修改备注'),
          content: TextFormField(
            key: const ValueKey('friend-remark-field'),
            initialValue: value,
            autofocus: true,
            maxLength: 100,
            onChanged: (nextValue) => value = nextValue,
            decoration: InputDecoration(
              hintText: '请输入备注名',
              errorText: validationMessage,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final remark = value.trim();
                if (remark.isEmpty) {
                  setDialogState(() => validationMessage = '备注名不能为空');
                  return;
                }
                Navigator.pop(dialogContext, remark);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || remark == null) return;
    try {
      await _controller.updateRemark(friend, remark);
      if (!mounted) return;
      _showNotice('备注修改成功');
    } on Object catch (error) {
      if (!mounted) return;
      _showNotice(_readableError(error, '备注修改失败'));
    }
  }

  Future<void> _confirmDelete(FriendshipSummary friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: const AppDialogIcon.danger(icon: Icons.person_remove_rounded),
        title: const Text('删除好友'),
        content: Text('确定要删除 ${friend.displayName} 吗？相关本地会话和消息也会被清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _controller.deleteFriend(friend);
      if (!mounted) return;
      _showNotice('好友已删除');
    } on Object catch (error) {
      if (!mounted) return;
      _showNotice(_readableError(error, '删除好友失败'));
    }
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DirectoryHeader extends StatelessWidget {
  const _DirectoryHeader({
    required this.requestCount,
    required this.onBlacklist,
    required this.onRequests,
    required this.onAdd,
  });

  final int requestCount;
  final VoidCallback onBlacklist;
  final VoidCallback onRequests;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('friend-directory-header'),
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 348;
            return Stack(
              children: [
                Positioned.fill(
                  right: compact ? 144 : 0,
                  child: Align(
                    alignment: compact
                        ? Alignment.centerLeft
                        : Alignment.center,
                    child: const Text(
                      '通讯录',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 144,
                    child: Row(
                      children: [
                        IconButton(
                          key: const ValueKey('friend-chat-blocks-entry'),
                          tooltip: '黑名单',
                          onPressed: onBlacklist,
                          icon: const Icon(
                            Icons.person_off_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              key: const ValueKey('friend-requests-entry'),
                              tooltip: '好友申请',
                              onPressed: onRequests,
                              icon: const Icon(
                                Icons.mark_email_unread_outlined,
                                color: AppColors.primary,
                              ),
                            ),
                            if (requestCount > 0)
                              Positioned(
                                top: 1,
                                right: -3,
                                child: _RequestBadge(count: requestCount),
                              ),
                          ],
                        ),
                        IconButton(
                          key: const ValueKey('friend-add-entry'),
                          tooltip: '添加好友',
                          onPressed: onAdd,
                          icon: const Icon(
                            Icons.person_add_alt_1_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RequestBadge extends StatelessWidget {
  const _RequestBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      constraints: const BoxConstraints(minWidth: 18),
      width: count < 10 ? 18 : null,
      padding: count < 10
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DirectorySearch extends StatefulWidget {
  const _DirectorySearch({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_DirectorySearch> createState() => _DirectorySearchState();
}

class _DirectorySearchState extends State<_DirectorySearch> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }

  void _handleTextChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: SizedBox(
        height: 44,
        child: TextField(
          key: const ValueKey('friend-directory-search-field'),
          controller: widget.controller,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: '搜索好友',
            prefixIcon: const Icon(Icons.search, size: 21),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            suffixIcon: widget.controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: '清空',
                    onPressed: widget.onClear,
                    icon: const Icon(Icons.cancel_outlined, size: 20),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: ValueKey('friend-directory-section-$letter'),
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            letter,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.onTap,
    required this.onLongPress,
  });

  final FriendshipSummary friend;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('friend-directory-${friend.friendId}'),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              FriendAvatar(
                name: friend.displayName,
                imageUrl: friend.friendAvatar,
                radius: 23,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      friend.friendSignature?.trim().isNotEmpty == true
                          ? friend.friendSignature!
                          : '暂无个性签名',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFFD1D5DB),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlphabetIndex extends StatelessWidget {
  const _AlphabetIndex({required this.letters, required this.onSelected});

  final List<String> letters;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('friends-directory-alphabet-index'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final letter in letters)
          SizedBox(
            width: 26,
            height: 19,
            child: IconButton(
              tooltip: '跳转到 $letter',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 26, height: 19),
              onPressed: () => onSelected(letter),
              icon: Text(
                letter,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DirectoryError extends StatelessWidget {
  const _DirectoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF7ED),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.error_outline, color: Color(0xFFEA580C)),
        title: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: TextButton(onPressed: onRetry, child: const Text('重试')),
      ),
    );
  }
}

class _DirectoryEmpty extends StatelessWidget {
  const _DirectoryEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: const Color(0xFFD1D5DB)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9CA3AF)),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

sealed class _DirectoryRow {
  const _DirectoryRow();
}

class _SectionRow extends _DirectoryRow {
  const _SectionRow(this.letter);

  final String letter;
}

class _FriendRow extends _DirectoryRow {
  const _FriendRow(this.friend);

  final FriendshipSummary friend;
}

enum _FriendAction { remark, delete }

String _readableError(Object error, String fallback) {
  final text = error.toString().trim();
  if (text.isEmpty) return fallback;
  return text
      .replaceFirst('Exception: ', '')
      .replaceFirst('Invalid argument(s): ', '')
      .replaceFirst('Bad state: ', '');
}
