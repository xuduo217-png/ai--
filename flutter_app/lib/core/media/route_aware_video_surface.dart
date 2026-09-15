import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'android_video_surface_exit.dart';

final Map<ModalRoute<dynamic>, Set<_RouteAwareVideoSurfaceState>>
_videoSurfacesByRoute = {};
final Map<ModalRoute<dynamic>, Future<void>> _routePreparations = {};
final Map<ModalRoute<dynamic>, int> _coordinatedRouteReferences = {};

/// Prevents the route transition from starting until its Android video
/// surfaces have been hidden and acknowledged by the platform.
class VideoRoutePopScope<T> extends StatefulWidget {
  const VideoRoutePopScope({super.key, required this.child});

  final Widget child;

  @override
  State<VideoRoutePopScope<T>> createState() => _VideoRoutePopScopeState<T>();
}

class _VideoRoutePopScopeState<T> extends State<VideoRoutePopScope<T>> {
  ModalRoute<dynamic>? _route;
  bool _allowPop = false;
  bool _isLeaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRoute = ModalRoute.of(context);
    if (identical(_route, nextRoute)) return;
    _unregisterRoute();
    _route = nextRoute;
    if (nextRoute != null) {
      _coordinatedRouteReferences.update(
        nextRoute,
        (references) => references + 1,
        ifAbsent: () => 1,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<T>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _allowPop) return;
        unawaited(_prepareAndPop(result));
      },
      child: widget.child,
    );
  }

  Future<void> _prepareAndPop(T? result) async {
    if (_isLeaving) return;
    _isLeaving = true;
    final route = _route;
    try {
      await _prepareVideoRouteForExit(route);
    } on Object {
      // A player or platform failure must not trap the user on this route.
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop<T>(result);
    });
  }

  @override
  void dispose() {
    _unregisterRoute();
    super.dispose();
  }

  void _unregisterRoute() {
    final route = _route;
    if (route == null) return;
    final references = _coordinatedRouteReferences[route] ?? 0;
    if (references <= 1) {
      _coordinatedRouteReferences.remove(route);
    } else {
      _coordinatedRouteReferences[route] = references - 1;
    }
    _route = null;
  }
}

Future<void> _prepareVideoRouteForExit(ModalRoute<dynamic>? route) {
  if (route == null) return AndroidVideoSurfaceExit.prepareForRouteExit();
  final current = _routePreparations[route];
  if (current != null) return current;

  final preparation = _runVideoRoutePreparation(route);
  _routePreparations[route] = preparation;
  preparation.whenComplete(() {
    if (identical(_routePreparations[route], preparation)) {
      _routePreparations.remove(route);
    }
  });
  return preparation;
}

Future<void> _runVideoRoutePreparation(ModalRoute<dynamic> route) async {
  final surfaces = List<_RouteAwareVideoSurfaceState>.of(
    _videoSurfacesByRoute[route] ?? const <_RouteAwareVideoSurfaceState>{},
  );
  if (surfaces.isEmpty) return;
  await Future.wait(surfaces.map((surface) => surface._pauseForRouteExit()));
  await AndroidVideoSurfaceExit.prepareForRouteExit();
  for (final surface in surfaces) {
    surface._detachAfterNativeExit();
  }
  await WidgetsBinding.instance.endOfFrame.timeout(
    const Duration(milliseconds: 250),
    onTimeout: () {},
  );
}

/// 在路由退出动画开始时移除视频画面，避免 Android PlatformView 的原生
/// Surface 滞留在 Flutter 页面之上。
class RouteAwareVideoSurface extends StatefulWidget {
  const RouteAwareVideoSurface({
    super.key,
    required this.controller,
    required this.child,
    this.placeholder = const ColoredBox(color: Colors.black),
    this.detachedKey,
  });

  final VideoPlayerController controller;
  final Widget child;
  final Widget placeholder;
  final Key? detachedKey;

