import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/media/chat_media_display_size.dart';
import '../../../core/network/asset_url_resolver.dart';
import '../domain/chat_models.dart';

const chatPrimary = Color(0xFF7E97FA);
const chatTextPrimary = Color(0xFF1F2937);
const chatTextHint = Color(0xFF9CA3AF);

double chatScale(BuildContext context, double value) {
  return (value * MediaQuery.sizeOf(context).shortestSide / 750)
      .roundToDouble();
}

String resolveChatUrl(String rawUrl) {
  return resolveAssetUrl(rawUrl);
}

class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.target,
    required this.online,
    required this.remaining,
    required this.onBack,
    this.statusText,
    this.statusActive,
    this.canExtendSession = false,
    this.extendingSession = false,
    this.onExtendSession,
    this.onTap,
  });

  final ChatTarget target;
  final bool online;
  final Duration? remaining;
  final VoidCallback onBack;
  final String? statusText;
  final bool? statusActive;
  final bool canExtendSession;
  final bool extendingSession;
  final Future<void> Function(int minutes)? onExtendSession;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        chatScale(context, 16),
        top + chatScale(context, 16),
        chatScale(context, 16),
        chatScale(context, 16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: chatScale(context, 40),
            height: chatScale(context, 40),
            child: IconButton(
              key: const ValueKey('chat-back-button'),
              padding: EdgeInsets.zero,
              onPressed: onBack,
              tooltip: '返回',
              icon: Icon(
                Icons.arrow_back,
                size: chatScale(context, 48),
                color: chatTextPrimary,
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              button: onTap != null,
              label: onTap == null ? null : '查看用户健康档案',
              child: InkWell(
                key: onTap == null
                    ? null
                    : const ValueKey('chat-patient-record-entry'),
                onTap: onTap,
                borderRadius: BorderRadius.circular(chatScale(context, 8)),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Avatar(
                        imageUrl: target.avatarUrl,
                        size: chatScale(context, 64),
                      ),
                      SizedBox(width: chatScale(context, 8)),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: chatScale(context, 210),
                            ),
                            child: Text(
                              target.name.isEmpty ? '医生' : target.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: chatTextPrimary,
                                fontSize: chatScale(context, 30),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          SizedBox(height: chatScale(context, 2)),
                          Text(
                            statusText ?? (online ? '在线' : '离线'),
                            style: TextStyle(
                              color: (statusActive ?? online)
                                  ? const Color(0xFF10B981)
                                  : chatTextHint,
                              fontSize: chatScale(context, 20),
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                      if (onTap != null) ...[
                        SizedBox(width: chatScale(context, 6)),
                        Icon(
                          Icons.chevron_right,
                          color: chatTextHint,
                          size: chatScale(context, 32),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: chatScale(context, 100),
                child: remaining == null
                    ? const SizedBox.shrink()
                    : _SessionTimer(remaining: remaining!),
              ),
              if (canExtendSession || extendingSession)
                SizedBox(
                  width: chatScale(context, 96),
                  height: chatScale(context, 44),
                  child: extendingSession
                      ? Padding(
                          padding: EdgeInsets.all(chatScale(context, 10)),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: chatPrimary,
                          ),
                        )
                      : Tooltip(
                          message: '延长咨询时间',
                          child: TextButton.icon(
                            key: const ValueKey('chat-extend-time-button'),
                            onPressed: () => _showExtensionOptions(context),
                            style: TextButton.styleFrom(
                              foregroundColor: chatPrimary,
                              padding: EdgeInsets.symmetric(
                                horizontal: chatScale(context, 4),
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: Icon(
                              Icons.more_time,
                              size: chatScale(context, 24),
                            ),
                            label: Text(
                              '延长',
                              style: TextStyle(
                                fontSize: chatScale(context, 20),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showExtensionOptions(BuildContext context) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const [5, 10, 15, 30])
              ListTile(
                leading: const Icon(Icons.more_time),
                title: Text('延长 $option 分钟'),
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
    if (minutes == null || onExtendSession == null) return;
    await onExtendSession!(minutes);
  }
}

class _SessionTimer extends StatelessWidget {
  const _SessionTimer({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final expired = remaining.inSeconds <= 0;
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);
    final value = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: chatScale(context, 8),
        vertical: chatScale(context, 4),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(chatScale(context, 12)),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            size: chatScale(context, 16),
            color: const Color(0xFF667EEA),
          ),
          SizedBox(width: chatScale(context, 3)),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: expired
                    ? const Color(0xFFFF3B30)
                    : const Color(0xFF667EEA),
                fontSize: chatScale(context, 20),
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    this.currentUserType = 'user',
    this.currentUserAvatar = '',
    required this.targetAvatar,
    required this.paidSession,
    required this.onPurchase,
    required this.onImageTap,
    required this.onVideoTap,
    this.onLongPress,
  });

  final ChatMessage message;
  final int currentUserId;
  final String currentUserType;
  final String currentUserAvatar;
  final String targetAvatar;
  final bool paidSession;
  final ValueChanged<ChatPackage> onPurchase;
  final ValueChanged<ChatMessage> onImageTap;
  final ValueChanged<ChatMessage> onVideoTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (message.isRevoked) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: chatScale(context, 12)),
        child: Center(
          child: Text(
            message.content,
            style: TextStyle(
              color: chatTextHint,
              fontSize: chatScale(context, 22),
              letterSpacing: 0,
            ),
          ),
        ),
      );
    }
    if (message.type == ChatMessageType.paymentPrompt) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: chatScale(context, 8)),
        child: PaymentPromptBubble(
          packages: message.packages,
          disabled: paidSession,
          onPurchase: onPurchase,
        ),
      );
    }
    if (message.type == ChatMessageType.paymentSuccess) {
      return _PaymentSuccessBubble(message: message);
    }
    if (message.isSystem) {
      return _SystemMessage(message: message);
    }

    final senderType = message.senderType;
    final own =
        message.senderId == currentUserId &&
        (senderType == null ||
            senderType.isEmpty ||
            senderType == currentUserType);
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.only(bottom: chatScale(context, 16)),
        child: Row(
          mainAxisAlignment: own
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!own) ...[
              _Avatar(imageUrl: targetAvatar, size: chatScale(context, 64)),
              SizedBox(width: chatScale(context, 12)),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.7,
              ),
              child: Column(
                crossAxisAlignment: own
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  _MessageContent(
                    message: message,
                    own: own,
                    onImageTap: () => onImageTap(message),
                    onVideoTap: () => onVideoTap(message),
                  ),
                  SizedBox(height: chatScale(context, 4)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.failed) ...[
                        Icon(
                          Icons.error_outline,
                          size: chatScale(context, 20),
                          color: const Color(0xFFEF4444),
                        ),
                        SizedBox(width: chatScale(context, 4)),
                      ],
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          color: message.failed
                              ? const Color(0xFFEF4444)
                              : chatTextHint,
                          fontSize: chatScale(context, 20),
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (own) ...[
              SizedBox(width: chatScale(context, 12)),
              _Avatar(
                imageUrl: currentUserAvatar,
                size: chatScale(context, 64),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.message,
    required this.own,
    required this.onImageTap,
    required this.onVideoTap,
  });

  final ChatMessage message;
  final bool own;
  final VoidCallback onImageTap;
  final VoidCallback onVideoTap;

  @override
  Widget build(BuildContext context) {
    if (message.type == ChatMessageType.image) {
      final media = message.mediaContent;
      return _MediaMessageFrame(
        key: ValueKey('chat-image-${message.id}'),
        sourceWidth: media?.width,
        sourceHeight: media?.height,
        fallbackAspectRatio: 4 / 3,
        borderRadius: chatScale(context, 12),
        onTap: onImageTap,
        child: _MediaImage(message: message),
      );
    }
    if (message.type == ChatMessageType.video) {
      final media = message.mediaContent;
      return _MediaMessageFrame(
        key: ValueKey('chat-video-${message.id}'),
        sourceWidth: media?.width,
        sourceHeight: media?.height,
        fallbackAspectRatio: 16 / 9,
        borderRadius: chatScale(context, 14),
        onTap: onVideoTap,
        child: ColoredBox(
          color: own ? const Color(0xFF1D4ED8) : const Color(0xFF111827),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (media?.thumbnail?.isNotEmpty == true)
                Image.network(
                  resolveChatUrl(media!.thumbnail!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              Container(color: const Color(0x2E0F172A)),
              Center(
                child: Container(
                  width: chatScale(context, 52),
                  height: chatScale(context, 52),
                  decoration: const BoxDecoration(
                    color: Color(0xA60F172A),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: chatScale(context, 34),
                  ),
                ),
              ),
              Positioned(
                right: chatScale(context, 10),
                bottom: chatScale(context, 10),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: chatScale(context, 8),
                    vertical: chatScale(context, 4),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xB80F172A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.videocam,
                        size: chatScale(context, 18),
                        color: Colors.white,
                      ),
                      SizedBox(width: chatScale(context, 4)),
                      Text(
                        _formatDuration(media?.duration),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: chatScale(context, 18),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (message.pending)
                const ColoredBox(
                  color: Color(0x33000000),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: chatScale(context, 12),
        vertical: chatScale(context, 8),
      ),
      decoration: BoxDecoration(
        color: own ? chatPrimary : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(chatScale(context, 16)),
          topRight: Radius.circular(chatScale(context, 16)),
          bottomLeft: Radius.circular(chatScale(context, own ? 16 : 4)),
          bottomRight: Radius.circular(chatScale(context, own ? 4 : 16)),
        ),
      ),
      child: Text(
        message.content,
        style: TextStyle(
          color: own ? Colors.white : chatTextPrimary,
          fontSize: chatScale(context, 30),
          height: 36 / 30,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _MediaMessageFrame extends StatelessWidget {
  const _MediaMessageFrame({
    super.key,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.fallbackAspectRatio,
    required this.borderRadius,
    required this.onTap,
    required this.child,
  });

  final int? sourceWidth;
  final int? sourceHeight;
  final double fallbackAspectRatio;
  final double borderRadius;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = chatMediaDisplaySize(
          viewportWidth: MediaQuery.sizeOf(context).width,
          availableWidth: constraints.maxWidth,
          sourceWidth: sourceWidth,
          sourceHeight: sourceHeight,
          fallbackAspectRatio: fallbackAspectRatio,
        );
        return GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _MediaImage extends StatelessWidget {
  const _MediaImage({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final localPath = message.localMediaPath;
    final url = resolveChatUrl(message.mediaContent?.url ?? '');
    final image = localPath != null && localPath.isNotEmpty
        ? Image.file(File(localPath), fit: BoxFit.cover)
        : Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Color(0xFFE5E7EB),
              child: Icon(Icons.broken_image_outlined, color: chatTextHint),
            ),
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        if (message.pending)
          const ColoredBox(
            color: Color(0x33000000),
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.imageUrl, required this.size});

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = resolveChatUrl(imageUrl);
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          shape: BoxShape.circle,
        ),
        child: resolvedUrl.isEmpty
            ? Icon(
                Icons.person,
                color: const Color(0xFFB6C6E3),
                size: size * 0.58,
              )
            : Image.network(
                resolvedUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.person,
                  color: const Color(0xFFB6C6E3),
                  size: size * 0.58,
                ),
              ),
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: chatScale(context, 8)),
      child: Column(
        children: [
          Text(
            _formatTime(message.createdAt),
            style: TextStyle(
              color: chatTextHint,
              fontSize: chatScale(context, 22),
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: chatScale(context, 4)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: chatScale(context, 12),
              vertical: chatScale(context, 6),
            ),
            decoration: BoxDecoration(
              color: const Color(0x0D000000),
              borderRadius: BorderRadius.circular(chatScale(context, 12)),
            ),
            child: Text(
              message.content,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: chatTextHint,
                fontSize: chatScale(context, 24),
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSuccessBubble extends StatelessWidget {
  const _PaymentSuccessBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: chatScale(context, 8)),
      child: Column(
        children: [
          Text(
            _formatTime(message.createdAt),
            style: TextStyle(
              color: chatTextHint,
              fontSize: chatScale(context, 22),
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: chatScale(context, 6)),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.85,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: chatScale(context, 16),
              vertical: chatScale(context, 12),
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(chatScale(context, 12)),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: const Color(0xFF10B981),
                  size: chatScale(context, 40),
                ),
                SizedBox(width: chatScale(context, 10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content,
                        style: TextStyle(
                          color: const Color(0xFF065F46),
                          fontSize: chatScale(context, 24),
                          height: 40 / 24,
                          letterSpacing: 0,
                        ),
                      ),
                      if (message.orderId != null)
                        Text(
                          '订单号: ${message.orderId}',
                          style: TextStyle(
                            color: const Color(0xFF047857),
                            fontSize: chatScale(context, 22),
                            letterSpacing: 0,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentPromptBubble extends StatelessWidget {
  const PaymentPromptBubble({
    super.key,
    required this.packages,
    required this.disabled,
    required this.onPurchase,
  });

  static const disclaimer =
      '在线咨询仅供宠物健康管理参考，不能替代线下诊疗。若宠物出现急症或症状加重，请及时前往正规宠物医院就诊。';

  final List<ChatPackage> packages;
  final bool disabled;
  final ValueChanged<ChatPackage> onPurchase;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.85,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(chatScale(context, 12)),
          border: Border.all(color: const Color(0xFFDBEAFE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: const Color(0xFFFFFBEB),
              padding: EdgeInsets.symmetric(
                horizontal: chatScale(context, 12),
                vertical: chatScale(context, 10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: const Color(0xFFB45309),
                        size: chatScale(context, 26),
                      ),
                      SizedBox(width: chatScale(context, 6)),
                      Text(
                        '免责声明',
                        style: TextStyle(
                          color: const Color(0xFF92400E),
                          fontSize: chatScale(context, 24),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: chatScale(context, 4)),
                  Text(
                    disclaimer,
                    style: TextStyle(
                      color: const Color(0xFF78350F),
                      fontSize: chatScale(context, 20),
                      height: 28 / 20,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: const Color(0xFFDBEAFE),
              padding: EdgeInsets.symmetric(
                horizontal: chatScale(context, 12),
                vertical: chatScale(context, 8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications,
                    color: chatPrimary,
                    size: chatScale(context, 30),
                  ),
                  SizedBox(width: chatScale(context, 6)),
                  Text(
                    '免费咨询次数已用完',
                    style: TextStyle(
                      color: const Color(0xFF1E40AF),
                      fontSize: chatScale(context, 22),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(chatScale(context, 12)),
              child: Column(
                children: [
                  for (final package in packages) ...[
                    ChatPackageTile(
                      package: package,
                      disabled: disabled,
                      onTap: () => onPurchase(package),
                    ),
                    SizedBox(height: chatScale(context, 12)),
                  ],
                ],
              ),
            ),
            Container(
              color: const Color(0xFFDBEAFE),
              padding: EdgeInsets.symmetric(
                horizontal: chatScale(context, 12),
                vertical: chatScale(context, 8),
              ),
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
      ),
    );
  }
}

class ChatPackageTile extends StatelessWidget {
  const ChatPackageTile({
    super.key,
    required this.package,
    required this.disabled,
    required this.onTap,
    this.width,
  });

  final ChatPackage package;
  final bool disabled;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(chatScale(context, 12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onTap,
          child: Ink(
            width: width,
            padding: EdgeInsets.all(chatScale(context, 16)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: disabled
                    ? const [Color(0xFFE5E7EB), Color(0xFFD1D5DB)]
                    : const [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(chatScale(context, 12)),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.name,
                      style: TextStyle(
                        color: disabled
                            ? const Color(0xFF666666)
                            : Colors.white,
                        fontSize: chatScale(context, 24),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: chatScale(context, 6)),
                    Text(
                      '¥${_formatPrice(package.price)}',
                      style: TextStyle(
                        color: disabled
                            ? const Color(0xFF666666)
                            : Colors.white,
                        fontSize: chatScale(context, 24),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: chatScale(context, 8)),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: disabled
                              ? const Color(0xFF666666)
                              : Colors.white,
                          size: chatScale(context, 30),
                        ),
                        SizedBox(width: chatScale(context, 6)),
                        Text(
                          '${package.displayDays}天',
                          style: TextStyle(
                            color: disabled
                                ? const Color(0xFF666666)
                                : Colors.white,
                            fontSize: chatScale(context, 20),
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                    if (package.description?.isNotEmpty == true) ...[
                      SizedBox(height: chatScale(context, 6)),
                      Text(
                        package.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: disabled
                              ? const Color(0xFF666666)
                              : const Color(0xD9FFFFFF),
                          fontSize: chatScale(context, 20),
                          height: 28 / 20,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ],
                ),
                if (disabled)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: chatScale(context, 8),
                        vertical: chatScale(context, 4),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x80000000),
                        borderRadius: BorderRadius.circular(
                          chatScale(context, 8),
                        ),
                      ),
                      child: Text(
                        '已购买',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: chatScale(context, 20),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _formatDuration(int? rawDuration) {
  if (rawDuration == null || rawDuration <= 0) return '视频';
  final totalSeconds = rawDuration > 10000 ? rawDuration ~/ 1000 : rawDuration;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _formatPrice(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}
