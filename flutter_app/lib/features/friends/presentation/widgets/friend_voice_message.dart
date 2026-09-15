import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/friend_messaging_models.dart';
import '../../domain/friend_voice_content.dart';
import '../friend_voice_controller.dart';

class FriendVoiceMessage extends StatelessWidget {
  const FriendVoiceMessage({
    super.key,
    required this.message,
    required this.isMine,
    required this.onTap,
    this.playback,
  });

  final FriendMessage message;
  final bool isMine;
  final VoidCallback? onTap;
  final ValueListenable<FriendVoicePlaybackStatus>? playback;

  @override
  Widget build(BuildContext context) {
    final listenable = playback;
    if (listenable == null) {
      return _buildContent(FriendVoicePlaybackStatus.idle);
    }
    return ValueListenableBuilder<FriendVoicePlaybackStatus>(
      valueListenable: listenable,
      builder: (context, status, _) => _buildContent(status),
    );
  }

  Widget _buildContent(FriendVoicePlaybackStatus status) {
    final content = FriendVoiceContent.parse(message.content);
    final foreground = isMine ? Colors.white : const Color(0xFF25304A);
    final secondary = isMine
        ? Colors.white.withValues(alpha: 0.72)
        : const Color(0xFF798198);
    final duration = content?.duration ?? 0;
    final enabled = content?.canPlay == true && onTap != null;

    return Semantics(
      button: true,
      label: status == FriendVoicePlaybackStatus.playing ? '停止语音' : '播放语音',
      child: InkWell(
        key: ValueKey('friend-voice-${message.localKey}'),
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 132,
          height: 32,
          child: Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: status == FriendVoicePlaybackStatus.loading
                    ? Padding(
                        padding: const EdgeInsets.all(4),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                        ),
                      )
                    : Icon(
                        status == FriendVoicePlaybackStatus.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: foreground,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(9, (index) {
                    const heights = <double>[8, 14, 20, 11, 17, 23, 13, 19, 9];
                    return Container(
                      width: 2,
                      height: heights[index],
                      decoration: BoxDecoration(
                        color: secondary,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                '$duration"',
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
