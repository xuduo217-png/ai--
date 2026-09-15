import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

import '../../../core/media/gallery_media_picker.dart';
import '../../../core/media/camera_media_picker.dart';
import '../../../core/media/local_chat_media.dart';
import '../../../core/navigation/app_route_observer.dart';
import '../domain/chat_models.dart';
import '../../mall/payment/presentation/payment_sheet_session.dart';
import '../../mall/payment/presentation/widgets/payment_sheet.dart';
import 'chat_controller.dart';
import 'chat_media_viewer_page.dart';
import 'chat_widgets.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.controller,
    this.onHeaderTap,
    this.galleryMediaPicker,
    this.cameraMediaPicker,
  });

  final ChatController controller;
  final VoidCallback? onHeaderTap;
  final GalleryMediaPicker? galleryMediaPicker;
  final CameraMediaPicker? cameraMediaPicker;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with WidgetsBindingObserver, RouteAware {
  late final GalleryMediaPicker _galleryMediaPicker;
  late final CameraMediaPicker _cameraMediaPicker;
  final ScrollController _messageScrollController = ScrollController();
  int _knownMessageCount = 0;
  bool _scrollToEndScheduled = false;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _galleryMediaPicker = widget.galleryMediaPicker ?? GalleryMediaPicker();
    _cameraMediaPicker = widget.cameraMediaPicker ?? CameraMediaPicker();
    WidgetsBinding.instance.addObserver(this);
    _knownMessageCount = widget.controller.messages.length;
    widget.controller.addListener(_handleControllerChanged);
    widget.controller.initialize();
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.handleAppResumed();
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChanged);
    widget.controller.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    _showControllerNotice();

    final nextMessageCount = widget.controller.messages.length;
    if (nextMessageCount <= _knownMessageCount) {
      _knownMessageCount = nextMessageCount;
      return;
    }

    _knownMessageCount = nextMessageCount;
    _scheduleScrollToMessageListEnd();
  }

  void _scheduleScrollToMessageListEnd() {
    if (_scrollToEndScheduled) return;
    _scrollToEndScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToEndScheduled = false;
      if (!mounted || !_messageScrollController.hasClients) return;
      final position = _messageScrollController.position;
      final target = position.maxScrollExtent;
      if ((target - position.pixels).abs() < 1) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _messageScrollController.jumpTo(target);
        return;
      }
      _messageScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _showControllerNotice() {
    final notice = widget.controller.takeNotice();
    if (notice == null || notice.isEmpty || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(notice)));
    });
  }

  Future<void> _pickMedia() async {
    try {
      final files = await _galleryMediaPicker.pick(
        context: context,
        mediaType: GalleryMediaType.imageAndVideo,
        allowMultiple: true,
        maxCount: maxChatMediaSelectionCount,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (files.isEmpty || !mounted) return;
      await _sendSelectedMedia(files);
    } on PlatformException catch (error) {
      _showPickerError(error);
    }
  }

  Future<void> _captureMedia() async {
    try {
      final captured = await _cameraMediaPicker.capture(
        context: context,
        allowPhoto: true,
        allowVideo: true,
        permissionDescription: '在医生咨询中拍照需要使用相机，长按录像还需要使用麦克风录制声音。',
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (captured == null) return;
      await _sendSelectedMedia([captured.file]);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法使用相机，请稍后重试')));
    }
  }

  Future<void> _sendSelectedMedia(List<XFile> files) async {
    for (final file in files) {
      await widget.controller.sendMedia(
        path: file.path,
        fileName: file.name,
        type: localChatMediaKindFor(file) == LocalChatMediaKind.video
            ? ChatMessageType.video
            : ChatMessageType.image,
      );
    }
  }

  void _showPickerError(PlatformException error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.message ?? '无法访问系统相册')));
  }

  Future<void> _confirmPurchase(ChatPackage package) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: const AppDialogIcon(icon: Icons.shopping_bag_outlined),
        title: const Text('确认购买'),
        content: Text(
          '您将购买「${package.name}」，价格 ¥${_formatPrice(package.price)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认购买'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    widget.controller.beginPurchase(package);
    final result = await showUnifiedPaymentSheet(
      context,
      session: widget.controller,
      summary: PaymentSheetSummary(
        amount: package.price,
        referenceLabel: '咨询套餐',
        referenceValue: package.name,
        timeoutMessage: '支付已超时，请稍后重新进入咨询确认状态',
      ),
    );
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(result.message)));
  }

  void _openMediaViewer(ChatMessage selectedMessage) {
    final items = widget.controller.messages
        .map(ChatMediaViewerItem.fromMessage)
        .whereType<ChatMediaViewerItem>()
        .toList(growable: false);
    final initialIndex = items.indexWhere(
      (item) => identical(item.message, selectedMessage),
    );
    if (initialIndex < 0) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            ChatMediaViewerPage(items: items, initialIndex: initialIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFFDEE9FF),
      resizeToAvoidBottomInset: false,
      body: AnimatedPadding(
        key: const ValueKey('chat-keyboard-inset'),
        onEnd: _scheduleScrollToMessageListEnd,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
            ),
          ),
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              final controller = widget.controller;
              return Column(
                children: [
                  ChatHeader(
                    target: controller.target,
                    online: controller.doctorOnline,
                    remaining: controller.remaining,
                    statusText: controller.headerStatusText,
                    statusActive: controller.headerStatusActive,
                    canExtendSession: controller.canExtendSession,
                    extendingSession: controller.extendingSession,
                    onExtendSession: controller.extendSession,
                    onTap: widget.onHeaderTap,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  Expanded(child: _buildMessages(controller)),
                  if (controller.showExpiredBanner)
                    _ExpiredSessionBanner(
                      packages: controller.availablePackages,
                      purchasing: controller.purchasing,
                      onClose: controller.dismissExpiredBanner,
                      onPurchase: _confirmPurchase,
                    ),
                  ChatComposer(
                    enabled: controller.canSend,
                    hintText: controller.inputHint,
                    sendingMedia: controller.sendingMedia,
                    bottomPadding: keyboardInset > 0
                        ? chatScale(context, 12)
                        : chatScale(context, 12) + bottomSafeInset,
                    onSendText: controller.sendText,
                    onSelectMedia: _pickMedia,
                    onTakePhoto: _captureMedia,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMessages(ChatController controller) {
    if (controller.loading && controller.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF667EEA)),
            SizedBox(height: chatScale(context, 12)),
            Text(
              '正在加载聊天...',
              style: TextStyle(
                color: chatTextHint,
                fontSize: chatScale(context, 32),
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      );
    }
    if (controller.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              color: chatTextHint,
              size: chatScale(context, 128),
            ),
            SizedBox(height: chatScale(context, 16)),
            Text(
              '暂无消息',
              style: TextStyle(
                color: chatTextHint,
                fontSize: chatScale(context, 32),
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: chatScale(context, 8)),
            Text(
              '开始你们的对话吧',
              style: TextStyle(
                color: const Color(0xFF9CA3AF),
                fontSize: chatScale(context, 28),
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: const ValueKey('chat-message-list'),
      controller: _messageScrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        chatScale(context, 16),
        chatScale(context, 8),
        chatScale(context, 16),
        chatScale(context, 8),
      ),
      itemCount: controller.messages.length,
      itemBuilder: (context, index) {
        final message = controller.messages[index];
        return ChatMessageBubble(
          key: ValueKey('chat-message-${message.id}'),
          message: message,
          currentUserId: controller.currentUserId,
          currentUserType: controller.currentUserType,
          currentUserAvatar: controller.currentUserAvatar,
          targetAvatar: controller.target.avatarUrl,
          paidSession:
              controller.isHistoryMode ||
              controller.session?.status == ChatSessionStatus.paid,
          onPurchase: _confirmPurchase,
          onImageTap: _openMediaViewer,
          onVideoTap: _openMediaViewer,
          onLongPress: controller.canRevoke(message)
              ? () => _showMessageActions(message)
              : null,
        );
      },
    );
  }

  Future<void> _showMessageActions(ChatMessage message) async {
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
      await widget.controller.revokeMessage(message);
    }
  }
}

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.enabled,
    required this.hintText,
    required this.sendingMedia,
    required this.bottomPadding,
    required this.onSendText,
    required this.onSelectMedia,
    required this.onTakePhoto,
  });

  final bool enabled;
  final String hintText;
  final bool sendingMedia;
  final double bottomPadding;
  final ValueChanged<String> onSendText;
  final VoidCallback onSelectMedia;
  final VoidCallback onTakePhoto;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showMediaPanel = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onTextChanged() => setState(() {});

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _showMediaPanel) {
      setState(() => _showMediaPanel = false);
    }
  }

  @override
  void dispose() {
    _textController
      ..removeListener(_onTextChanged)
      ..dispose();
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _send() {
    final value = _textController.text.trim();
    if (!widget.enabled || value.isEmpty) return;
    widget.onSendText(value);
    _textController.clear();
    setState(() => _showMediaPanel = false);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final canSendText =
        widget.enabled && _textController.text.trim().isNotEmpty;
    return Container(
      key: const ValueKey('chat-composer'),
      padding: EdgeInsets.fromLTRB(
        chatScale(context, 16),
        chatScale(context, 12),
        chatScale(context, 16),
        widget.bottomPadding,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showMediaPanel) ...[
            Row(
              children: [
                Expanded(
                  child: _MediaActionButton(
                    icon: Icons.perm_media_outlined,
                    label: '图片/视频',
                    onTap: widget.onSelectMedia,
                  ),
                ),
                SizedBox(width: chatScale(context, 12)),
                Expanded(
                  child: _MediaActionButton(
                    icon: Icons.photo_camera_outlined,
                    label: '相机',
                    onTap: widget.onTakePhoto,
                  ),
                ),
              ],
            ),
            SizedBox(height: chatScale(context, 12)),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: chatScale(context, 84),
                child: IconButton(
                  key: const ValueKey('chat-media-toggle'),
                  tooltip: '添加媒体',
                  onPressed: widget.enabled && !widget.sendingMedia
                      ? () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          setState(() => _showMediaPanel = !_showMediaPanel);
                        }
                      : null,
                  style: IconButton.styleFrom(
                    backgroundColor: _showMediaPanel
                        ? const Color(0xFFEFF6FF)
                        : Colors.white,
                    side: BorderSide(
                      color: _showMediaPanel
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFFD1D5DB),
                    ),
                  ),
                  icon: widget.sendingMedia
                      ? SizedBox.square(
                          dimension: chatScale(context, 34),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF3B82F6),
                          ),
                        )
                      : Icon(
                          Icons.add,
                          color: widget.enabled
                              ? (_showMediaPanel
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFF6B7280))
                              : const Color(0xFFD1D5DB),
                          size: chatScale(context, 46),
                        ),
                ),
              ),
              SizedBox(width: chatScale(context, 12)),
              Expanded(
                child: Container(
                  key: const ValueKey('chat-message-input-container'),
                  constraints: BoxConstraints(
                    minHeight: chatScale(context, 84),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.symmetric(
                    horizontal: chatScale(context, 20),
                    vertical: chatScale(context, 8),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: TextField(
                    key: const ValueKey('chat-message-input'),
                    controller: _textController,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(
                      color: widget.enabled
                          ? chatTextPrimary
                          : const Color(0xFFD1D5DB),
                      fontSize: chatScale(context, 30),
                      letterSpacing: 0,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.zero,
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        color: const Color(0xFF9CA3AF),
                        fontSize: chatScale(context, 30),
                        letterSpacing: 0,
                      ),
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
              SizedBox(width: chatScale(context, 12)),
              SizedBox.square(
                dimension: chatScale(context, 88),
                child: IconButton.filled(
                  key: const ValueKey('chat-send-button'),
                  tooltip: '发送',
                  onPressed: canSendText ? _send : null,
                  style: IconButton.styleFrom(
                    backgroundColor: canSendText
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFE5E7EB),
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        chatScale(context, 10),
                      ),
                    ),
                  ),
                  icon: Icon(
                    Icons.send_rounded,
                    color: canSendText ? Colors.white : const Color(0xFF9CA3AF),
                    size: chatScale(context, 42),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaActionButton extends StatelessWidget {
  const _MediaActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(chatScale(context, 14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(chatScale(context, 14)),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: chatScale(context, 14),
            vertical: chatScale(context, 12),
          ),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(chatScale(context, 14)),
          ),
          child: Row(
            children: [
              Container(
                width: chatScale(context, 64),
                height: chatScale(context, 64),
                decoration: const BoxDecoration(
                  color: Color(0xFFDBEAFE),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF3B82F6),
                  size: chatScale(context, 52),
                ),
              ),
              SizedBox(width: chatScale(context, 12)),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: chatTextPrimary,
                    fontSize: chatScale(context, 26),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpiredSessionBanner extends StatelessWidget {
  const _ExpiredSessionBanner({
    required this.packages,
    required this.purchasing,
    required this.onClose,
    required this.onPurchase,
  });

  final List<ChatPackage> packages;
  final bool purchasing;
  final VoidCallback onClose;
  final ValueChanged<ChatPackage> onPurchase;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFF6FF),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: const Color(0xFFDBEAFE),
            padding: EdgeInsets.symmetric(
              horizontal: chatScale(context, 16),
              vertical: chatScale(context, 10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications,
                  color: chatPrimary,
                  size: chatScale(context, 30),
                ),
                SizedBox(width: chatScale(context, 6)),
                Expanded(
                  child: Text(
                    '会话已过期，请续费继续咨询',
                    style: TextStyle(
                      color: const Color(0xFF1E40AF),
                      fontSize: chatScale(context, 22),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onClose,
                  icon: Icon(
                    Icons.close,
                    color: chatPrimary,
                    size: chatScale(context, 30),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: chatScale(context, 200),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: chatScale(context, 16),
                vertical: chatScale(context, 12),
              ),
              itemCount: packages.length,
              separatorBuilder: (_, _) =>
                  SizedBox(width: chatScale(context, 12)),
              itemBuilder: (context, index) {
                final package = packages[index];
                return ChatPackageTile(
                  package: package,
                  disabled: purchasing,
                  width: chatScale(context, 240),
                  onTap: () => onPurchase(package),
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            color: const Color(0xFFDBEAFE),
            padding: EdgeInsets.symmetric(vertical: chatScale(context, 8)),
            child: Text(
              '购买后可随时向医生咨询问题',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF1E40AF),
                fontSize: chatScale(context, 20),
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatVideoPreviewPage extends StatelessWidget {
  const ChatVideoPreviewPage({
    super.key,
    required this.localPath,
    required this.videoUrl,
  });

  final String? localPath;
  final String videoUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: ChatVideoPlayerView(
              localPath: localPath,
              videoUrl: videoUrl,
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            child: IconButton.filledTonal(
              tooltip: '关闭',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatPrice(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}
