import 'package:flutter/material.dart';

const petPrimaryColor = Color(0xFF7E97FA);
const petTextPrimaryColor = Color(0xFF1F2937);
const petTextSecondaryColor = Color(0xFF6B7280);
const petTextTertiaryColor = Color(0xFF9CA3AF);
const petBorderColor = Color(0xFFE5E7EB);

double petDesignPx(BuildContext context, num designPixels) {
  final size = MediaQuery.sizeOf(context);
  final referenceWidth = size.width < size.height ? size.width : size.height;
  return (designPixels * referenceWidth / 750).roundToDouble();
}

class PetGradientBackground extends StatelessWidget {
  const PetGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
        ),
      ),
      child: child,
    );
  }
}

class PetPageHeader extends StatelessWidget {
  const PetPageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final height = petDesignPx(context, 72);
    final sideWidth = petDesignPx(context, 112);
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: petDesignPx(context, 20),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: sideWidth,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: onBack == null
                          ? null
                          : IconButton(
                              key: const ValueKey('pet-page-back'),
                              tooltip: '返回',
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                              onPressed: onBack,
                              icon: Icon(
                                Icons.chevron_left_rounded,
                                size: petDesignPx(context, 62),
                                color: petTextPrimaryColor,
                              ),
                            ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: sideWidth,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: trailing,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: sideWidth,
            right: sideWidth,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                style: TextStyle(
                  fontSize: petDesignPx(context, 36),
                  height: 44 / 36,
                  fontWeight: FontWeight.w600,
                  color: petTextPrimaryColor,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PetPrimaryButton extends StatelessWidget {
  const PetPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: petDesignPx(context, 90),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          elevation: onPressed == null ? 0 : petDesignPx(context, 2),
          backgroundColor: petPrimaryColor,
          disabledBackgroundColor: const Color(0xFFD1D5DB),
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          textStyle: TextStyle(
            fontSize: petDesignPx(context, 30),
            height: 34 / 30,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        child: busy
            ? SizedBox.square(
                dimension: petDesignPx(context, 34),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