  @override
  State<RouteAwareVideoSurface> createState() => _RouteAwareVideoSurfaceState();
}

class _RouteAwareVideoSurfaceState extends State<RouteAwareVideoSurface> {
  ModalRoute<dynamic>? _route;
  Animation<double>? _routeAnimation;
  Future<void>? _pauseInFlight;
  bool _detached = false;
  bool _resumeAfterCanceledPop = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRoute = ModalRoute.of(context);
    if (!identical(_route, nextRoute)) {
      _unregisterFromRoute();
      _route = nextRoute;
      if (nextRoute != null) {
        (_videoSurfacesByRoute[nextRoute] ??= {}).add(this);
      }
    }
    final nextAnimation = nextRoute?.animation;
    if (identical(_routeAnimation, nextAnimation)) return;
    _routeAnimation?.removeStatusListener(_handleRouteStatus);
    _routeAnimation = nextAnimation;
    _routeAnimation?.addStatusListener(_handleRouteStatus);
  }

  @override
  void didUpdateWidget(covariant RouteAwareVideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    _pauseInFlight = null;
    _resumeAfterCanceledPop = false;
  }

  void _handleRouteStatus(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.reverse:
        if (_coordinatedRouteReferences.containsKey(_route)) return;
        _detachForRouteExit();
      case AnimationStatus.forward || AnimationStatus.completed:
        if (_detached && (ModalRoute.of(context)?.isCurrent ?? false)) {
          _restoreAfterCanceledPop();
        }
      case AnimationStatus.dismissed:
        break;
    }
  }

  void _detachForRouteExit() {
    if (_detached) return;
    final controller = widget.controller;
    _resumeAfterCanceledPop = controller.value.isPlaying;
    _pauseInFlight ??= _pauseQuietly(controller);
    unawaited(AndroidVideoSurfaceExit.prepareForRouteExit());
    setState(() => _detached = true);
  }

  Future<void> _pauseForRouteExit() {
    if (_detached) return Future<void>.value();
    final controller = widget.controller;
    _resumeAfterCanceledPop = controller.value.isPlaying;
    return _pauseInFlight ??= _pauseQuietly(controller);
  }

  void _detachAfterNativeExit() {
    if (!mounted || _detached) return;
    setState(() => _detached = true);
  }

  void _restoreAfterCanceledPop() {
    final controller = widget.controller;
    final shouldResume = _resumeAfterCanceledPop;
    setState(() => _detached = false);
    if (shouldResume) {
      unawaited(_resumeAfterPause(controller, _pauseInFlight));
    }
    unawaited(AndroidVideoSurfaceExit.restoreAfterCanceledExit());
    _resumeAfterCanceledPop = false;
    _pauseInFlight = null;
  }

  Future<void> _pauseQuietly(VideoPlayerController controller) async {
    try {
      await controller.pause();
    } on Object {
      // 原生播放器暂停异常不应阻断路由退出。
    }
  }

  Future<void> _resumeAfterPause(
    VideoPlayerController controller,
    Future<void>? pauseInFlight,
  ) async {
    await pauseInFlight;
    if (!mounted ||
        _detached ||
        !identical(widget.controller, controller) ||
        !controller.value.isInitialized ||
        !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    try {
      await controller.play();
    } on Object {
      // 返回手势取消后的恢复失败由播放器现有错误状态处理。
    }
  }

  @override
  void dispose() {
    _unregisterFromRoute();
    _routeAnimation?.removeStatusListener(_handleRouteStatus);
    super.dispose();
  }

  void _unregisterFromRoute() {
    final route = _route;
    if (route == null) return;
    final surfaces = _videoSurfacesByRoute[route];
    surfaces?.remove(this);
    if (surfaces?.isEmpty ?? false) _videoSurfacesByRoute.remove(route);
    _route = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_detached) {
      return KeyedSubtree(key: widget.detachedKey, child: widget.placeholder);
    }
    return widget.child;
  }
}
