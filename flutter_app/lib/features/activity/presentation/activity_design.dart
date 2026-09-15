import 'package:flutter/material.dart';

import '../domain/activity_models.dart';

const activityPrimary = Color(0xFF7E97FA);
const activityInk = Color(0xFF1F2937);
const activityMuted = Color(0xFF6B7280);
const activityHint = Color(0xFF9CA3AF);
const activityBorder = Color(0xFFE5E7EB);
const activitySuccess = Color(0xFF10B981);
const activityIndigo = Color(0xFF4F46E5);

double activityDesignPx(BuildContext context, num designPixels) {
  final size = MediaQuery.sizeOf(context);
  final referenceWidth = size.width < size.height ? size.width : size.height;
  return (designPixels * referenceWidth / 750).roundToDouble();
}

Color activityStatusColor(ActivityStatus status) => switch (status) {
  ActivityStatus.upcoming => activityPrimary,
  ActivityStatus.ongoing => activitySuccess,
  ActivityStatus.expired => activityHint,
};

Color activityTypeColor(ActivityType type) => switch (type) {
  ActivityType.online => activityIndigo,
  ActivityType.offline => const Color(0xFF059669),
};

Color activityTypeBackground(ActivityType type) => switch (type) {
  ActivityType.online => const Color(0xFFEEF2FF),
  ActivityType.offline => const Color(0xFFECFDF5),
};

IconData activityTypeIcon(ActivityType type) => switch (type) {
  ActivityType.online => Icons.how_to_vote_rounded,
  ActivityType.offline => Icons.location_on_rounded,
};

String activityDate(DateTime? value) {
  if (value == null) return '-';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}

String activityDateRange(DateTime? start, DateTime? end) {
  final startText = activityDate(start);
  final endText = activityDate(end);
  return startText == endText ? startText : '$startText - $endText';
}

String activityRelativeTime(DateTime? value, {DateTime? now}) {
  if (value == null) return '';
  final difference = (now ?? DateTime.now()).difference(value);
  if (difference.isNegative || difference.inMinutes < 1) return '刚刚';
  if (difference.inHours < 1) return '${difference.inMinutes}分钟前';
  if (difference.inDays < 1) return '${difference.inHours}小时前';
  if (difference.inDays < 7) return '${difference.inDays}天前';
  return '${value.month}月${value.day}日';
}

class ActivityGradientBackground extends StatelessWidget {
  const ActivityGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('activity-gradient-background'),
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

class ActivityAppBar extends StatelessWidget {
  const ActivityAppBar({
    super.key,
    required this.title,
    required this.onBack,
    this.action,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  key: const ValueKey('activity-back'),
                  tooltip: '返回',
                  onPressed: onBack,
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 22,
                    color: activityInk,
                  ),
                ),
                SizedBox(width: 48, height: 48, child: action),
              ],
            ),
          ),
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 72),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: activityInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
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
