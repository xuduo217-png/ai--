import 'package:flutter/material.dart';

import '../friend_voice_controller.dart';

class FriendRecordingOverlay extends StatelessWidget {
  const FriendRecordingOverlay({
    super.key,
    required this.controller,
    required this.onCancel,
  });

  final FriendVoiceController controller;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final visible =
        controller.state == FriendVoiceControllerState.recording ||
        controller.state == FriendVoiceControllerState.stopping;
    if (!visible) return const SizedBox.shrink();
    final stopping = controller.state == FriendVoiceControllerState.stopping;

    return Material(
      key: const ValueKey('friend-recording-overlay'),
      color: const Color(0xFF232A3A),
      child: SafeArea(
        top: false,
        bottom: false,
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  stopping ? Icons.hourglass_top_rounded : Icons.mic_rounded,
                  color: stopping
                      ? const Color(0xFFFFC857)
                      : const Color(0xFFFF6262),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stopping ? '正在处理语音' : '正在录音  ${controller.elapsedSeconds}"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!stopping)
                  IconButton(
                    key: const ValueKey('friend-recording-cancel'),
                    tooltip: '取消录音',
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
