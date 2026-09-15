import 'package:flutter/material.dart';

import '../domain/activity_models.dart';
import 'activity_design.dart';

class ActivityCoverImage extends StatefulWidget {
  const ActivityCoverImage({
    super.key,
    required this.url,
    this.children = const [],
    this.semanticLabel = '活动封面',
    this.fit = BoxFit.contain,
  });

  final String url;
  final List<Widget> children;
  final String semanticLabel;
  final BoxFit fit;

  @override
  State<ActivityCoverImage> createState() => _ActivityCoverImageState();
}

class _ActivityCoverImageState extends State<ActivityCoverImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double _aspectRatio = 2;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant ActivityCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _aspectRatio = 2;
      _resolveImage();
    }
  }

  void _resolveImage() {
    _stream?.removeListener(_listener!);
    if (widget.url.isEmpty) return;
    final stream = NetworkImage(
      widget.url,
    ).resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, _) {
      final width = info.image.width;
      final height = info.image.height;
      if (mounted && width > 0 && height > 0) {
        setState(() => _aspectRatio = width / height);
      }
    });
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _aspectRatio,
      child: ColoredBox(
        color: const Color(0xFFF3F4F6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.url,
              fit: widget.fit,
              semanticLabel: widget.semanticLabel,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: activityHint,
                  size: 42,
                ),
              ),
            ),
            ...widget.children,
          ],
        ),
      ),
    );
  }
}

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    required this.onPressed,
  });

  final ActivityItem activity;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    double px(num value) => activityDesignPx(context, value);
    return Padding(
      padding: EdgeInsets.only(bottom: px(16)),
      child: Material(
        key: ValueKey('activity-card-${activity.id}'),
        color: Colors.white,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(px(12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ActivityCardCover(activity: activity),
              Padding(
                padding: EdgeInsets.fromLTRB(px(16), px(14), px(16), px(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: activityInk,
                        fontSize: px(30),
                        height: 38 / 30,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: px(6)),
                    _InfoRow(
                      icon: Icons.schedule_rounded,
                      text: activityDateRange(
                        activity.startTime,
                        activity.endTime,
                      ),
                    ),
                    if (!activity.isOnline) ...[
                      SizedBox(height: px(6)),
                      _InfoRow(
                        icon: Icons.location_on_rounded,
                        text: activity.location.isEmpty
                            ? '-'
                            : activity.location,
                      ),
                    ],
                    if (activity.summary.isNotEmpty) ...[
                      SizedBox(height: px(6)),
                      Text(
                        activity.summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: activityMuted,
                          fontSize: px(24),
                          height: 32 / 24,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                    if (!activity.isOnline &&
                        activity.registrationCount > 0) ...[
                      SizedBox(height: px(12)),
                      Container(height: 1, color: const Color(0xFFF3F4F6)),
                      SizedBox(height: px(12)),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${activity.registrationCount} 人报名',
                              style: TextStyle(
                                color: activityPrimary,
                                fontSize: px(23),
                                height: 30 / 23,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: activityHint,
                            size: px(30),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCardCover extends StatelessWidget {
  const _ActivityCardCover({required this.activity});

  final ActivityItem activity;

  @override
  Widget build(BuildContext context) {
    final badges = [
      Positioned(
        top: activityDesignPx(context, 8),
        left: activityDesignPx(context, 8),
        child: ActivityTypeBadge(type: activity.activityType),
      ),
      Positioned(
        top: activityDesignPx(context, 8),
        right: activityDesignPx(context, 8),
        child: ActivityStatusBadge(status: activity.status),
      ),
    ];
    if (activity.coverImageUrl.isNotEmpty) {
      return ActivityCoverImage(
        url: activity.coverImageUrl,
        semanticLabel: '${activity.title}活动封面',
        children: badges,
      );
    }
    return AspectRatio(
      aspectRatio: 2,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: activityTypeColor(activity.activityType),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  activityTypeIcon(activity.activityType),
                  size: activityDesignPx(context, 56),
                  color: Colors.white,
                ),
                SizedBox(height: activityDesignPx(context, 8)),
                Text(
                  '暂无封面',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: activityDesignPx(context, 24),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ...badges,
        ],
      ),
    );
  }
}

class ActivityTypeBadge extends StatelessWidget {
  const ActivityTypeBadge({super.key, required this.type});

  final ActivityType type;

  @override
  Widget build(BuildContext context) {
    double px(num value) => activityDesignPx(context, value);
    final color = activityTypeColor(type);
    return Container(
      constraints: BoxConstraints(maxWidth: px(180)),
      padding: EdgeInsets.symmetric(horizontal: px(10), vertical: px(6)),
      decoration: BoxDecoration(
        color: activityTypeBackground(type),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(activityTypeIcon(type), size: px(26), color: color),
          SizedBox(width: px(6)),
          Flexible(
            child: Text(
              type.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: px(22),
                height: 26 / 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityStatusBadge extends StatelessWidget {
  const ActivityStatusBadge({super.key, required this.status});

  final ActivityStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: activityDesignPx(context, 10),
        vertical: activityDesignPx(context, 6),
      ),
      decoration: BoxDecoration(
        color: activityStatusColor(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: Colors.white,
          fontSize: activityDesignPx(context, 20),
          height: 24 / 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: activityDesignPx(context, 28), color: activityPrimary),
        SizedBox(width: activityDesignPx(context, 6)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: const Color(0xFF374151),
              fontSize: activityDesignPx(context, 23),
              height: 30 / 23,
            ),
          ),
        ),
      ],
    );
  }
}
