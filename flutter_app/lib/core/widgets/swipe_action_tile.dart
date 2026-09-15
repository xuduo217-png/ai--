import 'package:flutter/material.dart';

class SwipeActionTile extends StatefulWidget {
  const SwipeActionTile({
    super.key,
    required this.child,
    required this.onAction,
    this.actionKey,
    this.actionLabel = '隐藏',
    this.actionIcon = Icons.visibility_off_outlined,
    this.actionColor = const Color(0xFFE5484D),
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  final Widget child;
  final Future<void> Function() onAction;
  final Key? actionKey;
  final String actionLabel;
  final IconData actionIcon;
  final Color actionColor;
  final BorderRadius borderRadius;

  @override
  State<SwipeActionTile> createState() => _SwipeActionTileState();
}

class _SwipeActionTileState extends State<SwipeActionTile>
    with SingleTickerProviderStateMixin {
  static const _actionExtent = 76.0;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  bool _performingAction = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: _actionExtent,
                child: Material(
                  color: widget.actionColor,
                  child: InkWell(
                    key: widget.actionKey,
                    onTap: _performingAction ? null : _handleAction,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.actionIcon, color: Colors.white, size: 21),
                        const SizedBox(height: 3),
                        Text(
                          widget.actionLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            child: widget.child,
            builder: (_, child) => Transform.translate(
              offset: Offset(-_actionExtent * _controller.value, 0),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  _controller.value =
                      (_controller.value - details.delta.dx / _actionExtent)
                          .clamp(0.0, 1.0);
                },
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -250 ||
                      (velocity <= 250 && _controller.value >= 0.35)) {
                    _controller.forward();
                  } else {
                    _controller.reverse();
                  }
                },
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction() async {
    setState(() => _performingAction = true);
    try {
      await widget.onAction();
    } finally {
      if (mounted) {
        _controller.reverse();
        setState(() => _performingAction = false);
      }
    }
  }
}
