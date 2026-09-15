import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/navigation/app_route_observer.dart';
import '../../../core/network/asset_url_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../friends/domain/friend_media_content.dart';
import '../../friends/domain/friend_messaging_models.dart';
import '../../friends/presentation/friend_media_controller.dart';
import '../../friends/presentation/friend_voice_controller.dart';
import '../../friends/presentation/friend_voice_gateways.dart';
import '../../friends/presentation/pages/friend_chat_media_viewer_page.dart';
import '../../friends/presentation/widgets/conversation_tile.dart';
import '../../friends/presentation/widgets/friend_message_bubble.dart';
import '../../friends/presentation/widgets/friend_recording_overlay.dart';
import '../domain/marketplace_chat_models.dart';
import 'marketplace_chat_controller.dart';

typedef _MessageSignature = ({
  String content,
  DateTime createdAt,
  String messageType,
  int receiverId,
  int senderId,
});

typedef MarketplaceProductTap = Future<void> Function(int productId);

class MarketplaceChatPage extends StatefulWidget {
  const MarketplaceChatPage({
    super.key,
    required this.controller,
    required this.conversation,
    this.mediaController,
    this.onProductTap,
  });

  final MarketplaceChatController controller;
  final MarketplaceConversation conversation;
  final FriendMediaController? mediaController;
  final MarketplaceProductTap? onProductTap;

  @override
  State<MarketplaceChatPage> createState() => _MarketplaceChatPageState();
}

