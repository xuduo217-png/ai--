import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/swipe_action_tile.dart';
import '../../friends/presentation/widgets/conversation_tile.dart';
import '../consultation_messaging_session.dart';
import '../domain/chat_models.dart';
import '../domain/consultation_conversation.dart';

class ConsultationConversationListView extends StatefulWidget {
  const ConsultationConversationListView({
    super.key,
    required this.session,
    required this.onOpenConversation,
    this.showHeader = true,
  });

  final ConsultationMessagingSession session;
  final ValueChanged<ConsultationConversation> onOpenConversation;
  final bool showHeader;

  @override
  State<ConsultationConversationListView> createState() =>
      _ConsultationConversationListViewState();
}

class _ConsultationConversationListViewState
    extends State<ConsultationConversationListView> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 240) {
      unawaited(widget.session.loadMoreConversations());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (widget.showHeader)
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 14, 18, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '医生咨询',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  key: const ValueKey('consultation-conversation-search'),
                  controller: _searchController,
                  onChanged: (value) => setState(() => _search = value.trim()),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '搜索医生或消息',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空搜索',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: widget.session,
                  builder: (_, _) => _buildContent(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final session = widget.session;
    final query = _search.toLowerCase();
    final conversations = session.conversations
        .where((conversation) {
          if (query.isEmpty) return true;
          return conversation.doctorName.toLowerCase().contains(query) ||
              (conversation.lastMessage?.preview.toLowerCase().contains(
                    query,
                  ) ??
                  false);
        })
        .toList(growable: false);

    if (session.loadingConversations && session.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (session.conversationError != null && session.conversations.isEmpty) {
      return _ConsultationMessageState(
        icon: Icons.cloud_off_rounded,
        message: '咨询消息加载失败，请稍后重试',
        actionLabel: '重试',
        onAction: session.refresh,
      );
    }
    if (conversations.isEmpty && !session.hasMoreConversations) {
      return RefreshIndicator(
        onRefresh: session.refresh,
        child: ListView(
          key: const ValueKey('consultation-conversation-empty'),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
            const Icon(
              Icons.medical_services_outlined,
              size: 48,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            Text(
              query.isEmpty ? '暂无医生咨询' : '没有匹配的咨询会话',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF4F6FD8),
      onRefresh: session.refresh,
      child: ListView.builder(
        controller: _scrollController,
        key: const ValueKey('consultation-conversation-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
        itemCount:
            conversations.length +
            (session.hasMoreConversations ||
                    session.loadingMoreConversations ||
                    session.loadMoreError != null
                ? 1
                : 0),
        itemBuilder: (_, index) {
          if (index == conversations.length) {
            return _ConsultationLoadMore(session: session);
          }
          final conversation = conversations[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SwipeActionTile(
              key: ValueKey(
                'consultation-swipe-${conversation.conversationId}',
              ),
              actionKey: ValueKey(
                'consultation-hide-${conversation.conversationId}',
              ),
              onAction: () => session.hideConversation(conversation),
              child: _ConsultationConversationTile(
                conversation: conversation,
                onTap: () => widget.onOpenConversation(conversation),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConsultationLoadMore extends StatelessWidget {
  const _ConsultationLoadMore({required this.session});

  final ConsultationMessagingSession session;

  @override
  Widget build(BuildContext context) {
    if (session.loadingMoreConversations) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Center(
      child: TextButton(
        key: const ValueKey('consultation-load-more'),
        onPressed: session.loadMoreConversations,
        child: Text(session.loadMoreError == null ? '加载更多' : '重试加载'),
      ),
    );
  }
}

class _ConsultationConversationTile extends StatelessWidget {
  const _ConsultationConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final ConsultationConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: ValueKey(
          'consultation-conversation-${conversation.conversationId}',
        ),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  FriendAvatar(
                    name: conversation.doctorName,
                    imageUrl: conversation.doctorAvatarUrl,
                    radius: 26,
                  ),
                  Positioned(
                    right: -3,
                    bottom: -2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F6EF),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(
                          Icons.medical_services_outlined,
                          size: 12,
                          color: Color(0xFF278B62),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.doctorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatConversationTime(conversation.sortTime),
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _ConsultationStatus(status: conversation.status),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            conversation.lastMessage?.preview ??
                                (conversation.paymentRequired
                                    ? '需要购买咨询服务'
                                    : '暂无消息'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (conversation.unreadCount > 0) ...[
                          const SizedBox(width: 10),
                          _ConsultationUnreadBadge(
                            count: conversation.unreadCount,
                          ),
                        ],
                      ],
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

class _ConsultationStatus extends StatelessWidget {
  const _ConsultationStatus({required this.status});

  final ChatSessionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, foreground, background) = switch (status) {
      ChatSessionStatus.paid => (
        '服务中',
        const Color(0xFF18794E),
        const Color(0xFFE8F6EF),
      ),
      ChatSessionStatus.expired => (
        '已结束',
        const Color(0xFF6B7280),
        const Color(0xFFF1F3F5),
      ),
      ChatSessionStatus.free => (
        '免费咨询',
        const Color(0xFF3D5DB5),
        const Color(0xFFE8EEFF),
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ConsultationUnreadBadge extends StatelessWidget {
  const _ConsultationUnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      constraints: const BoxConstraints(minWidth: 22),
      width: count < 10 ? 22 : null,
      padding: count < 10
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE5484D),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConsultationMessageState extends StatelessWidget {
  const _ConsultationMessageState({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF9CA3AF), size: 46),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => unawaited(onAction()),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
