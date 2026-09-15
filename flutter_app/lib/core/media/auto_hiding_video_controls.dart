import 'dart:async';

import 'package:flutter/widgets.dart';

class AutoHidingVideoControls extends StatefulWidget {
  const AutoHidingVideoControls({
    super.key,
    required this.isPlaying,
    required this.child,
    required this.controls,
    this.surfaceKey,
    this.controlsKey,
    this.autoHideDelay = const Duration(seconds: 3),
    this.fadeDuration = const Duration(milliseconds: 180),
  });

  final bool isPlaying;
  final Widget child;
  final Widget controls;
  final Key? surfaceKey;
  final Key? controlsKey;
  final Duration autoHideDelay;
  final Duration fadeDuration;

  @override
  State<AutoHidingVideoControls> createState() =>
      _AutoHidingVideoControlsState();
}

class _AutoHidingVideoControlsState extends State<AutoHidingVideoControls> {
  Timer? _hideTimer;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    _scheduleAutoHide();
  }

  @override
  void didUpdateWidget(covariant AutoHidingVideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isPlaying) {
      _hideTimer?.cancel();
      _setControlsVisible(true);
      return;
    }
    if (!oldWidget.isPlaying ||
        oldWidget.autoHideDelay != widget.autoHideDelay) {
      _setControlsVisible(true);
      _scheduleAutoHide();
    }
  }

  void _setControlsVisible(bool visible) {
    if (_controlsVisible == visible) return;
    setState(() => _controlsVisible = visible);
  }

  void _scheduleAutoHide() {
    _hideTimer?.cancel();
    if (!widget.isPlaying) return;
    _hideTimer = Timer(widget.autoHideDelay, () {
      if (!mounted || !widget.isPlaying) return;
      _setControlsVisible(false);
    });
  }

  void _showControls() {
    _setControlsVisible(true);
    _scheduleAutoHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(
          child: GestureDetector(
            key: widget.surfaceKey,
            behavior: HitTestBehavior.opaque,
            onTap: _showControls,
          ),
        ),
        Positioned.fill(
          child: AnimatedOpacity(
            key: widget.controlsKey,
            opacity: _controlsVisible ? 1 : 0,
            duration: widget.fadeDuration,
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: Listener(
                onPointerDown: (_) => _hideTimer?.cancel(),
                onPointerUp: (_) => _scheduleAutoHide(),
                onPointerCancel: (_) => _scheduleAutoHide(),
                child: widget.controls,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
