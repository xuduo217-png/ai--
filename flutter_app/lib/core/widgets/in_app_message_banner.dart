import 'package:flutter/material.dart';

import '../messaging/in_app_message_banner_controller.dart';
import '../messaging/in_app_message_event.dart';
import '../network/asset_url_resolver.dart';

typedef InAppMessageTapCallback =
    Future<void> Function(InAppMessageEvent event);

class InAppMessageOverlayHost extends StatelessWidget {
  const InAppMessageOverlayHost({
    super.key,
    required this.child,
    required this.controller,
    required this.onMessageTap,
  });

  final Widget child;
  final InAppMessageBannerController controller;
  final InAppMessageTapCallback onMessageTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final item = controller.current;
            return Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 12,
              right: 12,
              child: Align(
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, -0.18),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: child,
                    ),
                  ),
                  child: item == null
                      ? const SizedBox.shrink()
                      : ConstrainedBox(
                          key: ValueKey(item.event.eventKey),
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: _InAppMessageBanner(
                            item: item,
                            onDismissed: controller.dismiss,
                            onTap: () async {
                              controller.dismiss();
                              await onMessageTap(item.event);
                            },
                          ),
                        ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _InAppMessageBanner extends StatefulWidget {
  const _InAppMessageBanner({
    required this.item,
    required this.onDismissed,
    required this.onTap,
  });

  final InAppMessageBannerItem item;
  final VoidCallback onDismissed;
  final VoidCallback onTap;

  @override
  State<_InAppMessageBanner> createState() => _InAppMessageBannerState();
}

class _InAppMessageBannerState extends State<_InAppMessageBanner>
    with SingleTickerProviderStateMixin {
  static const _horizontalThreshold = 72.0;
  static const _upwardThreshold = 44.0;
  static const _velocityThreshold = 700.0;

  late final AnimationController _animationController;
  Offset _dragOffset = Offset.zero;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_dismissing) return;
    final next = _dragOffset + details.delta;
    setState(() {
      _dragOffset = Offset(next.dx, next.dy > 0 ? next.dy * 0.18 : next.dy);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_dismissing) return;
    final velocity = details.velocity.pixelsPerSecond;
    final dismissLeft =
        _dragOffset.dx <= -_horizontalThreshold ||
        velocity.dx <= -_velocityThreshold;
    final dismissRight =
        _dragOffset.dx >= _horizontalThreshold ||
        velocity.dx >= _velocityThreshold;
    final dismissUp =
        _dragOffset.dy <= -_upwardThreshold ||
        velocity.dy <= -_velocityThreshold;
    if (dismissLeft || dismissRight || dismissUp) {
      final direction =
          dismissUp && _dragOffset.dy.abs() >= _dragOffset.dx.abs()
          ? const Offset(0, -1)
          : Offset(dismissLeft ? -1 : 1, 0);
      _animateDismiss(direction);
      return;
    }
    _animateBack();
  }

  Future<void> _animateDismiss(Offset direction) async {
    _dismissing = true;
    final size = MediaQuery.sizeOf(context);
    final target = Offset(direction.dx * (size.width + 40), direction.dy * 160);
    await _animateOffset(target, Curves.easeInCubic);
    if (mounted) widget.onDismissed();
  }

  Future<void> _animateBack() async {
    await _animateOffset(Offset.zero, Curves.easeOutCubic);
  }

  Future<void> _animateOffset(Offset target, Curve curve) async {
    final begin = _dragOffset;
    _animationController
      ..stop()
      ..reset();
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: curve,
    );
    void update() {
      if (!mounted) return;
      setState(() {
        _dragOffset = Offset.lerp(begin, target, animation.value)!;
      });
    }

    animation.addListener(update);
    await _animationController.forward();
    animation.removeListener(update);
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.item.event;
    final opacity =
        (1 -
                (_dragOffset.distance /
                        (MediaQuery.sizeOf(context).width * 0.85))
                    .clamp(0.0, 0.55))
            .clamp(0.45, 1.0);
    return Transform.translate(
      offset: _dragOffset,
      child: Opacity(
        opacity: opacity,
        child: Semantics(
          button: true,
          label: '${event.channelLabel}，${event.title}，${event.preview}',
          child: Material(
            key: const ValueKey('in-app-message-banner'),
            color: const Color(0xFFFDFEFF),
            elevation: 12,
            shadowColor: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismissing ? null : widget.onTap,
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Row(
                  children: [
                    _MessageAvatar(event: event),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF172033),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.item.messageCount > 1
                                    ? '${widget.item.messageCount}条'
                                    : event.channelLabel,
                                style: const TextStyle(
                                  color: Color(0xFF758096),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            event.preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF596579),
                              fontSize: 13,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF9AA4B5),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({required this.event});

  final InAppMessageEvent event;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveAssetUrl(event.avatarUrl);
    final fallback = Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFE8EEFF),
        shape: BoxShape.circle,
      ),
      child: Icon(_channelIcon(event.channel), color: const Color(0xFF4C73E6)),
    );
    if (!resolved.startsWith('http://') && !resolved.startsWith('https://')) {
      return fallback;
    }
    return ClipOval(
      child: Image.network(
        resolved,
        width: 42,
        height: 42,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

IconData _channelIcon(InAppMessageChannel channel) => switch (channel) {
  InAppMessageChannel.friend => Icons.person_rounded,
  InAppMessageChannel.consultation => Icons.medical_services_rounded,
  InAppMessageChannel.marketplace => Icons.storefront_rounded,
};