class _MarketplaceChatPageState extends State<MarketplaceChatPage>
    with WidgetsBindingObserver, RouteAware {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  late final FriendMediaController _mediaController;
  late final FriendVoiceController _voiceController;
  List<FriendMessage> _messages = const [];
  bool _loading = true;
  bool _loadingOlder = false;
  bool _hasMore = true;
  int _nextPage = 2;
  bool _reverse = false;
  bool _scrollToLatestScheduled = false;
  _MessageSignature? _knownLatestMessage;
  bool _routeVisible = true;
  bool _showPrivateTradeReminder = false;
  Timer? _privateTradeReminderTimer;
  ModalRoute<dynamic>? _route;
  late MarketplaceConversation _conversation;

  MarketplaceConversation get conversation => _conversation;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _mediaController = widget.mediaController ?? FriendMediaController();
    _showPrivateTradeReminder = conversation.role.toLowerCase() == 'buyer';
    if (_showPrivateTradeReminder) {
      _privateTradeReminderTimer = Timer(
        const Duration(seconds: 10),
        _dismissPrivateTradeReminder,
      );
    }
    WidgetsBinding.instance.addObserver(this);
    _voiceController = FriendVoiceController(
      onSend: (request) => widget.controller.sendVoice(conversation, request),
    );
    widget.controller.addListener(_refreshMessages);
    _voiceController.addListener(_refreshVoice);
    _scrollController.addListener(_handleScroll);
    unawaited(_initialize());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (identical(route, _route)) return;
    if (_route != null) appRouteObserver.unsubscribe(this);
    _route = route;
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void didPush() => _setRouteVisible(true);

  @override
  void didPopNext() => _setRouteVisible(true);

  @override
  void didPushNext() => _setRouteVisible(false);

  @override
  void didPop() => _setRouteVisible(false);

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_refreshMessages);
    _voiceController.removeListener(_refreshVoice);
    _voiceController.dispose();
    _inputController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _privateTradeReminderTimer?.cancel();
    widget.controller.clearActiveConversation(conversation.conversationId);
    super.dispose();
  }

  Future<void> _initialize() async {
    if (_routeVisible) {
      await widget.controller.setActiveConversation(conversation);
    }
    await _reloadMessages();
    try {
      final refreshed = await widget.controller.refreshConversation(
        conversation.conversationId,
      );
      if (mounted) {
        setState(() => _conversation = refreshed);
        if (_routeVisible) {
          await widget.controller.setActiveConversation(refreshed);
        }
      }
    } on Object {
      // Cached conversation data keeps chat usable while refresh is unavailable.
    }
    try {
      await widget.controller.syncConversation(conversation, page: 1);
      _hasMore = true;
      _nextPage = 2;
      await _reloadMessages();
    } on Object catch (error) {
      _showNotice('$error');
    } finally {
      if (!_routeVisible) {
        widget.controller.clearActiveConversation(conversation.conversationId);
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setRouteVisible(bool visible) {
    if (_routeVisible == visible) return;
    _routeVisible = visible;
    if (visible) {
      unawaited(widget.controller.setActiveConversation(conversation));
    } else {
      widget.controller.clearActiveConversation(conversation.conversationId);
    }
  }

  Future<void> _reloadMessages() async {
    final messages = await widget.controller.loadMessages(
      conversation.conversationId,
      limit: 50 * _nextPage,
    );
    if (!mounted) return;
    final latestMessage = _latestMessageSignature(messages);
    final shouldFollowLatest =
        latestMessage != null && latestMessage != _knownLatestMessage;
    _knownLatestMessage = latestMessage;
    setState(() => _messages = messages);
    if (shouldFollowLatest) _scheduleScrollToLatestMessage();
  }

  void _refreshMessages() {
    if (!mounted) return;
    unawaited(_reloadMessages());
  }

  void _refreshVoice() {
    if (mounted) setState(() {});
    final notice = _voiceController.takeNotice();
    if (notice != null) _showNotice(notice);
  }

  @override
  void didChangeMetrics() => _scheduleScrollToLatestMessage();

  void _handleScroll() {
    if (!_reverse ||
        !_scrollController.hasClients ||
        _loadingOlder ||
        !_hasMore) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 80) {
      unawaited(_loadOlder());
    }
  }

  Future<void> _loadOlder() async {
    _loadingOlder = true;
    if (mounted) setState(() {});
    try {
      await widget.controller.syncConversation(conversation, page: _nextPage);
      _nextPage += 1;
      _hasMore =
          (await widget.controller.messageCount(conversation.conversationId)) >
          _messages.length;
      await _reloadMessages();
    } on Object catch (error) {
      _showNotice('$error');
    } finally {
      _loadingOlder = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE7F1FF),
        surfaceTintColor: const Color(0xFFE7F1FF),
        foregroundColor: AppColors.ink,
        titleSpacing: 0,
        title: Row(
          children: [
            FriendAvatar(
              name: conversation.peer.nickname,
              imageUrl: conversation.peer.avatar,
              radius: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                conversation.peer.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: '会话设置',
            onSelected: _handleAction,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('举报消息')),
              PopupMenuItem(value: 'block', child: Text('屏蔽对方')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                _ProductContext(
                  product: conversation.product,
                  onTap: widget.onProductTap,
                ),
                Expanded(child: _buildMessages()),
                FriendRecordingOverlay(
                  controller: _voiceController,
                  onCancel: () => unawaited(_voiceController.cancelHold()),
                ),
                _Composer(
                  controller: _inputController,
                  focusNode: _focusNode,
                  recording: _voiceController.isRecording,
                  onSend: _sendText,
                  onMedia: () => unawaited(_chooseMedia()),
                  onCamera: () => unawaited(_captureMedia()),
                  onVoiceStart: () => unawaited(_beginVoice()),
                  onVoiceStop: () => unawaited(_voiceController.finishHold()),
                  onVoiceCancel: () => unawaited(_voiceController.cancelHold()),
                ),
              ],
            ),
            if (_showPrivateTradeReminder)
              Positioned(
                key: const ValueKey('marketplace-private-trade-reminder'),
                top: 8,
                left: 12,
                right: 12,
                child: _PrivateTradeReminder(
                  onClose: _dismissPrivateTradeReminder,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text('暂无消息', style: TextStyle(color: Color(0xFF9CA3AF))),
      );
    }
    _scheduleLayoutCheck();
    final messages = _reverse ? _messages.reversed.toList() : _messages;
    return ListView.builder(
      key: const ValueKey('marketplace-chat-message-list'),
      controller: _scrollController,
      reverse: _reverse,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: messages.length + (_loadingOlder ? 1 : 0),
      itemBuilder: (_, index) {
        if (_loadingOlder && index == (_reverse ? messages.length : 0)) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final messageIndex = !_reverse && _loadingOlder ? index - 1 : index;
        final message = messages[messageIndex];
        return FriendMessageBubble(
          key: ValueKey('marketplace-message-${message.localKey}'),
          message: message,
          isMine: message.senderId == widget.controller.ownerUserId,
          avatarName: message.senderId == widget.controller.ownerUserId
              ? '我'
              : conversation.peer.nickname,
          avatarUrl: message.senderId == widget.controller.ownerUserId
              ? widget.controller.currentUserAvatar
              : conversation.peer.avatar,
          onRetry: () =>
              unawaited(widget.controller.retry(conversation, message)),
          onMediaTap: _openMediaViewer,
          onVoiceTap: message.messageType == 'voice'
              ? () => unawaited(
                  _voiceController.togglePlayback(
                    message,
                    isMine: message.senderId == widget.controller.ownerUserId,
                  ),
                )
              : null,
          voicePlayback: message.messageType == 'voice'
              ? _voiceController.playbackFor(message.localKey)
              : null,
          onLongPress: widget.controller.canRevoke(message)
              ? () => unawaited(_showMessageActions(message))
              : null,
        );
      },
    );
  }

  Future<void> _showMessageActions(FriendMessage message) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.undo_rounded),
          title: const Text('撤回'),
          onTap: () => Navigator.pop(sheetContext, 'revoke'),
        ),
      ),
    );
    if (action != 'revoke' || !mounted) return;
    try {
      await _voiceController.stopAll();
      await widget.controller.revokeMessage(conversation, message);
      _showNotice('消息已撤回');
    } on Object catch (error) {
      _showNotice('$error');
    }
  }

  void _openMediaViewer(FriendMessage selectedMessage) {
    final items = _messages
        .map(FriendChatMediaItem.fromMessage)
        .whereType<FriendChatMediaItem>()
        .toList(growable: false);
    final initialIndex = items.indexWhere(
      (item) => item.message.localKey == selectedMessage.localKey,
    );
    if (initialIndex < 0) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            FriendChatMediaViewerPage(items: items, initialIndex: initialIndex),
      ),
    );
  }

  void _scheduleLayoutCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final shouldReverse = _scrollController.position.maxScrollExtent > 0;
      if (shouldReverse == _reverse) return;
      setState(() => _reverse = shouldReverse);
      _scheduleScrollToLatestMessage();
    });
  }

  void _scheduleScrollToLatestMessage() {
    if (_scrollToLatestScheduled) return;
    _scrollToLatestScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToLatestScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final shouldReverse = position.maxScrollExtent > 0;
      if (shouldReverse != _reverse) {
        setState(() => _reverse = shouldReverse);
        _scheduleScrollToLatestMessage();
        return;
      }
      final target = _reverse
          ? position.minScrollExtent
          : position.maxScrollExtent;
      if ((target - position.pixels).abs() < 1) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scrollController.jumpTo(target);
        return;
      }
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  _MessageSignature? _latestMessageSignature(List<FriendMessage> messages) {
    if (messages.isEmpty) return null;
    final message = messages.last;
    return (
      content: message.content,
      createdAt: message.createdAt,
      messageType: message.messageType,
      receiverId: message.receiverId,
      senderId: message.senderId,
    );
  }

  void _sendText() {
    final value = _inputController.text.trim();
    if (value.isEmpty) return;
    _inputController.clear();
    setState(() {});
    unawaited(widget.controller.sendText(conversation, value));
    _scheduleScrollToLatestMessage();
  }

  Future<void> _chooseMedia() async {
    try {
      final drafts = await _mediaController.pickMedia(context: context);
      if (drafts.isNotEmpty && mounted) await _sendDrafts(drafts);
    } on Object {
      if (mounted) _showNotice('无法选择图片或视频');
    }
  }

  Future<void> _captureMedia() async {
    try {
      final draft = await _mediaController.captureMedia(context: context);
      if (draft != null && mounted) await _sendDrafts([draft]);
    } on Object {
      if (mounted) _showNotice('无法访问系统相机');
    }
  }

  Future<void> _sendDrafts(List<FriendMediaSendRequest> drafts) async {
    for (final draft in drafts) {
      await widget.controller.sendMedia(conversation, draft);
    }
  }

  Future<void> _beginVoice() async {
    _focusNode.unfocus();
    final outcome = await _voiceController.beginHold();
    if (!mounted) return;
    if (outcome == FriendVoiceStartOutcome.needsPermissionRequest ||
        outcome == FriendVoiceStartOutcome.needsRationale) {
      final status = await _voiceController.requestPermission();
      if (status == FriendMicrophonePermissionStatus.permanentlyDenied) {
        await _voiceController.openSettings();
      }
    } else if (outcome == FriendVoiceStartOutcome.permanentlyDenied) {
      await _voiceController.openSettings();
    }
  }

  Future<void> _handleAction(String action) async {
    if (action == 'block') {
      await widget.controller.blockPeer(conversation);
      if (mounted) Navigator.pop(context);
      return;
    }
    final message = _messages.isEmpty ? null : _messages.last;
    if (message == null) return;
    await widget.controller.reportMessage(message);
    if (mounted) _showNotice('已提交举报');
  }

  void _showNotice(String notice) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(notice.replaceFirst('Exception: ', ''))),
      );
  }

  void _dismissPrivateTradeReminder() {
    _privateTradeReminderTimer?.cancel();
    _privateTradeReminderTimer = null;
    if (!mounted || !_showPrivateTradeReminder) return;
    setState(() => _showPrivateTradeReminder = false);
  }
}

