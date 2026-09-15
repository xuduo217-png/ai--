import 'package:flutter/material.dart';

import '../../chat/domain/chat_models.dart';
import '../../chat/presentation/chat_page.dart';
import '../../chat/presentation/chat_widgets.dart';
import '../../pets/presentation/pages/pet_page_chrome.dart';
import '../domain/doctor_portal_models.dart';

const _historyPrimary = petPrimaryColor;
const _historyText = petTextPrimaryColor;
const _historyMuted = petTextSecondaryColor;
const _historyPrimarySoft = Color(0x197E97FA);
const _historyCardShadow = [
  BoxShadow(color: Color(0x14000000), offset: Offset(0, 1), blurRadius: 2),
];

class DoctorConsultationHistoryPage extends StatefulWidget {
  const DoctorConsultationHistoryPage({
    super.key,
    required this.gateway,
    required this.consultation,
    this.currentDoctorAvatarUrl = '',
  });

  final DoctorPortalGateway gateway;
  final DoctorConsultation consultation;
  final String currentDoctorAvatarUrl;

  @override
  State<DoctorConsultationHistoryPage> createState() =>
      _DoctorConsultationHistoryPageState();
}

class _DoctorConsultationHistoryPageState
    extends State<DoctorConsultationHistoryPage> {
  final List<DoctorHistorySession> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 0;
  int _totalPages = 0;

  bool get _hasMore => _page < _totalPages;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  Future<void> _load({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final nextPage = refresh ? 1 : _page + 1;
      final result = await widget.gateway.loadPatientHistory(
        conversationId: widget.consultation.conversationId,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) _items.clear();
        final knownIds = _items.map((item) => item.id).toSet();
        _items.addAll(result.items.where((item) => knownIds.add(item.id)));
        _page = result.page;
        _totalPages = result.totalPages;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PetGradientBackground(
      key: const ValueKey('patient-history-background'),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              PetPageHeader(
                title: '历史咨询',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _historyPrimary),
      );
    }
    if (_items.isEmpty) {
      return _HistoryMessage(
        icon: _error == null ? Icons.history : Icons.error_outline,
        message: _error == null ? '暂无历史咨询' : '历史咨询加载失败',
        actionLabel: _error == null ? null : '重试',
        onAction: _error == null ? null : () => _load(refresh: true),
      );
    }

    return RefreshIndicator(
      color: _historyPrimary,
      onRefresh: () => _load(refresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return Center(
              child: TextButton.icon(
                key: const ValueKey('patient-history-load-more'),
                onPressed: _loadingMore ? null : () => _load(refresh: false),
                icon: _loadingMore
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _historyPrimary,
                        ),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(_loadingMore ? '加载中' : '查看更多'),
              ),
            );
          }
          final item = _items[index];
          return _HistorySessionTile(
            item: item,
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => DoctorConsultationHistoryDetailPage(
                  gateway: widget.gateway,
                  consultation: widget.consultation,
                  history: item,
                  currentDoctorAvatarUrl: widget.currentDoctorAvatarUrl,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class DoctorConsultationHistoryDetailPage extends StatefulWidget {
  const DoctorConsultationHistoryDetailPage({
    super.key,
    required this.gateway,
    required this.consultation,
    required this.history,
    this.currentDoctorAvatarUrl = '',
  });

  final DoctorPortalGateway gateway;
  final DoctorConsultation consultation;
  final DoctorHistorySession history;
  final String currentDoctorAvatarUrl;

  @override
  State<DoctorConsultationHistoryDetailPage> createState() =>
      _DoctorConsultationHistoryDetailPageState();
}

class _DoctorConsultationHistoryDetailPageState
    extends State<DoctorConsultationHistoryDetailPage> {
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _loadingOlder = false;
  String? _error;
  int _page = 0;
  int _totalPages = 0;

  bool get _hasOlder => _page < _totalPages;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _loadPage(1);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(result.items);
        _page = result.page;
        _totalPages = result.totalPages;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<DoctorHistoryMessagePage> _loadPage(int page) {
    return widget.gateway.loadPatientHistoryMessages(
      conversationId: widget.consultation.conversationId,
      historyConversationId: widget.history.conversationId,
      page: page,
    );
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasOlder) return;
    setState(() => _loadingOlder = true);
    final previousExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final previousOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    try {
      final result = await _loadPage(_page + 1);
      if (!mounted) return;
      setState(() {
        final knownIds = _messages.map((message) => message.id).toSet();
        _messages.insertAll(
          0,
          result.items.where((message) => knownIds.add(message.id)),
        );
        _page = result.page;
        _totalPages = result.totalPages;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final addedExtent =
            _scrollController.position.maxScrollExtent - previousExtent;
        _scrollController.jumpTo(previousOffset + addedExtent);
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _previewImage(ChatMessage message) {
    final imageUrl = resolveChatUrl(message.mediaContent?.url ?? '');
    if (imageUrl.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: Image.network(imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(dialogContext).top + 8,
              right: 12,
              child: IconButton.filledTonal(
                tooltip: '关闭',
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previewVideo(ChatMessage message) {
    final videoUrl = resolveChatUrl(message.mediaContent?.url ?? '');
    if (videoUrl.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            ChatVideoPreviewPage(localPath: null, videoUrl: videoUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PetGradientBackground(
      key: const ValueKey('patient-history-detail-background'),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              PetPageHeader(
                title: widget.history.serviceItemName,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _historyPrimary),
      );
    }
    if (_messages.isEmpty) {
      return _HistoryMessage(
        icon: _error == null ? Icons.chat_bubble_outline : Icons.error_outline,
        message: _error == null ? '该次咨询暂无消息' : '聊天记录加载失败',
        actionLabel: _error == null ? null : '重试',
        onAction: _error == null ? null : _loadInitial,
      );
    }

    return Column(
      children: [
        _HistoryDetailHeader(history: widget.history),
        if (_error != null)
          MaterialBanner(
            backgroundColor: Colors.white.withValues(alpha: 0.92),
            content: const Text('更早消息加载失败，请重试'),
            actions: [
              TextButton(onPressed: _loadOlder, child: const Text('重试')),
            ],
          ),
        Expanded(
          child: ListView.builder(
            key: const ValueKey('patient-history-message-list'),
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: _messages.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                if (!_hasOlder) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: Text(
                        '已显示全部消息',
                        style: TextStyle(color: _historyMuted, fontSize: 12),
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: TextButton.icon(
                      key: const ValueKey('patient-history-load-older'),
                      onPressed: _loadingOlder ? null : _loadOlder,
                      icon: _loadingOlder
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _historyPrimary,
                              ),
                            )
                          : const Icon(Icons.expand_less),
                      label: Text(_loadingOlder ? '加载中' : '加载更早消息'),
                    ),
                  ),
                );
              }
              final message = _messages[index - 1];
              return ChatMessageBubble(
                key: ValueKey('patient-history-message-${message.id}'),
                message: message,
                currentUserId: widget.consultation.doctorId,
                currentUserType: 'doctor',
                currentUserAvatar: widget.currentDoctorAvatarUrl,
                targetAvatar: widget.consultation.userAvatarUrl,
                paidSession: true,
                onPurchase: (_) {},
                onImageTap: _previewImage,
                onVideoTap: _previewVideo,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistorySessionTile extends StatelessWidget {
  const _HistorySessionTile({required this.item, required this.onTap});

  final DoctorHistorySession item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = item.serviceStartAt ?? item.createdAt ?? item.lastMessageAt;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: _historyCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey('patient-history-${item.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.serviceItemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _historyText,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _historyPrimarySoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '已结束',
                        style: TextStyle(color: _historyPrimary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatHistoryDate(date),
                  style: const TextStyle(color: _historyMuted, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.lastMessage ?? '暂无消息',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _historyMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${item.messageCount} 条',
                      style: const TextStyle(
                        color: _historyMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: _historyMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryDetailHeader extends StatelessWidget {
  const _HistoryDetailHeader({required this.history});

  final DoctorHistorySession history;

  @override
  Widget build(BuildContext context) {
    final date =
        history.serviceStartAt ?? history.createdAt ?? history.lastMessageAt;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(15, 6, 15, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: _historyCardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _historyPrimarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.event_outlined,
              color: _historyPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _formatHistoryDate(date),
              style: const TextStyle(color: _historyMuted, fontSize: 13),
            ),
          ),
          Text(
            '共 ${history.messageCount} 条消息',
            style: const TextStyle(color: _historyMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _historyMuted, size: 52),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: _historyMuted)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

String _formatHistoryDate(DateTime? value) {
  if (value == null) return '时间未记录';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
