import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

import '../../../core/network/asset_url_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/friend_relation_models.dart';
import 'friend_search_controller.dart';
import 'widgets/conversation_tile.dart';

class SearchUserPage extends StatefulWidget {
  const SearchUserPage({super.key, required this.controller});

  final FriendSearchController controller;

  @override
  State<SearchUserPage> createState() => _SearchUserPageState();
}

class _SearchUserPageState extends State<SearchUserPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _showMessageInput = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('添加好友'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SafeArea(
          top: false,
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) => ListView(
              key: const ValueKey('friend-search-list'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              children: [
                const Text(
                  '通过手机号查找好友',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '输入对方注册时使用的手机号，即可快速发起好友申请。',
                  style: TextStyle(color: AppColors.muted, height: 1.5),
                ),
                const SizedBox(height: 18),
                _SearchBar(
                  controller: _phoneController,
                  searching: widget.controller.searching,
                  onClear: _clearPhone,
                  onSearch: _search,
                ),
                if (widget.controller.errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.controller.errorMessage!,
                    key: const ValueKey('friend-search-error'),
                    style: TextStyle(
                      color: widget.controller.notFound
                          ? AppColors.muted
                          : AppColors.accent,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (widget.controller.result case final user?)
                  _UserResultCard(
                    user: user,
                    self: widget.controller.isSelfResult,
                    showMessageInput: _showMessageInput,
                    sending: widget.controller.sending,
                    messageController: _messageController,
                    messageFocusNode: _messageFocusNode,
                    onAdd: _showRequestForm,
                    onCancel: _cancelRequest,
                    onSend: _sendRequest,
                  )
                else if (!widget.controller.searching)
                  Padding(
                    padding: const EdgeInsets.only(top: 90),
                    child: Column(
                      children: [
                        Icon(
                          widget.controller.notFound
                              ? Icons.person_off_outlined
                              : Icons.person_search_outlined,
                          size: 64,
                          color: const Color(0xFFD1D5DB),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.controller.notFound ? '未找到该用户' : '输入手机号搜索好友',
                          style: const TextStyle(
                            color: Color(0xFF374151),
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.controller.notFound
                              ? '请确认手机号后重试'
                              : '搜索成功后，可直接发起好友申请',
                          style: const TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _clearPhone() {
    _phoneController.clear();
    widget.controller.clearResult();
    setState(() {
      _showMessageInput = false;
      _messageController.clear();
    });
  }

  Future<void> _search() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final found = await widget.controller.search(_phoneController.text);
    if (!mounted || !found) return;
    setState(() {
      _showMessageInput = false;
      _messageController.clear();
    });
  }

  void _showRequestForm() {
    setState(() => _showMessageInput = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _messageFocusNode.requestFocus();
    });
  }

  void _cancelRequest() {
    setState(() {
      _showMessageInput = false;
      _messageController.clear();
    });
  }

  Future<void> _sendRequest() async {
    final result = await widget.controller.sendRequest(_messageController.text);
    if (!mounted || result == null) return;
    if (result.status == SendFriendRequestStatus.sent) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      Navigator.of(context).pop();
      return;
    }
    setState(() => _showMessageInput = false);
    await showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        icon: const AppDialogIcon(icon: Icons.info_outline_rounded),
        title: const Text('温馨提示'),
        content: Text(_resultMessage(result)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({
    required this.controller,
    required this.searching,
    required this.onClear,
    required this.onSearch,
  });

  final TextEditingController controller;
  final bool searching;
  final VoidCallback onClear;
  final VoidCallback onSearch;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant _SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleTextChanged);
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  void _handleTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 350;
        final input = TextField(
          key: const ValueKey('friend-phone-search-field'),
          controller: widget.controller,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 11,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => widget.onSearch(),
          decoration: InputDecoration(
            counterText: '',
            hintText: '输入手机号搜索',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: widget.controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: '清空',
                    onPressed: widget.onClear,
                    icon: const Icon(Icons.cancel_outlined),
                  ),
          ),
        );
        final button = FilledButton.icon(
          key: const ValueKey('friend-search-submit'),
          onPressed: widget.searching || widget.controller.text.isEmpty
              ? null
              : widget.onSearch,
          icon: widget.searching
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.person_search_outlined),
          label: const Text('搜索用户'),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [input, const SizedBox(height: 10), button],
          );
        }
        return Row(
          children: [
            Expanded(child: input),
            const SizedBox(width: 10),
            SizedBox(width: 122, child: button),
          ],
        );
      },
    );
  }
}

class _UserResultCard extends StatefulWidget {
  const _UserResultCard({
    required this.user,
    required this.self,
    required this.showMessageInput,
    required this.sending,
    required this.messageController,
    required this.messageFocusNode,
    required this.onAdd,
    required this.onCancel,
    required this.onSend,
  });

  final UserSearchResult user;
  final bool self;
  final bool showMessageInput;
  final bool sending;
  final TextEditingController messageController;
  final FocusNode messageFocusNode;
  final VoidCallback onAdd;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  State<_UserResultCard> createState() => _UserResultCardState();
}

class _UserResultCardState extends State<_UserResultCard> {
  @override
  void initState() {
    super.initState();
    widget.messageController.addListener(_updateCount);
  }

  @override
  void didUpdateWidget(covariant _UserResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageController == widget.messageController) return;
    oldWidget.messageController.removeListener(_updateCount);
    widget.messageController.addListener(_updateCount);
  }

  @override
  void dispose() {
    widget.messageController.removeListener(_updateCount);
    super.dispose();
  }

  void _updateCount() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('friend-search-result-card'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FriendAvatar(
                  name: widget.user.displayName,
                  imageUrl: resolveAssetUrl(widget.user.avatar),
                  radius: 36,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '用户 ID · ${widget.user.id}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _InfoCell(label: '昵称', value: widget.user.username),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _InfoCell(label: '手机号', value: widget.user.phone),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.self ? '这是你自己的账号，不能向自己发送好友申请。' : '确认资料无误后，可直接发送好友申请。',
              style: const TextStyle(color: AppColors.muted, height: 1.45),
            ),
            const SizedBox(height: 16),
            if (widget.self)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '当前搜索结果是你自己',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            else if (!widget.showMessageInput)
              FilledButton.icon(
                key: const ValueKey('friend-search-add'),
                onPressed: widget.onAdd,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('添加好友'),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '申请附言',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '让对方更容易认出你，内容可选填。',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('friend-request-message-field'),
                    controller: widget.messageController,
                    focusNode: widget.messageFocusNode,
                    maxLength: 50,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: '输入申请附言（选填，最多 50 字）',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '最多 50 个字',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${widget.messageController.text.length}/50',
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton(
                            key: const ValueKey('friend-request-cancel'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFF3F4F6),
                              foregroundColor: AppColors.muted,
                              disabledBackgroundColor: const Color(0xFFF3F4F6),
                              disabledForegroundColor: const Color(0xFF9CA3AF),
                              elevation: 0,
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: widget.sending ? null : widget.onCancel,
                            child: const Text('取消'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton(
                            key: const ValueKey('friend-request-send'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: widget.sending ? null : widget.onSend,
                            child: widget.sending
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('发送申请'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
            const SizedBox(height: 5),
            Text(
              value.isEmpty ? '-' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _resultMessage(SendFriendRequestResult result) {
  if (result.message.trim().isNotEmpty) return result.message;
  return switch (result.status) {
    SendFriendRequestStatus.sent => '好友申请已发送',
    SendFriendRequestStatus.outgoingPending => '好友申请已发送，请耐心等待对方处理',
    SendFriendRequestStatus.incomingPending => '对方已向你发送好友申请，请直接处理对方申请',
    SendFriendRequestStatus.alreadyFriends => '你们已经是好友了',
    SendFriendRequestStatus.self => '不能给自己发送好友申请',
  };
}
