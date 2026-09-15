import 'dart:math' as math;

import 'package:flutter/material.dart';

const lostFoundBlue = Color(0xFF2563EB);
const lostFoundBlueSoft = Color(0xFFEEF4FF);
const lostFoundText = Color(0xFF172033);
const lostFoundTextSecondary = Color(0xFF64748B);
const lostFoundBorder = Color(0xFFE5E7EB);
const lostFoundSurface = Color(0xFFFFFFFF);

double lostFoundPx(BuildContext context, num designValue) {
  final width = MediaQuery.sizeOf(context).width;
  return designValue * math.min(width, 750) / 750;
}

BoxDecoration lostFoundCardDecoration({double radius = 12}) {
  return BoxDecoration(
    color: lostFoundSurface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: lostFoundBorder),
    boxShadow: const [
      BoxShadow(color: Color(0x0F0F172A), blurRadius: 14, offset: Offset(0, 4)),
    ],
  );
}

class LostFoundGradientBackground extends StatelessWidget {
  const LostFoundGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
          stops: [0, 0.58],
        ),
      ),
      child: child,
    );
  }
}

class LostFoundNetworkImage extends StatelessWidget {
  const LostFoundNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.pets_rounded,
  });

  final String url;
  final BoxFit fit;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return _placeholder();
    return Image.network(
      url,
      fit: fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return const ColoredBox(
          color: Color(0xFFDBEAFE),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: const Color(0xFF7E97FA),
      child: Center(
        child: Icon(placeholderIcon, color: Colors.white, size: 34),
      ),
    );
  }
}

class LostFoundSectionTitle extends StatelessWidget {
  const LostFoundSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: lostFoundBlueSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: lostFoundBlue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: lostFoundText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
