import 'package:flutter/material.dart';

import '../../chat/consultation_messaging_session.dart';
import '../../chat/domain/consultation_conversation.dart';
import '../../chat/presentation/consultation_conversation_list_view.dart';
import '../../friends/presentation/conversation_list_view.dart';
import '../../friends/presentation/friends_messaging_controller.dart';
import '../../friends/domain/friend_messaging_models.dart';
import '../presentation/marketplace_chat_controller.dart';
import 'marketplace_chat_page.dart';
import 'marketplace_conversation_list_view.dart';

class MessagesHubView extends StatelessWidget {
  const MessagesHubView({
    super.key,
    required this.friendsController,
    required this.marketplaceController,
    required this.consultationSession,
    required this.onOpenConsultation,
    this.onOpenFriend,
    this.onMarketplaceProductTap,
  });

  final FriendsMessagingController friendsController;
  final MarketplaceChatController marketplaceController;
  final ConsultationMessagingSession consultationSession;
  final ValueChanged<ConsultationConversation> onOpenConsultation;
  final ValueChanged<FriendshipSummary>? onOpenFriend;
  final MarketplaceProductTap? onMarketplaceProductTap;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '消息',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    _MessagesTabLabel(
                      label: '好友消息',
                      unreadCount: friendsController.totalUnreadCount,
                    ),
                    _MessagesTabLabel(
                      label: '医生咨询',
                      unreadCount: consultationSession.totalUnreadCount,
                    ),
                    _MessagesTabLabel(
                      label: '商城消息',
                      unreadCount: marketplaceController.totalUnreadCount,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ConversationListView(
                      controller: friendsController,
                      onOpenConversation: onOpenFriend,
                      showHeader: false,
                    ),
                    ConsultationConversationListView(
                      session: consultationSession,
                      onOpenConversation: onOpenConsultation,
                      showHeader: false,
                    ),
                    MarketplaceConversationListView(
                      controller: marketplaceController,
                      showHeader: false,
                      onProductTap: onMarketplaceProductTap,
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

class _MessagesTabLabel extends StatelessWidget {
  const _MessagesTabLabel({required this.label, required this.unreadCount});

  final String label;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (unreadCount > 0)
            Positioned(
              right: -14,
              top: -8,
              child: Container(
                height: 18,
                constraints: const BoxConstraints(minWidth: 18),
                width: unreadCount < 10 ? 18 : null,
                padding: unreadCount < 10
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5484D),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
