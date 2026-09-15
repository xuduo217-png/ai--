import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 应用内统一的内容弹窗，保留业务传入的按钮及表单组件。
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.icon,
    this.title,
    this.content,
    this.actions = const <Widget>[],
    this.maxWidth = 360,
  });

  final Widget? icon;
  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height -
        mediaQuery.padding.vertical -
        mediaQuery.viewInsets.vertical -
        48;
    final maxHeight = availableHeight.clamp(120.0, double.infinity).toDouble();

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        key: const ValueKey('app-dialog-panel'),
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x240F172A),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              Align(child: icon),
              const SizedBox(height: 14),
            ],
            if (title != null)
              DefaultTextStyle.merge(
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 19,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
                child: title!,
              ),
            if (title != null && content != null) const SizedBox(height: 10),
            if (content != null)
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: DefaultTextStyle.merge(
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                      height: 1.5,
                      letterSpacing: 0,
                    ),
                    child: content!,
                  ),
                ),
              ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              _AppDialogActions(actions: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class AppDialogIcon extends StatelessWidget {
  const AppDialogIcon({
    super.key,
    required this.icon,
    this.foregroundColor = AppColors.primary,
    this.backgroundColor = const Color(0xFFEEF2FF),
  });

  const AppDialogIcon.danger({super.key, required this.icon})
    : foregroundColor = AppColors.accent,
      backgroundColor = const Color(0xFFFFEBEE);

  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Icon(icon, color: foregroundColor, size: 25),
    );
  }
}

class _AppDialogActions extends StatelessWidget {
  const _AppDialogActions({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final buttonTheme = Theme.of(context).copyWith(
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.border),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            actions.length > 2 ||
            constraints.maxWidth < 280 ||
            textScale > 1.25;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final action in actions.reversed) ...[
                Theme(data: buttonTheme, child: action),
                if (action != actions.first) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < actions.length; index++) ...[
              if (index > 0) const SizedBox(width: 10),
              Expanded(
                child: Theme(data: buttonTheme, child: actions[index]),
              ),
            ],
          ],
        );
      },
    );
  }
}
