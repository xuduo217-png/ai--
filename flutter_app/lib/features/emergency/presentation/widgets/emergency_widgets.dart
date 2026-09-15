import 'package:flutter/material.dart';

const emergencyRed = Color(0xFFE5484D);
const emergencyBackground = Color(0xFFFFF7F7);

class EmergencyPanel extends StatelessWidget {
  const EmergencyPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD9DB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A8A1117),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class AidGuideIcon extends StatelessWidget {
  const AidGuideIcon({
    super.key,
    required this.iconUrl,
    this.size = 48,
    this.iconSize = 28,
  });

  final String iconUrl;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      Icons.medical_information_outlined,
      color: emergencyRed,
      size: iconSize,
    );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFFFECEC),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: iconUrl.isEmpty
          ? fallback
          : Image.network(
              iconUrl,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

class EmergencyEmptyState extends StatelessWidget {
  const EmergencyEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 52, color: const Color(0xFFB7A4A5)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF292325),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF766B6D),
                fontSize: 13,
                height: 1.5,
                letterSpacing: 0,
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}
