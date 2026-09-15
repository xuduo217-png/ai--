import 'package:flutter/material.dart';

Future<void> showFullscreenNetworkImagePreview(
  BuildContext context, {
  required String imageUrl,
}) {
  if (imageUrl.trim().isEmpty) return Future<void>.value();
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierColor: Colors.black,
    builder: (dialogContext) => Dialog.fullscreen(
      key: const ValueKey('fullscreen-network-image-preview'),
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const _FullscreenImageError(),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(dialogContext).top + 8,
            right: 12,
            child: IconButton.filledTonal(
              key: const ValueKey('fullscreen-network-image-close'),
              tooltip: '关闭',
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FullscreenImageError extends StatelessWidget {
  const _FullscreenImageError();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_outlined, color: Colors.white70, size: 44),
        SizedBox(height: 8),
        Text('图片无法加载', style: TextStyle(color: Colors.white70)),
      ],
    );
  }
}
