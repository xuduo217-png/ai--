import 'dart:io';

import 'package:flutter/material.dart';

import '../media/local_chat_media.dart';
import 'app_dialog.dart';

class LocalMediaPreviewItem {
  const LocalMediaPreviewItem({
    required this.path,
    required this.fileName,
    required this.kind,
  });

  final String path;
  final String fileName;
  final LocalChatMediaKind kind;
}

class LocalMediaBatchPreview extends StatefulWidget {
  const LocalMediaBatchPreview({
    super.key,
    required this.items,
    required this.onSend,
  }) : assert(items.length > 1),
       assert(items.length <= maxChatMediaSelectionCount);

  final List<LocalMediaPreviewItem> items;
  final Future<void> Function() onSend;

  @override
  State<LocalMediaBatchPreview> createState() => _LocalMediaBatchPreviewState();
}

class _LocalMediaBatchPreviewState extends State<LocalMediaBatchPreview> {
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sending,
      child: AppDialog(
        icon: const AppDialogIcon(icon: Icons.collections_outlined),
        title: Text('发送 ${widget.items.length} 个媒体'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 340),
          child: GridView.builder(
            key: const ValueKey('local-media-batch-grid'),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.78,
            ),
            itemCount: widget.items.length,
            itemBuilder: (context, index) =>
                _MediaPreviewTile(item: widget.items[index], index: index),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            key: const ValueKey('local-media-batch-send'),
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
    );
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await widget.onSend();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _MediaPreviewTile extends StatelessWidget {
  const _MediaPreviewTile({required this.item, required this.index});

  final LocalMediaPreviewItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: item.kind == LocalChatMediaKind.video
                ? const ColoredBox(
                    color: Color(0xFF111827),
                    child: Center(
                      child: Icon(
                        Icons.play_circle_outline_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Image.file(
                    File(item.path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Color(0xFFE5E7EB),
                      child: Center(child: Icon(Icons.broken_image_outlined)),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${index + 1}. ${item.fileName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
