import 'package:flutter/material.dart';

import '../../../shared/mall_widgets.dart';

class AfterSaleEvidencePicker extends StatelessWidget {
  const AfterSaleEvidencePicker({
    super.key,
    required this.urls,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> urls;
  final bool uploading;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '图片凭证 ${urls.length}/9',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < urls.length; index++)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      urls[index],
                      width: 82,
                      height: 82,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      tooltip: '删除凭证',
                      onPressed: () => onRemove(index),
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ),
                ],
              ),
            if (urls.length < 9)
              SizedBox.square(
                dimension: 82,
                child: OutlinedButton(
                  onPressed: uploading ? null : onAdd,
                  child: uploading
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Icon(Icons.add_photo_alternate_outlined),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class AfterSaleEvidenceGrid extends StatelessWidget {
  const AfterSaleEvidenceGrid({super.key, required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 420 ? 4 : 3;
        const spacing = 8.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var index = 0; index < urls.length; index++)
              SizedBox.square(
                dimension: itemWidth,
                child: Material(
                  color: const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(8),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('after-sale-evidence-$index'),
                    onTap: () => _preview(context, urls[index]),
                    child: MallNetworkImage(url: urls[index]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _preview(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
        backgroundColor: const Color(0xFF111318),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.68,
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: MallNetworkImage(url: url, fit: BoxFit.contain),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  tooltip: '关闭图片预览',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0x99000000),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
