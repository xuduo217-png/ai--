import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/media/auto_hiding_video_controls.dart';
import '../../../../core/media/route_aware_video_surface.dart';
import '../../../../core/media/video_player_view_type.dart';
import '../../domain/friend_media_content.dart';
import 'friend_video_message.dart';

class FriendMediaDraftPreview extends StatefulWidget {
  const FriendMediaDraftPreview({
    super.key,
    required this.draft,
    required this.onSend,
  });

  final FriendMediaSendRequest draft;
  final Future<void> Function() onSend;

  @override
  State<FriendMediaDraftPreview> createState() =>
      _FriendMediaDraftPreviewState();
}

class _FriendMediaDraftPreviewState extends State<FriendMediaDraftPreview> {
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return VideoRoutePopScope<void>(
      child: PopScope(
        canPop: !_sending,
        child: AppDialog(
          icon: AppDialogIcon(
            icon: draft.type == FriendMediaType.video
                ? Icons.videocam_outlined
                : Icons.image_outlined,
          ),
          title: Text(draft.type == FriendMediaType.video ? '发送视频' : '发送图片'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AspectRatio(
                    aspectRatio:
                        draft.width != null &&
                            draft.width! > 0 &&
                            draft.height != null &&
                            draft.height! > 0
                        ? draft.width! / draft.height!
                        : 4 / 3,
                    child: draft.type == FriendMediaType.image
                        ? Image.file(
                            File(draft.localFilePath),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const _DraftError(),
                          )
                        : _DraftVideo(filePath: draft.localFilePath),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        draft.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (draft.type == FriendMediaType.video)
                      Text(formatFriendVideoDuration(draft.duration)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _sending
                  ? null
                  : () => Navigator.of(context).maybePop(),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              key: const ValueKey('friend-media-draft-send'),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_sending ? '发送中' : '发送'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await widget.onSend();
      if (mounted) {
        setState(() => _sending = false);
        await Navigator.of(context).maybePop();
      }
    } finally {
      if (mounted && _sending) setState(() => _sending = false);
    }
  }
}

class _DraftVideo extends StatefulWidget {
  const _DraftVideo({required this.filePath});

  final String filePath;

  @override
  State<_DraftVideo> createState() => _DraftVideoState();
}

class _DraftVideoState extends State<_DraftVideo> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(
      File(widget.filePath),
      viewType: platformAdaptiveVideoViewType,
    );
    _initialization = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _DraftError();
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _controller,
          builder: (context, value, _) => AutoHidingVideoControls(
            isPlaying: value.isPlaying,
            controls: Center(
              child: IconButton(
                key: const ValueKey('friend-draft-video-toggle'),
                tooltip: value.isPlaying ? '暂停' : '播放',
                onPressed: () {
                  value.isPlaying ? _controller.pause() : _controller.play();
                },
                iconSize: 48,
                color: Colors.white,
                icon: Icon(
                  value.isPlaying
                      ? Icons.pause_circle_outline_rounded
                      : Icons.play_circle_outline_rounded,
                ),
              ),
            ),
            child: RouteAwareVideoSurface(
              controller: _controller,
              detachedKey: const ValueKey('friend-draft-video-detached'),
              child: VideoPlayer(_controller),
            ),
          ),
        );
      },
    );
  }
}

class _DraftError extends StatelessWidget {
  const _DraftError();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE5E7EB),
      child: Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}
