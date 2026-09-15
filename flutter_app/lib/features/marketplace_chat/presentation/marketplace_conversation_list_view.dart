import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/swipe_action_tile.dart';
import '../../friends/presentation/widgets/conversation_tile.dart';
import '../domain/marketplace_chat_models.dart';
import 'marketplace_chat_controller.dart';
import 'marketplace_chat_page.dart';

class MarketplaceConversationListView extends StatefulWidget {
  const MarketplaceConversationListView({
    super.key,
    required this.controller,
    this.showHeader = true,
    this.onProductTap,
  });

  final MarketplaceChatController controller;
  final bool showHeader;
  final MarketplaceProductTap? onProductTap;

  @override
  State<MarketplaceConversationListView> createState() =>
      _MarketplaceConversationListViewState();
}

class _MarketplaceConversationListViewState
    extends State<MarketplaceConversationListView> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

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
      unawaited(widget.controller.loadMoreConversations());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          if (widget.showHeader)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '商城消息',
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
              controller: _searchController,
              onChanged: widget.controller.updateSearch,
              decoration: InputDecoration(
                hintText: '搜索商品或卖家',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        onPressed: () {
                          _searchController.clear();
                          unawaited(widget.controller.updateSearch(''));
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: const OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (_, _) => _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final controller = widget.controller;
    if (controller.loading && controller.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.errorMessage != null && controller.conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 10),
            Text(controller.errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: controller.refresh,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (controller.conversations.isEmpty) {
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(
              Icons.shopping_bag_outlined,
              size: 48,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 12),
            Center(
              child: Text('暂无商城会话', style: TextStyle(color: Color(0xFF6B7280))),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
        itemCount:
            controller.conversations.length +
            (controller.hasMoreConversations ||
                    controller.loadingMoreConversations
                ? 1
                : 0),
        itemBuilder: (_, index) {
          if (index == controller.conversations.length) {
            return _MarketplaceLoadMore(controller: controller);
          }
          final conversation = controller.conversations[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SwipeActionTile(
              key: ValueKey('marketplace-swipe-${conversation.conversationId}'),
              actionKey: ValueKey(
                'marketplace-hide-${conversation.conversationId}',
              ),
              onAction: () => controller.hideConversation(conversation),
              child: _MarketplaceConversationTile(
                conversation: conversation,
                onTap: () => _open(conversation),
              ),
            ),
          );
        },
      ),
    );
  }

  void _open(MarketplaceConversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketplaceChatPage(
          controller: widget.controller,
          conversation: conversation,
          onProductTap: widget.onProductTap,
        ),
      ),
    );
  }
}

class _MarketplaceLoadMore extends StatelessWidget {
  const _MarketplaceLoadMore({required this.controller});

  final MarketplaceChatController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.loadingMoreConversations) {
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
        key: const ValueKey('marketplace-load-more'),
        onPressed: controller.loadMoreConversations,
        child: const Text('加载更多'),
      ),
    );
  }
}

class _MarketplaceConversationTile extends StatelessWidget {
  const _MarketplaceConversationTile({
    required this.conversation,
    required this.onTap,
  });
  final MarketplaceConversation conversation;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
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
                    name: conversation.peer.nickname,
                    imageUrl: conversation.peer.avatar,
                    radius: 26,
                  ),
                  Positioned(
                    right: -3,
                    bottom: -2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F1FF),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          size: 12,
                          color: Color(0xFF4F6FD8),
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
                            conversation.peer.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
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
                    const SizedBox(height: 4),
                    Text(
                      conversation.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF4F6FD8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _preview(conversation.lastMessage),
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
                          Container(
                            height: 22,
                            constraints: const BoxConstraints(minWidth: 22),
                            width: conversation.unreadCount < 10 ? 22 : null,
                            padding: conversation.unreadCount < 10
                                ? EdgeInsets.zero
                                : const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5484D),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Text(
                              conversation.unreadCount > 99
                                  ? '99+'
                                  : '${conversation.unreadCount}',
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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

String _preview(MarketplaceLastMessage? message) {
  if (message == null) return '暂无消息';
  return switch (message.messageType) {
    'image' => '[图片]',
    'video' => '[视频]',
    'voice' => '[语音]',
    _ => message.content,
  };
}
