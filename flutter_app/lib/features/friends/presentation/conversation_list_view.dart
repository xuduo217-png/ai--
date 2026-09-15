import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pet_hospital_flutter/core/widgets/swipe_action_tile.dart';

import '../domain/friend_messaging_models.dart';
import 'friend_chat_controller.dart';
import 'friend_chat_page.dart';
import 'friends_messaging_controller.dart';
import 'widgets/conversation_tile.dart';

class ConversationListView extends StatefulWidget {
  const ConversationListView({
    super.key,
    required this.controller,
    this.onOpenConversation,
    this.showHeader = true,
  });

  final FriendsMessagingController controller;
  final ValueChanged<FriendshipSummary>? onOpenConversation;
  final bool showHeader;

  @override
  State<ConversationListView> createState() => _ConversationListViewState();
}

class _ConversationListViewState extends State<ConversationListView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('conversation-background'),
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
                    '好友消息',
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
                key: const ValueKey('conversation-search-field'),
                controller: _searchController,
                onChanged: widget.controller.updateSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '搜索会话',
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
                animation: widget.controller,
                builder: (context, _) => _buildContent(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final controller = widget.controller;
    if (controller.loading && controller.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.errorMessage != null && controller.conversations.isEmpty) {
      return _MessageState(
        icon: Icons.cloud_off_rounded,
        message: controller.errorMessage!,
        actionLabel: '重试',
        onAction: controller.refresh,
      );
    }
    if (controller.conversations.isEmpty) {
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          key: const ValueKey('conversation-empty-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            Text(
              controller.search.isEmpty ? '暂无会话' : '没有匹配的会话',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF4F6FD8),
      onRefresh: controller.refresh,
      child: ListView.builder(
        key: const ValueKey('conversation-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
        itemCount: controller.conversations.length,
        itemBuilder: (context, index) {
          final conversation = controller.conversations[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SwipeActionTile(
              key: ValueKey('dismiss-${conversation.conversationId}'),
              actionKey: ValueKey(
                'hide-conversation-${conversation.conversationId}',
              ),
              onAction: () => controller.hideConversation(conversation),
              child: ConversationTile(
                conversation: conversation,
                onTap: () => _openConversation(conversation),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openConversation(FriendConversation conversation) {
    final friend = widget.controller.friendForConversation(conversation);
    final externalHandler = widget.onOpenConversation;
    if (externalHandler != null) {
      externalHandler(friend);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FriendChatPage(
          controller: FriendChatController(
            messagingController: widget.controller,
            friend: friend,
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
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
