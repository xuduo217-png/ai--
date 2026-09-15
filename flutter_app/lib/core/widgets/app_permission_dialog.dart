import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Future<bool> showAppPermissionDialog({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String description,
  required List<String> assurances,
  required String confirmText,
  String cancelText = '暂不允许',
  Color accentColor = AppColors.primary,
  Key? cancelButtonKey,
  Key? confirmButtonKey,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AppPermissionDialog(
          icon: icon,
          title: title,
          description: description,
          assurances: assurances,
          confirmText: confirmText,
          cancelText: cancelText,
          accentColor: accentColor,
          cancelButtonKey: cancelButtonKey,
          confirmButtonKey: confirmButtonKey,
        ),
      ) ??
      false;
}

class AppPermissionDialog extends StatelessWidget {
  const AppPermissionDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.assurances,
    required this.confirmText,
    this.cancelText = '暂不允许',
    this.accentColor = AppColors.primary,
    this.cancelButtonKey,
    this.confirmButtonKey,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> assurances;
  final String confirmText;
  final String cancelText;
  final Color accentColor;
  final Key? cancelButtonKey;
  final Key? confirmButtonKey;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEF2FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 30, color: accentColor),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (assurances.isNotEmpty) ...[
                const SizedBox(height: 20),
                ...assurances.map(
                  (assurance) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            assurance,
                            style: const TextStyle(
                              color: Color(0xFF374151),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _PermissionDialogActions(
                cancelText: cancelText,
                confirmText: confirmText,
                accentColor: accentColor,
                cancelButtonKey: cancelButtonKey,
                confirmButtonKey: confirmButtonKey,
                onCancel: () => Navigator.of(context).pop(false),
                onConfirm: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionDialogActions extends StatelessWidget {
  const _PermissionDialogActions({
    required this.cancelText,
    required this.confirmText,
    required this.accentColor,
    required this.onCancel,
    required this.onConfirm,
    this.cancelButtonKey,
    this.confirmButtonKey,
  });

  final String cancelText;
  final String confirmText;
  final Color accentColor;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final Key? cancelButtonKey;
  final Key? confirmButtonKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledLabelHeight = MediaQuery.textScalerOf(context).scale(16);
        final useStackedLayout =
            constraints.maxWidth < 260 || scaledLabelHeight > 20;
        final cancelButton = _DialogButton(
          key: cancelButtonKey,
          label: cancelText,
          foregroundColor: AppColors.ink,
          backgroundColor: Colors.white,
          borderColor: AppColors.border,
          onPressed: onCancel,
        );
        final confirmButton = _DialogButton(
          key: confirmButtonKey,
          label: confirmText,
          foregroundColor: Colors.white,
          backgroundColor: accentColor,
          onPressed: onConfirm,
        );

        if (useStackedLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [confirmButton, const SizedBox(height: 10), cancelButton],
          );
        }

        return Row(
          children: [
            Expanded(child: cancelButton),
            const SizedBox(width: 12),
            Expanded(child: confirmButton),
          ],
        );
      },
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    super.key,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.onPressed,
    this.borderColor,
  });

  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color? borderColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: borderColor == null
                ? BorderSide.none
                : BorderSide(color: borderColor!),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
