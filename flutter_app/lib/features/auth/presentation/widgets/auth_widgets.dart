import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuthColors {
  const AuthColors._();

  static const primary = Color(0xFF5B75E5);
  static const gradientStart = Color(0xFFDEE9FF);
  static const gradientEnd = Color(0xFFFAFBFF);
  static const text = Color(0xFF000000);
  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);
  static const placeholder = Color(0xFF999999);
}

double rnDesignPx(BuildContext context, double value) {
  final size = MediaQuery.sizeOf(context);
  final referenceWidth = size.shortestSide;
  return (value * referenceWidth / 750).roundToDouble();
}

class AuthGradientBackground extends StatelessWidget {
  const AuthGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AuthColors.gradientStart, AuthColors.gradientEnd],
        ),
      ),
      child: child,
    );
  }
}

class AuthInput extends StatelessWidget {
  const AuthInput({
    super.key,
    required this.controller,
    required this.placeholder,
    this.keyboardType,
    this.obscureText = false,
    this.maxLength,
    this.textInputAction,
    this.onSubmitted,
    this.onTap,
    this.inputFormatters,
    this.autofillHints,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String placeholder;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLength: maxLength,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        onTap: onTap,
        inputFormatters: inputFormatters,
        autofillHints: autofillHints,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          color: AuthColors.textPrimary,
          fontSize: 16,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(
            color: AuthColors.placeholder,
            fontSize: 16,
            letterSpacing: 0,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          counterText: '',
          isCollapsed: true,
        ),
      ),
    );
  }
}

class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.title,
    required this.onPressed,
    this.loading = false,
    this.disabled = false,
  });

  final String title;
  final VoidCallback onPressed;
  final bool loading;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final inactive = disabled || loading;

    return Semantics(
      button: true,
      enabled: !inactive,
      label: title,
      child: AnimatedOpacity(
        opacity: inactive ? 0.5 : 1,
        duration: const Duration(milliseconds: 120),
        child: Material(
          color: AuthColors.primary,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: inactive ? null : onPressed,
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: Center(
                child: loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SimpleAuthAppBar extends StatelessWidget {
  const SimpleAuthAppBar({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final height = rnDesignPx(context, 72);
    final slotWidth = rnDesignPx(context, 56);

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: rnDesignPx(context, 20)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: slotWidth,
                height: height,
                child: Semantics(
                  button: true,
                  label: '返回',
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '‹',
                        style: TextStyle(
                          color: AuthColors.textPrimary,
                          fontSize: rnDesignPx(context, 80),
                          height: 0.9,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: rnDesignPx(context, 72),
              ),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AuthColors.textPrimary,
                  fontSize: rnDesignPx(context, 36),
                  height: 44 / 36,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      '谷德E宠',
      style: TextStyle(
        color: AuthColors.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

void showAuthMessage(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) {
    return;
  }

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      return Positioned(
        top: MediaQuery.paddingOf(context).top + 16,
        left: 16,
        right: 16,
        child: SafeArea(
          bottom: false,
          child: Material(
            color: Colors.white,
            elevation: 7,
            shadowColor: const Color(0x33000000),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(minHeight: 58),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: error ? const Color(0xFFEF4444) : AuthColors.primary,
                    width: 5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    error ? Icons.error_outline : Icons.check_circle_outline,
                    color: error ? const Color(0xFFEF4444) : AuthColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: AuthColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);
  unawaited(
    Future<void>.delayed(const Duration(seconds: 3)).then((_) {
      if (entry.mounted) {
        entry.remove();
      }
    }),
  );
}