class _PrivateTradeReminder extends StatelessWidget {
  const _PrivateTradeReminder({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF8E1),
      elevation: 5,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFF2D58A)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.shield_outlined,
                size: 18,
                color: Color(0xFFB7791F),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '安全提醒：请勿私下转账或交易，不要点击陌生链接或提供验证码等敏感信息。',
                style: TextStyle(
                  color: Color(0xFF7A5414),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('marketplace-private-trade-reminder-close'),
              tooltip: '关闭提醒',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: onClose,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Color(0xFF8B6B2E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductContext extends StatelessWidget {
  const _ProductContext({required this.product, this.onTap});

  final MarketplaceProductSnapshot product;
  final MarketplaceProductTap? onTap;

  bool get _canOpen =>
      onTap != null &&
      product.id > 0 &&
      (product.isSold || (product.isActive && product.price != null));

  String get _statusText {
    if (product.isSold) return '已售出';
    if (!product.isActive) return '已下架';
    if (product.price == null) return '商品已不可见';
    return '¥${product.price!.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        key: const ValueKey('marketplace-product-context'),
        onTap: _canOpen ? () => unawaited(onTap!(product.id)) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              _ProductImage(url: product.image),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusText,
                      style: TextStyle(
                        color:
                            product.isSold ||
                                !product.isActive ||
                                product.price == null
                            ? Colors.grey
                            : const Color(0xFFE05B54),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (_canOpen)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9CA3AF),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.url});
  final String? url;
  @override
  Widget build(BuildContext context) {
    final value = resolveAssetUrl(url ?? '');
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: value.startsWith('http')
          ? Image.network(
              value,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() => Container(
    width: 48,
    height: 48,
    color: const Color(0xFFF1F5F9),
    child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8)),
  );
}

class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.recording,
    required this.onSend,
    required this.onMedia,
    required this.onCamera,
    required this.onVoiceStart,
    required this.onVoiceStop,
    required this.onVoiceCancel,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool recording;
  final VoidCallback onSend;
  final VoidCallback onMedia;
  final VoidCallback onCamera;
  final VoidCallback onVoiceStart;
  final VoidCallback onVoiceStop;
  final VoidCallback onVoiceCancel;
  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  bool _more = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    widget.focusNode.addListener(_focusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    widget.focusNode.removeListener(_focusChanged);
    super.dispose();
  }

  void _refresh() => setState(() {});
  void _focusChanged() {
    if (widget.focusNode.hasFocus && _more) setState(() => _more = false);
  }

  @override
  Widget build(BuildContext context) {
    final canSend = widget.controller.text.trim().isNotEmpty;
    return Material(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Listener(
                  onPointerDown: (_) => widget.onVoiceStart(),
                  onPointerUp: (_) => widget.onVoiceStop(),
                  onPointerCancel: (_) => widget.onVoiceCancel(),
                  child: IconButton(
                    tooltip: '按住录音',
                    onPressed: () {},
                    icon: Icon(
                      widget.recording ? Icons.mic : Icons.mic_none_rounded,
                      color: widget.recording ? Colors.red : null,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('marketplace-chat-media-toggle'),
                  tooltip: '更多',
                  onPressed: () {
                    widget.focusNode.unfocus();
                    setState(() => _more = !_more);
                  },
                  icon: Icon(_more ? Icons.close : Icons.add_circle_outline),
                ),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    decoration: const InputDecoration(
                      hintText: '请输入文字',
                      counterText: '',
                      filled: true,
                      fillColor: Color(0xFFF3F4F6),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  tooltip: '发送',
                  onPressed: canSend ? widget.onSend : null,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
          if (_more)
            SizedBox(
              height: 88,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  _MediaAction(
                    icon: Icons.perm_media_outlined,
                    label: '图片/视频',
                    onTap: widget.onMedia,
                  ),
                  const SizedBox(width: 24),
                  _MediaAction(
                    icon: Icons.photo_camera_outlined,
                    label: '相机',
                    onTap: widget.onCamera,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaAction extends StatelessWidget {
  const _MediaAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 64,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 30, color: const Color(0xFF4F6FD8)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}
