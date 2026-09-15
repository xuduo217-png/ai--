import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

import '../../../core/navigation/app_route_observer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_permission_dialog.dart';
import '../domain/friend_media_content.dart';
import '../domain/friend_messaging_models.dart';
import 'friend_chat_controller.dart';
import 'friend_voice_controller.dart';
import 'friend_voice_gateways.dart';
import 'pages/friend_chat_media_viewer_page.dart';
import 'widgets/conversation_tile.dart';
import 'widgets/friend_message_bubble.dart';
import 'widgets/friend_recording_overlay.dart';

const _friendChatHeaderBackgroundColor = Color(0xFFDEE9FF);

enum _FriendChatMenuAction { block, unblock, delete, remark }

typedef _MessageSignature = ({
  String content,
  DateTime createdAt,
  String messageType,
  int receiverId,
  int senderId,
});

class FriendChatPage extends StatefulWidget {
  const FriendChatPage({super.key, required this.controller});

  final FriendChatController controller;

  @override
  State<FriendChatPage> createState() => _FriendChatPageState();
}

class _FriendChatPageState extends State<FriendChatPage>
    with WidgetsBindingObserver, RouteAware {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _reverseMessages = false;
  bool _scrollToLatestScheduled = false;
  _MessageSignature? _knownLatestMessage;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_handleControllerChanged);
    widget.controller.voiceController.addListener(_handleVoiceChanged);
    _scrollController.addListener(_handleScroll);
    _knownLatestMessage = _latestMessageSignature(widget.controller.messages);
    unawaited(widget.controller.initialize());
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
  void didPush() => widget.controller.setRouteVisible(true);

  @override
  void didPopNext() => widget.controller.setRouteVisible(true);

  @override
  void didPushNext() => widget.controller.setRouteVisible(false);

  @override
  void didPop() => widget.controller.setRouteVisible(false);

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChanged);
    widget.controller.voiceController.removeListener(_handleVoiceChanged);
    widget.controller.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    final latestMessage = _latestMessageSignature(widget.controller.messages);
    final shouldFollowLatest =
        latestMessage != null && latestMessage != _knownLatestMessage;
    _knownLatestMessage = latestMessage;
    setState(() {});
    if (shouldFollowLatest) _scheduleScrollToLatestMessage();
    final notice = widget.controller.takeNotice();
    _showNotice(notice);
  }

  void _handleVoiceChanged() {
    if (!mounted) return;
    _showNotice(widget.controller.takeVoiceNotice());
  }

  void _showNotice(String? notice) {
    if (notice == null || notice.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(notice)));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(widget.controller.stopVoiceActivity());
    }
  }

  @override
  void didChangeMetrics() => _scheduleScrollToLatestMessage();

  void _handleScroll() {
    if (!_reverseMessages || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 80) {
      unawaited(widget.controller.loadOlder());
    }
  }

  @override
  Widget build(BuildContext context) {
    final friend = widget.controller.friend;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        backgroundColor: _friendChatHeaderBackgroundColor,
        surfaceTintColor: _friendChatHeaderBackgroundColor,
        foregroundColor: AppColors.ink,
        titleSpacing: 0,
        title: Row(
          children: [
            FriendAvatar(
              name: friend.displayName,
              imageUrl: friend.friendAvatar,
              radius: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                friend.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: _buildAppBarActions(),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) => _buildMessages(),
              ),
            ),
            if (widget.controller.canSendMessage)
              AnimatedBuilder(
                animation: widget.controller.voiceController,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FriendRecordingOverlay(
                      controller: widget.controller.voiceController,
                      onCancel: () =>
                          unawaited(widget.controller.cancelVoiceRecording()),
                    ),
                    _MessageComposer(
                      controller: _inputController,
                      focusNode: _inputFocusNode,
                      recording: widget.controller.voiceController.isRecording,
                      onSend: _send,
                      onMedia: _chooseMedia,
                      onCamera: _captureMedia,
                      onVoiceStart: () => unawaited(_beginVoiceRecording()),
                      onVoiceStop: () =>
                          unawaited(widget.controller.finishVoiceRecording()),
                      onVoiceCancel: () =>
                          unawaited(widget.controller.cancelVoiceRecording()),
                    ),
                  ],
                ),
              )
            else
              _ChatUnavailableBanner(
                loading: widget.controller.relationshipLoading,
                message: widget.controller.unavailableMessage,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    final controller = widget.controller;
    if (!controller.supportsRelationshipActions) return const [];
    if (!controller.relationshipReady) {
      return const [
        IconButton(
          tooltip: '好友操作加载中',
          onPressed: null,
          icon: Icon(Icons.more_vert_rounded),
        ),
      ];
    }
    if (!controller.isFriend && !controller.blockedByMe) return const [];
    return [
      PopupMenuButton<_FriendChatMenuAction>(
        key: const ValueKey('friend-chat-actions'),
        tooltip: '好友操作',
        enabled: !controller.operationInProgress,
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: (action) => unawaited(_handleMenuAction(action)),
        itemBuilder: (context) => [
          if (controller.blockedByMe)
            const PopupMenuItem(
              value: _FriendChatMenuAction.unblock,
              child: _MenuItem(
                icon: Icons.person_add_alt_rounded,
                label: '解除拉黑',
              ),
            )
          else if (controller.isFriend)
            const PopupMenuItem(
              value: _FriendChatMenuAction.block,
              child: _MenuItem(icon: Icons.block_rounded, label: '拉黑'),
            ),
          if (controller.isFriend)
            const PopupMenuItem(
              value: _FriendChatMenuAction.remark,
              child: _MenuItem(icon: Icons.edit_outlined, label: '修改备注'),
            ),
          if (controller.isFriend)
            const PopupMenuItem(
              value: _FriendChatMenuAction.delete,
              child: _MenuItem(
                icon: Icons.person_remove_outlined,
                label: '删除好友',
                destructive: true,
              ),
            ),
        ],
      ),
    ];
  }

  Future<void> _handleMenuAction(_FriendChatMenuAction action) async {
    switch (action) {
      case _FriendChatMenuAction.block:
        await _confirmBlock();
        return;
      case _FriendChatMenuAction.unblock:
        final success = await widget.controller.unblockFriendChat();
        if (success && mounted) _showNotice('已解除拉黑');
        return;
      case _FriendChatMenuAction.delete:
        await _confirmDelete();
        return;
      case _FriendChatMenuAction.remark:
        await _editRemark();
        return;
    }
  }

  Future<void> _confirmBlock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: const AppDialogIcon.danger(icon: Icons.block_rounded),
        title: const Text('拉黑好友'),
        content: Text(
          '拉黑 ${widget.controller.friend.displayName} 后，双方都无法发送好友消息。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('拉黑'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await widget.controller.blockFriendChat();
    if (success && mounted) _showNotice('已拉黑该好友');
  }

  Future<void> _confirmDelete() async {
    final friend = widget.controller.friend;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: const AppDialogIcon.danger(icon: Icons.person_remove_rounded),
        title: const Text('删除好友'),
        content: Text('确定要删除 ${friend.displayName} 吗？相关本地会话和消息也会被清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await widget.controller.deleteFriend();
    if (success && mounted) Navigator.of(context).pop();
  }

  Future<void> _editRemark() async {
    var value = widget.controller.friend.remark ?? '';
    String? validationMessage;
    final remark = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialog(
          icon: const AppDialogIcon(icon: Icons.edit_note_rounded),
          title: const Text('修改备注'),
          content: TextFormField(
            key: const ValueKey('friend-chat-remark-field'),
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
    if (remark == null || !mounted) return;
    final success = await widget.controller.updateRemark(remark);
    if (success && mounted) _showNotice('备注修改成功');
  }

  Widget _buildMessages() {
    final controller = widget.controller;
    if (controller.loading && controller.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.messages.isEmpty) {
      return const Center(
        child: Text(
          '暂无消息',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
        ),
      );
    }
    final messages = _reverseMessages
        ? controller.messages.reversed.toList(growable: false)
        : controller.messages;
    _scheduleMessageLayoutCheck();
    return ListView.builder(
      key: const ValueKey('friend-chat-message-list'),
      controller: _scrollController,
      reverse: _reverseMessages,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: messages.length + (controller.loadingOlder ? 1 : 0),
      itemBuilder: (context, index) {
        final loadingIndex = _reverseMessages ? messages.length : 0;
        if (controller.loadingOlder && index == loadingIndex) {
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
        final messageIndex = !_reverseMessages && controller.loadingOlder
            ? index - 1
            : index;
        final message = messages[messageIndex];
        return FriendMessageBubble(
          key: ValueKey('friend-message-${message.localKey}'),
          message: message,
          isMine: message.senderId == controller.currentUserId,
          avatarName: message.senderId == controller.currentUserId
              ? '我'
              : controller.friend.displayName,
          avatarUrl: message.senderId == controller.currentUserId
              ? controller.currentUserAvatar
              : controller.friend.friendAvatar,
          onRetry: () => unawaited(controller.retry(message)),
          onMediaTap: _openMediaViewer,
          onVoiceTap: message.messageType == 'voice'
              ? () => unawaited(controller.toggleVoicePlayback(message))
              : null,
          voicePlayback: message.messageType == 'voice'
              ? controller.voiceController.playbackFor(message.localKey)
              : null,
          onLongPress: controller.canRevoke(message)
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
    if (action == 'revoke' && mounted) {
      await widget.controller.revoke(message);
    }
  }

  void _openMediaViewer(FriendMessage selectedMessage) {
    final items = widget.controller.messages
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

  void _scheduleMessageLayoutCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final shouldReverse = _scrollController.position.maxScrollExtent > 0;
      if (shouldReverse == _reverseMessages) return;
      setState(() => _reverseMessages = shouldReverse);
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
      if (shouldReverse != _reverseMessages) {
        setState(() => _reverseMessages = shouldReverse);
        _scheduleScrollToLatestMessage();
        return;
      }
      final target = _reverseMessages
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

  void _send() {
    final value = _inputController.text.trim();
    if (value.isEmpty) return;
    _inputController.clear();
    setState(() {});
    unawaited(widget.controller.sendText(value));
    _scheduleScrollToLatestMessage();
  }

  Future<void> _chooseMedia() async {
    final drafts = await widget.controller.pickMedia(context: context);
    if (drafts.isNotEmpty && mounted) await _sendMediaDrafts(drafts);
  }

  Future<void> _captureMedia() async {
    final draft = await widget.controller.captureMedia(context: context);
    if (draft != null && mounted) await _sendMediaDrafts([draft]);
  }

  Future<void> _sendMediaDrafts(List<FriendMediaSendRequest> drafts) async {
    for (final draft in drafts) {
      await widget.controller.sendMedia(draft);
    }
  }

  Future<void> _beginVoiceRecording() async {
    _inputFocusNode.unfocus();
    final outcome = await widget.controller.beginVoiceRecording();
    if (!mounted) return;
    switch (outcome) {
      case FriendVoiceStartOutcome.needsRationale:
        if (defaultTargetPlatform != TargetPlatform.android) {
          await _requestVoicePermission();
          break;
        }
        final accepted = await showAppPermissionDialog(
          context: context,
          icon: Icons.mic_none_rounded,
          title: '需要麦克风权限',
          description: '录制语音需要使用麦克风，用于在好友聊天中发送语音消息。',
          assurances: const ['只在按住录音时访问麦克风', '不会在后台录音'],
          confirmText: '允许使用麦克风',
          cancelText: '暂不录音',
          confirmButtonKey: const ValueKey(
            'friend-microphone-permission-confirm',
          ),
          cancelButtonKey: const ValueKey(
            'friend-microphone-permission-cancel',
          ),
        );
        if (accepted && mounted) await _requestVoicePermission();
        break;
      case FriendVoiceStartOutcome.needsPermissionRequest:
        await _requestVoicePermission();
        break;
      case FriendVoiceStartOutcome.permanentlyDenied:
        await _showVoiceSettingsDialog();
        break;
      case FriendVoiceStartOutcome.started:
      case FriendVoiceStartOutcome.ignored:
        break;
    }
  }

  Future<void> _requestVoicePermission() async {
    final status = await widget.controller.requestVoicePermission();
    if (!mounted) return;
    if (status == FriendMicrophonePermissionStatus.permanentlyDenied) {
      await _showVoiceSettingsDialog();
    }
  }

  Future<void> _showVoiceSettingsDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: const AppDialogIcon(icon: Icons.mic_off_rounded),
        title: const Text('需要麦克风权限'),
        content: const Text('请在系统设置中开启麦克风权限后，再次按住录音。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(widget.controller.openVoiceSettings());
            },
            child: const Text('前往设置'),
          ),
        ],
      ),
    );
  }
}

class _MessageComposer extends StatefulWidget {
  const _MessageComposer({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onMedia,
    required this.onCamera,
    required this.recording,
    required this.onVoiceStart,
    required this.onVoiceStop,
    required this.onVoiceCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onMedia;
  final VoidCallback onCamera;
  final bool recording;
  final VoidCallback onVoiceStart;
  final VoidCallback onVoiceStop;
  final VoidCallback onVoiceCancel;

  @override
  State<_MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<_MessageComposer> {
  bool _showMediaPanel = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    widget.focusNode.removeListener(_handleFocusChanged);
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _handleFocusChanged() {
    if (widget.focusNode.hasFocus && _showMediaPanel && mounted) {
      setState(() => _showMediaPanel = false);
    }
  }

  void _runMediaAction(VoidCallback action) {
    setState(() => _showMediaPanel = false);
    action();
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
            padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Listener(
                  key: const ValueKey('friend-chat-voice-button'),
                  onPointerDown: (_) => widget.onVoiceStart(),
                  onPointerUp: (_) => widget.onVoiceStop(),
                  onPointerCancel: (_) => widget.onVoiceCancel(),
                  child: IconButton(
                    tooltip: '按住录音',
                    onPressed: () {},
                    icon: Icon(
                      widget.recording ? Icons.mic : Icons.mic_none_rounded,
                      color: widget.recording ? const Color(0xFFE5484D) : null,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('friend-chat-media-toggle'),
                  tooltip: '更多',
                  onPressed: () {
                    widget.focusNode.unfocus();
                    setState(() => _showMediaPanel = !_showMediaPanel);
                  },
                  icon: Icon(
                    _showMediaPanel ? Icons.close : Icons.add_circle_outline,
                  ),
                ),
                Expanded(
                  child: TextField(
                    key: const ValueKey('friend-chat-input'),
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: '输入消息',
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  key: const ValueKey('friend-chat-send'),
                  tooltip: '发送',
                  onPressed: canSend ? widget.onSend : null,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
          if (_showMediaPanel)
            SizedBox(
              key: const ValueKey('friend-chat-media-panel'),
              height: 96,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  _MediaAction(
                    icon: Icons.perm_media_outlined,
                    label: '图片/视频',
                    onTap: () => _runMediaAction(widget.onMedia),
                  ),
                  const SizedBox(width: 24),
                  _MediaAction(
                    icon: Icons.photo_camera_outlined,
                    label: '相机',
                    onTap: () => _runMediaAction(widget.onCamera),
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 30, color: const Color(0xFF4F6FD8)),
              const SizedBox(height: 5),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final color = destructive ? AppColors.accent : null;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _ChatUnavailableBanner extends StatelessWidget {
  const _ChatUnavailableBanner({required this.loading, required this.message});

  final bool loading;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppColors.muted,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
