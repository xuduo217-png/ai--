import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/friend_messaging_models.dart';
import '../friend_voice_controller.dart';
import 'conversation_tile.dart';
import 'friend_image_message.dart';
import 'friend_video_message.dart';
import 'friend_voice_message.dart';

class FriendMessageBubble extends StatelessWidget {
  const FriendMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.onRetry,
    this.avatarName = '友',
    this.avatarUrl,
    this.onMediaTap,
    this.onVoiceTap,
    this.voicePlayback,
    this.onLongPress,
  });

  final FriendMessage message;
  final bool isMine;
  final VoidCallback onRetry;
  final String avatarName;
  final String? avatarUrl;
  final ValueChanged<FriendMessage>? onMediaTap;
  final VoidCallback? onVoiceTap;
  final ValueListenable<FriendVoicePlaybackStatus>? voicePlayback;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (message.isRevoked) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Center(
          child: Text(
            message.content,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          ),
        ),
      );
    }
    final isMedia =
        message.messageType == 'image' || message.messageType == 'video';
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.74,
      ),
      padding: isMedia
          ? const EdgeInsets.all(3)
          : const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: isMine ? const Color(0xFF4F6FD8) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
          bottomLeft: Radius.circular(isMine ? 8 : 2),
          bottomRight: Radius.circular(isMine ? 2 : 8),
        ),
        border: isMine
            ? null
            : Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: switch (message.messageType) {
        'image' => FriendImageMessage(
          message: message,
          onPreview: onMediaTap == null ? null : () => onMediaTap!(message),
        ),
        'video' => FriendVideoMessage(
          message: message,
          onPreview: onMediaTap == null ? null : () => onMediaTap!(message),
        ),
        'voice' => FriendVoiceMessage(
          message: message,
          isMine: isMine,
          onTap: onVoiceTap,
          playback: voicePlayback,
        ),
        _ => Text(
          message.content,
          style: TextStyle(
            color: isMine ? Colors.white : const Color(0xFF1F2937),
            fontSize: 15,
            height: 1.35,
          ),
        ),
      },
    );

    final avatar = FriendAvatar(
      key: ValueKey('friend-message-avatar-${message.localKey}'),
      name: avatarName,
      imageUrl: avatarUrl,
      radius: 20,
    );

    final content = Flexible(
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          bubble,
          const SizedBox(height: 4),
          Wrap(
            alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text(
                _formatMessageTime(message.createdAt),
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
              ),
              if (isMine) _MessageStatus(message: message, onRetry: onRetry),
            ],
          ),
        ],
      ),
    );

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        key: ValueKey('friend-message-${message.localKey}'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisAlignment: isMine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine) ...[avatar, const SizedBox(width: 8)],
            content,
            if (isMine) ...[const SizedBox(width: 8), avatar],
          ],
        ),
      ),
    );
  }
}

String _formatMessageTime(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

class _MessageStatus extends StatelessWidget {
  const _MessageStatus({required this.message, required this.onRetry});

  final FriendMessage message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (message.sendStatus) {
      MessageSendStatus.sending => const SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      ),
      MessageSendStatus.failed => IconButton(
        key: ValueKey('retry-${message.localKey}'),
        tooltip: '重试',
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
        padding: EdgeInsets.zero,
        onPressed: onRetry,
        icon: const Icon(
          Icons.error_rounded,
          color: Color(0xFFE5484D),
          size: 20,
        ),
      ),
      MessageSendStatus.sent => Text(
        message.isRead ? '已读' : '',
        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
      ),
    };
  }
}
