import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/network/asset_url_resolver.dart';
import '../../domain/friend_messaging_models.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  final FriendConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: ValueKey('conversation-${conversation.conversationId}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              FriendAvatar(
                name: conversation.friendName,
                imageUrl: conversation.friendAvatar,
                radius: 26,
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
                            conversation.friendName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatConversationTime(conversation.lastMessageAt),
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.lastMessage?.isNotEmpty == true
                                ? conversation.lastMessage!
                                : '暂无消息',
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
                          _UnreadBadge(count: conversation.unreadCount),
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

class FriendAvatar extends StatelessWidget {
  const FriendAvatar({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.radius,
  });

  final String name;
  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = _AvatarPlaceholder(name: name, radius: radius);
    final value = imageUrl?.trim() ?? '';
    if (value.isEmpty) return placeholder;
    final resolved = resolveAssetUrl(value);
    final localFile = resolveLocalFile(resolved);
    Widget image;
    if (localFile != null && localFile.existsSync()) {
      image = Image.file(
        localFile,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    } else if (resolved.startsWith('data:')) {
      final bytes = _decodeDataUri(resolved);
      image = bytes == null
          ? placeholder
          : Image.memory(
              bytes,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            );
    } else if (resolved.startsWith('http://') ||
        resolved.startsWith('https://')) {
      image = Image.network(
        resolved,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    } else {
      return placeholder;
    }
    return ClipOval(child: image);
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.name, required this.radius});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '友' : name.trim().characters.first;
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE8EEFF),
      child: Text(
        initial,
        style: TextStyle(
          color: const Color(0xFF4969C7),
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      constraints: const BoxConstraints(minWidth: 22),
      width: count < 10 ? 22 : null,
      padding: count < 10
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE5484D),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String formatConversationTime(DateTime value, {DateTime? now}) {
  final local = value.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  if (_sameDay(local, current)) {
    return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }
  final difference = current.difference(local);
  if (!difference.isNegative && difference.inDays < 7) {
    return const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][local.weekday - 1];
  }
  return '${local.month}/${local.day}';
}

String resolveFriendImageUrl(String value) {
  return resolveAssetUrl(value);
}

Uint8List? _decodeDataUri(String value) {
  final separator = value.indexOf(',');
  if (separator < 0 || !value.substring(0, separator).contains(';base64')) {
    return null;
  }
  try {
    return base64Decode(value.substring(separator + 1));
  } on FormatException {
    return null;
  }
}

bool _sameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
