import 'package:flutter/material.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

import '../catalog/domain/catalog_models.dart';

const mallPrimary = Color(0xFF718AF5);
const mallBackground = Color(0xFFF6F7FB);

class MallNetworkImage extends StatelessWidget {
  const MallNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final child = url.trim().isEmpty
        ? _placeholder()
        : Image.network(
            url,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, _, _) => _placeholder(),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : ColoredBox(
                    color: const Color(0xFFF0F2F5),
                    child: Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes == null
                            ? null
                            : progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!,
                        strokeWidth: 2,
                        color: mallPrimary,
                      ),
                    ),
                  ),
          );
    if (width == null && height == null) return child;
    return SizedBox(width: width, height: height, child: child);
  }

  Widget _placeholder() {
    return ColoredBox(
      color: const Color(0xFFF0F2F5),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: const Color(0xFFB8BEC9),
          size: (width ?? height ?? 44).clamp(28, 52),
        ),
      ),
    );
  }
}

class MallStateView extends StatelessWidget {
  const MallStateView({
    super.key,
    required this.icon,
    required this.message,
    this.onRetry,
    this.actionLabel = '重试',
    this.actionIcon = Icons.refresh,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;
  final String actionLabel;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: const Color(0xFFB7BDC9)),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF7A8190), fontSize: 15),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: Icon(actionIcon),
                label: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MallProductTile extends StatelessWidget {
  const MallProductTile({
    super.key,
    required this.product,
    required this.onTap,
    this.onAdd,
  });

  final CatalogProduct product;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: MallNetworkImage(url: product.imageUrl)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (product.isSecondHand && product.sellerLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
                child: Text(
                  product.sellerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7A8190),
                    fontSize: 12,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 6, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '¥${product.price.toStringAsFixed(2)}',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFFE95656),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onAdd != null)
                    IconButton(
                      key: ValueKey('add-product-${product.id}'),
                      tooltip: '加入购物车',
                      onPressed: onAdd,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.add_shopping_cart,
                        size: 21,
                        color: mallPrimary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showMallMessage(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFD84949) : null,
      ),
    );
}

Future<bool> showMallConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = '确定',
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AppDialog(
          icon: const AppDialogIcon(icon: Icons.help_outline_rounded),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmText),
            ),
          ],
        ),
      ) ??
      false;
}
